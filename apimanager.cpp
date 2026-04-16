#include "apimanager.h"
#include "config.h"
#include "json.h"
#include "qrimageprovider.h"
#include <QUrl>
#include <QNetworkRequest>
#include <QDebug>
#include <QImage>

ApiManager::ApiManager(Config *config, QrImageProvider *qrProvider, QObject *parent)
    : QObject(parent), m_config(config), m_qrProvider(qrProvider) // Снова принимаем провайдер здесь
{
    m_networkManager = new QNetworkAccessManager(this);
    connect(m_networkManager, SIGNAL(finished(QNetworkReply*)), this, SLOT(onReplyFinished(QNetworkReply*)));
}

ApiManager::~ApiManager()
{
}

void ApiManager::sanitizeVideoList(QVariantList &list) {
    for (int i = 0; i < list.size(); ++i) {
        QVariantMap map = list[i].toMap();

        // Исправляем превью видео
        if (map.contains("thumbnail")) {
            QString url = map["thumbnail"].toString();
            url.replace("https://", "http://");
            map["thumbnail"] = url;
        }

        // Исправляем аватарку канала
        if (map.contains("channel_thumbnail")) {
            QString url = map["channel_thumbnail"].toString();
            url.replace("https://", "http://");
            map["channel_thumbnail"] = url;
        }

        list[i] = map;
    }
}

void ApiManager::setImageProvider(QrImageProvider *provider)
{
    m_qrProvider = provider;
}

void ApiManager::sendRequest(const QString &url, const QString &requestType)
{
    QNetworkRequest request;
    request.setUrl(QUrl(url)); // QUrl сам безопасно обработает строку
    request.setRawHeader("User-Agent", "Mozilla/5.0 (Symbian/3; Series60/5.3 NokiaN8-00) Qt/4.7.3");
    request.setRawHeader("Accept", "application/json");

    QNetworkReply *reply = m_networkManager->get(request);
    reply->setProperty("RequestType", requestType);
}

void ApiManager::getHomeVideos(const QString &pageToken)
{
    QString token = m_config->userToken();
    QString url;

    if (!token.isEmpty()) {
        url = m_config->apiBaseUrl() + "get_recommendations.php?token=" + token;
        if (!pageToken.isEmpty()) url += "&pageToken=" + pageToken;
        sendRequest(url, "HomeVideos");
    } else {
        QString apiKey = m_config->apiKey();
        /*if (apiKey.isEmpty()) {
            emit requestFailed("HomeVideos", "API key is missing");
            return;
        }*/
        url = m_config->apiBaseUrl() + "get_top_videos.php";
        if (!pageToken.isEmpty()) url += "&pageToken=" + pageToken;
        sendRequest(url, "HomeVideos");
    }
}

void ApiManager::searchVideos(const QString &query)
{
    QString apiKey = m_config->apiKey();
    // Пользовательский ввод кодируем
    QString url = m_config->apiBaseUrl() + "get_search_videos.php?query=" + QUrl::toPercentEncoding(query);
    sendRequest(url, "SearchVideos");
}

void ApiManager::getSearchSuggestions(const QString &query)
{
    QString apiKey = m_config->apiKey();
    QString url = m_config->apiBaseUrl() + "get_search_suggestions.php?query=" + QUrl::toPercentEncoding(query);
    sendRequest(url, "SearchSuggestions");
}

void ApiManager::getVideoInfo(const QString &videoId)
{
    QString apiKey = m_config->apiKey();
    QString url = m_config->apiBaseUrl() + "get-ytvideo-info.php?video_id=" + videoId;
    qDebug() << "[ApiManager] Запрос информации о видео по URL:" << url; // <-- ДОБАВЬТЕ ЭТУ СТ� ОКУ
    sendRequest(url, "VideoInfo");
}

