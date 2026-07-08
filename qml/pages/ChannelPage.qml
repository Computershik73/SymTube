import QtQuick 1.0
import "../components"

Rectangle {
    id: channelPage
    anchors.fill: parent
    color: "black"

    property variant channelData: null
    property variant videosModel:[]

    property string activeTab: "Videos"
    property variant playlistsModel: []

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

        onPlaylistsReady: {
            loadingIndicator.visible = false;
            playlistsModel = playlists;
        }
    }

    function loadChannel(author) {
        channelData = null;
        videosModel = [];
        playlistsModel = [];
        activeTab = "Videos";
        loadingIndicator.visible = true;
        errorText.visible = false;
        ApiManager.getChannelVideos(author);
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
        // Переключаем модель в зависимости от активной вкладки
        model: activeTab === "Videos" ? videosModel : playlistsModel
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

            // ПАНЕЛЬ ВКЛАДОК (ВИДЕО / ПЛЕЙЛИСТЫ)
            Row {
                width: parent.width - 32
                height: 40
                spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    width: (parent.width - 12) / 2
                    height: 36
                    color: activeTab === "Videos" ? "#333333" : "transparent"
                    border.color: "#444444"
                    border.width: activeTab === "Videos" ? 0 : 1
                    radius: 18

                    Text {
                        text: qsTr("Видео")
                        color: "white"
                        font.pixelSize: 14
                        font.bold: activeTab === "Videos"
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: activeTab = "Videos"
                    }
                }

                Rectangle {
                    width: (parent.width - 12) / 2
                    height: 36
                    color: activeTab === "Playlists" ? "#333333" : "transparent"
                    border.color: "#444444"
                    border.width: activeTab === "Playlists" ? 0 : 1
                    radius: 18

                    Text {
                        text: qsTr("Плейлисты")
                        color: "white"
                        font.pixelSize: 14
                        font.bold: activeTab === "Playlists"
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            activeTab = "Playlists";
                            if (playlistsModel.length === 0 && channelData && channelData.channel_info) {
                                loadingIndicator.visible = true;
                                ApiManager.getChannelPlaylists(channelData.channel_info.channel_id);
                            }
                        }
                    }
                }
            }

            Item { width: parent.width; height: 8 }
        }

        // Рендерим VideoCard для видео или кастомный блок для плейлистов
        delegate: Item {
            width: parent.width
            height: activeTab === "Videos" ? 300 : 100

            VideoCard {
                anchors.fill: parent
                modelData: model.modelData
                visible: activeTab === "Videos"
                onClicked: {
                    root.navigateToVideo(videoId)
                }
            }

            // Элемент отображения плейлиста в списке
            Rectangle {
                anchors.fill: parent
                color: "black"
                visible: activeTab === "Playlists"

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        width: 140
                        height: 80
                        color: "#1A1A1A"
                        radius: 8
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: modelData.thumbnail || ""
                            fillMode: Image.PreserveAspectCrop
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            color: "#CC000000"
                            width: pcText.width + 12
                            height: pcText.height + 4
                            radius: 4
                            visible: modelData.views !== undefined

                            Text {
                                id: pcText
                                anchors.centerIn: parent
                                text: modelData.views || ""
                                color: "white"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Column {
                        width: parent.width - 162
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: modelData.title || ""
                            color: "white"
                            font.pixelSize: 15
                            font.bold: true
                            width: parent.width
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.author || ""
                            color: "gray"
                            font.pixelSize: 13
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.navigateToVideo("", modelData.playlist_id);
                    }
                }
            }
        }
    }
}
