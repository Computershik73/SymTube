#include "apimanager.h"
#include "config.h"
#include "json.h"
#include <QNetworkRequest>
#include <QSettings>
#include <QEventLoop>
#include <QUuid>
#include <QDebug>
#include <QNetworkProxy>
#include <QApplication>
#include <QClipboard>

#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QScriptEngine>
#include <QScriptValue>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QRegExp>

const QByteArray VR_CLIENT_VERSION = "1.65.10";
const QByteArray VR_USER_AGENT = "com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip";

// Константы OAuth для получения токена
const QString OAUTH_CLIENT_ID = "861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com";
const QString OAUTH_CLIENT_SECRET = "SboVhoG9s0rNafixCSGGKXAT";

const QByteArray TV_CLIENT_VERSION = "7.20260114.12.00";
const QByteArray TV_USER_AGENT = "Mozilla/5.0 (ChromiumStylePlatform) Cobalt/25.lts.30.1034943-gold "
"(unlike Gecko), Unknown_TV_Unknown_0/Unknown (Unknown, Unknown)";

ApiManager::ApiManager(Config *config, QrImageProvider *qrProvider, QObject *parent)
    : QObject(parent), m_config(config), m_qrProvider(qrProvider)
{
    m_networkManager = new QNetworkAccessManager(this);
    connect(m_networkManager, SIGNAL(finished(QNetworkReply*)), this, SLOT(onReplyFinished(QNetworkReply*)));

    // Загружаем кэшированный адрес и код base.js из настроек и диска
    QSettings settings("SymTubeApp", "Settings");
    m_cachedScriptUrl = settings.value("CachedPlayerScriptUrl", "").toString();

    QFile file("C:/Data/SymTube_base_js.js");
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        m_cachedScriptContent = in.readAll();
        file.close();
        logDebug("Loaded cached base.js from local storage.");

        m_signatureTimestamp = extractSignatureTimestamp(m_cachedScriptContent);
        if (m_signatureTimestamp > 0)
            logDebug(QString("Extracted sts from cached base.js: %1").arg(m_signatureTimestamp));

    }
}

ApiManager::~ApiManager() {}

void ApiManager::copyToClipboard(const QString &text) {
    QApplication::clipboard()->setText(text);
}

int ApiManager::extractSignatureTimestamp(const QString &script) {
    if (script.isEmpty()) return 0;
    QRegExp rx("(?:signatureTimestamp|sts)\\s*:\\s*(\\d{5})");
    if (rx.indexIn(script) >= 0) return rx.cap(1).toInt();
    return 0;
}

void ApiManager::logDebug(const QString &msg) {
    QFile file("C:/Data/SymTube_debug.txt");
    if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        QTextStream out(&file);
        out << QDateTime::currentDateTime().toString("hh:mm:ss") << " : " << msg << "\n";
        file.close();
    }
}

void ApiManager::setImageProvider(QrImageProvider *provider) {
    m_qrProvider = provider;
}

QString ApiManager::getLocaleParams(bool firstParam) {
    QSettings settings("SymTubeApp", "Settings");
    QString lang = settings.value("Language", "en_US").toString();
    QStringList parts = lang.split("_");
    QString prefix = firstParam ? "?" : "&";
    if (parts.size() >= 2) return prefix + "hl=" + parts[0] + "&gl=" + parts[1];
    return prefix + "hl=en&gl=US";
}

QVariantMap ApiManager::buildContext(const QString &clientName, const QString &clientVersion) {
    QSettings settings("SymTubeApp", "Settings");
    QString lang = settings.value("Language", "en_US").toString();
    QStringList parts = lang.split("_");

    QVariantMap client;
    client["clientName"] = clientName;
    client["clientVersion"] = clientVersion;
    client["hl"] = parts.size() > 0 ? parts[0] : "en";
    client["gl"] = parts.size() > 1 ? parts[1] : "US";

    if (clientName == "ANDROID_VR") {
        client["deviceMake"] = "Oculus";
        client["deviceModel"] = "Quest 3";
        client["androidSdkVersion"] = 32;
        client["userAgent"] = QString::fromLatin1(VR_USER_AGENT);
    } else if (clientName == "TVHTML5") {
        // Оставляем для совместимости
        client["userAgent"] = QString::fromLatin1(TV_USER_AGENT);
    }

    QVariantMap context;
    context["client"] = client;
    return context;
}

QString ApiManager::getAccessToken() {
    QString refreshToken = m_config->userToken();
    if (refreshToken.isEmpty()) return "";

    if (!m_accessToken.isEmpty() && QDateTime::currentDateTime() < m_tokenExpiry) {
        return m_accessToken;
    }

    QNetworkAccessManager syncManager;
    QNetworkRequest req(QUrl("https://oauth2.googleapis.com/token"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
    QString data = "client_id=" + OAUTH_CLIENT_ID + "&client_secret=" + OAUTH_CLIENT_SECRET + "&refresh_token=" + refreshToken + "&grant_type=refresh_token";

    QNetworkReply *reply = syncManager.post(req, data.toUtf8());
    QEventLoop loop;
    connect(reply, SIGNAL(finished()), &loop, SLOT(quit()));
    loop.exec();

    if (reply->error() == QNetworkReply::NoError) {
        bool ok;
        QVariantMap map = QtJson::parse(QString::fromUtf8(reply->readAll()), ok).toMap();
        m_accessToken = map.value("access_token").toString();
        m_tokenExpiry = QDateTime::currentDateTime().addSecs(map.value("expires_in").toInt() - 60);
    }
    reply->deleteLater();
    return m_accessToken;
}

void ApiManager::postInnertube(const QString &endpoint, const QVariantMap &payload, const QString &requestType, bool requiresAuth) {
    // Получаем токен ДО формирования URL
    QString token;
    if (requiresAuth) {
        token = getAccessToken();
    }

    QVariantMap context = payload.value("context").toMap();
    QVariantMap client = context.value("client").toMap();
    QString clientName = client.value("clientName").toString();

    // Определяем правильный API-ключ в зависимости от клиента
    QString apiKey = m_config->apiKey();
    if (clientName == "ANDROID_VR") {
        apiKey = "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"; // Родной ключ ANDROID_VR
    }

    // Собираем финальный URL
    QString url = "https://www.youtube.com/youtubei/v1/" + endpoint + "?key=" + apiKey;

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json; charset=utf-8");

    if (clientName == "ANDROID") {
        request.setRawHeader("x-youtube-client-name", "3");
        request.setRawHeader("User-Agent", "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip");
    } else if (clientName == "ANDROID_VR") {
        request.setRawHeader("x-youtube-client-name", "28");
        request.setRawHeader("x-youtube-client-version", VR_CLIENT_VERSION);
        request.setRawHeader("User-Agent", VR_USER_AGENT);
    } else if (clientName == "TVHTML5") {
        request.setRawHeader("x-youtube-client-name", "7");
        request.setRawHeader("x-youtube-client-version", TV_CLIENT_VERSION);
        request.setRawHeader("User-Agent", TV_USER_AGENT);
    } else {
        request.setRawHeader("x-youtube-client-name", "1");
        request.setRawHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
    }

    if (!token.isEmpty() && clientName != "ANDROID_VR") {
        request.setRawHeader("Authorization", "Bearer " + token.toUtf8());
    }

    request.setRawHeader("Origin", "https://www.youtube.com");
    if (!m_visitorData.isEmpty()) {
        request.setRawHeader("X-Goog-Visitor-Id", m_visitorData.toUtf8());
    }

    bool success;
    QByteArray data = QtJson::serialize(payload, success);
    QNetworkReply *reply = m_networkManager->post(request, data);
    reply->setProperty("RequestType", requestType);
}

void ApiManager::fetchAlternativeQualities(const QString &videoId) {
    if (m_pipedInstances.isEmpty()) {
        QNetworkRequest req(QUrl("http://144.31.189.129/notPipe.json"));
        QNetworkReply *reply = m_networkManager->get(req);
        reply->setProperty("RequestType", "NotPipeJson");
        reply->setProperty("VideoId", videoId);
    } else {
        requestPipedStreams(videoId);
    }
}

void ApiManager::requestPipedStreams(const QString &videoId) {
    if (m_pipedInstances.isEmpty()) return;
    QString instance = m_pipedInstances.first();
    m_pipedInstances.removeFirst();
    m_pipedInstances.append(instance);

    QUrl url(instance + "/streams/" + videoId);
    QNetworkRequest req(url);
    QNetworkReply *reply = m_networkManager->get(req);
    reply->setProperty("RequestType", "PipedStreams");
    reply->setProperty("VideoId", videoId);
}

void ApiManager::getComments(const QString &videoId, const QString &continuationToken) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    if (continuationToken.isEmpty()) {
        payload["videoId"] = videoId;
        postInnertube("next", payload, "CommentsTokenFetch");
    } else {
        payload["continuation"] = continuationToken;
        postInnertube("next", payload, "CommentsFetch");
    }
}

void ApiManager::getSearchSuggestions(const QString &query) {
    QString url = "https://clients1.google.com/complete/search?client=youtube&ds=yt&q=" + QUrl::toPercentEncoding(query) + getLocaleParams();
    QNetworkRequest request;
    request.setUrl(QUrl(url));
    QNetworkReply *reply = m_networkManager->get(request);
    reply->setProperty("RequestType", "SearchSuggestions");
}

void ApiManager::getHistory() {
    QVariantMap payload;
    payload["context"] = buildContext("TVHTML5", TV_CLIENT_VERSION);
    payload["browseId"] = "FEhistory";
    postInnertube("browse", payload, "History", true);
}

void ApiManager::getSubscriptions() {
    QVariantMap payload;
    payload["context"] = buildContext("TVHTML5", TV_CLIENT_VERSION);
    payload["browseId"] = "FEchannels";
    postInnertube("browse", payload, "Subscriptions", true);
}

void ApiManager::getAccountInfo() {
    QVariantMap payload;
    payload["context"] = buildContext("TVHTML5", TV_CLIENT_VERSION);
    QVariantMap accountReadMask;
    accountReadMask["returnOwner"] = true;
    payload["accountReadMask"] = accountReadMask;
    postInnertube("account/accounts_list", payload, "AccountInfo", true);
}

void ApiManager::rateVideo(const QString &videoId, const QString &rating) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    QVariantMap target;
    target["videoId"] = videoId;
    payload["target"] = target;
    postInnertube("like/" + rating, payload, "RateVideo", true);
}

