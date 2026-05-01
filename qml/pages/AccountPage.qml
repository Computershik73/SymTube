import QtQuick 1.0

Rectangle {
    id: accountPage
    anchors.fill: parent
    color: "black"

    property bool isAuthenticated: Config.userToken !== ""
    property variant accountData: null
    property variant historyModel:[]
    property int qrVersion: 0

    Connections {
        target: ApiManager

        onAuthContentReady: {
            if (type === "Token") {
                pollingTimer.stop();
                Config.userToken = content;
                isAuthenticated = true;
                loadAccountInfo();
            }
        }

        onAuthImageReady: {
            qrVersion++;
            // В QML 1.0, чтобы обойти жесткое кэширование,
            // привязываем счетчик прямо к URL
            qrImage.source = "image://qr/auth?" + qrVersion;
            qrImage.visible = true;
            loadingText.visible = false;
        }

        onAccountInfoReady: {
            accountData = accountInfo;
        }

        onHistoryReady: {
            historyModel = historyList;
        }
    }

    Timer {
        id: pollingTimer
        interval: 5000 // Для проверки лучше ставить 3 сек
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
            qrImage.visible = false;
            loadingText.visible = true;
            qrVersion++;
            pollingTimer.start();
            ApiManager.checkAuthContent();
        }
    }

    function loadAccountInfo() {
        ApiManager.getAccountInfo();
        ApiManager.getHistory(); // Сразу же запрашиваем историю
    }

    // --- СОСТОЯНИЕ: НЕ АВТОРИЗОВАН ---
    Column {
        anchors.centerIn: parent
        spacing: 20
        visible: !isAuthenticated

        Text {
            text: qsTr("Для входа отсканируйте QR-код")
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
                visible: false
            }

            Text {
                id: loadingText
                text: qsTr("Загрузка...")
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
            Text { text: qsTr("Настройки"); color: "white"; anchors.centerIn: parent; font.bold: true }
            MouseArea {
                anchors.fill: parent
                onClicked: root.navigateToSettings()
            }
        }
    }


    // --- СОСТОЯНИЕ: АВТОРИЗОВАН ---
    Flickable {
        anchors.fill: parent
        visible: isAuthenticated
        contentWidth: parent.width
        contentHeight: authColumn.height + 40
        clip: true

        Column {
            id: authColumn
            x: 16; y: 16
            width: parent.width - 32
            spacing: 24

            // 1. ПРОФИЛЬ (Жесткая высота 80, чтобы кнопки не налезли!)
            Item {
                width: parent.width
                height: 80

                Row {
                    anchors.fill: parent
                    spacing: 16

                    // Аватарка
                    Rectangle {
                        width: 80; height: 80
                        color: "#333333"
                        radius: 40
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: {
                                if (!accountData || !accountData.google_account || !accountData.google_account.picture) return "";

                                var originalUrl = accountData.google_account.picture;
                                // Просто энкодим URL и отдаем провайдеру (меняем https на http для стабильности на Symbian)
                                return "image://rounded/" + encodeURIComponent(originalUrl);
                            }
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    // Текстовая информация
                    Column {
                        width: parent.width - 96
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: accountData && accountData.google_account ? (accountData.google_account.given_name || qsTr("Пользователь")) : qsTr("Загрузка...")
                            color: "white"
                            font.pixelSize: 22
                            font.bold: true
                            width: parent.width
                            elide: Text.ElideRight
                            font.family: "Nokia Pure Text"
                        }

                        Text {
                            text: accountData && accountData.youtube_channel ? (accountData.youtube_channel.custom_url || "") : ""
                            color: "gray"
                            font.pixelSize: 14
                        }
                    }
                }
            }

            // 2. КНОПКИ УПРАВЛЕНИЯ
            Row {
                width: parent.width
                height: 40 // Жесткая высота
                spacing: 10

                Rectangle {
                    width: (parent.width - 10) / 2; height: 40
                    color: "#1F1F1F"
                    border.color: "#333333"
                    border.width: 1
                    radius: 5
                    Text { text: qsTr("Настройки"); color: "white"; anchors.centerIn: parent; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: root.navigateToSettings() }
                }

                Rectangle {
                    width: (parent.width - 10) / 2; height: 40
                    color: "#333333"
                    radius: 5
                    Text { text: qsTr("Выйти"); color: "white"; anchors.centerIn: parent; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Config.userToken = "";
                            isAuthenticated = false;
                            historyModel = []; // Очищаем историю при выходе
                            accountData = null;
                            pollingTimer.start();
                            ApiManager.checkAuthContent();
                        }
                    }
                }
            }

            // 3. Заголовок истории
            Text {
                text: qsTr("История просмотров")
                color: "white"
                font.pixelSize: 18
                font.bold: true
                visible: historyModel.length > 0
            }

            // 4. ГОРИЗОНТАЛЬНАЯ ЛЕНТА ИСТОРИИ
            ListView {
                width: parent.width
                height: 150 // Фиксированная высота для горизонтального списка
                orientation: ListView.Horizontal
                model: historyModel
                spacing: 12
                cacheBuffer: 500 // Для плавного скролла

                // Делегат для каждого видео в истории
                delegate: Item {
                    width: 150
                    height: 120

                    Column {
                        spacing: 8

                        // Превью видео
                        Rectangle {
                            width: 150; height: 84
                            color: "#1A1A1A"

                            Image {
                                anchors.fill: parent
                                source: modelData.thumbnail || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                clip: true
                            }

                            // Закругление углов поверх картинки
                            Image {
                                anchors.fill: parent
                                source: "../Assets/rounding_up.png" // Используем вашу готовую маску
                            }
                        }

                        // Название видео
                        Text {
                            text: modelData.title || ""
                            color: "white"
                            font.pixelSize: 13
                            width: parent.width
                            wrapMode: Text.WordWrap // Обязательно, чтобы текст переносился

                            // ИСПРАВЛЕНИЕ: Вместо maximumLineCount используем фиксированную высоту
                            // 13px шрифт * 2 строки + небольшой запас = примерно 28-30px
                            height: 30
                            clip: true // Обрезаем текст, который не влез в 30px

                            elide: Text.ElideRight // Добавляем многоточие
                            font.family: "Nokia Pure Text"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // Переходим на страницу видео
                            root.navigateToVideo(modelData.video_id);
                        }
                    }
                }
            }
        }
    }
}

