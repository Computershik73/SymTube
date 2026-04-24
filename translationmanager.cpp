#include "translationmanager.h"
#include <QApplication>
#include <QSettings>
#include <QDir>
#include <QFileInfoList>
#include <QDebug>

TranslationManager::TranslationManager(QObject *parent)
    : QObject(parent), m_translator(new QTranslator(this))
{
    scanDirectory();

    QSettings settings("SymTubeApp", "Settings");
    QString savedLang = settings.value("Language", "ru_RU").toString();

    // Безопасный откат на английский, если файл был удален
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
    m_languageFiles.clear();

    QStringList filters;
    filters << "*.qm";

    // 1. Ищем встроенные переводы в папке программы (там же, где qml/main.qml)
    QDir appLangDir("lang");
    if (appLangDir.exists()) {
        QStringList files = appLangDir.entryList(filters, QDir::Files);
        for (int i = 0; i < files.size(); ++i) {
            QString file = files.at(i);
            QString lang = file;
            lang.remove(".qm");
            lang.remove("SymTube_"); // Очищаем имя (например, из SymTube_ru_RU.qm делаем ru_RU)

            m_availableLanguages.append(lang);
            m_languageFiles.insert(lang, appLangDir.absoluteFilePath(file));
        }
    }

    // 2. Сканируем все диски на устройстве для кастомных переводов (C:\, E:\, F:\)
    QFileInfoList drives = QDir::drives();
    for (int d = 0; d < drives.size(); ++d) {
        QString drivePath = drives.at(d).absolutePath();
        QDir customDir(drivePath + "SymTube/lang"); // Путь вида E:/SymTube/lang/

        if (customDir.exists()) {
            QStringList files = customDir.entryList(filters, QDir::Files);
            for (int i = 0; i < files.size(); ++i) {
                QString file = files.at(i);
                QString lang = file;
                lang.remove(".qm");

                // Если язык новый, добавляем его в список
                if (!m_availableLanguages.contains(lang)) {
                    m_availableLanguages.append(lang);
                }

                // Перезаписываем путь (файл на E: будет в приоритете перед lang/)
                m_languageFiles.insert(lang, customDir.absoluteFilePath(file));
                qDebug() << "[Lang] Found custom translation:" << customDir.absoluteFilePath(file);
            }
        }
    }

    // Если английский нигде не найден, всё равно добавляем его как резервный вариант
    // (он зашит в исходники QML, для него файл .qm не обязателен)
    if (!m_availableLanguages.contains("en_US")) {
        m_availableLanguages.prepend("en_US");
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

    QSettings settings("SymTubeApp", "Settings");
    settings.setValue("Language", localeName);

    qApp->removeTranslator(m_translator);

    // Берем точный абсолютный путь к файлу
    if (m_languageFiles.contains(localeName)) {
        QString absoluteFilePath = m_languageFiles.value(localeName);

        if (m_translator->load(absoluteFilePath)) {
            qApp->installTranslator(m_translator);
            qDebug() << "[Lang] Loaded translation:" << absoluteFilePath;
        } else {
            qDebug() << "[Lang] FAILED to load translation:" << absoluteFilePath;
        }
    } else {
        qDebug() << "[Lang] No .qm file for" << localeName << "(using default QML strings)";
    }

    emit languageChanged();
}