void ApiManager::subscribeToChannel(const QString &channelIdentifier) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    payload["channelIds"] = QVariantList() << channelIdentifier;
    postInnertube("subscription/subscribe", payload, "SubscribeChannel", true);
}

void ApiManager::unsubscribeFromChannel(const QString &channelIdentifier) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    payload["channelIds"] = QVariantList() << channelIdentifier;
    postInnertube("subscription/unsubscribe", payload, "UnsubscribeChannel", true);
}

void ApiManager::fetchServerList() {
    QNetworkRequest request(QUrl("https://raw.githubusercontent.com/Computershik73/SymTube-Revived/main/servers.txt"));
    QNetworkReply *reply = m_networkManager->get(request);
    reply->setProperty("RequestType", "ServerList");
}

void ApiManager::checkAuthContent() {
    if (m_deviceCode.isEmpty()) {
        QNetworkRequest request(QUrl("https://www.youtube.com/o/oauth2/device/code"));
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
        request.setRawHeader("User-Agent", "Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0)");
        QString data = "client_id=" + OAUTH_CLIENT_ID + "&scope=http://gdata.youtube.com https://www.googleapis.com/auth/youtube-paid-content&device_id=" + QUuid::createUuid().toString().replace("{","").replace("}","") + "&device_model=ytlr:samsung:smarttv";
        QNetworkReply *reply = m_networkManager->post(request, data.toUtf8());
        reply->setProperty("RequestType", "OAuthDeviceCode");
    } else {
        emit authImageReady();
        QNetworkRequest request(QUrl("https://www.youtube.com/o/oauth2/token"));
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
        request.setRawHeader("User-Agent", "Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0)");
        QString data = "client_id=" + OAUTH_CLIENT_ID + "&client_secret=" + OAUTH_CLIENT_SECRET + "&code=" + m_deviceCode + "&grant_type=http://oauth.net/grant_type/device/1.0";
        QNetworkReply *reply = m_networkManager->post(request, data.toUtf8());
        reply->setProperty("RequestType", "OAuthTokenPoll");
    }
}

void ApiManager::getHomeVideos(const QString &pageToken) {
    QVariantMap payload;
    if (m_config->userToken().isEmpty()) {
        emit homeVideosReady(QVariantList(), "");
        return;
    }
    payload["context"] = buildContext("TVHTML5", TV_CLIENT_VERSION);
    payload["browseId"] = "FEwhat_to_watch";
    if (!pageToken.isEmpty()) payload["continuation"] = pageToken;
    postInnertube("browse", payload, "HomeVideos", true);
}

void ApiManager::getHomeCategoryVideos(const QString &category, const QString &pageToken) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    payload["query"] = category;
    payload["params"] = "EgIQAQ==";
    if (!pageToken.isEmpty()) payload["continuation"] = pageToken;
    postInnertube("search", payload, "HomeCategoryVideos");
}

void ApiManager::searchVideos(const QString &query) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    payload["query"] = query;
    postInnertube("search", payload, "SearchVideos");
}

void ApiManager::getVideoInfo(const QString &videoId) {
    logDebug(">>> Requesting VideoInfo for ID: " + videoId);

    if (m_signatureTimestamp > 0) {
        // sts есть — можно сразу делать player-запрос
        requestPlayer(videoId);
    } else {
        // base.js нет — СНАЧАЛА добываем его, потом player-запрос
        logDebug("No sts available. Fetching watch page first...");
        QUrl watchUrl("https://www.youtube.com/watch?v=" + videoId);
        QNetworkRequest req(watchUrl);
        req.setRawHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36");
        QNetworkReply *watchReply = m_networkManager->get(req);
        watchReply->setProperty("RequestType", "WatchPageFetch");
        watchReply->setProperty("PendingVideoId", videoId);
    }
}

void ApiManager::requestPlayer(const QString &videoId) {
    QSettings settings("SymTubeApp", "Settings");
    QString lang = settings.value("Language", "en_US").toString();
    QStringList parts = lang.split("_");

    QVariantMap client;
    client["clientName"] = "ANDROID_VR";
    client["clientVersion"] = VR_CLIENT_VERSION;
    client["deviceMake"] = "Meta";
    client["deviceModel"] = "Quest 3";
    client["androidSdkVersion"] = 32; // Передаем как число
    client["osName"] = "Android";
    client["osVersion"] = "12L";
    client["platform"] = "MOBILE";
    client["userAgent"] = QString::fromLatin1(VR_USER_AGENT);
    client["hl"] = parts.size() > 0 ? parts[0] : "en";
    client["gl"] = parts.size() > 1 ? parts[1] : "US";
    if (!m_visitorData.isEmpty()) client["visitorData"] = m_visitorData;

    QVariantMap context;
    context["client"] = client;

    QVariantMap payload;
    payload["context"] = context;
    payload["videoId"] = videoId;
    payload["contentCheckOk"] = true;
    payload["racyCheckOk"] = true;

    m_lastRequestedVideoId = videoId;
    logDebug("[ANDROID_VR] Sending player request for: " + videoId);

    // Передаем false в параметр requiresAuth, чтобы не отправлять ТВ-токены
    postInnertube("player", payload, "VideoInfo", false);
}

void ApiManager::getRelatedVideos(const QString &videoId, int page) {
    Q_UNUSED(page)
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    payload["videoId"] = videoId;
    postInnertube("next", payload, "RelatedVideos");
}

void ApiManager::getChannelVideos(const QString &author) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    payload["browseId"] = author;
    postInnertube("browse", payload, "ChannelVideos");
}

void ApiManager::getShorts(const QString &sequenceToken) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");

    if (!sequenceToken.isEmpty()) {
        payload["sequenceParams"] = sequenceToken;
        postInnertube("reel/reel_watch_sequence", payload, "Shorts");
    } else {
        payload["inputType"] = "REEL_WATCH_INPUT_TYPE_SEEDLESS";
        payload["params"] = "CA8%3D";
        payload["disablePlayerResponse"] = true;
        postInnertube("reel/reel_item_watch", payload, "Shorts");
    }
}

QList<QVariantMap> ApiManager::enumerateObjectsWithKey(const QVariant &root, const QString &targetKey)
{
    QList<QVariantMap> result;
    QList<QVariant> stack;
    stack.append(root);

    while (!stack.isEmpty()) {
        QVariant current = stack.takeLast();
        if (current.type() == QVariant::Map) {
            QVariantMap map = current.toMap();
            if (map.contains(targetKey)) {
                result.append(map.value(targetKey).toMap());
            }
            foreach (const QVariant &child, map.values()) {
                if (child.type() == QVariant::Map || child.type() == QVariant::List) stack.append(child);
            }
        } else if (current.type() == QVariant::List) {
            foreach (const QVariant &child, current.toList()) {
                if (child.type() == QVariant::Map || child.type() == QVariant::List) stack.append(child);
            }
        }
    }
    return result;
}

QString ApiManager::extractTextFromField(const QVariantMap &obj, const QString &fieldName) {
    if (!obj.contains(fieldName)) return "";
    QVariantMap field = obj.value(fieldName).toMap();
    if (field.contains("simpleText")) return field.value("simpleText").toString();
    if (field.contains("runs")) {
        QString result;
        foreach(const QVariant &run, field.value("runs").toList()) {
            result += run.toMap().value("text").toString();
        }
        return result;
    }
    return "";
}

QString ApiManager::extractThumbnailUrl(const QVariantMap &obj, const QString &fieldName) {
    if (!obj.contains(fieldName)) return "";
    QVariantMap photoObj = obj.value(fieldName).toMap();
    QVariantList thumbs = photoObj.value("thumbnails").toList();
    if (thumbs.isEmpty()) thumbs = photoObj.value("sources").toList();
    if (!thumbs.isEmpty()) {
        QString url = thumbs.first().toMap().value("url").toString();
        if (url.startsWith("//")) url = "https:" + url;
        return url;
    }
    return "";
}

