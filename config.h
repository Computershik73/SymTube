#ifndef CONFIG_H
#define CONFIG_H

#include <QObject>
#include <QString>
#include <QSettings>

class Config : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString apiBaseUrl READ apiBaseUrl WRITE setApiBaseUrl NOTIFY apiBaseUrlChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString userToken READ userToken WRITE setUserToken NOTIFY userTokenChanged)
    Q_PROPERTY(bool enableChannelThumbnails READ enableChannelThumbnails WRITE setEnableChannelThumbnails NOTIFY enableChannelThumbnailsChanged)
    Q_PROPERTY(qreal persistentVolume READ persistentVolume WRITE setPersistentVolume NOTIFY persistentVolumeChanged)

public:
    explicit Config(QObject *parent = 0);
    ~Config();

    QString apiBaseUrl() const;
    void setApiBaseUrl(const QString &url);

    QString apiKey() const;
    void setApiKey(const QString &key);

    QString userToken() const;
    void setUserToken(const QString &token);

    bool enableChannelThumbnails() const;
    void setEnableChannelThumbnails(bool enable);

    qreal persistentVolume() const;
    void setPersistentVolume(qreal volume);

    Q_INVOKABLE QString getVideoUrl(const QString &videoId, const QString &quality = QString()) const;

signals:
    void apiBaseUrlChanged();
    void apiKeyChanged();
    void userTokenChanged();
    void enableChannelThumbnailsChanged();
    void persistentVolumeChanged();

private:
    QSettings *m_settings;
    QString m_apiBaseUrl;
    QString m_apiKey;
    QString m_userToken;
    bool m_enableChannelThumbnails;
    qreal m_persistentVolume;
};

#endif // CONFIG_H
