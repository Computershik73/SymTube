import QtQuick 1.0
import "../components"

Rectangle {
    id: channelPage
    anchors.fill: parent
    color: "black"

    property variant channelData: null
    property variant videosModel: []

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
        videosModel = []
        loadingIndicator.visible = true
        errorText.visible = false
        ApiManager.getChannelVideos(author)
    }
	
	function getEncodedIconUrl(rawUrl) {
    if (!rawUrl) return "";
    // 1. Декодируем всё, чтобы получить чистый URL (http://...)
    // 2. Кодируем один раз (все : / ? будут заменены на %3A %2F и т.д.)
    return encodeURIComponent(decodeURIComponent(rawUrl));
	}

    Text {
        id: loadingIndicator
        text: "Загрузка канала..."
        color: "white"
        font.pixelSize: 18
        anchors.centerIn: parent
        visible: false
        z: 5
    }

    Text {
        id: errorText
        text: "Не удалось загрузить канал"
        color: "gray"
        font.pixelSize: 16
        anchors.centerIn: parent
        visible: false
    }

    Flickable {
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: channelContent.height
        clip: true

        Column {
            id: channelContent
            width: parent.width
            spacing: 16
            
            // Баннер канала
            Image {
                width: parent.width
                height: 120
                source: channelData && channelData.channel_info ? (channelData.channel_info["banner"] || "") : ""
                fillMode: Image.PreserveAspectCrop
                clip: true
            }

            // Информация о канале
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 16
                
                Rectangle {
                    width: 80; height: 80; radius: 40; color: "#333"; clip: true
                    Image {
                        anchors.fill: parent
                        source: channelData && channelData.channel_info ? decodeURIComponent(channelData.channel_info["thumbnail"].replace("yt.modyleprojects.ru", "yt.swlbst.ru") || "") : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        text: channelData && channelData.channel_info ? (channelData.channel_info["title"] || "") : ""
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Text {
                        text: channelData && channelData.channel_info ? ((channelData.channel_info["subscriber_count"] || "0") + " подписчиков") : ""
                        color: "gray"
                        font.pixelSize: 14
                    }
                }
            }
            
            // Список видео
            ListView {
                width: parent.width
                height: 500 // Даем начальную высоту, Flickable ее растянет
                model: videosModel
                interactive: false // Прокруткой управляет родительский Flickable
                
                delegate: VideoCard {
                    modelData: model.modelData
                    onClicked: {
                        root.navigateToVideo(videoId)
                    }
                }
            }
        }
    }
}