void ApiManager::onReplyFinished(QNetworkReply *reply)
{
    QString requestType = reply->property("RequestType").toString();
    QByteArray responseData = reply->readAll();



    if (requestType == "PlaylistDetails" || requestType == "RelatedVideos" || requestType == "VideoInfo" || requestType == "HomeVideos") {
        logDebug(QString("=== [VIDEO PAGE LOG: %1] ===").arg(requestType));
        logDebug(QString::fromUtf8(responseData));
        logDebug(QString("=== [END LOG: %1] ===").arg(requestType));
    }

    if (reply->error() != QNetworkReply::NoError && requestType != "OAuthTokenPoll" && requestType != "PipedStreams" && requestType != "NotPipeJson") {
        logDebug(QString("[Network Error] Request '%1' failed with error: %2 (HTTP Code: %3)")
                 .arg(requestType)
                 .arg(reply->errorString())
                 .arg(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt()));
        int httpCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (requestType == "VideoInfo" && (httpCode == 403 || httpCode == 429)) {
            logDebug("Network error indicates a bot block / rate limit (HTTP 403/429)!");
            emit botBlockDetected();
        }
        emit requestFailed(requestType, reply->errorString());
        reply->deleteLater();
        return;
    }

    bool parseSuccess;
    QVariant parsedJson = QtJson::parse(QString::fromUtf8(responseData), parseSuccess);
    QVariantMap parsedMap = parsedJson.toMap();

    if (requestType == "NotPipeJson") {
        if (reply->error() == QNetworkReply::NoError && parseSuccess) {
            foreach (const QVariant &v, parsedMap.value("piped").toList()) {
                QStringList urls = v.toString().split(",");
                foreach (const QString &u, urls) {
                    if (!u.trimmed().isEmpty()) m_pipedInstances.append(u.trimmed());
                }
            }
            foreach (const QVariant &v, parsedMap.value("yt2009").toList()) {
                if (!v.toString().trimmed().isEmpty()) m_yt2009Instances.append(v.toString().trimmed());
            }
        }
        requestPipedStreams(reply->property("VideoId").toString());
    }
    else if (requestType == "PipedStreams") {
        QString videoId = reply->property("VideoId").toString();
        QVariantList qualities;
        if (reply->error() == QNetworkReply::NoError && parseSuccess) {
            QVariantList videoStreams = parsedMap.value("videoStreams").toList();
            foreach(const QVariant &v, videoStreams) {
                QVariantMap stream = v.toMap();
                if (!stream.value("videoOnly").toBool()) {
                    QVariantMap q;
                    q["label"] = stream.value("quality").toString() + " (Piped)";
                    q["url"] = stream.value("url").toString();
                    q["hasAudio"] = true;
                    qualities.append(q);
                }
            }
        }
        emit alternativeQualitiesReady(videoId, qualities);
    }
    else if (requestType == "CommentsTokenFetch") {
        QString token;
        QList<QVariantMap> engagementPanels = enumerateObjectsWithKey(parsedJson, "engagementPanelSectionListRenderer");
        foreach(QVariantMap panel, engagementPanels) {
            if (panel.value("panelIdentifier").toString().contains("comments-section")) {
                QList<QVariantMap> cont = enumerateObjectsWithKey(panel, "continuationCommand");
                if (!cont.isEmpty()) {
                    token = cont.first().value("token").toString();
                    break;
                }
            }
        }
        if (token.isEmpty()) {
            QList<QVariantMap> itemSections = enumerateObjectsWithKey(parsedJson, "itemSectionRenderer");
            foreach(QVariantMap section, itemSections) {
                if (section.value("sectionIdentifier").toString() == "comment-item-section") {
                    QList<QVariantMap> cont = enumerateObjectsWithKey(section, "continuationCommand");
                    if (!cont.isEmpty()) {
                        token = cont.first().value("token").toString();
                        break;
                    }
                }
            }
        }

        if (!token.isEmpty()) {
            QVariantMap payload;
            payload["context"] = buildContext("WEB", "2.20250101");
            payload["continuation"] = token;
            postInnertube("next", payload, "CommentsFetch");
        } else {
            emit commentsReady(QVariantList(), "");
        }
    }
    else if (requestType == "CommentsFetch") {
        QVariantList comments;
        QString nextToken;

        QList<QVariantMap> commentEntities = enumerateObjectsWithKey(parsedJson, "commentEntityPayload");
        foreach(QVariantMap payload, commentEntities) {
            QVariantMap c;
            QVariantMap authorData = payload.value("author").toMap();
            c["author"] = authorData.value("displayName").toString();
            if (!c["author"].toString().startsWith("@")) c["author"] = "@" + c["author"].toString();

            QVariantMap props = payload.value("properties").toMap();
            c["publishedAt"] = props.value("publishedTime").toString();

            QVariantMap contentObj = props.value("content").toMap();
            if (contentObj.contains("content")) {
                c["text"] = contentObj.value("content").toString();
            } else if (contentObj.contains("runs")) {
                QString textStr;
                foreach(const QVariant &run, contentObj.value("runs").toList()) {
                    textStr += run.toMap().value("text").toString();
                }
                c["text"] = textStr;
            }

            QVariantMap avatarObj = payload.value("avatar").toMap();
            c["authorThumbnail"] = extractThumbnailUrl(avatarObj, "image");

            comments.append(c);
        }

        if (comments.isEmpty()) {
            QList<QVariantMap> commentRenderers = enumerateObjectsWithKey(parsedJson, "commentRenderer");
            foreach(QVariantMap renderer, commentRenderers) {
                QVariantMap c;
                c["author"] = extractTextFromField(renderer, "authorText");
                c["text"] = extractTextFromField(renderer, "contentText");
                c["publishedAt"] = extractTextFromField(renderer, "publishedTimeText");
                c["authorThumbnail"] = extractThumbnailUrl(renderer, "authorThumbnail");
                comments.append(c);
            }
        }

        QList<QVariantMap> contCmd = enumerateObjectsWithKey(parsedJson, "continuationCommand");
        if (!contCmd.isEmpty()) {
            nextToken = contCmd.first().value("token").toString();
        }
        emit commentsReady(comments, nextToken);
    }
    else if (requestType == "HomeVideos" || requestType == "SearchVideos" || requestType == "RelatedVideos" || requestType == "ChannelVideos" || requestType == "History" || requestType == "HomeCategoryVideos") {
        QVariantList outVideos;
        QStringList seenIds;

        // Важно: парсим tileRenderer (плитки плейлистов/джемов) в первую очередь!
        QList<QVariantMap> renderers = enumerateObjectsWithKey(parsedJson, "tileRenderer");
        renderers.append(enumerateObjectsWithKey(parsedJson, "videoRenderer"));
        renderers.append(enumerateObjectsWithKey(parsedJson, "gridVideoRenderer"));
        renderers.append(enumerateObjectsWithKey(parsedJson, "compactVideoRenderer"));
        renderers.append(enumerateObjectsWithKey(parsedJson, "lockupViewModel"));
        renderers.append(enumerateObjectsWithKey(parsedJson, "videoWithContextRenderer"));

        foreach (QVariantMap renderer, renderers) {
            QVariantMap item;

            if (renderer.contains("contentImage") && renderer.contains("metadata") && renderer.value("metadata").toMap().contains("lockupMetadataViewModel")) {
                item["video_id"] = renderer.value("contentId").toString();
                QVariantMap meta = renderer.value("metadata").toMap().value("lockupMetadataViewModel").toMap();
                item["title"] = meta.value("title").toMap().value("content").toString();

                // Восстанавливаем разбор авторов, просмотров и дат публикации
                QVariantList rows = meta.value("metadata").toMap().value("contentMetadataViewModel").toMap().value("metadataRows").toList();
                if (rows.size() > 0) {
                    QVariantList parts = rows[0].toMap().value("metadataParts").toList();
                    if (!parts.isEmpty()) item["author"] = parts[0].toMap().value("text").toMap().value("content").toString();
                }
                if (rows.size() > 1) {
                    QVariantList parts = rows[1].toMap().value("metadataParts").toList();
                    if (parts.size() > 0) item["views"] = parts[0].toMap().value("text").toMap().value("content").toString();
                    if (parts.size() > 1) item["published_at"] = parts[1].toMap().value("text").toMap().value("content").toString();
                }

                // Восстанавливаем разбор длительности видео
                QVariantList overlays = renderer.value("contentImage").toMap().value("thumbnailViewModel").toMap().value("overlays").toList();
                foreach (const QVariant &ov, overlays) {
                    QVariantMap ovMap = ov.toMap();
                    if (ovMap.contains("thumbnailBottomOverlayViewModel")) {
                        QVariantList badges = ovMap.value("thumbnailBottomOverlayViewModel").toMap().value("badges").toList();
                        if (!badges.isEmpty()) item["duration"] = badges[0].toMap().value("thumbnailBadgeViewModel").toMap().value("text").toString();
                    }
                }
            }
            else if (renderer.contains("onSelectCommand")) {
                QVariantMap onSelect = renderer.value("onSelectCommand").toMap();
                QString videoId = "";
                QString playlistId = "";

                if (onSelect.contains("watchEndpoint")) {
                    QVariantMap endpoint = onSelect.value("watchEndpoint").toMap();
                    videoId = endpoint.value("videoId").toString();
                    playlistId = endpoint.value("playlistId").toString();
                } else if (onSelect.contains("watchPlaylistEndpoint")) {
                    QVariantMap endpoint = onSelect.value("watchPlaylistEndpoint").toMap();
                    playlistId = endpoint.value("playlistId").toString();
                    videoId = endpoint.value("videoId").toString();
                }

                item["video_id"] = videoId;
                item["playlist_id"] = playlistId;

                QVariantMap meta = renderer.value("metadata").toMap().value("tileMetadataRenderer").toMap();
                item["title"] = extractTextFromField(meta, "title");

                QVariantList overlays = renderer.value("header").toMap().value("tileHeaderRenderer").toMap().value("thumbnailOverlays").toList();
                foreach (const QVariant &ov, overlays) {
                    QVariantMap ovMap = ov.toMap();
                    if (ovMap.contains("thumbnailOverlayTimeStatusRenderer")) {
                        item["duration"] = extractTextFromField(ovMap.value("thumbnailOverlayTimeStatusRenderer").toMap(), "text");
                    }
                }

                QVariantList lines = meta.value("lines").toList();
                if (lines.size() > 0) {
                    QVariantList items0 = lines[0].toMap().value("lineRenderer").toMap().value("items").toList();
                    if (items0.size() > 0) item["author"] = extractTextFromField(items0[0].toMap().value("lineItemRenderer").toMap(), "text");
                }
                if (lines.size() > 1) {
                    QVariantList items1 = lines[1].toMap().value("lineRenderer").toMap().value("items").toList();
                    int count = items1.size();
                    if (count >= 1) item["published_at"] = extractTextFromField(items1[count - 1].toMap().value("lineItemRenderer").toMap(), "text");
                    if (count >= 3) item["views"] = extractTextFromField(items1[count - 3].toMap().value("lineItemRenderer").toMap(), "text");
                }

                // Пытаемся извлечь красивую обложку плейлиста
                QString thumb = extractThumbnailUrl(renderer, "thumbnail");
                if (thumb.isEmpty() && renderer.contains("header")) {
                    QVariantMap header = renderer.value("header").toMap();
                    if (header.contains("tileHeaderRenderer")) {
                        thumb = extractThumbnailUrl(header.value("tileHeaderRenderer").toMap(), "thumbnail");
                    }
                }
                if (!thumb.isEmpty()) {
                    item["thumbnail"] = thumb;
                }
            }
            else {
                item["video_id"] = renderer.value("videoId").toString();
                item["title"] = extractTextFromField(renderer, "title");
                if (item["title"].toString().isEmpty()) item["title"] = extractTextFromField(renderer, "headline");
                item["author"] = extractTextFromField(renderer, "shortBylineText");
                if (item["author"].toString().isEmpty()) item["author"] = extractTextFromField(renderer, "ownerText");
                item["duration"] = extractTextFromField(renderer, "lengthText");
                item["views"] = extractTextFromField(renderer, "viewCountText");
                item["published_at"] = extractTextFromField(renderer, "publishedTimeText");
            }

            QString videoId = item["video_id"].toString();
            QString playlistId = item["playlist_id"].toString();

            if (videoId.isEmpty() && playlistId.isEmpty()) continue;

            // ИСПРАВЛЕНИЕ 1: Приоритет отдаем плейлисту. Миксы больше не конфликтуют с видео!
            QString itemKey = !playlistId.isEmpty() ? ("playlist:" + playlistId) : ("video:" + videoId);
            if (seenIds.contains(itemKey)) continue;
            seenIds.append(itemKey);

            // ИСПРАВЛЕНИЕ 2: Если это плейлист/джем, подменяем текст длительности на "Джем"
            if (!playlistId.isEmpty()) {
                item["duration"] = "Джем";
            }

            if (item["thumbnail"].toString().isEmpty() && !videoId.isEmpty()) {
                item["thumbnail"] = "https://i.ytimg.com/vi/" + videoId + "/mqdefault.jpg";
            }

            outVideos.append(item);
        }

        QString nextToken = "";
        QList<QVariantMap> nextContData = enumerateObjectsWithKey(parsedJson, "nextContinuationData");
        if (!nextContData.isEmpty()) {
            nextToken = nextContData.first().value("continuation").toString();
        } else {
            QList<QVariantMap> contCmd = enumerateObjectsWithKey(parsedJson, "continuationCommand");
            if (!contCmd.isEmpty()) {
                nextToken = contCmd.first().value("token").toString();
            }
        }

        if (requestType == "HomeVideos" || requestType == "HomeCategoryVideos") {
            if (outVideos.isEmpty()) {
                emit requestFailed(requestType, "Empty feed (Nudge)");
            } else {
                emit homeVideosReady(outVideos, nextToken);
            }
        }
        else if (requestType == "SearchVideos") {
            if (outVideos.isEmpty()) {
                emit requestFailed("SearchVideos", "No results");
            } else {
                emit searchResultsReady(outVideos);
            }
        }
        else if (requestType == "RelatedVideos") {
            QVariantMap extraDetails;
            QList<QVariantMap> structuredDesc = enumerateObjectsWithKey(parsedJson, "expandableVideoDescriptionBodyRenderer");
            if (!structuredDesc.isEmpty()) extraDetails["description"] = structuredDesc.first().value("attributedDescriptionBodyText").toMap().value("content").toString();

            QList<QVariantMap> videoOwner = enumerateObjectsWithKey(parsedJson, "videoOwnerRenderer");
            if (!videoOwner.isEmpty()) {
                QVariantMap owner = videoOwner.first();
                extraDetails["channel_thumbnail"] = extractThumbnailUrl(owner, "thumbnail");
                extraDetails["subscriberCount"] = extractTextFromField(owner, "subscriberCountText");
                QVariantMap navEndpoint = owner.value("navigationEndpoint").toMap();
                if (navEndpoint.contains("browseEndpoint")) extraDetails["channel_custom_url"] = navEndpoint.value("browseEndpoint").toMap().value("browseId").toString();
            }

            QList<QVariantMap> likeButton = enumerateObjectsWithKey(parsedJson, "likeButtonViewModel");
            if (!likeButton.isEmpty()) {
                QVariantMap toggle = likeButton.first().value("toggleButtonViewModel").toMap().value("toggleButtonViewModel").toMap().value("defaultButtonViewModel").toMap().value("buttonViewModel").toMap();
                extraDetails["likes"] = toggle.value("title").toString();
            }

            emit videoExtraInfoReady(extraDetails);
            emit relatedVideosReady(outVideos);
        }
        else if (requestType == "ChannelVideos") {
            if (outVideos.isEmpty()) {
                emit requestFailed("ChannelVideos", "No videos");
            } else {
                QVariantMap m;
                m["videos"] = outVideos;
                QVariantMap channelInfo;

                QList<QVariantMap> channelMetadataList = enumerateObjectsWithKey(parsedJson, "channelMetadataRenderer");
                if (!channelMetadataList.isEmpty()) {
                    QVariantMap meta = channelMetadataList.first();
                    channelInfo["title"] = meta.value("title").toString();
                    channelInfo["description"] = meta.value("description").toString();
                    channelInfo["thumbnail"] = extractThumbnailUrl(meta, "avatar");
                    channelInfo["channel_id"] = meta.value("externalId").toString();
                }

                QList<QVariantMap> imageBannerList = enumerateObjectsWithKey(parsedJson, "imageBannerViewModel");
                if (!imageBannerList.isEmpty()) {
                    QVariantMap img = imageBannerList.first().value("image").toMap();
                    if (img.contains("sources")) {
                        QVariantList sources = img.value("sources").toList();
                        if (!sources.isEmpty()) channelInfo["banner"] = sources.first().toMap().value("url").toString();
                    }
                }

                QList<QVariantMap> pageHeaderList = enumerateObjectsWithKey(parsedJson, "pageHeaderViewModel");
                if (!pageHeaderList.isEmpty()) {
                    QVariantMap headerMeta = pageHeaderList.first().value("metadata").toMap().value("contentMetadataViewModel").toMap();
                    QVariantList rows = headerMeta.value("metadataRows").toList();
                    if (rows.size() > 1) {
                        QVariantList parts = rows[1].toMap().value("metadataParts").toList();
                        if (!parts.isEmpty()) channelInfo["subscriber_count"] = parts[0].toMap().value("text").toMap().value("content").toString();
                    }
                }

                if (channelInfo["thumbnail"].toString().isEmpty()) {
                    QList<QVariantMap> c4List = enumerateObjectsWithKey(parsedJson, "c4TabbedHeaderRenderer");
                    if (!c4List.isEmpty()) {
                        channelInfo["thumbnail"] = extractThumbnailUrl(c4List.first(), "avatar");
                        channelInfo["banner"] = extractThumbnailUrl(c4List.first(), "banner");
                        channelInfo["title"] = extractTextFromField(c4List.first(), "title");
                        channelInfo["subscriber_count"] = extractTextFromField(c4List.first(), "subscriberCountText");
                    }
                }

                QString thumb = channelInfo["thumbnail"].toString();
                if (thumb.startsWith("//")) thumb = "http:" + thumb;
                else thumb.replace("https://", "http://");
                channelInfo["thumbnail"] = thumb;

                QString banner = channelInfo["banner"].toString();
                if (banner.startsWith("//")) banner = "http:" + banner;
                else banner.replace("https://", "http://");
                channelInfo["banner"] = banner;

                m["channel_info"] = channelInfo;

                QString channelName = channelInfo["title"].toString();
                QVariantList updatedVideos;
                foreach (const QVariant &v, outVideos) {
                    QVariantMap vid = v.toMap();
                    if (vid["author"].toString().isEmpty()) vid["author"] = channelName;
                    updatedVideos.append(vid);
                }
                m["videos"] = updatedVideos;

                emit channelVideosReady(m);
            }
        }
        else if (requestType == "History") {
            emit historyReady(outVideos);
        }
    }
    else if (requestType == "VideoInfo") {
        logDebug("======================= [YOUTUBE RESPONSE] VIDEO INFO =======================");
        logDebug("Raw Server JSON Response:\n" + QString::fromUtf8(responseData));
        logDebug("============================================================================");


        QVariantMap root = parsedJson.toMap();

        // Запоминаем visitorData для последующих запросов
        QString vd = root.value("responseContext").toMap().value("visitorData").toString();
        if (!vd.isEmpty()) m_visitorData = vd;

        // Протух base.js/sts? Сервер просит "перезагрузить страницу" —
        // обновляем base.js и повторяем запрос (один раз на видео)
        QVariantMap playability = root.value("playabilityStatus").toMap();

        if (playability.contains("reason")) {
            logDebug("Reason of unavailability: " + playability.value("reason").toString());
        }

        QString status = playability.value("status").toString();
        QString reason = playability.value("reason").toString();
        bool isBotBlock = false;

        // Проверяем текстовые упоминания бота/робота/трафика в причине
        if (reason.contains("bot", Qt::CaseInsensitive) ||
                reason.contains("robot", Qt::CaseInsensitive) ||
                reason.contains("бот", Qt::CaseInsensitive) ||
                reason.contains("unusual traffic", Qt::CaseInsensitive)) {
            isBotBlock = true;
        }

        // Проверяем наличие блока капчи (playerCaptchaViewModel) или блокирующегоErrorMessage
        QVariantMap errorScreen = playability.value("errorScreen").toMap();
        if (errorScreen.contains("playerCaptchaViewModel")) {
            isBotBlock = true;
        }
        if (errorScreen.contains("playerErrorMessageRenderer")) {
            QVariantMap errorMessageRenderer = errorScreen.value("playerErrorMessageRenderer").toMap();
            QString subreason = extractTextFromField(errorMessageRenderer, "subreason");
            if (subreason.contains("bot", Qt::CaseInsensitive) ||
                    subreason.contains("robot", Qt::CaseInsensitive) ||
                    subreason.contains("бот", Qt::CaseInsensitive) ||
                    subreason.contains("unusual traffic", Qt::CaseInsensitive)) {
                isBotBlock = true;
            }
        }

        if (isBotBlock) {
            logDebug("CRITICAL: Bot block detected in playabilityStatus!");
            emit botBlockDetected();
            emit requestFailed("VideoInfo", "BotBlocked");
            reply->deleteLater();
            return;
        }


        QVariantMap details;

        QVariantMap videoDetails = root.value("videoDetails").toMap();

        QString vid = videoDetails.value("videoId").toString();
        if (vid.isEmpty()) vid = m_lastRequestedVideoId;

        if (status == "UNPLAYABLE" && m_stsRetriedFor != vid) {
            m_stsRetriedFor = vid;
            logDebug("UNPLAYABLE received. Refreshing base.js/sts and retrying...");
            m_cachedScriptContent.clear();
            m_signatureTimestamp = 0;
            getVideoInfo(vid);   // уйдёт по ветке WatchPageFetch
            reply->deleteLater();
            return;
        }

        details["video_id"] = videoDetails.value("videoId").toString();
        details["title"] = videoDetails.value("title").toString();
        details["author"] = videoDetails.value("author").toString();
        details["views"] = videoDetails.value("viewCount").toString();

        logDebug(QString("Parsed Metadata -> ID: %1 | Title: %2")
                 .arg(details["video_id"].toString())
                 .arg(details["title"].toString()));

        QString directUrl = "";
        QVariantMap streamingData = root.value("streamingData").toMap();
        QVariantList formats = streamingData.value("formats").toList();

        for (int i = 0; i < formats.size(); ++i) {
            QVariantMap fmt = formats[i].toMap();
            int itag = fmt.value("itag").toInt();
            if (itag == 18) { // Ищем 360p
                directUrl = fmt.value("url").toString();
                break;
            }
        }

        if (directUrl.isEmpty()) {
            logDebug("WARNING: Direct streaming URL for itag 18 was NOT found in formats.");
            emit requestFailed("VideoInfo", "Empty stream URL");
            reply->deleteLater();
            return;
        }

        details["video_url"] = directUrl;
        m_pendingVideoDetails = details; // локальный бэкап

        // Попытка дешифрации n-параметра через уже имеющийся локальный кэш base.js
        bool decryptedOk = false;
        if (!m_cachedScriptContent.isEmpty()) {
            QString decryptedUrl = decryptNParameter(directUrl);
            if (decryptedUrl != directUrl) {
                logDebug("Decryption success using cached base.js.");
                m_pendingVideoDetails["video_url"] = decryptedUrl;
                decryptedOk = true;
            }
        }

        if (decryptedOk) {
            // Кэш сработал — запускаем видео мгновенно
            m_stsRetriedFor.clear();
            emit videoInfoReady(m_pendingVideoDetails);
        } else {
            // Кэша нет или он устарел: скачиваем watch-страницу для поиска актуального base.js
            logDebug("Local cache is empty or outdated. Fetching watch page to locate base.js...");
            QUrl watchUrl("https://www.youtube.com/watch?v=" + details["video_id"].toString());
            QNetworkRequest req(watchUrl);
            req.setRawHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36");
            QNetworkReply *watchReply = m_networkManager->get(req);
            watchReply->setProperty("RequestType", "WatchPageFetch");

            // КРИТИЧЕСКИ ВАЖНО: Привязываем детали видео к конкретному сетевому запросу
            watchReply->setProperty("PendingVideoDetails", details);
        }
    }
    else if (requestType == "WatchPageFetch") {
        logDebug("Watch page downloaded. Parsing HTML to locate player script...");
        QString html = QString::fromUtf8(responseData);

        // Полностью очищаем HTML-код от экранирующих слэшей JSON (\/ -> /)
        html.replace("\\/", "/");

        // Ищем путь начала скрипта и его окончание через строковый поиск
        int index = html.indexOf("/s/player/");
        if (index >= 0) {
            int end = html.indexOf("base.js", index);
            if (end >= 0) {
                QString jsPath = html.mid(index, end - index + 7);
                // jsPath вида: /s/player/4918c89a/player_es6.vflset/ru_RU/base.js
                // QScriptEngine (Qt 4.7) не понимает ES6 — берём ES5-сборку того же плеера
                QString jsUrl;
                QRegExp idRx("/s/player/([0-9a-fA-F]+)/");
                if (idRx.indexIn(jsPath) >= 0) {
                    jsUrl = "https://www.youtube.com/s/player/" + idRx.cap(1)
                            + "/tv-player-ias.vflset/tv-player-ias.js";
                } else {
                    jsUrl = "https://www.youtube.com" + jsPath;
                }
                logDebug("Located player script URL (tv variant): " + jsUrl);
                QUrl jsUrll(jsUrl);
                QNetworkRequest req(jsUrll);
                req.setRawHeader("User-Agent", TV_USER_AGENT); // качаем TV-плеер с TV UA
                QNetworkReply *scriptReply = m_networkManager->get(req);
                scriptReply->setProperty("RequestType", "PlayerScriptDownload");
                scriptReply->setProperty("JsUrl", jsUrl);
                scriptReply->setProperty("PendingVideoDetails", reply->property("PendingVideoDetails"));
                scriptReply->setProperty("PendingVideoId", reply->property("PendingVideoId"));
            } else {
                logDebug("Error: 'tv-player-ias.js' string not found!");
                QString pendingId = reply->property("PendingVideoId").toString();
                if (!pendingId.isEmpty()) {
                    // preflight провалился — честно сообщаем об ошибке
                    emit requestFailed("VideoInfo", "base.js not found");
                } else {
                    emit videoInfoReady(reply->property("PendingVideoDetails").toMap());
                }
            }
        } else {
            logDebug("Error: '/s/player/' string not found in watch page HTML!");
            QString pendingId = reply->property("PendingVideoId").toString();
            if (!pendingId.isEmpty()) {
                emit requestFailed("VideoInfo", "player script not found");
            } else {
                emit videoInfoReady(reply->property("PendingVideoDetails").toMap());
            }
        }
    }
    else if (requestType == "PlayerScriptDownload") {
        QString jsUrl = reply->property("JsUrl").toString();

        // Потокобезопасно извлекаем привязанные детали именно этого видео
        QVariantMap pendingDetails = reply->property("PendingVideoDetails").toMap();

        if (reply->error() == QNetworkReply::NoError && !responseData.isEmpty()) {
            m_cachedScriptContent = QString::fromUtf8(responseData);
            m_cachedScriptUrl = jsUrl;

            // Сохраняем на диск C:
            QDir dir;
            dir.mkpath("C:/Data");
            QFile file("C:/Data/SymTube_base_js.js");
            if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
                QTextStream out(&file);
                out << m_cachedScriptContent;
                file.close();
            }

            QSettings settings("SymTubeApp", "Settings");
            settings.setValue("CachedPlayerScriptUrl", jsUrl);
            logDebug("base.js cached successfully.");

            m_signatureTimestamp = extractSignatureTimestamp(m_cachedScriptContent);
            logDebug(QString("Fresh sts extracted: %1").arg(m_signatureTimestamp));

            // Если это был preflight перед player-запросом — выполняем его теперь
            QString pendingId = reply->property("PendingVideoId").toString();
            if (!pendingId.isEmpty()) {
                requestPlayer(pendingId);
                reply->deleteLater();
                return;
            }

            // Расшифровываем отложенное видео
            QString directUrl = pendingDetails["video_url"].toString();
            QString decryptedUrl = decryptNParameter(directUrl);
            pendingDetails["video_url"] = decryptedUrl;
            m_stsRetriedFor.clear();
            emit videoInfoReady(pendingDetails);
        } else {
            logDebug("Failed to download player script: " + reply->errorString());
            QString pendingId = reply->property("PendingVideoId").toString();
            if (!pendingId.isEmpty()) {
                emit requestFailed("VideoInfo", "Failed to download player script");
            } else {
                m_stsRetriedFor.clear();
                emit videoInfoReady(pendingDetails);
            }
        }
    }
    else if (requestType == "Shorts") {
        QVariantList outShorts;
        QString seqToken = "";

        QVariantMap rootMap = parsedJson.toMap();

        if (rootMap.contains("sequenceContinuation")) {
            seqToken = rootMap.value("sequenceContinuation").toString();
        } else {
            QList<QVariantMap> contCmds = enumerateObjectsWithKey(parsedJson, "continuationCommand");
            if (!contCmds.isEmpty()) seqToken = contCmds.first().value("token").toString();
        }

        QVariantList entries;
        if (rootMap.contains("entries")) {
            entries = rootMap.value("entries").toList();
        } else if (rootMap.contains("replacementEndpoint")) {
            entries.append(rootMap);
        }

        foreach (const QVariant &e, entries) {
            QVariantMap entry = e.toMap();
            QVariantMap endpoint;

            if (entry.contains("reelWatchEndpoint"))
                endpoint = entry.value("reelWatchEndpoint").toMap();
            else if (entry.contains("command") && entry.value("command").toMap().contains("reelWatchEndpoint"))
                endpoint = entry.value("command").toMap().value("reelWatchEndpoint").toMap();
            else if (entry.contains("replacementEndpoint") && entry.value("replacementEndpoint").toMap().contains("reelWatchEndpoint"))
                endpoint = entry.value("replacementEndpoint").toMap().value("reelWatchEndpoint").toMap();

            QString videoId = endpoint.value("videoId").toString();
            if (videoId.isEmpty()) continue;

            QString title = "Shorts";

            QVariantMap prefetch;
            if (endpoint.contains("unserializedPrefetchData")) {
                prefetch = endpoint.value("unserializedPrefetchData").toMap();
            } else if (entry.contains("unserializedPrefetchData")) {
                prefetch = entry.value("unserializedPrefetchData").toMap();
            } else if (entry.contains("command") && entry.value("command").toMap().contains("unserializedPrefetchData")) {
                prefetch = entry.value("command").toMap().value("unserializedPrefetchData").toMap();
            }

            if (!prefetch.isEmpty() && prefetch.contains("playerResponse")) {
                QVariant prVar = prefetch.value("playerResponse");
                QVariantMap prMap;
                if (prVar.type() == QVariant::String) {
                    bool ok;
                    prMap = QtJson::parse(prVar.toString(), ok).toMap();
                } else {
                    prMap = prVar.toMap();
                }

                if (prMap.contains("videoDetails")) {
                    QVariantMap videoDetails = prMap.value("videoDetails").toMap();
                    if (videoDetails.contains("title")) title = videoDetails.value("title").toString();
                }
            }

            QVariantMap item;
            item["video_id"] = videoId;
            item["title"] = title;
            item["thumbnail"] = "https://i.ytimg.com/vi/" + videoId + "/hqdefault.jpg";
            outShorts.append(item);
        }

        if (outShorts.isEmpty()) {
            QList<QVariantMap> endpoints = enumerateObjectsWithKey(parsedJson, "reelWatchEndpoint");
            foreach (QVariantMap endpoint, endpoints) {
                QVariantMap item;
                item["video_id"] = endpoint.value("videoId").toString();
                if (item["video_id"].toString().isEmpty()) continue;
                item["thumbnail"] = "https://i.ytimg.com/vi/" + item["video_id"].toString() + "/hqdefault.jpg";
                item["title"] = "Shorts";
                outShorts.append(item);
            }
        }

        emit shortsReady(outShorts, seqToken);
    }
    else if (requestType == "Subscriptions") {
        QVariantList subsList;
        QList<QVariantMap> tiles = enumerateObjectsWithKey(parsedJson, "tileRenderer");
        foreach (const QVariantMap &tile, tiles) {
            if (tile.value("contentType").toString() == "TILE_CONTENT_TYPE_CHANNEL") {
                QVariantMap sub;
                sub["channel_id"] = tile.value("contentId").toString();
                sub["title"] = extractTextFromField(tile.value("metadata").toMap().value("tileMetadataRenderer").toMap(), "title");
                sub["local_thumbnail"] = extractThumbnailUrl(tile.value("header").toMap().value("tileHeaderRenderer").toMap(), "thumbnail");
                sub["profile_url"] = sub["channel_id"];
                subsList.append(sub);
            }
        }
        emit subscriptionsReady(subsList);
    }
    else if (requestType == "AccountInfo") {
        QList<QVariantMap> accountItems = enumerateObjectsWithKey(parsedJson, "accountItem");
        if (!accountItems.isEmpty()) {
            QVariantMap account = accountItems.first();
            QVariantMap info;

            QVariantMap google_account;
            google_account["given_name"] = extractTextFromField(account, "accountName");
            QVariantMap photoObj = account.value("accountPhoto").toMap();
            QVariantList thumbs = photoObj.value("thumbnails").toList();
            if (!thumbs.isEmpty()) google_account["picture"] = thumbs.last().toMap().value("url").toString();
            info["google_account"] = google_account;

            QVariantMap youtube_channel;
            youtube_channel["custom_url"] = extractTextFromField(account, "channelHandle");
            info["youtube_channel"] = youtube_channel;

            emit accountInfoReady(info);
        }
    }
    else if (requestType == "SearchSuggestions") {
        QString data = QString::fromUtf8(responseData);
        if (data.startsWith("window.google.ac.h(")) {
            data = data.mid(19);
            if (data.endsWith(")")) data.chop(1);
        }
        bool ok;
        QVariant parsed = QtJson::parse(data, ok);
        QVariantList suggestions;
        if (ok && parsed.type() == QVariant::List) {
            QVariantList arr = parsed.toList();
            if (arr.size() > 1) {
                QVariantList suggArr = arr[1].toList();
                foreach (const QVariant &item, suggArr) {
                    QVariantList suggItem = item.toList();
                    if (!suggItem.isEmpty()) suggestions.append(suggItem[0].toString());
                }
            }
        }
        emit searchSuggestionsReady(suggestions);
    }
    else if (requestType == "OAuthDeviceCode") {
        m_deviceCode = parsedMap.value("device_code").toString();
        m_userCode = parsedMap.value("user_code").toString();

        QVariantMap rapidQrParams;
        rapidQrParams["qrPresetStyle"] = "HANDOFF_QR_LIMITED_PRESET_STYLE_MODERN_BIG_DOTS_INVERT_WITH_YT_LOGO";
        rapidQrParams["userCode"] = m_userCode;
        rapidQrParams["rapidQrFeature"] = "RAPID_QR_FEATURE_DEFAULT";
        QVariantMap handoff;
        handoff["rapidQrParams"] = rapidQrParams;
        QVariantMap payload;
        payload["context"] = buildContext("TVHTML5", "7.20251217.19.00");
        payload["handoffQrParams"] = handoff;
        postInnertube("mdx/handoff", payload, "OAuthQrCode");
    }
    else if (requestType == "OAuthQrCode") {
        QString qrUrl = parsedMap.value("rapidQrRenderer").toMap().value("qrCodeRenderer").toMap().value("qrCodeImage").toMap().value("thumbnails").toList().first().toMap().value("url").toString();
        if (!qrUrl.isEmpty()) {
            int marker = qrUrl.indexOf("base64,");
            if (marker >= 0) {
                QString b64 = qrUrl.mid(marker + 7);
                QImage img;
                img.loadFromData(QByteArray::fromBase64(b64.toUtf8()));
                if (m_qrProvider) {
                    m_qrProvider->setImage(img);
                    emit authImageReady();
                }
            }
        }
    }
    else if (requestType == "OAuthTokenPoll") {
        if (reply->error() == QNetworkReply::NoError) {
            QString refreshToken = parsedMap.value("refresh_token").toString();
            QString accessToken = parsedMap.value("access_token").toString();
            if (!refreshToken.isEmpty()) {
                m_deviceCode.clear();
                m_userCode.clear();
                emit authContentReady(refreshToken, "Token");
            } else if (!accessToken.isEmpty()) {
                m_deviceCode.clear();
                m_userCode.clear();
                emit authContentReady(accessToken, "Token");
            }
        }
    }


    else if (requestType == "MyPlaylists" || requestType == "ChannelPlaylists") {
        QVariantList outPlaylists;
        QList<QVariantMap> renderers = enumerateObjectsWithKey(parsedJson, "playlistRenderer");
        renderers.append(enumerateObjectsWithKey(parsedJson, "gridPlaylistRenderer"));
        renderers.append(enumerateObjectsWithKey(parsedJson, "tileRenderer"));
        renderers.append(enumerateObjectsWithKey(parsedJson, "lockupViewModel"));

        foreach (QVariantMap renderer, renderers) {
            QVariantMap item;
            QString playlistId;
            if (renderer.contains("playlistId")) {
                playlistId = renderer.value("playlistId").toString();
            } else if (renderer.contains("contentId")) {
                playlistId = renderer.value("contentId").toString();
            }

            if (playlistId.isEmpty()) continue;

            // Исключаем другие типы карточек
            if (renderer.contains("contentType")) {
                QString cType = renderer.value("contentType").toString();
                if (cType.contains("VIDEO") || cType.contains("CHANNEL")) {
                    continue;
                }
            }

            item["playlist_id"] = playlistId;
            item["title"] = extractTextFromField(renderer, "title");
            if (item["title"].toString().isEmpty()) {
                item["title"] = extractTextFromField(renderer, "headline");
            }
            if (item["title"].toString().isEmpty()) {
                item["title"] = "Playlist";
            }

            QString thumb = extractThumbnailUrl(renderer, "thumbnail");
            if (thumb.isEmpty() && renderer.contains("header")) {
                QVariantMap header = renderer.value("header").toMap();
                if (header.contains("tileHeaderRenderer")) {
                    thumb = extractThumbnailUrl(header.value("tileHeaderRenderer").toMap(), "thumbnail");
                }
            }
            item["thumbnail"] = thumb;

            QString count = extractTextFromField(renderer, "videoCountText");
            if (count.isEmpty()) {
                count = renderer.value("videoCount").toString();
                if (!count.isEmpty()) count += " videos";
            }
            item["video_count_text"] = count;

            outPlaylists.append(item);
        }
        emit playlistsReady(outPlaylists);
    }
    else if (requestType == "PlaylistDetails") {
        QVariantMap result;
        QVariantList outVideos;
        QStringList seenIds;

        QList<QVariantMap> renderers = enumerateObjectsWithKey(parsedJson, "videoRenderer");
        renderers.append(enumerateObjectsWithKey(parsedJson, "gridVideoRenderer"));
        renderers.append(enumerateObjectsWithKey(parsedJson, "compactVideoRenderer"));
        renderers.append(enumerateObjectsWithKey(parsedJson, "playlistVideoRenderer"));
        renderers.append(enumerateObjectsWithKey(parsedJson, "playlistPanelVideoRenderer"));

        foreach (QVariantMap renderer, renderers) {
            QVariantMap item;
            item["video_id"] = renderer.value("videoId").toString();
            if (item["video_id"].toString().isEmpty()) continue;

            item["title"] = extractTextFromField(renderer, "title");
            item["author"] = extractTextFromField(renderer, "shortBylineText");
            if (item["author"].toString().isEmpty()) {
                item["author"] = extractTextFromField(renderer, "longBylineText");
            }
            item["duration"] = extractTextFromField(renderer, "lengthText");
            if (item["duration"].toString().isEmpty()) {
                QList<QVariantMap> overlays = enumerateObjectsWithKey(renderer, "thumbnailOverlayTimeStatusRenderer");
                if (!overlays.isEmpty()) {
                    item["duration"] = extractTextFromField(overlays.first(), "text");
                }
            }
            item["thumbnail"] = "https://i.ytimg.com/vi/" + item["video_id"].toString() + "/mqdefault.jpg";

            QString videoId = item["video_id"].toString();
            if (seenIds.contains(videoId)) continue;
            seenIds.append(videoId);

            outVideos.append(item);
        }

        result["videos"] = outVideos;

        QString plTitle = "Playlist";
        QList<QVariantMap> sidebar = enumerateObjectsWithKey(parsedJson, "playlistSidebarPrimaryInfoRenderer");
        if (!sidebar.isEmpty()) {
            plTitle = extractTextFromField(sidebar.first(), "title");
            result["description"] = extractTextFromField(sidebar.first(), "description");
        } else {
            QList<QVariantMap> header = enumerateObjectsWithKey(parsedJson, "playlistHeaderRenderer");
            if (!header.isEmpty()) {
                plTitle = extractTextFromField(header.first(), "title");
                result["description"] = extractTextFromField(header.first(), "description");
            }
        }
        result["title"] = plTitle;

        emit playlistDetailsReady(result);
    }

    else if (requestType == "ServerList") {
        QStringList servers;
        QString content = QString::fromUtf8(responseData);
        foreach (const QString &line, content.split('\n', QString::SkipEmptyParts)) {
            QString trimmed = line.trimmed();
            if (!trimmed.isEmpty() && !trimmed.startsWith("#")) servers.append(trimmed);
        }
        emit serverListReady(servers);
    }

    reply->deleteLater();
}

