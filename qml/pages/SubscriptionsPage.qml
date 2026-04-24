import QtQuick 1.0
import "../components"

Rectangle {
    id: subsPage
    anchors.fill: parent
    color: "black"

    property variant subsModel: []
    property variant videosModel: []

    Connections {
        target: ApiManager

        onSubscriptionsReady: {
            loadingIndicator.visible = false
            subsModel = subscriptions

            // Если есть подписки, сразу грузим видео первого канала
            if (subscriptions.length > 0) {
                // Используем нашу новую функцию для надежности
                var author = extractChannelId(subscriptions[0].profile_url || "")
                if (author !== "") {
                    loadingIndicator.visible = true
                    ApiManager.getChannelVideos(author)
                }
            }
        }

        onChannelVideosReady: {
            loadingIndicator.visible = false
            if (channelDataMap && channelDataMap.videos) {
                videosModel = channelDataMap.videos
            } else {
                videosModel = []
            }
        }
    }

    function onNavigatedTo() {
        if (Config.userToken === "") {
            errorText.text = "Требуется авторизация"
            errorText.visible = true
            return
        }

        if (subsModel.length === 0) {
            loadingIndicator.visible = true
            errorText.visible = false
            ApiManager.getSubscriptions()
        }
    }

    function extractChannelId(url) {
        if (!url) return "";
        if (url.indexOf("author=") !== -1) {
            return url.split("author=")[1].split("&")[0];
        }
        var parts = url.split("/");
        var lastPart = parts[parts.length - 1];
        if (lastPart.indexOf("?") !== -1) {
            lastPart = lastPart.split("?")[0];
        }
        return lastPart;
    }

    Text {
        id: loadingIndicator
        text: qsTr("Загрузка...")
        color: "white"
        font.pixelSize: 18
        anchors.centerIn: parent
        visible: false
        z: 10
    }

    Text {
        id: errorText
        text: ""
        color: "gray"
        font.pixelSize: 16
        anchors.centerIn: parent
        visible: false
    }

    // --- ИСПРАВЛЕНИЕ: Заменили Column на Item, чтобы разрешить anchors у вложенных списков ---
    Item {
        anchors.fill: parent
        visible: !errorText.visible

        // Горизонтальный список подписок
        ListView {
            id: channelsList
            anchors.top: parent.top
            width: parent.width
            height: 120
            orientation: ListView.Horizontal
            model: subsModel
            spacing: 16
            cacheBuffer: 800

            delegate: Item {
                width: 80
                height: 120

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Item {
                        width: 70; height: 70
                        anchors.horizontalCenter: parent.horizontalCenter

                        Image {
                            id: channelAvatar
                            anchors.fill: parent

                            // ФОРМИРУЕМ URL ДЛЯ C++ ПРОВАЙДЕРА
                            source: {
                                var rawUrl = model.modelData.local_thumbnail;
                                if (!rawUrl) return "";

                                // 1. Очищаем ссылку от домена и https, оставляя только хвост
                                // Нам нужно передать в C++ только финальную прямую ссылку на картинку
                                var cleanUrl = rawUrl.replace("yt.modyleprojects.ru", "yt.swlbst.ru").replace("https", "http");

                                // 2. Теперь кодируем только этот чистый хвост (https%3A%2F%2F...)
                                // и добавляем префикс провайдера
                                return "image://rounded/" + encodeURIComponent(cleanUrl);
                            }



                            // Важные настройки для Symbian:
                            //asynchronous: true    // Грузим в фоне
                            smooth: true          // Сглаживание при масштабировании
                            fillMode: Image.PreserveAspectFit

                            // Оптимизация: просим C++ вернуть картинку в нужном размере
                            sourceSize.width: 70
                            sourceSize.height: 70

                            // Пока картинка грузится, показываем серый круг
                            Rectangle {
                                anchors.fill: parent
                                radius: 35
                                color: "#333333"
                                visible: channelAvatar.status !== Image.Ready
                            }
                        }
                    }

                    Text {
                        text: model.modelData.title ? model.modelData.title : ""
                        color: "white"
                        font.pixelSize: 12
                        width: 80
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var rawUrl = model.modelData.profile_url || "";
                        var authorId = extractChannelId(rawUrl);
                        if (authorId !== "") {
                            videosModel = []
                            loadingIndicator.visible = true
                            ApiManager.getChannelVideos(authorId);
                        }
                    }
                }
            }
        }

        // Список видео текущего выбранного канала
        ListView {
            id: channelVideosList
            // Привязываем к низу верхнего списка
            anchors.top: channelsList.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 10

            model: videosModel

            // --- ИСПРАВЛЕНИЕ: Увеличили spacing, чтобы текст не лез на следующую карточку ---
            spacing: 1

            // Оптимизация скролла для Symbian
            cacheBuffer: 1000

            delegate: VideoCard {
                modelData: model.modelData
                onClicked: {
                    root.navigateToVideo(videoId)
                }
            }
        }
    }
}
