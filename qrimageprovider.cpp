#include "qrimageprovider.h"

QrImageProvider::QrImageProvider()
    : QDeclarativeImageProvider(QDeclarativeImageProvider::Image)
{
}

QImage QrImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    Q_UNUSED(id);
    Q_UNUSED(requestedSize);

    if (m_image.isNull()) {
            // Возвращаем пустую картинку 1x1, чтобы не было ошибки
            QImage empty(1, 1, QImage::Format_ARGB32);
            empty.fill(Qt::transparent);
            if (size) *size = QSize(1, 1);
            return empty;
        }

    if (size) {
        *size = m_image.size();
    }
    return m_image;
}

void QrImageProvider::setImage(const QImage &image)
{
    m_image = image;
}
