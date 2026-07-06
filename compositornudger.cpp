#include "compositornudger.h"
#include <QWidget>

#ifdef Q_OS_SYMBIAN
#include <mw/coemain.h>   // CCoeEnv, LIBS += -lcone (у вас уже подключено)
#include <w32std.h>    // RWsSession
#endif

CompositorNudger::CompositorNudger(QWidget *viewport, QObject *parent)
    : QObject(parent), m_viewport(viewport), m_active(false)
{
    // Интервал ДОЛЖЕН быть меньше таймаута кэширования (~10 сек).
    // 4 секунды дают запас и почти не жрут батарею.
    m_timer.setInterval(4000);
    connect(&m_timer, SIGNAL(timeout()), this, SLOT(nudge()));
}

void CompositorNudger::setActive(bool active)
{
    if (m_active == active) return;
    m_active = active;

    if (m_active) {
        nudge();        // сразу, не ждём первого срабатывания
        m_timer.start();
    } else {
        m_timer.stop();
    }
    emit activeChanged();
}

void CompositorNudger::nudge()
{
    // 1. Полная перерисовка viewport'a QDeclarativeView.
    //    Заново рисуется "дырка" под видеоповерхность,
    //    окно перестаёт считаться статичным.
    if (m_viewport) {
        m_viewport->update();
    }

#ifdef Q_OS_SYMBIAN
    // 2. Толкаем window server, чтобы композиция произошла немедленно,
    //    а не когда ему захочется.
    CCoeEnv *env = CCoeEnv::Static();
    if (env) {
        env->Flush();
    }
#endif
}