void ApiManager::setProxyPort(quint16 port)
{
    m_proxyPort = port;
}

// Находит имя или выражение функции дешифрации n-параметра
// Находит имя или выражение функции дешифрации n-параметра
QString ApiManager::extractNFunctionExpression(const QString &playerScript) {
    if (playerScript.isEmpty()) return "";

    logDebug("[N-Extract] Starting robust n-function extraction...");

    // 1. Поиск через точные регулярные выражения
    QRegExp rx1("\\.get\\([\"']n[\"']\\)\\s*\\)?\\s*&&\\s*\\(?[a-zA-Z_\\$][\\w\\$]*\\s*=\\s*([a-zA-Z_\\$][\\w\\$]*)(?:\\[(\\d+)\\])?\\(");
    QRegExp rx2("String\\.fromCharCode\\(110\\),[a-zA-Z_\\$][\\w\\$]*=[a-zA-Z_\\$][\\w\\$]*\\.get\\([a-zA-Z_\\$][\\w\\$]*\\)\\s*\\)?\\s*&&\\s*\\(?[a-zA-Z_\\$][\\w\\$]*\\s*=\\s*([a-zA-Z_\\$][\\w\\$]*)(?:\\[(\\d+)\\])?\\(");
    QRegExp rx3("\\.get\\([\"']n[\"']\\)\\s*\\)?\\s*&&\\s*([a-zA-Z_\\$][\\w\\$]*)(?:\\[(\\d+)\\])?\\(");

    QStringList exactCandidates;
    QStringList exactIndices;

    if (rx1.indexIn(playerScript) >= 0) {
        exactCandidates << rx1.cap(1);
        exactIndices << rx1.cap(2);
        logDebug("[N-Extract] Precise match rx1: " + rx1.cap(1));
    }
    if (rx2.indexIn(playerScript) >= 0) {
        exactCandidates << rx2.cap(1);
        exactIndices << rx2.cap(2);
        logDebug("[N-Extract] Precise match rx2: " + rx2.cap(1));
    }
    if (rx3.indexIn(playerScript) >= 0) {
        exactCandidates << rx3.cap(1);
        exactIndices << rx3.cap(2);
        logDebug("[N-Extract] Precise match rx3: " + rx3.cap(1));
    }

    for (int i = 0; i < exactCandidates.size(); ++i) {
        QString nfunc = exactCandidates[i];
        QString idx = exactIndices[i];

        // Имя функции-дешифратора обфусцировано и строго ограничено длиной 2-4 символа
        if (nfunc.length() < 2 || nfunc.length() > 4 || nfunc == "get" || nfunc == "set" || nfunc == "fromCharCode" ||
                nfunc == "split" || nfunc == "join" || nfunc == "indexOf" || nfunc == "replace" ||
                nfunc == "if" || nfunc == "match" || nfunc == "catch" || nfunc == "sz" || nfunc == "call") {
            continue;
        }

        QString resolvedFuncName = nfunc;
        if (!idx.isEmpty()) {
            QRegExp arrayRx("(?:var\\s+|[^\\w\\$])" + QRegExp::escape(nfunc) + "\\s*=\\s*\\[\\s*([\\w\\$,\\s]+)\\s*\\]");
            if (arrayRx.indexIn(playerScript) >= 0) {
                QString arrayContent = arrayRx.cap(1);
                QStringList elements = arrayContent.split(",", QString::SkipEmptyParts);
                int indexVal = idx.toInt();
                if (indexVal >= 0 && indexVal < elements.size()) {
                    resolvedFuncName = elements[indexVal].trimmed();
                } else {
                    continue;
                }
            } else {
                continue;
            }
        }

        QString fnSource = extractFunctionSource(playerScript, resolvedFuncName);
        if (!fnSource.isEmpty()) {
            if (fnSource.contains("split") && fnSource.contains("join")) {
                logDebug("[N-Extract] SUCCESS (Precise Regex): Found scramble function -> " + resolvedFuncName);
                return resolvedFuncName;
            }
        }
    }

    // 2. Сканирование всех вхождений ключевых точек (если точные шаблоны не сработали)
    logDebug("[N-Extract] Precise regexes failed. Scanning all entry point occurrences...");

    QStringList entryPoints;
    entryPoints << ".get(\"n\")" << "get('n')" << "fromCharCode(110)" << "nn\"[+";

    foreach (const QString &ep, entryPoints) {
        int findPos = -1;
        // Перебираем абсолютно все вхождения ключевой строки в файле
        while ((findPos = playerScript.indexOf(ep, findPos + 1)) >= 0) {
            QString surrounding = playerScript.mid(findPos, 200);
            if (surrounding.contains(".replace(") || surrounding.contains("replace(\"/n/\"") || surrounding.contains("match(///n///")) {
                continue; // Надежно пропускаем URL-хелпер замены и идем к следующему вхождению
            }

            logDebug("[N-Extract] Testing entry point: " + ep + " at position " + QString::number(findPos));

            QString searchArea = playerScript.mid(findPos, 400);
            QRegExp rx("([\\w\\$]+)(?:\\[(\\d+)\\])?\\s*\\(");
            int scanPos = 0;
            while ((scanPos = rx.indexIn(searchArea, scanPos)) >= 0) {
                QString nfunc = rx.cap(1);
                QString idx = rx.cap(2);
                scanPos += rx.matchedLength();

                if (nfunc.length() < 2 || nfunc.length() > 4 || nfunc == "get" || nfunc == "set" || nfunc == "fromCharCode" ||
                        nfunc == "split" || nfunc == "join" || nfunc == "indexOf" || nfunc == "replace" ||
                        nfunc == "if" || nfunc == "match" || nfunc == "catch" || nfunc == "sz" || nfunc == "call" ||
                        nfunc == "var" || nfunc == "function" || nfunc == "return" || nfunc == "for" || nfunc == "while" ||
                        nfunc == "try" || nfunc == "new" || nfunc == "null" || nfunc == "true" || nfunc == "false" ||
                        nfunc == "this" || nfunc == "typeof" || nfunc == "instanceof") {
                    continue;
                }

                QString resolvedFuncName = nfunc;
                if (!idx.isEmpty()) {
                    QRegExp arrayRx("(?:var\\s+|[^\\w\\$])" + QRegExp::escape(nfunc) + "\\s*=\\s*\\[\\s*([\\w\\$,\\s]+)\\s*\\]");
                    if (arrayRx.indexIn(playerScript) >= 0) {
                        QString arrayContent = arrayRx.cap(1);
                        QStringList elements = arrayContent.split(",", QString::SkipEmptyParts);
                        int indexVal = idx.toInt();
                        if (indexVal >= 0 && indexVal < elements.size()) {
                            resolvedFuncName = elements[indexVal].trimmed();
                        } else {
                            continue;
                        }
                    } else {
                        continue;
                    }
                }

                if (resolvedFuncName.length() < 2 || resolvedFuncName.length() > 4 ||
                        resolvedFuncName == "if" || resolvedFuncName == "for" || resolvedFuncName == "while" ||
                        resolvedFuncName == "catch" || resolvedFuncName == "try" || resolvedFuncName == "return" ||
                        resolvedFuncName == "var" || resolvedFuncName == "function" || resolvedFuncName == "new") {
                    continue;
                }

                QString fnSource = extractFunctionSource(playerScript, resolvedFuncName);
                if (!fnSource.isEmpty()) {
                    if (fnSource.contains("split") && fnSource.contains("join")) {
                        logDebug("[N-Extract] SUCCESS (Fallback Scan): Found scramble function -> " + resolvedFuncName);
                        return resolvedFuncName;
                    }
                }
            }
        }
    }

    // 3. Глобальный резервный поиск (если по точкам входа ничего не подтвердилось)
    logDebug("[N-Extract] Entry points failed. Falling back to global search...");

    QRegExp fnGlobalRx("(?:function\\s+([\\w\\$]+)\\s*\\(|([\\w\\$]+)\\s*=\\s*function\\s*\\()");
    int scanPos = 0;
    while ((scanPos = fnGlobalRx.indexIn(playerScript, scanPos)) >= 0) {
        QString fnName = fnGlobalRx.cap(1);
        if (fnName.isEmpty()) fnName = fnGlobalRx.cap(2);
        scanPos += fnGlobalRx.matchedLength();

        // Строгое отсечение длинных библиотечных имён (resolve, clone) на этапе глобального поиска
        if (fnName.length() < 2 || fnName.length() > 4 || fnName == "get" || fnName == "set" || fnName == "F" ||
                fnName == "if" || fnName == "match" || fnName == "replace" || fnName == "catch" ||
                fnName == "while" || fnName == "for" || fnName == "try" || fnName == "return") continue;

        int openBracePos = playerScript.indexOf('{', scanPos);
        if (openBracePos >= 0) {
            QString peekBody = playerScript.mid(openBracePos, 4000);
            if (!peekBody.contains("split") || !peekBody.contains("join")) {
                continue;
            }
        }

        QString fnSource = extractFunctionSource(playerScript, fnName);
        if (fnSource.length() > 600 && fnSource.length() < 6000) {
            if (fnSource.contains("split") && fnSource.contains("join")) {
                logDebug("[N-Extract] SUCCESS (Global Fallback): Found scramble function: " + fnName);
                return fnName;
            }
        }
    }

    logDebug("[N-Extract] CRITICAL: No n-scramble function found in script!");
    return "";
}

