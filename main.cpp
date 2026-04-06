#include <QtGui/QApplication>
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeContext>
#include <QtDeclarative/qdeclarative.h>
#include "qmlapplicationviewer.h"
#include "qrimageprovider.h"
#include <QDeclarativeEngine>
#include <QNetworkConfigurationManager>
#include <QNetworkConfiguration>
#include <QNetworkSession>
#include <QNetworkProxy>


#include "config.h"
#include "apimanager.h"
#include "historymanager.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    // Инициализация менеджеров
    Config config;
    QrImageProvider *qrProvider = new QrImageProvider();
    ApiManager apiManager(&config, qrProvider);
    HistoryManager historyManager;

    QNetworkConfigurationManager manager;
    if (manager.capabilities() & QNetworkConfigurationManager::NetworkSessionRequired) {
        QNetworkConfiguration config = manager.defaultConfiguration();
        QNetworkSession *networkSession = new QNetworkSession(config);
        networkSession->open();
    }

    QNetworkProxy proxy;
         proxy.setType(QNetworkProxy::HttpProxy);
         proxy.setHostName("192.168.1.183");
         proxy.setPort(8890);
      //   QNetworkProxy::setApplicationProxy(proxy);


    QmlApplicationViewer view;

    view.engine()->addImageProvider(QLatin1String("qr"), qrProvider);

    // Оптимизации для Symbian
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);

    // Пробрасываем C++ объекты в QML
    QDeclarativeContext *context = view.rootContext();
    context->setContextProperty("Config", &config);
    context->setContextProperty("ApiManager", &apiManager);
    context->setContextProperty("HistoryManager", &historyManager);

    view.setSource(QUrl::fromLocalFile("qml/qml/main.qml"));

#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
#else
    view.resize(360, 640);
    view.show();
#endif

    return app.exec();
}
