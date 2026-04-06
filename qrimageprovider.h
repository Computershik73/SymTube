#ifndef QRIMAGEPROVIDER_H
#define QRIMAGEPROVIDER_H

#include <QDeclarativeImageProvider>
#include <QImage>

class QrImageProvider : public QDeclarativeImageProvider
{
public:
    QrImageProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize);
    void setImage(const QImage &image);

private:
    QImage m_image;
};

#endif // QRIMAGEPROVIDER_H
