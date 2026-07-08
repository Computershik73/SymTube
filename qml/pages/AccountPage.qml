import QtQuick 1.0

Rectangle {
    id: accountPage
    anchors.fill: parent
    color: "black"

    property bool isAuthenticated: Config.userToken !== ""
    property variant accountData: null
    property variant historyModel:[]
    property int qrVersion: 0

    property variant playlistsModel: []

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

        onPlaylistsReady: {
            playlistsModel = playlists;
        }
    }

    Timer {
        id: pollingTimer
        interval: 5000
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
        ApiManager.getHistory();
        ApiManager.getMyPlaylists();
    }

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

            Item {
                width: parent.width
                height: 80

                Row {
                    anchors.fill: parent
                    spacing: 16

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
                                return "image://rounded/" + encodeURIComponent(originalUrl);
                            }
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

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

                        }

                        Text {
                            text: accountData && accountData.youtube_channel ? (accountData.youtube_channel.custom_url || "") : ""
                            color: "gray"
                            font.pixelSize: 14
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: 40
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
                            historyModel = [];
                            accountData = null;
                            pollingTimer.start();
                            ApiManager.checkAuthContent();
                        }
                    }
                }
            }

            Text {
                text: qsTr("История просмотров")
                color: "white"
                font.pixelSize: 18
                font.bold: true
                visible: historyModel.length > 0
            }

            ListView {
                width: parent.width
                height: 150
                orientation: ListView.Horizontal
                model: historyModel
                spacing: 12
                cacheBuffer: 500

                delegate: Item {
                    width: 150
                    height: 120

                    Column {
                        spacing: 8

                        Rectangle {
                            width: 150; height: 84
                            color: "#1A1A1A"
                            radius: 8
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: modelData.thumbnail || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                clip: true
                            }
                        }

                        Text {
                            text: modelData.title || ""
                            color: "white"
                            font.pixelSize: 13
                            width: parent.width
                            wrapMode: Text.WordWrap

                            height: 30
                            clip: true

                            elide: Text.ElideRight

                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.navigateToVideo(modelData.video_id);
                        }
                    }
                }
            }

            Text {
                text: qsTr("Ваши плейлисты")
                color: "white"
                font.pixelSize: 18
                font.bold: true
                visible: playlistsModel.length > 0
            }

            ListView {
                width: parent.width
                height: 150
                orientation: ListView.Horizontal
                model: playlistsModel
                spacing: 12
                cacheBuffer: 500
                visible: playlistsModel.length > 0

                delegate: Item {
                    width: 150
                    height: 120

                    Column {
                        spacing: 8

                        Rectangle {
                            width: 150; height: 84
                            color: "#1A1A1A"
                            radius: 8
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: modelData.thumbnail || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            // Плашка с количеством видео в плейлисте сверху картинки
                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 4
                                color: "#CC000000"
                                radius: 4
                                width: plCountText.width + 8
                                height: plCountText.height + 4
                                Text {
                                    id: plCountText
                                    anchors.centerIn: parent
                                    text: modelData.video_count_text || ""
                                    color: "white"
                                    font.pixelSize: 10
                                }
                            }
                        }

                        Text {
                            text: modelData.title || ""
                            color: "white"
                            font.pixelSize: 13
                            width: parent.width
                            wrapMode: Text.WordWrap
                            height: 30
                            clip: true
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // При клике на плейлист открываем его первое видео
                            root.navigateToVideo("", modelData.playlist_id);
                        }
                    }
                }
            }


        }
    }
}
