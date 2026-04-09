#ifndef ROUNDEDIMAGEPROVIDER_H
#define ROUNDEDIMAGEPROVIDER_H

#include <QDeclarativeImageProvider>
#include <QImage>
#include <QCache>
#include <QMutex>

class RoundedImageProvider : public QDeclarativeImageProvider
{
public:
    RoundedImageProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize);

private:
    QImage roundImage(const QImage &img);
    // Кэш для готовых аватарок, чтобы не скачивать их при каждом скролле
    QCache<QString, QImage> m_cache;
    QMutex m_mutex;
};

#endif // ROUNDEDIMAGEPROVIDER_H
