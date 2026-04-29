#ifndef LOCALHTTPPROXY_H
#define LOCALHTTPPROXY_H

#include <QObject>
#include <QTcpServer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTcpSocket>
#include <QMap>

class LocalHttpProxy : public QObject
{
    Q_OBJECT
public:
    explicit LocalHttpProxy(QObject *parent = 0);
    ~LocalHttpProxy();

    bool start();
    quint16 serverPort() const;

private slots:
    void onNewConnection();
    void onClientReadyRead();
    void onClientDisconnected();

    void onProxyReplyFinished();
    void onProxyReadyRead();
    void onProxyHeadersReceived();


private:
    QTcpServer* m_server;
    QNetworkAccessManager* m_networkManager;

    // Связываем сокет от плеера с ответом от Google
    QMap<QTcpSocket*, QNetworkReply*> m_connections;
};

#endif // LOCALHTTPPROXY_H
