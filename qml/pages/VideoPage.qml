import QtQuick 1.0
import QtMultimediaKit 1.1

Rectangle {
    id: videoPage
    color: "black"

    property string currentVideoId: ""
    property variant videoDetails: null
    property bool isPlaying: false

    Connections {
        target: ApiManager
        onVideoInfoReady: {
            videoDetails = videoDetailsMap;
            HistoryManager.addToHistory({
                "video_id": videoDetails.video_id,
                "title": videoDetails.title,
                "author": videoDetails.author,
                "thumbnail": videoDetails.thumbnail
            });

            var directUrl = Config.getVideoUrl(videoDetails.video_id, "").replace("https", "http");
            videoPlayer.source = directUrl;
            videoPlayer.play();
        }
    }

    function loadVideo(videoId) {
        currentVideoId = videoId;
        videoDetails = null;
        videoPlayer.stop();
        videoPlayer.source = "";
        isPlaying = false;
        ApiManager.getVideoInfo(videoId);
    }

    Rectangle {
        id: playerContainer
        width: parent.width; height: parent.width * 0.5625
        anchors.top: parent.top; color: "black"

        Video {
            id: videoPlayer
            anchors.fill: parent
            fillMode: Video.PreserveAspectFit
            onResumed: isPlaying = true
            onStarted: isPlaying = true
            onPaused: isPlaying = false
            onStopped: isPlaying = false

            MouseArea {
                anchors.fill: parent
                onClicked: { if (isPlaying) videoPlayer.pause(); else videoPlayer.play(); }
            }
        }

        Rectangle {
            anchors.centerIn: parent; color: "#CC000000"; radius: 8
            width: errorText.width + 40; height: errorText.height + 20
            visible: videoPlayer.status === Video.InvalidMedia || videoPlayer.status === Video.NoMedia
            Text { id: errorText; anchors.centerIn: parent; color: "white"; font.pixelSize: 18; text: "Ошибка воспроизведения" }
        }

        Text {
            anchors.centerIn: parent; color: "white"; font.pixelSize: 14
            visible: videoPlayer.status === Video.Loading
            text: "Загрузка видео..."
        }

        Rectangle {
            anchors.bottom: parent.bottom; width: parent.width; height: 30; color: "#80000000"
            visible: videoPlayer.status === Video.Loaded || videoPlayer.status === Video.Playing || videoPlayer.status === Video.Paused
            Text {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 10
                color: "white"; font.pixelSize: 12
                text: Math.floor(videoPlayer.position / 1000) + " / " + (videoPlayer.duration > 0 ? Math.floor(videoPlayer.duration / 1000) : "-1") + " сек"
            }
        }
    }

    Flickable {
        anchors.top: playerContainer.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        contentWidth: parent.width; contentHeight: contentColumn.height + 40; clip: true

        Column {
            id: contentColumn
            width: parent.width; spacing: 0

            Item { width: parent.width; height: titleText.height + 32
                Text {
                    id: titleText; x: 16; y: 16; width: parent.width - 32
                    text: videoDetails ? (videoDetails["title"] || "Загрузка...") : ""
                    color: "white"; font.pixelSize: 18; font.bold: true
                    wrapMode: Text.WordWrap; font.family: "Nokia Pure Text"
                }
            }

            Text { x: 16; text: videoDetails ? ((videoDetails["views"] || "0") + " просмотров") : ""; color: "gray"; font.pixelSize: 14 }

            Item {
                width: parent.width; height: 60
                Row {
                    x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    Rectangle {
                        width: 40; height: 40; radius: 20; color: "#333"; clip: true
                        Image { anchors.fill: parent; source: videoDetails ? (videoDetails["channel_thumbnail"] || "") : ""; fillMode: Image.PreserveAspectCrop }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 100
                        Text {
                            text: videoDetails ? (videoDetails["author"] || "") : ""; color: "white"; font.pixelSize: 16; font.bold: true
                            font.family: "Nokia Pure Text"; width: parent.width; elide: Text.ElideRight
                        }
                        Text { text: videoDetails ? (videoDetails["subscriberCount"] || "") + " подписчиков" : ""; color: "gray"; font.pixelSize: 12 }
                    }
                }
            }

            Rectangle {
                x: 16; width: parent.width - 32; height: 80
                color: "#272727"; radius: 12; clip: true
                Text {
                    x: 12; y: 12; width: parent.width - 24; height: 56
                    text: videoDetails ? (videoDetails["description"] || "Нет описания") : ""
                    color: "white"; font.pixelSize: 14; wrapMode: Text.WordWrap; elide: Text.ElideRight; font.family: "Nokia Pure Text"
                }
                MouseArea { anchors.fill: parent; onClicked: descriptionSheet.state = "visible" }
            }
        }
    }

    Rectangle {
        id: descriptionSheet
        anchors.fill: parent; color: "#E6000000"; visible: state === "visible"; z: 20
        state: "hidden"
        states:[
            State { name: "visible"; PropertyChanges { target: descriptionPanel; y: root.height - descriptionPanel.height } },
            State { name: "hidden"; PropertyChanges { target: descriptionPanel; y: root.height } }
        ]
        transitions: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad } }
        MouseArea { anchors.fill: parent; onClicked: descriptionSheet.state = "hidden" }

        Rectangle {
            id: descriptionPanel
            width: parent.width; height: root.height * 0.75
            anchors.bottom: parent.bottom; color: "#282828"
            Item {
                anchors.fill: parent; anchors.margins: 16
                Column {
                    anchors.fill: parent; spacing: 10
                    Rectangle { width: 40; height: 5; radius: 2.5; color: "gray"; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "Описание"; color: "white"; font.pixelSize: 18; font.bold: true }
                    Flickable {
                        width: parent.width; height: parent.height - 60
                        contentWidth: width; contentHeight: descriptionText.height; clip: true
                        Text {
                            id: descriptionText; width: parent.width
                            text: videoDetails ? (videoDetails["description"] || "") : ""
                            color: "white"; font.pixelSize: 16; wrapMode: Text.WordWrap; font.family: "Nokia Pure Text"
                        }
                    }
                }
            }
        }
    }
}
