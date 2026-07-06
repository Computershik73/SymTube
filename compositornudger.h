#ifndef COMPOSITORNUDGER_H
#define COMPOSITORNUDGER_H

#include <QObject>
#include <QTimer>
#include <QPointer>

class QWidget;

// Обход бага композитора Belle FP2: не даём window server
// закэшировать окно как статичное и закрыть видеоповерхность.
class CompositorNudger : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit CompositorNudger(QWidget *viewport, QObject *parent = 0);

    bool active() const { return m_active; }
    void setActive(bool active);

signals:
    void activeChanged();

private slots:
    void nudge();

private:
    QPointer<QWidget> m_viewport;
    QTimer m_timer;
    bool m_active;
};

#endif // COMPOSITORNUDGER_H