void ApiManager::getRelatedVideos(const QString &videoId, int page)
{
    QString apiKey = m_config->apiKey();
    QString token = m_config->userToken();
    QString url = m_config->apiBaseUrl() + "get_related_videos.php?video_id=" + videoId + "&page=" + QString::number(page) + "&token=" + token;
    sendRequest(url, "RelatedVideos");
}

void ApiManager::checkRating(const QString &videoId)
{
    // QString token = m_config->userToken();
    // if (token.isEmpty()) {
    emit ratingChecked("none");
    // return;
    /* }
    QString url = m_config->apiBaseUrl() + "actions/check_rating?video_id=" + videoId + "&token=" + token;
    sendRequest(url, "CheckRating");*/
}

void ApiManager::checkSubscription(const QString &channelIdentifier)
{
    QString token = m_config->userToken();
    if (token.isEmpty()) {
        emit subscriptionChecked(false);
        return;
    }
    QString url = m_config->apiBaseUrl() + "actions/check_subscription?channel=" + channelIdentifier + "&token=" + token;
    sendRequest(url, "CheckSubscription");
}

void ApiManager::rateVideo(const QString &videoId, const QString &rating)
{
    QString token = m_config->userToken();
    if (token.isEmpty()) return;
    QString url = m_config->apiBaseUrl() + "actions/rate?video_id=" + videoId + "&rating=" + rating + "&token=" + token;
    sendRequest(url, "RateVideo");
}

void ApiManager::subscribeToChannel(const QString &channelIdentifier)
{
    QString token = m_config->userToken();
    if (token.isEmpty()) return;
    QString url = m_config->apiBaseUrl() + "actions/subscribe?channel=" + channelIdentifier + "&token=" + token;
    sendRequest(url, "SubscribeChannel");
}

void ApiManager::unsubscribeFromChannel(const QString &channelIdentifier)
{
    QString token = m_config->userToken();
    if (token.isEmpty()) return;
    QString url = m_config->apiBaseUrl() + "actions/unsubscribe?channel=" + channelIdentifier + "&token=" + token;
    sendRequest(url, "UnsubscribeChannel");
}

void ApiManager::getChannelVideos(const QString &author)
{
    QString apiKey = m_config->apiKey();
    QString url = m_config->apiBaseUrl() + "get_author_videos.php?author=" + author;
    sendRequest(url, "ChannelVideos");
}

void ApiManager::getSubscriptions()
{
    QString token = m_config->userToken();
    if (token.isEmpty()) {
        emit requestFailed("Subscriptions", "Token missing");
        return;
    }
    QString url = m_config->apiBaseUrl() + "get_subscriptions.php?token=" + token;
    sendRequest(url, "Subscriptions");
}

void ApiManager::getAccountInfo()
{
    QString token = m_config->userToken();
    QString url = m_config->apiBaseUrl() + "account_info?token=" + token;
    sendRequest(url, "AccountInfo");
}

void ApiManager::getShorts(const QString &sequenceToken)
{
    QString url = m_config->apiBaseUrl() + "get_shorts.php";
    if (!sequenceToken.isEmpty()) {
        url += "?sequence=" + sequenceToken;
    }
    sendRequest(url, "Shorts");
}

void ApiManager::checkAuthContent()
{
    QString url = m_config->apiBaseUrl() + "auth";
    sendRequest(url, "AuthContent");
}

QString ApiManager::extractContentFromYtreq(const QString &response)
{
    QString content = response;
    int start = content.indexOf("<ytreq>");
    int end = content.indexOf("</ytreq>");

    if (start != -1 && end != -1) {
        content = content.mid(start + 7, end - start - 7).trimmed();
    }
    return content;
}

void ApiManager::downloadChannelIcon(const QString &url)
{
    QNetworkRequest request;
    request.setUrl(QUrl(url));
    QNetworkReply *reply = m_networkManager->get(request);
    // Помечаем запрос как загрузку иконки
    reply->setProperty("RequestType", "DownloadIcon");
}

