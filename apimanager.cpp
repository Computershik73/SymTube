#include "apimanager.h"
#include "config.h"
#include "json.h"
#include <QNetworkRequest>
#include <QSettings>
#include <QEventLoop>
#include <QUuid>
#include <QDebug>
#include <QNetworkProxy>

// Константы OAuth для получения токена
const QString OAUTH_CLIENT_ID = "861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com";
const QString OAUTH_CLIENT_SECRET = "SboVhoG9s0rNafixCSGGKXAT";

ApiManager::ApiManager(Config *config, QrImageProvider *qrProvider, QObject *parent)
    : QObject(parent), m_config(config), m_qrProvider(qrProvider)
{
    m_networkManager = new QNetworkAccessManager(this);

    connect(m_networkManager, SIGNAL(finished(QNetworkReply*)), this, SLOT(onReplyFinished(QNetworkReply*)));
}

ApiManager::~ApiManager() {}

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

    if (clientName == "TVHTML5") {
        client["platform"] = "TV";
        client["deviceMake"] = "Samsung";
        client["deviceModel"] = "SmartTV";
        client["osName"] = "Tizen";
        client["osVersion"] = "5.0";
    }

    QVariantMap context;
    context["client"] = client;
    return context;
}

// Получение свежего Access Token через сохраненный Refresh Token (Синхронно)
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
    QString url = "https://www.youtube.com/youtubei/v1/" + endpoint + "?key=" + m_config->apiKey();
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json; charset=utf-8");

    // Вытаскиваем clientName из payload, чтобы выставить правильный заголовок x-youtube-client-name
    QVariantMap context = payload.value("context").toMap();
    QVariantMap client = context.value("client").toMap();
    QString clientName = client.value("clientName").toString();

    if (clientName == "ANDROID") {
        request.setRawHeader("x-youtube-client-name", "3");
        request.setRawHeader("User-Agent", "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip");
    } else if (clientName == "TVHTML5") {
        request.setRawHeader("x-youtube-client-name", "85");
        request.setRawHeader("User-Agent", "Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebkit/537.36");
    }

    if (requiresAuth) {
        QString token = getAccessToken();
        if (!token.isEmpty()) {
            request.setRawHeader("Authorization", "Bearer " + token.toUtf8());
        }
    }

    bool success;
    QByteArray data = QtJson::serialize(payload, success);
    QNetworkReply *reply = m_networkManager->post(request, data);
    reply->setProperty("RequestType", requestType);
}

// === API ВОССТАНОВЛЕННЫЕ ФУНКЦИИ ===

void ApiManager::getSearchSuggestions(const QString &query) {
    QString url = "https://clients1.google.com/complete/search?client=youtube&ds=yt&q=" + QUrl::toPercentEncoding(query) + getLocaleParams();
    QNetworkRequest request;
    request.setUrl(QUrl(url));
    QNetworkReply *reply = m_networkManager->get(request);
    reply->setProperty("RequestType", "SearchSuggestions");
}

void ApiManager::getHistory() {
    QVariantMap payload;
    payload["context"] = buildContext("TVHTML5", "7.20250209.19.00");
    payload["browseId"] = "FEhistory";
    postInnertube("browse", payload, "History", true);
}

void ApiManager::getSubscriptions() {
    QVariantMap payload;
    payload["context"] = buildContext("TVHTML5", "7.20250209.19.00");
    payload["browseId"] = "FEchannels";
    postInnertube("browse", payload, "Subscriptions", true);
}

