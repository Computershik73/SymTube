#include "volumekeysobserver.h"
#include <QDebug>
#include <remconcoreapitarget.h>       // Полное определение класса
#include <remconinterfaceselector.h>   // Полное определение класса

VolumeKeysObserver::VolumeKeysObserver(QObject *parent)
    : QObject(parent), m_interfaceSelector(0), m_coreTarget(0)
{
    m_maxVolume = 100;
    m_currentVolume = 50;

    QT_TRAP_THROWING(
        m_interfaceSelector = CRemConInterfaceSelector::NewL();
        m_coreTarget = CRemConCoreApiTarget::NewL(*m_interfaceSelector, *this);
        m_interfaceSelector->OpenTargetL();
    );
}

VolumeKeysObserver::~VolumeKeysObserver()
{
    delete m_interfaceSelector; // Это автоматически удалит m_coreTarget
}

int VolumeKeysObserver::volume() const
{
    return m_currentVolume;
}

void VolumeKeysObserver::setVolume(int vol)
{
    if (vol < 0) vol = 0;
    if (vol > m_maxVolume) vol = m_maxVolume;

    if (m_currentVolume != vol) {
        m_currentVolume = vol;
        emit volumeChanged(m_currentVolume);
    }
}

int VolumeKeysObserver::maxVolume() const
{
    return m_maxVolume;
}

// Этот метод дергается Symbian OS при нажатии на хард-кнопки телефона
void VolumeKeysObserver::MrccatoCommand(TRemConCoreApiOperationId aOperationId, TRemConCoreApiButtonAction aButtonAct)
{
    // ERemConCoreApiButtonClick - одиночное нажатие.
    // ERemConCoreApiButtonPress - удержание. Мы будем обрабатывать и то, и то.
    if (aButtonAct == ERemConCoreApiButtonClick || aButtonAct == ERemConCoreApiButtonPress) {
        switch (aOperationId) {
            case ERemConCoreApiVolumeUp:
                setVolume(m_currentVolume + 10); // Шаг +10%
                emit volumeUpPressed();
                break;

            case ERemConCoreApiVolumeDown:
                setVolume(m_currentVolume - 10); // Шаг -10%
                emit volumeDownPressed();
                break;

            default:
                break;
        }
    }
}
