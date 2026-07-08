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
#include "apimanager.h"

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

    // 1. Проверяем локальный кэш картинок
    m_mutex.lock();
    if (QImage *cachedImg = m_cache.object(decodedId)) {
        QImage result = *cachedImg;
        if (size) *size = result.size();
        m_mutex.unlock();
        return result;
    }
    m_mutex.unlock();

    QImage originalImage;

    // 2. Скачивание изображения (БЕЗОПАСНЫЙ СИНХРОННЫЙ ВЫЗОВ ГЛАВНОГО ПОТОКА)
    if (decodedId.startsWith("http://") || decodedId.startsWith("https://")) {
        QByteArray imgData;
        ApiManager *api = ApiManager::instance();

        if (api) {
            // Вызываем метод скачивания на ГЛАВНОМ GUI-потоке,
            // фоновый поток рендеринга QML безопасно блокируется и ждет результат.
            QMetaObject::invokeMethod(api, "downloadImageSync",
                                      Qt::BlockingQueuedConnection,
                                      Q_RETURN_ARG(QByteArray, imgData),
                                      Q_ARG(QString, decodedId));
        }

        if (!imgData.isEmpty()) {
            originalImage.loadFromData(imgData);
        }
    } else if (decodedId.startsWith("qrc:/")) {
        originalImage.load(":" + decodedId.mid(4));
    } else {
        originalImage.load(decodedId);
    }

    // Заглушка при отсутствии сети
    if (originalImage.isNull()) {
        int w = requestedSize.isValid() ? requestedSize.width() : 64;
        int h = requestedSize.isValid() ? requestedSize.height() : 64;
        QImage empty(w, h, QImage::Format_ARGB32_Premultiplied);
        empty.fill(Qt::transparent);
        return empty;
    }

    // 3. Скругляем оригинальное изображение
    QImage rounded = roundImage(originalImage);

    if (requestedSize.isValid()) {
        rounded = rounded.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    if (size) *size = rounded.size();

    // 4. Сохраняем в кэш
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
