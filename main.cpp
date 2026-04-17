#include "qsymbianapplication.h"
#include "qmlapplicationviewer.h"
#include <QtDeclarative/QDeclarativeContext>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/qdeclarative.h>

// Ваши сетевые заголовки
#include <QNetworkConfigurationManager>
#include <QNetworkConfiguration>
#include <QNetworkSession>
#include <QNetworkProxy>
#include <QTextCodec>
#include <dlfcn.h>

// Наши классы
#include "config.h"
#include "apimanager.h"
#include "historymanager.h"
#include "qrimageprovider.h"
#include "roundedimageprovider.h"
#include "volumekeysobserver.h"

int main(int argc, char *argv[])
{
    QSymbianApplication app(argc, argv);

    QApplication::setAttribute(Qt::AA_S60DisablePartialScreenInputMode, false);

    // Динамическая загрузка фикса для частичной клавиатуры (Qt 4.8+ specific hack)
    void* library = dlopen("QtGui", 0);
    if (library != 0) {
        // Символ для qt_s60_setPartialScreenAutomaticTranslation(bool)
        void* func = dlsym(library, "12199");
        if (func != 0) {
            ((void(*)(bool)) func)(false);
        }
        dlclose(library);
    }

    QTextCodec *codec = QTextCodec::codecForName("UTF-8");
    QTextCodec::setCodecForTr(codec);
    QTextCodec::setCodecForCStrings(codec);
    QTextCodec::setCodecForLocale(codec);

    // 1. Настройка сети (как у вас)
    QNetworkConfigurationManager manager;
    if (manager.capabilities() & QNetworkConfigurationManager::NetworkSessionRequired) {
        // На Symbian это обязательно для установления соединения
        QNetworkConfiguration config = manager.defaultConfiguration();
        QNetworkSession *networkSession = new QNetworkSession(config, &app); // Привязываем к жизни приложения
        networkSession->open();
    }

    QNetworkProxy proxy;
    proxy.setType(QNetworkProxy::HttpProxy);
    proxy.setHostName("192.168.116.224");
    proxy.setPort(8888);
    //QNetworkProxy::setApplicationProxy(proxy);

    // 2. Инициализация менеджеров
    Config config;
    // Создаем провайдер ПЕРЕД ApiManager
    QrImageProvider *qrProvider = new QrImageProvider();
    // Передаем указатель на провайдер в конструктор
    ApiManager apiManager(&config, qrProvider);
    HistoryManager historyManager;
    VolumeKeysObserver volumeKeys;

    // 3. Используем чистый QDeclarativeView
    QmlApplicationViewer view;

    // 4. Добавляем Image Provider в движок QML
    view.engine()->addImageProvider(QLatin1String("qr"), qrProvider);
    view.engine()->addImageProvider(QLatin1String("rounded"), new RoundedImageProvider());

    QPalette pal = view.palette();
    pal.setColor(QPalette::Window, Qt::black);
    view.setPalette(pal);
    view.setStyleSheet("background: black;"); // Дополнительно для QWidget-контейнера

    // Оптимизация: не очищать фон каждый раз (ускоряет Symbian)
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);

    // Оптимизации для Symbian
    //view.setAttribute(Qt::WA_OpaquePaintEvent);
    //view.setAttribute(Qt::WA_NoSystemBackground);
    //view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    //view.viewport()->setAttribute(Qt::WA_NoSystemBackground);

    // 5. Пробрасываем C++ объекты в QML
    QDeclarativeContext *context = view.rootContext();
    context->setContextProperty("Config", &config);
    context->setContextProperty("ApiManager", &apiManager);
    context->setContextProperty("HistoryManager", &historyManager);
    context->setContextProperty("VolumeKeys", &volumeKeys);
    context->setContextProperty("SymbianApp", &app);

    // 6. Загружаем QML
    view.setSource(QUrl::fromLocalFile("qml/main.qml"));

#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
#else
    view.resize(360, 640);
    view.show();
#endif

    return app.exec();
}
