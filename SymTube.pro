# Add more folders to ship with the application, here
folder_01.source = qml
folder_01.target = .
DEPLOYMENTFOLDERS = folder_01
QT += core quick gui qml multimedia multimedia-private network declarative widgets
CONFIG += mobility
MOBILITY += multimedia

# Additional import path used to resolve QML modules in Creator's code model
QML_IMPORT_PATH =
LIBS += -lremconcoreapi -lremconinterfacebase -leikcore -lcone
symbian:TARGET.UID3 = 0xE748633B

TARGET.STACKSIZE = 0x8000
TARGET.EPOCHEAPSIZE = 0x20000 0x4000000  # Увеличение хипа для парсинга JSON и картинок
PKG_VERSION = "0,1,0"

vendor_info = \
        " " \
        "; Localised Vendor name" \
        "%{\"Computershik\"}" \
        " " \
        "; Unique Vendor name" \
        ":\"Computershik\"" \
        " "
    package.pkg_prerules += vendor_info

    header = "$${LITERAL_HASH}{\"SymTube\"},(0xE748633B),$$PKG_VERSION,TYPE=SA,RU"
    package.pkg_prerules += header

    DEPLOYMENT += package

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
    qrimageprovider.h \
    roundedimageprovider.h \
    volumekeysobserver.h \
    qsymbianapplication.h

SOURCES += \
    main.cpp \
    json.cpp \
    config.cpp \
    apimanager.cpp \
    historymanager.cpp \
    qrimageprovider.cpp \
    roundedimageprovider.cpp \
    volumekeysobserver.cpp \
    qsymbianapplication.cpp

OTHER_FILES += \
#    qml/*.qml \
#    qml/components/*.qml \
#    qml/pages/*.qml \
    Assets/*.png \
    Assets/player/*.png \
    Assets/tabbar/*.png

# Please do not modify the following two lines. Required for deployment.
include(qmlapplicationviewer/qmlapplicationviewer.pri)
qtcAddDeployment()
