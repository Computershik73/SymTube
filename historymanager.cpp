#include "historymanager.h"
#include "json.h"
#include <QString>
#include <QByteArray>

HistoryManager::HistoryManager(QObject *parent) : QObject(parent)
{
    m_settings = new QSettings("YouTubeClient", "History", this);
    loadHistory();
}

HistoryManager::~HistoryManager()
{
}

void HistoryManager::loadHistory()
{
    QString jsonStr = m_settings->value("ViewHistory", "[]").toString();
    bool success = false;
    QVariant parsed = QtJson::parse(jsonStr, success);

    if (success && parsed.type() == QVariant::List) {
        m_history = parsed.toList();
    } else {
        m_history = QVariantList();
    }
}

void HistoryManager::saveHistory()
{
    bool success = false;
    QByteArray jsonBytes = QtJson::serialize(m_history, success);
    if (success) {
        m_settings->setValue("ViewHistory", QString::fromUtf8(jsonBytes));
    }
}

QVariantList HistoryManager::getHistory()
{
    return m_history;
}

void HistoryManager::addToHistory(const QVariantMap &video)
{
    QString videoId = video.value("video_id").toString();
    if (videoId.isEmpty()) return;

    // Удаляем, если уже есть в истории (чтобы поднять наверх)
    for (int i = 0; i < m_history.size(); ++i) {
        QVariantMap item = m_history.at(i).toMap();
        if (item.value("video_id").toString() == videoId) {
            m_history.removeAt(i);
            break;
        }
    }

    // Добавляем в начало
    m_history.prepend(video);

    // Оставляем только последние 100 элементов
    while (m_history.size() > 100) {
        m_history.removeLast();
    }

    saveHistory();
    emit historyChanged();
}

void HistoryManager::clearHistory()
{
    m_history.clear();
    saveHistory();
    emit historyChanged();
}
