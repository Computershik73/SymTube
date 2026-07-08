#include "qsymbianapplication.h"
#include "qmlapplicationviewer.h"
#include <QtDeclarative/QDeclarativeContext>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/qdeclarative.h>

#include <QNetworkConfigurationManager>
#include <QNetworkConfiguration>
#include <QNetworkSession>
#include <QNetworkProxy>
#include <QTextCodec>
#include <dlfcn.h>

#include "config.h"
#include "apimanager.h"
#include "historymanager.h"
#include "qrimageprovider.h"
#include "roundedimageprovider.h"
#include "translationmanager.h"
#include <QFile>
#include "compositornudger.h"
#include "volumekeysobserver.h"
#include <QFont>

#if defined(SYMBIAN) || defined(Q_OS_SYMBIAN)
#include <e32std.h>
#endif

int main(int argc, char *argv[])
{
#if defined(SYMBIAN) || defined(Q_OS_SYMBIAN)

    RThread().SetPriority(EPriorityAbsoluteVeryLow);
#endif
    QFile::remove("C:/Data/SymTube_debug.txt");
    QSymbianApplication app(argc, argv);

    QFont defaultFont("Series 60 Sans");
    app.setFont(defaultFont);


    QApplication::setAttribute(Qt::AA_S60DisablePartialScreenInputMode, false);

    void* library = dlopen("QtGui", 0);
    if (library != 0) {
        void* func = dlsym(library, "12199");
        if (func != 0) {
            ((void(*)(bool)) func)(false);
        }
        dlclose(library);
    }

    // ВОЗВРАЩАЕМ ГЛОБАЛЬНЫЙ ПРОКСИ ЧЕРЕЗ ВАШ VPN!


    QTextCodec *codec = QTextCodec::codecForName("UTF-8");
    QTextCodec::setCodecForTr(codec);
    QTextCodec::setCodecForCStrings(codec);
    QTextCodec::setCodecForLocale(codec);

    QNetworkConfigurationManager manager;
    if (manager.capabilities() & QNetworkConfigurationManager::NetworkSessionRequired) {
        QNetworkConfiguration config = manager.defaultConfiguration();
        QNetworkSession *networkSession = new QNetworkSession(config, &app);
        networkSession->open();
    }

    Config config;
    QrImageProvider *qrProvider = new QrImageProvider();
    ApiManager apiManager(&config, qrProvider);
    HistoryManager historyManager;
    TranslationManager translationManager;
    VolumeKeysObserver volumeKeys;

    QmlApplicationViewer view;
    CompositorNudger *nudger = new CompositorNudger(view.viewport(), &app);

    view.engine()->addImageProvider(QLatin1String("qr"), qrProvider);
    view.engine()->addImageProvider(QLatin1String("rounded"), new RoundedImageProvider());

    QPalette pal = view.palette();
    pal.setColor(QPalette::Window, Qt::black);
    view.setPalette(pal);
    view.setStyleSheet("background: black;");

    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);

    QDeclarativeContext *context = view.rootContext();
    context->setContextProperty("CompositorFix", nudger);
    context->setContextProperty("Config", &config);
    context->setContextProperty("ApiManager", &apiManager);
    context->setContextProperty("HistoryManager", &historyManager);
    context->setContextProperty("SymbianApp", &app);
    context->setContextProperty("TranslationManager", &translationManager);
    context->setContextProperty("VolumeKeys", &volumeKeys);

    view.setSource(QUrl::fromLocalFile("qml/main.qml"));

#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
#else
    view.resize(360, 640);
    view.show();
#endif

    return app.exec();
}
