# Add more folders to ship with the application, here
folder_01.source = qml
folder_01.target = qml
DEPLOYMENTFOLDERS = folder_01
QT += core quick gui qml multimedia multimedia-private network declarative widgets
CONFIG += mobility
MOBILITY += multimedia

# Additional import path used to resolve QML modules in Creator's code model
QML_IMPORT_PATH =

symbian:TARGET.UID3 = 0xE748633B

TARGET.EPOCHEAPSIZE = 0x20000 0x2000000 # Увеличение хипа для парсинга JSON и картинок

# Smart Installer package's UID
# This UID is from the protected range and therefore the package will
# fail to install if self-signed. By default qmake uses the unprotected
# range value if unprotected UID is defined for the application and
# 0x2002CCCF value if protected UID is given to the application
#symbian:DEPLOYMENT.installer_header = 0x2002CCCF

# Allow network access on Symbian
symbian:TARGET.CAPABILITY += NetworkServices

# If your application uses the Qt Mobility libraries, uncomment the following
# lines and add the respective components to the MOBILITY variable.
# CONFIG += mobility
# MOBILITY +=
MOC_DIR = moc
OBJECTS_DIR = obj
UI_DIR = ui


HEADERS += \
    json.h \
    config.h \
    apimanager.h \
    historymanager.h \
    qrimageprovider.h

SOURCES += \
    main.cpp \
    json.cpp \
    config.cpp \
    apimanager.cpp \
    historymanager.cpp \
    qrimageprovider.cpp

OTHER_FILES += \
    qml/*.qml \
    qml/components/*.qml \
    qml/pages/*.qml \
    Assets/*.png \
    Assets/player/*.png \
    Assets/tabbar/*.png

# Please do not modify the following two lines. Required for deployment.
include(qmlapplicationviewer/qmlapplicationviewer.pri)
qtcAddDeployment()
