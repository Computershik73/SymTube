#ifndef TRANSLATIONMANAGER_H
#define TRANSLATIONMANAGER_H

#include <QObject>
#include <QStringList>
#include <QTranslator>

class TranslationManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentLanguage READ currentLanguage NOTIFY languageChanged)
    Q_PROPERTY(QStringList availableLanguages READ availableLanguages CONSTANT)

public:
    explicit TranslationManager(QObject *parent = 0);
    ~TranslationManager();

    QString currentLanguage() const;
    QStringList availableLanguages() const;

    // Вызывается из QML для смены языка
    Q_INVOKABLE void setLanguage(const QString &localeName);

signals:
    void languageChanged();

private:
    QString m_currentLanguage;
    QStringList m_availableLanguages;
    QTranslator *m_translator;
    QString m_customPath;

    void scanDirectory();
};

#endif // TRANSLATIONMANAGER_H
