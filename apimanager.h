#ifndef APIMANAGER_H
#define APIMANAGER_H

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QDateTime>
#include "qrimageprovider.h"

class Config;

class ApiManager : public QObject
{
    Q_OBJECT
public:
    explicit ApiManager(Config *config, QrImageProvider *qrProvider, QObject *parent = 0);
    ~ApiManager();
    void setProxyPort(quint16 port);
    void setImageProvider(QrImageProvider *provider);

    // Основные методы
    Q_INVOKABLE void getHomeVideos(const QString &pageToken = QString());
    Q_INVOKABLE void searchVideos(const QString &query);
    Q_INVOKABLE void getVideoInfo(const QString &videoId);
    Q_INVOKABLE void getRelatedVideos(const QString &videoId, int page);
    Q_INVOKABLE void getChannelVideos(const QString &author);
    Q_INVOKABLE void getShorts(const QString &sequenceToken = QString());

    // Восстановленные методы, работающие напрямую с Google/YouTube API
    Q_INVOKABLE void getSearchSuggestions(const QString &query);
    Q_INVOKABLE void getHistory();
    Q_INVOKABLE void getSubscriptions();
    Q_INVOKABLE void getAccountInfo();
    Q_INVOKABLE void checkAuthContent(); // Запрашивает QR-код и опрашивает токен
    Q_INVOKABLE void fetchServerList();

    // Действия (Лайки, Подписки)
    Q_INVOKABLE void checkRating(const QString &videoId) { Q_UNUSED(videoId) } // Заглушка, лайки теперь в VideoInfo
    Q_INVOKABLE void checkSubscription(const QString &channelIdentifier) { Q_UNUSED(channelIdentifier) }
    Q_INVOKABLE void rateVideo(const QString &videoId, const QString &rating);
    Q_INVOKABLE void subscribeToChannel(const QString &channelIdentifier);
    Q_INVOKABLE void unsubscribeFromChannel(const QString &channelIdentifier);

signals:
    void homeVideosReady(QVariantList videos, QString token);
    void searchResultsReady(QVariantList videos);
    void searchSuggestionsReady(QVariantList suggestions);
    void videoInfoReady(QVariantMap videoDetailsMap);
    void relatedVideosReady(QVariantList videos);
    void channelVideosReady(QVariantMap channelDataMap);
    void shortsReady(QVariantList shortsList, QString seqToken);
    void historyReady(QVariantList historyList);
    void subscriptionsReady(QVariantList subscriptions);
    void accountInfoReady(QVariantMap accountInfo);
    void authContentReady(QString content, QString type);
    void authImageReady();
    void serverListReady(const QStringList &servers);
    void requestFailed(QString endpoint, QString errorMessage);

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    void postInnertube(const QString &endpoint, const QVariantMap &payload, const QString &requestType, bool requiresAuth = false);
    QVariantMap buildContext(const QString &clientName, const QString &clientVersion);
    QString getLocaleParams(bool firstParam = false);

    // Управление токенами OAuth
    QString getAccessToken();
    QString m_accessToken;
    QDateTime m_tokenExpiry;
    QString m_deviceCode;
    QString m_userCode;
    quint16 m_proxyPort;
    // Вспомогательные функции парсинга
    QList<QVariantMap> enumerateObjectsWithKey(const QVariant &root, const QString &targetKey);
    QString extractTextFromField(const QVariantMap &obj, const QString &fieldName);
    QString extractThumbnailUrl(const QVariantMap &obj, const QString &fieldName);

    QNetworkAccessManager *m_networkManager;
    Config *m_config;
    QrImageProvider *m_qrProvider;
};

#endif // APIMANAGER_H
