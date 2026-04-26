#include "config.h"
#include <QSysInfo>

Config::Config(QObject *parent) : QObject(parent)
{
    m_settings = new QSettings("SymTubeApp", "Settings", this);

    m_apiBaseUrl = m_settings->value("ApiBaseUrl", "http://yt.modyleprojects.ru/").toString();
    if (!m_apiBaseUrl.endsWith("/")) {
        m_apiBaseUrl += "/";
    }

    m_apiKey = m_settings->value("YouTubeApiKey", "").toString();
    m_userToken = m_settings->value("AuthToken", "").toString();
    m_enableChannelThumbnails = m_settings->value("EnableChannelThumbnails", true).toBool();
    m_persistentVolume = m_settings->value("PersistentVolume", 0.45).toReal();
    m_videoQuality = m_settings->value("VideoQuality", getDefaultQualityByOs()).toString();
}

Config::~Config()
{
}

QString Config::getDefaultQualityByOs() const
{
#ifdef Q_OS_SYMBIAN
    // Версии до SV_S60_5_1 — это Symbian 9.2, 9.3, 9.4. Начиная с 5_1 — Symbian^3/Anna/Belle.
    if (QSysInfo::s60Version() < QSysInfo::SV_S60_5_1) {
        return "240";
    } else {
        return "360";
    }
#else
    return "360";
#endif
}

qreal Config::persistentVolume() const
{
    return m_persistentVolume;
}

void Config::setPersistentVolume(qreal volume)
{
    if (volume < 0.0) volume = 0.0;
    if (volume > 1.0) volume = 1.0;

    if (m_persistentVolume != volume) {
        m_persistentVolume = volume;
        m_settings->setValue("PersistentVolume", m_persistentVolume);
        emit persistentVolumeChanged();
    }
}

QString Config::apiBaseUrl() const
{
    return m_apiBaseUrl;
}

void Config::setApiBaseUrl(const QString &url)
{
    QString formattedUrl = url;
    if (!formattedUrl.endsWith("/")) {
        formattedUrl += "/";
    }
    if (m_apiBaseUrl != formattedUrl) {
        m_apiBaseUrl = formattedUrl;
        m_settings->setValue("ApiBaseUrl", m_apiBaseUrl);
        emit apiBaseUrlChanged();
    }
}

QString Config::apiKey() const
{
    return m_apiKey;
}

void Config::setApiKey(const QString &key)
{
    if (m_apiKey != key) {
        m_apiKey = key;
        m_settings->setValue("YouTubeApiKey", m_apiKey);
        emit apiKeyChanged();
    }
}

QString Config::userToken() const
{
    return m_userToken;
}

void Config::setUserToken(const QString &token)
{
    if (m_userToken != token) {
        m_userToken = token;
        m_settings->setValue("AuthToken", m_userToken);
        emit userTokenChanged();
    }
}

bool Config::enableChannelThumbnails() const
{
    return m_enableChannelThumbnails;
}

void Config::setEnableChannelThumbnails(bool enable)
{
    if (m_enableChannelThumbnails != enable) {
        m_enableChannelThumbnails = enable;
        m_settings->setValue("EnableChannelThumbnails", m_enableChannelThumbnails);
        emit enableChannelThumbnailsChanged();
    }
}

QString Config::videoQuality() const
{
    return m_videoQuality;
}

void Config::setVideoQuality(const QString &quality)
{
    if (m_videoQuality != quality) {
        m_videoQuality = quality;
        m_settings->setValue("VideoQuality", m_videoQuality);
        emit videoQualityChanged();
    }
}


QString Config::getVideoUrl(const QString &videoId, const QString &quality) const
{
    QString url = m_apiBaseUrl + "direct_url?video_id=" + videoId;
    if (!quality.isEmpty()) {
        url += "&quality=" + quality;
    }
    return url;
}