void ApiManager::getAccountInfo() {
    QVariantMap payload;
    payload["context"] = buildContext("TVHTML5", "7.20250209.19.00");
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

// Авторизация по QR Коду (Полный аналог UWP StartDeviceFlow)
void ApiManager::checkAuthContent() {
    if (m_deviceCode.isEmpty()) {
        // Шаг 1: Запрашиваем Device Code
        QNetworkRequest request(QUrl("https://www.youtube.com/o/oauth2/device/code"));
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
        request.setRawHeader("User-Agent", "Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0)");
        QString data = "client_id=" + OAUTH_CLIENT_ID + "&scope=http://gdata.youtube.com https://www.googleapis.com/auth/youtube-paid-content&device_id=" + QUuid::createUuid().toString().replace("{","").replace("}","") + "&device_model=ytlr:samsung:smarttv";
        QNetworkReply *reply = m_networkManager->post(request, data.toUtf8());
        reply->setProperty("RequestType", "OAuthDeviceCode");
    } else {
        // Шаг 3: Опрашиваем статус (Poll)
        QNetworkRequest request(QUrl("https://www.youtube.com/o/oauth2/token"));
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
        request.setRawHeader("User-Agent", "Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0)");
        QString data = "client_id=" + OAUTH_CLIENT_ID + "&client_secret=" + OAUTH_CLIENT_SECRET + "&code=" + m_deviceCode + "&grant_type=http://oauth.net/grant_type/device/1.0";
        QNetworkReply *reply = m_networkManager->post(request, data.toUtf8());
        reply->setProperty("RequestType", "OAuthTokenPoll");
    }
}

// === СУЩЕСТВУЮЩИЕ ФУНКЦИИ ===
void ApiManager::getHomeVideos(const QString &pageToken) {
    QVariantMap payload;
    payload["context"] = buildContext("TVHTML5", "7.20250209.19.00");
    payload["browseId"] = "FEwhat_to_watch";
    if (!pageToken.isEmpty()) payload["continuation"] = pageToken;
    postInnertube("browse", payload, "HomeVideos", !m_config->userToken().isEmpty());
}

void ApiManager::searchVideos(const QString &query) {
    QVariantMap payload;
    payload["context"] = buildContext("WEB", "2.20250101");
    payload["query"] = query;
    postInnertube("search", payload, "SearchVideos");
}

void ApiManager::getVideoInfo(const QString &videoId) {
    // ВАЖНО: Используем ANDROID, чтобы ссылка была совместима с прокси!
    QVariantMap client;
    client["clientName"] = "ANDROID";
    client["clientVersion"] = "20.10.38";
    client["androidSdkVersion"] = 30;
    client["hl"] = "en";
    client["gl"] = "US";

    QVariantMap context;
    context["client"] = client;

    QVariantMap payload;
    payload["context"] = context;
    payload["videoId"] = videoId;

    postInnertube("player", payload, "VideoInfo");
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
        postInnertube("reel/reel_item_watch", payload, "Shorts");
    }
}

