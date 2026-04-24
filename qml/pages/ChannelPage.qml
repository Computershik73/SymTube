import QtQuick 1.0
import "../components"

Rectangle {
    id: channelPage
    anchors.fill: parent
    color: "black"

    property variant channelData: null
    property variant videosModel:[]

    Connections {
        target: ApiManager
        onChannelVideosReady: {
            loadingIndicator.visible = false
            channelData = channelDataMap
            if (channelData && channelData.videos) {
                videosModel = channelData.videos
            }
        }
        onRequestFailed: {
            if (endpoint === "ChannelVideos") {
                loadingIndicator.visible = false
                errorText.visible = true
            }
        }
    }

    function loadChannel(author) {
        channelData = null
        videosModel =[]
        loadingIndicator.visible = true
        errorText.visible = false
        ApiManager.getChannelVideos(author)
    }

    Text {
        id: loadingIndicator
        text: qsTr("Загрузка канала...")
        color: "white"
        font.pixelSize: 18
        anchors.centerIn: parent
        visible: false
        z: 5
    }

    Text {
        id: errorText
        text: qsTr("Не удалось загрузить канал")
        color: "gray"
        font.pixelSize: 16
        anchors.centerIn: parent
        visible: false
    }

    // --- ГЛАВНЫЙ СПИСОК ---
    ListView {
        id: mainList
        anchors.fill: parent
        model: videosModel
        visible: !loadingIndicator.visible && !errorText.visible

        // Оптимизация для Symbian
        cacheBuffer: 1000

        // Сбрасываем скролл при загрузке нового канала
        onModelChanged: {
            mainList.contentY = 0;
        }

        // --- ВЕРХНЯЯ ЧАСТЬ КАНАЛА (скроллится вместе со списком) ---
        header: Column {
            width: mainList.width
            spacing: 16

            // Баннер канала
            Image {
                width: parent.width
                height: 120
                source: channelData && channelData.channel_info ? (channelData.channel_info["banner"] || "") : ""
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
            }

            // Инфо (Аватар + Название + Подписчики)
            Item {
                width: parent.width
                height: 80

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 16

                    // Аватар
                    Rectangle {
                        width: 80; height: 80; radius: 40; color: "#333"; clip: true
                        Image {
                            anchors.fill: parent
                            source: channelData && channelData.channel_info ? (channelData.channel_info["thumbnail"] || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    // Текст
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        width: parent.width - 112 // Ширина родителя минус ширина аватара и отступов

                        Text {
                            text: channelData && channelData.channel_info ? (channelData.channel_info["title"] || "") : ""
                            color: "white"
                            font.pixelSize: 20
                            font.bold: true
                            width: parent.width
                            elide: Text.ElideRight
                            font.family: "Nokia Pure Text"
                        }
                        Text {
                            text: channelData && channelData.channel_info ? ((channelData.channel_info["subscriber_count"] || "0") + qsTr(" подписчиков")) : ""
                            color: "gray"
                            font.pixelSize: 14
                            font.family: "Nokia Pure Text"
                        }
                    }
                }
            }

            // Отступ перед началом видео
            Item { width: parent.width; height: 8 }
        }

        // --- КАРТОЧКИ ВИДЕО ---
        delegate: VideoCard {
            modelData: model.modelData
            onClicked: {
                root.navigateToVideo(videoId)
            }
        }
    }
}
