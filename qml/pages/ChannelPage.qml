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

    ListView {
        id: mainList
        anchors.fill: parent
        model: videosModel
        visible: !loadingIndicator.visible && !errorText.visible

        cacheBuffer: 1000

        onModelChanged: {
            mainList.contentY = 0;
        }

        header: Column {
            width: mainList.width
            spacing: 16

            Image {
                width: parent.width
                height: 120
                source: channelData && channelData.channel_info ? (channelData.channel_info["banner"] || "") : ""
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
            }

            Item {
                width: parent.width
                height: 80

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 16

                    Rectangle {
                        width: 80; height: 80; radius: 40; color: "#333"; clip: true
                        Image {
                            anchors.fill: parent
                            source: {
                                var thumb = channelData && channelData.channel_info ? (channelData.channel_info.thumbnail || "") : "";
                                if (thumb !== "") {
                                    return "image://rounded/" + encodeURIComponent(thumb.replace("https://", "http://"));
                                }
                                return "";
                            }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        width: parent.width - 112

                        Text {
                            text: channelData && channelData.channel_info ? (channelData.channel_info["title"] || "") : ""
                            color: "white"
                            font.pixelSize: 20
                            font.bold: true
                            width: parent.width
                            elide: Text.ElideRight

                        }
                        Text {
                            text: channelData && channelData.channel_info ? ((channelData.channel_info["subscriber_count"] || "0")) : ""
                            color: "gray"
                            font.pixelSize: 14

                        }
                    }
                }
            }

            Item { width: parent.width; height: 8 }
        }

        delegate: VideoCard {
            modelData: model.modelData
            onClicked: {
                root.navigateToVideo(videoId)
            }
        }
    }
}