// === Итеративный поиск в JSON ===
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
    QVariantList thumbs = obj.value(fieldName).toMap().value("thumbnails").toList();
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

    if (reply->error() != QNetworkReply::NoError && requestType != "OAuthTokenPoll") {
        emit requestFailed(requestType, reply->errorString());
        reply->deleteLater();
        return;
    }

    bool parseSuccess;
    QVariant parsedJson = QtJson::parse(QString::fromUtf8(responseData), parseSuccess);
    QVariantMap parsedMap = parsedJson.toMap();

    if (requestType == "HomeVideos" || requestType == "SearchVideos" || requestType == "RelatedVideos" || requestType == "ChannelVideos" || requestType == "History") {
            QVariantList outVideos;

            QList<QVariantMap> renderers = enumerateObjectsWithKey(parsedJson, "videoRenderer");
            renderers.append(enumerateObjectsWithKey(parsedJson, "gridVideoRenderer"));
            renderers.append(enumerateObjectsWithKey(parsedJson, "compactVideoRenderer"));
            renderers.append(enumerateObjectsWithKey(parsedJson, "tileRenderer"));
            renderers.append(enumerateObjectsWithKey(parsedJson, "lockupViewModel"));

            foreach (QVariantMap renderer, renderers) {
                QVariantMap item;

                // 1. Формат lockupViewModel (Новые карточки рекомендаций из WEB-клиента)
                if (renderer.contains("contentImage") && renderer.contains("metadata") && renderer.value("metadata").toMap().contains("lockupMetadataViewModel")) {
                    item["video_id"] = renderer.value("contentId").toString();

                    QVariantMap meta = renderer.value("metadata").toMap().value("lockupMetadataViewModel").toMap();
                    item["title"] = meta.value("title").toMap().value("content").toString();

                    QVariantList rows = meta.value("metadata").toMap().value("contentMetadataViewModel").toMap().value("metadataRows").toList();
                    if (rows.size() > 0) {
                        QVariantList parts = rows[0].toMap().value("metadataParts").toList();
                        if (!parts.isEmpty()) {
                            item["author"] = parts[0].toMap().value("text").toMap().value("content").toString();
                        }
                    }
                    if (rows.size() > 1) {
                        QVariantList parts = rows[1].toMap().value("metadataParts").toList();
                        if (parts.size() > 0) {
                            item["views"] = parts[0].toMap().value("text").toMap().value("content").toString();
                        }
                        if (parts.size() > 1) {
                            item["published_at"] = parts[1].toMap().value("text").toMap().value("content").toString();
                        }
                    }

                    QVariantList overlays = renderer.value("contentImage").toMap().value("thumbnailViewModel").toMap().value("overlays").toList();
                    foreach (const QVariant &ov, overlays) {
                        QVariantMap ovMap = ov.toMap();
                        if (ovMap.contains("thumbnailBottomOverlayViewModel")) {
                            QVariantList badges = ovMap.value("thumbnailBottomOverlayViewModel").toMap().value("badges").toList();
                            if (!badges.isEmpty()) {
                                item["duration"] = badges[0].toMap().value("thumbnailBadgeViewModel").toMap().value("text").toString();
                            }
                        }
                    }
                }
                // 2. Формат tileRenderer (TVHTML5 - Главная страница, Поиск)
                else if (renderer.contains("onSelectCommand")) {
                    QVariantMap endpoint = renderer.value("onSelectCommand").toMap().value("watchEndpoint").toMap();
                    item["video_id"] = endpoint.value("videoId").toString();
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
                        if (items0.size() > 0) {
                            item["author"] = extractTextFromField(items0[0].toMap().value("lineItemRenderer").toMap(), "text");
                        }
                    }
                    if (lines.size() > 1) {
                        QVariantList items1 = lines[1].toMap().value("lineRenderer").toMap().value("items").toList();
                        int count = items1.size();
                        if (count >= 1) {
                            item["published_at"] = extractTextFromField(items1[count - 1].toMap().value("lineItemRenderer").toMap(), "text");
                        }
                        if (count >= 3) {
                            item["views"] = extractTextFromField(items1[count - 3].toMap().value("lineItemRenderer").toMap(), "text");
                        }
                    }
                }
                // 3. Старый формат (compactVideoRenderer / videoRenderer - старые API)
                else {
                    item["video_id"] = renderer.value("videoId").toString();
                    item["title"] = extractTextFromField(renderer, "title");
                    item["author"] = extractTextFromField(renderer, "shortBylineText");
                    if (item["author"].toString().isEmpty()) item["author"] = extractTextFromField(renderer, "ownerText");
                    item["duration"] = extractTextFromField(renderer, "lengthText");
                    item["views"] = extractTextFromField(renderer, "viewCountText");
                }

                if (item["video_id"].toString().isEmpty()) continue;
                item["thumbnail"] = "https://i.ytimg.com/vi/" + item["video_id"].toString() + "/mqdefault.jpg";
                outVideos.append(item);
            }

            if (requestType == "HomeVideos") {
                if (outVideos.isEmpty()) {
                    emit requestFailed("HomeVideos", "Empty feed (Nudge)");
                } else {
                    emit homeVideosReady(outVideos, "");
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
                if (!structuredDesc.isEmpty()) {
                    extraDetails["description"] = structuredDesc.first().value("attributedDescriptionBodyText").toMap().value("content").toString();
                }

                QList<QVariantMap> videoOwner = enumerateObjectsWithKey(parsedJson, "videoOwnerRenderer");
                if (!videoOwner.isEmpty()) {
                    QVariantMap owner = videoOwner.first();
                    extraDetails["channel_thumbnail"] = extractThumbnailUrl(owner, "thumbnail");
                    extraDetails["subscriberCount"] = extractTextFromField(owner, "subscriberCountText");

                    QVariantMap navEndpoint = owner.value("navigationEndpoint").toMap();
                    if (navEndpoint.contains("browseEndpoint")) {
                        extraDetails["channel_custom_url"] = navEndpoint.value("browseEndpoint").toMap().value("browseId").toString();
                    }
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
                    emit channelVideosReady(m);
                }
            }
            else if (requestType == "History") {
                emit historyReady(outVideos);
            }
        }
    else if (requestType == "VideoInfo") {
        QVariantMap details;
        QVariantMap root = parsedJson.toMap();
        QVariantMap videoDetails = root.value("videoDetails").toMap();
        details["video_id"] = videoDetails.value("videoId").toString();
        details["title"] = videoDetails.value("title").toString();
        details["author"] = videoDetails.value("author").toString();
        details["views"] = videoDetails.value("viewCount").toString();

        QString directUrl = "";
        QVariantMap streamingData = root.value("streamingData").toMap();
        QVariantList formats = streamingData.value("formats").toList();
        foreach (const QVariant &f, formats) {
            QVariantMap format = f.toMap();
            if (format.value("itag").toInt() == 18) { // Ищем 360p
                directUrl = format.value("url").toString();
                break;
            }
        }
        details["video_url"] = directUrl;

        emit videoInfoReady(details);
    }
    else if (requestType == "Shorts") {
        QVariantList outShorts;
        QList<QVariantMap> endpoints = enumerateObjectsWithKey(parsedJson, "reelWatchEndpoint");
        foreach (QVariantMap endpoint, endpoints) {
            QVariantMap item;
            item["video_id"] = endpoint.value("videoId").toString();
            if (item["video_id"].toString().isEmpty()) continue;
            item["thumbnail"] = "https://i.ytimg.com/vi/" + item["video_id"].toString() + "/hqdefault.jpg";
            outShorts.append(item);
        }
        emit shortsReady(outShorts, "");
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
            google_account["picture"] = extractThumbnailUrl(account, "accountPhoto");
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