QString ApiManager::buildPlayerScriptWithNExport(const QString &playerScript, const QString &nFunctionExpression) {
    // Внедряем глобальную функцию-обертку __yt_nsig во внешний скоуп base.js
    QString exportScript = QString(";__yt_nsig=function(n){return %1(n);};").arg(nFunctionExpression);

    int closingIndex = playerScript.lastIndexOf(";})(_yt_player);");
    if (closingIndex >= 0) {
        return QString(playerScript).insert(closingIndex, exportScript);
    }

    closingIndex = playerScript.lastIndexOf("})(_yt_player);");
    if (closingIndex >= 0) {
        return QString(playerScript).insert(closingIndex, exportScript);
    }

    return playerScript + exportScript;
}






// Поиск закрывающей '}' с учётом строковых литералов
static int findMatchingBrace(const QString &s, int openPos) {
    int depth = 0;
    QChar quote('\0');
    bool escaped = false;
    for (int i = openPos; i < s.length(); ++i) {
        QChar c = s.at(i);
        if (quote != QChar('\0')) {
            if (escaped) escaped = false;
            else if (c == '\\') escaped = true;
            else if (c == quote) quote = QChar('\0');
            continue;
        }
        if (c == '"' || c == '\'') { quote = c; continue; }
        if (c == '{') depth++;
        else if (c == '}') { if (--depth == 0) return i; }
    }
    return -1;
}