void ApiManager::onReplyFinished(QNetworkReply *reply)
{
    QString requestType = reply->property("RequestType").toString();


    // Проверяем, есть ли ошибка
    if (reply->error() != QNetworkReply::NoError) {
        int retryCount = reply->property("RetryCount").toInt();
        // Если попытки остались - повторяем
        if (retryCount < 3) {
            qDebug() << "[ApiManager] Ошибка" << requestType << ". Попытка" << retryCount + 1 << "из" << "3";

            QNetworkRequest request = reply->request();
            QNetworkReply *newReply = m_networkManager->get(request); // Повторяем GET-запрос
            newReply->setProperty("RequestType", requestType);
            newReply->setProperty("RetryCount", retryCount + 1);

            reply->deleteLater();
            return;
        }

        // Если все попытки исчерпаны
        emit requestFailed(requestType, reply->errorString());
        reply->deleteLater();
        return;
    }


    /* if (reply->error() != QNetworkReply::NoError) {
        emit requestFailed(requestType, reply->errorString());
        reply->deleteLater();
        return;
    }*/

    QByteArray responseData = reply->readAll();
    QString responseString = QString::fromUtf8(responseData);

    // --- НАЧАЛО ИСП� АВЛЕНИЯ ---
    // Этот костыль заменяет некорректное значение на валидное (пустая строка)
    responseString.replace("\"embed_url\": ,", "\"embed_url\": \"\",");
    // --- КОНЕЦ ИСП� АВЛЕНИЯ ---

    bool parseSuccess = false;
    QVariant parsedJson = QtJson::parse(responseString, parseSuccess);

    if (requestType == "HomeVideos" || requestType == "SearchVideos" || requestType == "RelatedVideos") {
        if (parseSuccess && parsedJson.type() == QVariant::List) {
            QVariantList list = parsedJson.toList();
            sanitizeVideoList(list);
            if (requestType == "HomeVideos") emit homeVideosReady(parsedJson.toList());
            else if (requestType == "SearchVideos") emit searchResultsReady(parsedJson.toList());
            else emit relatedVideosReady(parsedJson.toList());
        } else {
            emit requestFailed(requestType, "JSON parse error");
        }
    }
    else if (requestType == "SearchSuggestions") {
        if (parseSuccess && parsedJson.type() == QVariant::Map) {
            QVariantMap map = parsedJson.toMap();
            QVariantList resultList;
            if (map.contains("suggestions")) {
                QVariantList rawSuggestions = map["suggestions"].toList();
                for (int i = 0; i < rawSuggestions.size(); ++i) {
                    QVariantList subList = rawSuggestions[i].toList();
                    if (!subList.isEmpty()) {
                        resultList.append(subList[0].toString());
                    }
                }
            }
            emit searchSuggestionsReady(resultList);
        }
    }
    else if (requestType == "VideoInfo" || requestType == "ChannelVideos") {
        if (parseSuccess && parsedJson.type() == QVariant::Map) {

            QVariantMap map = parsedJson.toMap();

            if (map.contains("videos")) {
                QVariantList vList = map["videos"].toList();
                sanitizeVideoList(vList); // <--- ДОБАВИТЬ ЗДЕСЬ
                map["videos"] = vList;
            }

            // --- УНИВЕ� САЛЬНЫЙ ДЕКОДЕ�  ---
            if (map.contains("channel_thumbnail")) {
                QString url = map.value("channel_thumbnail").toString();

                // Просто заменяем %25 на % на случай, если сервер прислал двойную кодировку.
                // Это превратит "https%253A" в "https%3A", не ломая саму ссылку "http://..."
                url = url;

                map.insert("channel_thumbnail", url);
            }
            // -----------------------------

            if (requestType == "VideoInfo") emit videoInfoReady(map);
            else emit channelVideosReady(map);
        } else {
            emit requestFailed(requestType, "JSON parse error");
        }
    }
    else if (requestType == "CheckRating") {
        if (parseSuccess && parsedJson.type() == QVariant::Map) {
            QVariantMap map = parsedJson.toMap();
            emit ratingChecked(map.value("rating", "none").toString());
        }
    }
    else if (requestType == "CheckSubscription") {
        if (parseSuccess && parsedJson.type() == QVariant::Map) {
            QVariantMap map = parsedJson.toMap();
            emit subscriptionChecked(map.value("subscribed", false).toBool());
        }
    }
    else if (requestType == "RateVideo" || requestType == "SubscribeChannel" || requestType == "UnsubscribeChannel") {
        if (parseSuccess && parsedJson.type() == QVariant::Map) {
            QVariantMap map = parsedJson.toMap();
            emit actionCompleted(requestType, map.value("status").toString(), map.value("message").toString());
        }
    }
    else if (requestType == "Subscriptions") {
        if (parseSuccess && parsedJson.type() == QVariant::Map) {
            QVariantMap map = parsedJson.toMap();
            if (map.value("status").toString() == "success") {
                emit subscriptionsReady(map.value("subscriptions").toList());
            } else {
                emit requestFailed(requestType, "Status not success");
            }
        }
    }
    else if (requestType == "AccountInfo") {
        if (parseSuccess && parsedJson.type() == QVariant::Map) {
            emit accountInfoReady(parsedJson.toMap());
        }
    } else if (requestType == "DownloadIcon") {
        QByteArray imgData = reply->readAll();
        QImage img;
        img.loadFromData(imgData);
        if (!img.isNull() && m_qrProvider) {
            m_qrProvider->setImage(img);
            emit authImageReady(); // Используем тот же сигнал для обновления
        }
    }
    else if (requestType == "Shorts") {
        if (parseSuccess && parsedJson.type() == QVariant::Map) {
            QVariantMap map = parsedJson.toMap();
            if (map.contains("shorts")) {
                QVariantList shortsList = map["shorts"].toList();
                QString seqToken = map.value("sequence_token").toString();

                sanitizeVideoList(shortsList);
                emit shortsReady(shortsList, seqToken);
            }
        } else {
            emit requestFailed(requestType, "JSON parse error");
        }
    }

    else if (requestType == "AuthContent") {
        QString content = extractContentFromYtreq(responseString);

        if (content.startsWith("Token:", Qt::CaseInsensitive)) {
            emit authContentReady(content.mid(6).trimmed(), "Token");
        }
        // Если длина больше 100 символов, то это точно наш Base64 QR-код (токены короче)
        else if (content.length() > 100) {
            QString base64Data = content;

            // Если сервер прислал префикс, убираем его
            int b64Index = base64Data.indexOf("base64,");
            if (b64Index != -1) {
                base64Data = base64Data.mid(b64Index + 7);
            }

            // ЖЕСТКАЯ ОЧИСТКА: удаляем все пробелы и переносы строк,
            // которые могут сломать декодер Base64
            base64Data = base64Data.remove('\n').remove('\r').remove(' ');

            // Декодируем и загружаем
            QByteArray imgData = QByteArray::fromBase64(base64Data.toAscii());
            QImage img;
            bool success = img.loadFromData(imgData);

            qDebug() << "[Auth] � азмер Base64:" << base64Data.length();
            qDebug() << "[Auth] Декодирование картинки успешно:" << success;

            if (success && m_qrProvider) {
                // ВАЖНО: Если вы меняли провайдер на поддержку ID (как мы делали для иконок),
                // то вызов должен быть: m_qrProvider->setImage("auth", img);
                // Если оставили старый QrImageProvider, то просто:
                m_qrProvider->setImage(img);

                emit authImageReady();
            } else {
                qDebug() << "[Auth] ОШИБКА: QImage не смог прочитать данные!";
            }
        } else {
            emit authContentReady(content, "Unknown");
        }
    }

    reply->deleteLater();
}
