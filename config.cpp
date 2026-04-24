#include "config.h"

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
}

Config::~Config()
{
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

QString Config::getVideoUrl(const QString &videoId, const QString &quality) const
{
    QString url = m_apiBaseUrl + "direct_url?video_id=" + videoId;
    if (!quality.isEmpty()) {
        url += "&quality=" + quality;
    }
    return url;
}