// Извлекает тело функции по её имени (Оптимизировано через indexOf)
QString ApiManager::extractFunctionSource(const QString &script, const QString &name) {
    if (script.isEmpty() || name.isEmpty()) return "";

    // Быстрый поиск точного положения объявления функции через indexOf
    QStringList patterns;
    patterns << "function " + name
             << name + "=function"
             << name + " =function"
             << name + "= function"
             << name + " = function"
             << name + ":function"
             << name + " :function"
             << name + ": function"
             << name + " : function";

    int pos = -1;
    foreach (const QString &pat, patterns) {
        pos = script.indexOf(pat);
        if (pos >= 0) break;
    }

    if (pos < 0) return "";

    // Находим ключевое слово function рядом с найденной позицией
    int fnKw = script.indexOf("function", qMax(0, pos - 5));
    if (fnKw < 0) fnKw = pos;

    int open = script.indexOf('{', fnKw);
    if (open < 0) return "";

    int close = findMatchingBrace(script, open);
    if (close < 0) return "";

    return script.mid(fnKw, close - fnKw + 1);
}


// Извлекает глобальные переменные/массивы/объекты, от которых зависит функция (Оптимизировано через indexOf)
QString ApiManager::extractGlobalDefinition(const QString &script, const QString &name) {
    if (script.isEmpty() || name.isEmpty()) return "";

    // Быстрый поиск объявления переменной через indexOf
    QStringList patterns;
    patterns << "var " + name + "="
             << "var " + name + " ="
             << ";" + name + "="
             << ";" + name + " ="
             << "," + name + "="
             << "," + name + " ="
             << "\n" + name + "="
             << "\n" + name + " =";

    int pos = -1;
    foreach (const QString &pat, patterns) {
        pos = script.indexOf(pat);
        if (pos >= 0) break;
    }

    if (pos < 0) return "";

    int eq = script.indexOf('=', pos);
    if (eq < 0) return "";

    int depth = 0;
    QChar quote('\0');
    bool escaped = false;
    int i = eq + 1;
    for (; i < script.length(); ++i) {
        QChar c = script.at(i);
        if (quote != QChar('\0')) {
            if (escaped) escaped = false;
            else if (c == '\\') escaped = true;
            else if (c == quote) quote = QChar('\0');
            continue;
        }
        if (c == '"' || c == '\'') { quote = c; continue; }
        if (c == '(' || c == '[' || c == '{') depth++;
        else if (c == ')' || c == ']' || c == '}') depth--;
        else if ((c == ';' || c == ',') && depth == 0) break;
    }
    return "var " + name + "=" + script.mid(eq + 1, i - (eq + 1)) + ";";
}

