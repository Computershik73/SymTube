#include "localhttpproxy.h"
#include <QNetworkRequest>
#include <QNetworkProxy>
#include <QUrl>
#include <QDebug>
#include <QStringList>

LocalHttpProxy::~LocalHttpProxy()
{
}

LocalHttpProxy::LocalHttpProxy(QObject *parent) : QObject(parent)
{
    m_server = new QTcpServer(this);
    m_networkManager = new QNetworkAccessManager(this);

    // 1. НАСТРАИВАЕМ ВНЕШНИЙ ПРОКСИ (Чтобы прокси на телефоне мог обойти блокировку)
    QNetworkProxy extProxy;
    extProxy.setType(QNetworkProxy::HttpProxy);
    extProxy.setHostName("192.168.1.183"); // IP вашего ПК
    extProxy.setPort(8890);                // Порт вашего прокси
    m_networkManager->setProxy(extProxy);
}

bool LocalHttpProxy::start()
{
    connect(m_server, SIGNAL(newConnection()), this, SLOT(onNewConnection()));

    // 2. СЛУШАЕМ НА ВСЕХ АДРЕСАХ (Иногда 127.0.0.1 на Symbian глючит)
    // Попробуем порт 8080 или 0 для автовыбора
    return m_server->listen(QHostAddress::Any, 8080);
}

void LocalHttpProxy::onNewConnection()
{
    qDebug() << "Proxy: New connection incoming!";
    QTcpSocket *clientSocket = m_server->nextPendingConnection();
    if (clientSocket) {
        connect(clientSocket, SIGNAL(readyRead()), this, SLOT(onClientReadyRead()));
        connect(clientSocket, SIGNAL(disconnected()), this, SLOT(onClientDisconnected()));
    }
}

void LocalHttpProxy::onClientReadyRead()
{
    QTcpSocket *clientSocket = qobject_cast<QTcpSocket*>(sender());
    if (!clientSocket || m_connections.contains(clientSocket)) return;

    QByteArray requestData = clientSocket->readAll();
    QString requestString(requestData);

    // Ищем наш параметр b64url
    int b64Index = requestString.indexOf("b64url=");
    if (b64Index == -1) return;

    int spaceIndex = requestString.indexOf(" ", b64Index);
    QByteArray encodedUrl = requestString.mid(b64Index + 7, spaceIndex - (b64Index + 7)).toUtf8();

    // Декодируем обратно в чистую ссылку Google
    QByteArray rawUrl = QByteArray::fromBase64(encodedUrl);
    QString realUrl = QString::fromUtf8(rawUrl);

    if (realUrl.isEmpty()) return;

    qDebug() << "Proxy fixing URL and forwarding to Google Video...";

    // Используем fromEncoded, чтобы Qt не пытался "умничать" с процентами
    QUrl targetUrl = QUrl::fromEncoded(rawUrl);
    QNetworkRequest proxyRequest(targetUrl);

    // СТРОГОЕ СООТВЕТСТВИЕ ИДЕАЛЬНОМУ КЛИЕНТУ (UWP / NSPlayer)
    proxyRequest.setRawHeader("Host", targetUrl.host().toUtf8());
    proxyRequest.setRawHeader("User-Agent", "NSPlayer/12.00.15254.0603 WMFSDK/12.00.15254.0603");
    proxyRequest.setRawHeader("Accept", "*/*");
    proxyRequest.setRawHeader("GetContentFeatures.DLNA.ORG", "1");
    proxyRequest.setRawHeader("Accept-Language", "ru-RU,en,*");
    proxyRequest.setRawHeader("Connection", "Keep-Alive");

    // Копируем Range или ставим по умолчанию
    bool rangeFound = false;
    QStringList lines = requestString.split("\r\n");
    foreach (const QString &line, lines) {
        if (line.startsWith("Range:", Qt::CaseInsensitive)) {
            proxyRequest.setRawHeader("Range", line.mid(6).trimmed().toUtf8());
            rangeFound = true;
            break;
        }
    }
    if (!rangeFound) {
        proxyRequest.setRawHeader("Range", "bytes=0-");
    }

    QNetworkReply *proxyReply = m_networkManager->get(proxyRequest);
    m_connections.insert(clientSocket, proxyReply);

    connect(proxyReply, SIGNAL(finished()), this, SLOT(onProxyReplyFinished()));
    connect(proxyReply, SIGNAL(readyRead()), this, SLOT(onProxyReadyRead()));
    connect(proxyReply, SIGNAL(metaDataChanged()), this, SLOT(onProxyHeadersReceived()));
}



void LocalHttpProxy::onProxyHeadersReceived()
{
    QNetworkReply* proxyReply = qobject_cast<QNetworkReply*>(sender());
    if (!proxyReply) return;

    QTcpSocket* clientSocket = m_connections.key(proxyReply);
    if (!clientSocket) return;

    QByteArray headers;
    int statusCode = proxyReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QString reason = proxyReply->attribute(QNetworkRequest::HttpReasonPhraseAttribute).toString();

    headers.append(QString("HTTP/1.1 %1 %2\r\n").arg(statusCode).arg(reason).toUtf8());

    foreach(const QNetworkReply::RawHeaderPair& pair, proxyReply->rawHeaderPairs()) {
        QString hName = QString(pair.first).toLower();
        // Пропускаем специфичные заголовки Google, отдаем только нужные для медиа
        if (hName == "content-type" || hName == "content-length" || hName == "content-range" || hName == "accept-ranges") {
            headers.append(pair.first + ": " + pair.second + "\r\n");
        }
    }
    headers.append("\r\n");
    clientSocket->write(headers);
}

void LocalHttpProxy::onProxyReadyRead()
{
    QNetworkReply* proxyReply = qobject_cast<QNetworkReply*>(sender());
    if (!proxyReply) return;

    QTcpSocket* clientSocket = m_connections.key(proxyReply);
    if (clientSocket && clientSocket->isOpen()) {
        clientSocket->write(proxyReply->readAll());
    }
}

void LocalHttpProxy::onProxyReplyFinished()
{
    QNetworkReply* proxyReply = qobject_cast<QNetworkReply*>(sender());
    if (!proxyReply) return;

    QTcpSocket* clientSocket = m_connections.key(proxyReply);
    if (clientSocket) {
        clientSocket->disconnectFromHost();
    }
    proxyReply->deleteLater();
}

void LocalHttpProxy::onClientDisconnected()
{
    QTcpSocket *clientSocket = qobject_cast<QTcpSocket*>(sender());
    if (!clientSocket) return;

    QNetworkReply *proxyReply = m_connections.take(clientSocket);
    if (proxyReply) {
        proxyReply->abort();
        proxyReply->deleteLater();
    }
    clientSocket->deleteLater();
}
