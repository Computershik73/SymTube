#ifndef VOLUMEKEYSOBSERVER_H
#define VOLUMEKEYSOBSERVER_H

#include <QObject>

// Symbian-специфичные классы, которые мы будем использовать только как указатели
// Мы их пред-объявляем, а инклуды перенесем в .cpp файл
class CRemConInterfaceSelector;
class CRemConCoreApiTarget;

#include <remconcoreapitargetobserver.h> // Этот заголовок содержит M-класс (интерфейс), его нужно включить

class VolumeKeysObserver : public QObject, public MRemConCoreApiTargetObserver
{
    Q_OBJECT
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(int maxVolume READ maxVolume CONSTANT)

public:
    explicit VolumeKeysObserver(QObject *parent = 0);
    ~VolumeKeysObserver();

    int volume() const;
    void setVolume(int vol);
    int maxVolume() const;

signals:
    void volumeChanged(int volume);
    void volumeUpPressed();
    void volumeDownPressed();

private: // From MRemConCoreApiTargetObserver
    void MrccatoCommand(TRemConCoreApiOperationId aOperationId, TRemConCoreApiButtonAction aButtonAct);

private:
    CRemConInterfaceSelector *m_interfaceSelector;
    CRemConCoreApiTarget *m_coreTarget;
    int m_currentVolume;
    int m_maxVolume;
};

#endif // VOLUMEKEYSOBSERVER_H