// Универсальное разрешение зависимости: функция-объявление,
// функция-присваивание или глобальная переменная с данными
QString ApiManager::resolveDependency(const QString &script, const QString &name)
{
    // 1. Форма "function lI(M,W){...}" или "lI=function(M,W){...}"
    QString fnSrc = extractFunctionSource(script, name);
    if (!fnSrc.isEmpty()) {
        if (fnSrc.startsWith("function " + name) || fnSrc.startsWith("function  " + name)) {
            return fnSrc + ";";                    // декларация — годится как есть
        }
        return "var " + name + "=" + fnSrc + ";";  // анонимная — присваиваем имени
    }
    // 2. Форма "var lI=..." / ",lI=..." (данные: массивы, строки, объекты)
    return extractGlobalDefinition(script, name);
}

void ApiManager::collectTypeofDeps(const QString &code, QStringList &deps, QStringList &resolvedNames)
{
    QRegExp typeofRx("typeof\\s+([A-Za-z0-9_$]{2,})");
    int tp = 0;
    while ((tp = typeofRx.indexIn(code, tp)) >= 0) {
        QString depName = typeofRx.cap(1);
        tp += typeofRx.matchedLength();
        if (depName == "undefined" || resolvedNames.contains(depName)) continue;
        resolvedNames << depName;
        QString dep = resolveDependency(m_cachedScriptContent, depName);
        if (!dep.isEmpty()) {
            logDebug(QString("  [typeof-dep] '%1' resolved, %2 chars, head: %3")
                     .arg(depName).arg(dep.length()).arg(dep.left(80)));
            deps << dep;
            collectTypeofDeps(dep, deps, resolvedNames);  // гарды внутри гардов
        } else {
            logDebug("  [typeof-dep] '" + depName + "' not in script (browser global?)");
        }
    }
}

