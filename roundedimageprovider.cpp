#include "roundedimageprovider.h"
#include <QPainter>
#include <QPainterPath>
#include <QUrl>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QDebug>
#include <QMutex>
#include <QTimer>

// Глобальный мьютекс для сериализации сетевых запросов.
// Спасает от падений OpenSSL при попытке одновременного скачивания по HTTPS.
static QMutex s_networkMutex;

RoundedImageProvider::RoundedImageProvider()
    : QDeclarativeImageProvider(QDeclarativeImageProvider::Image)
{
    // Выделяем 10 МБ памяти под кэш изображений
    m_cache.setMaxCost(4 * 1024 * 1024);
}

QImage RoundedImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QString decodedId = QUrl::fromPercentEncoding(id.toUtf8());

    // 1. БЕЗОПАСНО проверяем кэш
    m_mutex.lock();
    if (QImage *cachedImg = m_cache.object(decodedId)) {
        QImage result = *cachedImg;
        if (size) *size = result.size();
        m_mutex.unlock();
        return result;
    }
    m_mutex.unlock();

    QImage originalImage;

    // 2. Скачивание изображения (в фоновом потоке от QML)
    if (decodedId.startsWith("http://") || decodedId.startsWith("https://")) {

        s_networkMutex.lock();

            QNetworkAccessManager manager;
            manager.setParent(0);
            QUrl requestUrl = QUrl::fromEncoded(decodedId.toUtf8());
            QNetworkReply *reply = manager.get(QNetworkRequest(requestUrl));
            reply->ignoreSslErrors();

            // Предохранитель: прерываем ожидание, если картинка не скачалась за 5 секунд
            QEventLoop loop;
            QTimer timeoutTimer;
            timeoutTimer.setSingleShot(true);
            QObject::connect(&timeoutTimer, SIGNAL(timeout()), &loop, SLOT(quit()));
            QObject::connect(reply, SIGNAL(finished()), &loop, SLOT(quit()));
            timeoutTimer.start(5000);

            loop.exec();

            if (reply->isRunning()) {
                reply->abort();
            } else if (reply->error() == QNetworkReply::NoError) {
                originalImage.loadFromData(reply->readAll());
            }

            reply->disconnect();
            delete reply;

            s_networkMutex.unlock();


    } else if (decodedId.startsWith("qrc:/")) {
        originalImage.load(":" + decodedId.mid(4));
    } else {
        originalImage.load(decodedId);
    }

    // Заглушка: если картинка не загрузилась (нет сети), возвращаем прозрачный фон
    if (originalImage.isNull()) {
        int w = requestedSize.isValid() ? requestedSize.width() : 64;
        int h = requestedSize.isValid() ? requestedSize.height() : 64;
        QImage empty(w, h, QImage::Format_ARGB32_Premultiplied);
        empty.fill(Qt::transparent);
        return empty;
    }

    // 3. Скругляем (сглаживание Antialiasing применяется внутри roundImage)
    QImage rounded = roundImage(originalImage);

    // Масштабируем до требуемого размера (запрошенного QML)
    if (requestedSize.isValid()) {
        rounded = rounded.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    if (size) *size = rounded.size();

    // 4. БЕЗОПАСНО сохраняем готовую круглую картинку в кэш
    m_mutex.lock();
    m_cache.insert(decodedId, new QImage(rounded), rounded.byteCount());
    m_mutex.unlock();

    return rounded;
}

QImage RoundedImageProvider::roundImage(const QImage &img)
{
    // Обрезаем по центру, чтобы картинка была квадратной
    int squareSize = qMin(img.width(), img.height());
    QRect targetRect(0, 0, squareSize, squareSize);
    QImage squareImg = img.copy((img.width() - squareSize) / 2,
                                (img.height() - squareSize) / 2,
                                squareSize, squareSize);

    // Создаем пустой холст с прозрачным фоном (Alpha Channel)
    QImage roundedImg(squareSize, squareSize, QImage::Format_ARGB32_Premultiplied);
    roundedImg.fill(Qt::transparent);

    QPainter painter(&roundedImg);
    // Включаем самое качественное сглаживание краев
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);

    // Накладываем круглую маску
    QPainterPath path;
    path.addEllipse(targetRect);
    painter.setClipPath(path);

    // Рисуем картинку
    painter.drawImage(targetRect, squareImg);

    return roundedImg;
}
