#include "translationmanager.h"
#include <QApplication>
#include <QSettings>
#include <QDir>
#include <QDebug>

TranslationManager::TranslationManager(QObject *parent)
    : QObject(parent), m_translator(new QTranslator(this))
{
    // Папка для пользовательских файлов локализации на Symbian
    m_customPath = "E:/SymTube/lang";
    QDir().mkpath(m_customPath);

    scanDirectory();

    // Загружаем сохраненный язык или русский по умолчанию
    QSettings settings("YouTubeClient", "Settings");
    QString savedLang = settings.value("Language", "ru_RU").toString();

    // Если файла нет, откатываемся на en_US
    if (!m_availableLanguages.contains(savedLang)) {
        savedLang = "en_US";
    }
    setLanguage(savedLang);
}

TranslationManager::~TranslationManager()
{
}

void TranslationManager::scanDirectory()
{
    m_availableLanguages.clear();

    // Базовые встроенные языки
    m_availableLanguages << "ru_RU" << "en_US" << "pl_PL";

    // Сканируем пользовательские файлы *.qm на карте памяти
    QDir dir(m_customPath);
    if (dir.exists()) {
        QStringList filters;
        filters << "*.qm";
        QStringList files = dir.entryList(filters, QDir::Files);
        for (int i = 0; i < files.size(); ++i) {
            QString lang = files.at(i);
            lang.remove(".qm"); // Убираем расширение, оставляя только "fr_FR" и т.д.
            if (!m_availableLanguages.contains(lang)) {
                m_availableLanguages.append(lang);
            }
        }
    }
}

QString TranslationManager::currentLanguage() const
{
    return m_currentLanguage;
}

QStringList TranslationManager::availableLanguages() const
{
    return m_availableLanguages;
}

void TranslationManager::setLanguage(const QString &localeName)
{
    m_currentLanguage = localeName;

    QSettings settings("YouTubeClient", "Settings");
    settings.setValue("Language", localeName);

    // Удаляем старый перевод
    qApp->removeTranslator(m_translator);

    // 1. Пробуем загрузить кастомный файл с карты памяти
    if (m_translator->load(localeName + ".qm", m_customPath)) {
        qApp->installTranslator(m_translator);
        qDebug() << "[Lang] Loaded custom translation:" << localeName;
    }
    // 2. Иначе грузим из встроенных ресурсов приложения
    else if (m_translator->load("SymTube_" + localeName + ".qm", ":/lang")) {
        qApp->installTranslator(m_translator);
        qDebug() << "[Lang] Loaded internal translation:" << localeName;
    } else {
        qDebug() << "[Lang] Translation not found, fallback to default English";
    }

    emit languageChanged();
}
