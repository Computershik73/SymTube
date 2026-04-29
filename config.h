#ifndef CONFIG_H
#define CONFIG_H

#include <QObject>
#include <QString>
#include <QSettings>

class Config : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString userToken READ userToken WRITE setUserToken NOTIFY userTokenChanged)
    Q_PROPERTY(bool enableChannelThumbnails READ enableChannelThumbnails WRITE setEnableChannelThumbnails NOTIFY enableChannelThumbnailsChanged)
    Q_PROPERTY(qreal persistentVolume READ persistentVolume WRITE setPersistentVolume NOTIFY persistentVolumeChanged)
    Q_PROPERTY(QString videoQuality READ videoQuality WRITE setVideoQuality NOTIFY videoQualityChanged)

public:
    explicit Config(QObject *parent = 0);
    ~Config();

    QString apiKey() const;
    void setApiKey(const QString &key);

    QString userToken() const;
    void setUserToken(const QString &token);

    bool enableChannelThumbnails() const;
    void setEnableChannelThumbnails(bool enable);

    qreal persistentVolume() const;
    void setPersistentVolume(qreal volume);

    QString videoQuality() const;
    void setVideoQuality(const QString &quality);

signals:
    void apiKeyChanged();
    void userTokenChanged();
    void enableChannelThumbnailsChanged();
    void persistentVolumeChanged();
    void videoQualityChanged();

private:
    QSettings *m_settings;
    QString m_apiKey;
    QString m_userToken;
    bool m_enableChannelThumbnails;
    qreal m_persistentVolume;
    QString m_videoQuality;

    QString getDefaultQualityByOs() const;
};

#endif // CONFIG_H
