#ifndef APIMANAGER_H
#define APIMANAGER_H

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include "qrimageprovider.h"

class Config;
class QrImageProvider;

class ApiManager : public QObject
{
    Q_OBJECT

public:
    explicit ApiManager(Config *config, QrImageProvider *qrProvider, QObject *parent = 0);
    void setImageProvider(QrImageProvider *provider);
    ~ApiManager();

    // Home API
    Q_INVOKABLE void getHomeVideos(const QString &pageToken = QString());
    Q_INVOKABLE void getShorts(const QString &sequenceToken = QString());
    // Search API
    Q_INVOKABLE void searchVideos(const QString &query);
    Q_INVOKABLE void getSearchSuggestions(const QString &query);

    // Video API
    Q_INVOKABLE void getVideoInfo(const QString &videoId);
    Q_INVOKABLE void getRelatedVideos(const QString &videoId, int page);
    Q_INVOKABLE void checkRating(const QString &videoId);
    Q_INVOKABLE void checkSubscription(const QString &channelIdentifier);
    Q_INVOKABLE void rateVideo(const QString &videoId, const QString &rating);
    Q_INVOKABLE void subscribeToChannel(const QString &channelIdentifier);
    Q_INVOKABLE void unsubscribeFromChannel(const QString &channelIdentifier);

    // Channel API
    Q_INVOKABLE void getChannelVideos(const QString &author);

    // Subscriptions API
    Q_INVOKABLE void getSubscriptions();

    // Account API
    Q_INVOKABLE void getAccountInfo();

    // Auth API

    Q_INVOKABLE void checkAuthContent();



    void downloadChannelIcon(const QString &url);

    void sanitizeVideoList(QVariantList &list);

    Q_INVOKABLE void getHistory();


signals:
    // Сигналы для QML об успешном получении данных
    void homeVideosReady(QVariantList videos, QString token);
    void searchResultsReady(QVariantList videos);
    void searchSuggestionsReady(QVariantList suggestions);
    void videoInfoReady(QVariantMap videoDetailsMap);
    void relatedVideosReady(QVariantList videos);
    void channelVideosReady(QVariantMap channelDataMap);
    void subscriptionsReady(QVariantList subscriptions);
    void accountInfoReady(QVariantMap accountInfo);
    void authContentReady(QString content, QString type);

    void ratingChecked(QString rating);
    void subscriptionChecked(bool isSubscribed);
    void actionCompleted(QString action, QString status, QString message);

    void requestFailed(QString endpoint, QString errorMessage);
    void authImageReady();
    void shortsReady(QVariantList shortsList, QString seqToken);
    void historyReady(QVariantList historyList);
private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    void sendRequest(const QString &url, const QString &requestType);
    QString extractContentFromYtreq(const QString &response);
    QString getLocaleParams(bool firstParam = false);

    QNetworkAccessManager *m_networkManager;
    Config *m_config;

    QrImageProvider *m_qrProvider;
};

#endif // APIMANAGER_H