void safeCharSwap(QString &str, int i, int j) {
    if (i < 0 || i >= str.length() || j < 0 || j >= str.length() || i == j) return;
    QChar temp = str.at(i);
    str.replace(i, 1, str.at(j));
    str.replace(j, 1, temp);
}

QString ApiManager::decryptNParameter(const QString &url)
{
    logDebug("----------------------- [N-PARAMETER DECRYPTION] -----------------------");
    logDebug("Input URL: " + url);

    // 1. Извлекаем исходное значение n из URL
    QRegExp nRx("[?&]n=([^&]+)");
    if (nRx.indexIn(url) < 0) {
        logDebug("No 'n' parameter found in URL. Returning as-is.");
        return url;
    }
    QString originalN = nRx.cap(1);
    logDebug("Extracted original 'n' value: " + originalN);

    // 2. Выполняем дешифрацию алгоритмом пользователя на чистом C++
    QString a = originalN;
    int len = a.length();
    if (len == 0) return url;

    // a.reverse() — разворачиваем строку в обратном порядке
    for (int i = 0; i < len / 2; ++i) {
        QChar temp = a.at(i);
        a.replace(i, 1, a.at(len - 1 - i));
        a.replace(len - 1 - i, 1, temp);
    }

    // a.splice(0, 1) — удаляем первый символ
    if (a.length() > 0) {
        a.remove(0, 1);
    }

    // Свап 0 и 55 % length
    if (a.length() > 0) {
        int idx = 55 % a.length();
        safeCharSwap(a, 0, idx);
    }

    // a.splice(0, 1) — удаляем первый символ
    if (a.length() > 0) {
        a.remove(0, 1);
    }

    // Свап 0 и 53 % length
    if (a.length() > 0) {
        int idx = 53 % a.length();
        safeCharSwap(a, 0, idx);
    }

    // Свап 0 and 9 % length
    if (a.length() > 0) {
        int idx = 9 % a.length();
        safeCharSwap(a, 0, idx);
    }

    // a.splice(0, 3) — удаляем первые 3 символа
    if (a.length() >= 3) {
        a.remove(0, 3);
    } else {
        a.clear();
    }

    logDebug("N-Decrypt Success: Transformed '" + originalN + "' -> '" + a + "'");

    // 3. Подставляем дешифрованное значение обратно в URL
    QString encodedN = QString::fromLatin1(QUrl::toPercentEncoding(a));
    QString resultUrl = url;
    resultUrl.replace(nRx.cap(0),
                      nRx.cap(0).left(nRx.cap(0).indexOf('=') + 1) + encodedN);
    logDebug("Output URL: " + resultUrl);
    logDebug("-------------------------------------------------------------------------");
    return resultUrl;
}

void ApiManager::getMyPlaylists() {
    QVariantMap payload;
    payload["context"] = buildContext("TVHTML5", TV_CLIENT_VERSION);
    payload["browseId"] = "FEplaylist_aggregation";
    postInnertube("browse", payload, "MyPlaylists", true);
}

void ApiManager::getPlaylistDetails(const QString &playlistId, const QString &pageToken) {
    QVariantMap payload;
    payload["context"] = buildContext("TVHTML5", TV_CLIENT_VERSION);

    QString browseId = playlistId;
    // Добавляем "VL" только если ID не начинается с "VL" и не является джемом "RD"
    if (!browseId.startsWith("VL") && !browseId.startsWith("RD")) {
        browseId = "VL" + browseId;
    }
    payload["browseId"] = browseId;
    if (!pageToken.isEmpty()) {
        payload["continuation"] = pageToken;
    }
    postInnertube("browse", payload, "PlaylistDetails", false);
}

void ApiManager::getChannelPlaylists(const QString &channelId) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    payload["browseId"] = channelId;
    // Параметр разметки вкладки плейлистов канала
    payload["params"] = "EglwbGF5bGlzdHPyBgQKAjoA";
    postInnertube("browse", payload, "ChannelPlaylists", false);
}
