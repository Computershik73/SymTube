#ifndef HISTORYMANAGER_H
#define HISTORYMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QSettings>

class HistoryManager : public QObject
{
    Q_OBJECT
public:
    explicit HistoryManager(QObject *parent = 0);
    ~HistoryManager();

    Q_INVOKABLE QVariantList getHistory();
    Q_INVOKABLE void addToHistory(const QVariantMap &video);
    Q_INVOKABLE void clearHistory();

signals:
    void historyChanged();

private:
    QSettings *m_settings;
    QVariantList m_history;

    void loadHistory();
    void saveHistory();
};

#endif // HISTORYMANAGER_H
