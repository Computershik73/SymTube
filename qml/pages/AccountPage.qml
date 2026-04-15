import QtQuick 1.0

Rectangle {
    id: accountPage
    anchors.fill: parent
    color: "black"

    property bool isAuthenticated: Config.userToken !== ""
    property variant accountData: null
    property int qrVersion: 0

    Connections {
        target: ApiManager

        // Теперь здесь обрабатывается только успешная авторизация (Токен)
        onAuthContentReady: {
            if (type === "Token") {
                pollingTimer.stop();
                Config.userToken = content;
                isAuthenticated = true;
                loadAccountInfo();
            }
            // Блок с "Base64Image" полностью удален, так как C++ его больше не отправляет
        }

        // Обработка новой картинки (сигнал, который мы добавили в C++)
        onAuthImageReady: {
            qrVersion++;
            // Трюк для принудительного обновления картинки в кэше QML
            var temp = qrImage.source;
            qrImage.source = "";
            qrImage.source = "image://qr/auth";

            qrImage.visible = true;
            loadingText.visible = false;
        }

        onAccountInfoReady: {
            accountData = accountInfo;
        }
    }

    Timer {
        id: pollingTimer
        interval: 10000
        repeat: true
        running: !isAuthenticated
        onTriggered: {
            if (!isAuthenticated) {
                ApiManager.checkAuthContent();
            }
        }
    }

    function onNavigatedTo() {
        if (isAuthenticated) {
            loadAccountInfo();
        } else {
            qrVersion++;
            pollingTimer.start();
            ApiManager.checkAuthContent();
        }
    }

    function loadAccountInfo() {
        ApiManager.getAccountInfo();
    }

    // Состояние: НЕ АВТОРИЗОВАН
    Column {
        anchors.centerIn: parent
        spacing: 20
        visible: !isAuthenticated

        Text {
            text: "Для входа отсканируйте QR-код"
            color: "white"
            font.pixelSize: 18
            width: parent.width - 40
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            width: 200; height: 200
            color: "white"
            radius: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                id: qrImage
                anchors.fill: parent
                anchors.margins: 10
                source: "image://qr/auth?" + qrVersion
                fillMode: Image.PreserveAspectFit
                visible: false // Скрыто, пока не сработает onAuthImageReady
                //cache: false   // Отключаем кэширование, чтобы QR-код всегда обновлялся
            }

            Text {
                id: loadingText
                text: "Загрузка..."
                color: "black"
                anchors.centerIn: parent
                visible: !qrImage.visible
            }
        }

        Rectangle {
            width: 200; height: 40
            color: "#333333"
            radius: 5
            anchors.horizontalCenter: parent.horizontalCenter
            Text { text: "Настройки"; color: "white"; anchors.centerIn: parent; font.bold: true }
            MouseArea {
                anchors.fill: parent
                onClicked: root.navigateToSettings() // Вызов глобальной функции из main.qml
            }
        }
    }


    // Состояние: АВТОРИЗОВАН
    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        visible: isAuthenticated

        Row {
            spacing: 20
            Rectangle {
                width: 88; height: 88
                color: "#333333"
                radius: 44
                clip: true
                
                Image {
                    anchors.fill: parent
                    source: accountData && accountData.PictureUrl ? accountData.PictureUrl : ""
                    fillMode: Image.PreserveAspectCrop
                }
            }

            Column {
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: accountData && accountData.GivenName ? accountData.GivenName : "Загрузка..."
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                }
                
                Text {
                    text: accountData && accountData.CustomUrl ? accountData.CustomUrl : ""
                    color: "gray"
                    font.pixelSize: 14
                }
            }
        }

        Rectangle {
            width: parent.width; height: 40
            color: "#333333"
            radius: 5
            
            Text {
                text: "Выйти из аккаунта"
                color: "white"
                anchors.centerIn: parent
                font.bold: true
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    Config.userToken = "";
                    isAuthenticated = false;
                    //qrBase64 = "";
                    pollingTimer.start();
                    ApiManager.checkAuthContent();
                }
            }
        }

        Rectangle {
            width: parent.width; height: 40
            color: "#1F1F1F"
            border.color: "#333333"
            border.width: 1
            radius: 5
            Text { text: "Настройки"; color: "white"; anchors.centerIn: parent; font.bold: true }
            MouseArea {
                anchors.fill: parent
                onClicked: root.navigateToSettings()
            }
        }

    }
}
