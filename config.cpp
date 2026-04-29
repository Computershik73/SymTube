#include "config.h"
#include <QSysInfo>

// Константы InnerTube
const QString OAUTH_CLIENT_ID = "861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com";
const QString OAUTH_CLIENT_SECRET = "SboVhoG9s0rNafixCSGGKXAT";
const QString INNERTUBE_API_KEY = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";

Config::Config(QObject *parent) : QObject(parent)
{
    m_settings = new QSettings("SymTubeApp", "Settings", this);
    m_apiKey = INNERTUBE_API_KEY;
    m_userToken = m_settings->value("AuthToken", "").toString();
    m_enableChannelThumbnails = m_settings->value("EnableChannelThumbnails", true).toBool();
    m_persistentVolume = m_settings->value("PersistentVolume", 0.8).toReal();
    m_videoQuality = m_settings->value("VideoQuality", getDefaultQualityByOs()).toString();
}

Config::~Config() {}

QString Config::getDefaultQualityByOs() const
{
#ifdef Q_OS_SYMBIAN
    if (QSysInfo::s60Version() < QSysInfo::SV_S60_5_1) return "240";
    else return "360";
#else
    return "360";
#endif
}

QString Config::apiKey() const { return m_apiKey; }
void Config::setApiKey(const QString &key) {
    if (m_apiKey != key) {
        m_apiKey = key;
        emit apiKeyChanged();
    }
}

QString Config::userToken() const { return m_userToken; }
void Config::setUserToken(const QString &token) {
    if (m_userToken != token) {
        m_userToken = token;
        m_settings->setValue("AuthToken", m_userToken);
        emit userTokenChanged();
    }
}

bool Config::enableChannelThumbnails() const { return m_enableChannelThumbnails; }
void Config::setEnableChannelThumbnails(bool enable) {
    if (m_enableChannelThumbnails != enable) {
        m_enableChannelThumbnails = enable;
        m_settings->setValue("EnableChannelThumbnails", m_enableChannelThumbnails);
        emit enableChannelThumbnailsChanged();
    }
}

qreal Config::persistentVolume() const { return m_persistentVolume; }
void Config::setPersistentVolume(qreal volume) {
    if (volume < 0.0) volume = 0.0;
    if (volume > 1.0) volume = 1.0;
    if (m_persistentVolume != volume) {
        m_persistentVolume = volume;
        m_settings->setValue("PersistentVolume", m_persistentVolume);
        emit persistentVolumeChanged();
    }
}

QString Config::videoQuality() const { return m_videoQuality; }
void Config::setVideoQuality(const QString &quality) {
    if (m_videoQuality != quality) {
        m_videoQuality = quality;
        m_settings->setValue("VideoQuality", m_videoQuality);
        emit videoQualityChanged();
    }
}
