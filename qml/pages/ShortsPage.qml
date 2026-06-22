import QtQuick 1.0
import QtMultimediaKit 1.1
import "../components"

Rectangle {
    id: shortsPage
    color: "black"

    property variant shortsList:[]
    property int currentIndex: 0
    property string sequenceToken: ""
    property bool isLoading: false
    property bool isPlaying: false

    property variant currentShortInfo: null
    property variant currentVideoDetails: null
    property variant commentsModel: []

    property bool showPlayIcon: false
    property string currentVideoUrl: ""
    property int recoveryAttempts: 0
    property int recoveryPosition: -1
    property bool isSeeking: false

    property int uiPosition: 0

    Timer {
        id: uiTimer
        interval: 500
        repeat: true
        running: shortsPage.isPlaying
        onTriggered: {
            if (videoLoader.item) {
                var pos = videoLoader.item.position;
                var dur = videoLoader.item.duration;
                shortsPage.uiPosition = pos;

                if (dur > 0 && pos >= dur - 600) {
                    videoLoader.item.position = 0;
                }
            }
        }
    }

    Connections {
        target: SymbianApp
        onInBackground: {
            if (videoLoader.item && isPlaying) {
                shortsPage.recoveryPosition = videoLoader.item.position;
                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
            }
        }
        onInFocus: {
        }
    }

    Timer {
        id: recreateTimer
        interval: 150
        repeat: false
        onTriggered: {
            videoLoader.sourceComponent = videoComponent;
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: SymbianApp.foreground()
        onTriggered: {
            if (typeof SymbianApp !== "undefined") {
                SymbianApp.keepScreenOn();
            }
        }
    }

    Connections {
        target: ApiManager
        onShortsReady: {
            isLoading = false;
            sequenceToken = seqToken;
            if (shortsList && shortsList.length > 0) {
                var combined = shortsPage.shortsList;
                for (var i=0; i<shortsList.length; i++) combined.push(shortsList[i]);
                shortsPage.shortsList = combined;

                if (currentIndex === 0 && !currentShortInfo) loadCurrentShort();
            }
        }

        onVideoInfoReady: {
            if (currentShortInfo && videoDetailsMap.video_id !== currentShortInfo.video_id) return;

            currentVideoDetails = videoDetailsMap;
            HistoryManager.addToHistory({
                "video_id": currentVideoDetails.video_id,
                "title": currentVideoDetails.title,
                "author": currentVideoDetails.author,
                "thumbnail": currentVideoDetails.thumbnail
            });

            var base64Url = Qt.btoa(currentVideoDetails.video_url);
            var directUrl = "http://127.0.0.1:8081/?url=" + base64Url;

            if (shortsPage.currentVideoUrl !== directUrl) {
                shortsPage.currentVideoUrl = directUrl;
                shortsPage.recoveryAttempts = 0;

                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
            } else {
                if (videoLoader.item && videoLoader.item.status === Video.Loaded) {
                    videoLoader.item.play();
                }
            }
        }

        onCommentsReady: {
            shortsPage.commentsModel = comments;
        }
    }

    function startPlaying() {
        if (shortsList.length === 0 && !isLoading) {
            isLoading = true;
            videoLoader.sourceComponent = undefined;
            isPlaying = false;
            isSeeking = false;
            ApiManager.getShorts("");
        } else if (currentShortInfo && !isPlaying && videoLoader.item) {
            videoLoader.item.play();
        }
    }

    function stopVideo() {
        if (videoLoader.item) videoLoader.item.stop();
        shortsPage.currentVideoUrl = "";
        videoLoader.sourceComponent = undefined;
        isPlaying = false;
    }

    function loadCurrentShort() {
        if (currentIndex < 0 || currentIndex >= shortsList.length) return;

        shortsPage.showPlayIcon = false;
        playIconTimer.stop();

        currentShortInfo = shortsList[currentIndex];
        currentVideoDetails = null;
        commentsModel = [];
        ApiManager.getVideoInfo(currentShortInfo.video_id);

        if (currentIndex >= shortsList.length - 2 && sequenceToken !== "" && !isLoading) {
            isLoading = true;
            ApiManager.getShorts(sequenceToken);
        }
    }

    Component {
        id: videoComponent
        Video {
            Rectangle {
                anchors.fill: parent
                color: "black"
                z: -1
            }
            z: 111

            property int lastIntendedPosition: -1
            anchors.fill: parent
            fillMode: Video.PreserveAspectCrop
            source: shortsPage.currentVideoUrl
            volume: Config.persistentVolume

            onVolumeChanged: {
                if (Config.persistentVolume !== volume) {
                    Config.persistentVolume = volume;
                }
            }

            onResumed: { shortsPage.isSeeking = false; shortsPage.isPlaying = true; shortsPage.recoveryAttempts = 0; }
            onStarted: { shortsPage.isSeeking = false; shortsPage.isPlaying = true; shortsPage.recoveryAttempts = 0; }
            onPaused: shortsPage.isPlaying = false
            onStopped: { shortsPage.isPlaying = false; shortsPage.isSeeking = false; uiOverlay.visible = true; }

            onStatusChanged: {
                if (status === Video.Loaded) {
                    if (typeof VolumeKeys !== "undefined") {
                        VolumeKeys.volume = Config.persistentVolume * 100;
                    }

                    if (shortsPage.recoveryPosition !== -1) {
                        var target = shortsPage.recoveryPosition;
                        shortsPage.recoveryPosition = -1;
                        performSafeSeek(target);
                    } else {
                        play();
                    }
                }
                if (status === Video.InvalidMedia || status === Video.NoMedia || status === Video.EndOfMedia) {
                    if (shortsPage.recoveryPosition === -1) {
                        shortsPage.isSeeking = false;
                        shortsPage.isPlaying = false;
                    }
                }
            }

            onError: {
                shortsPage.recoveryAttempts++;
                shortsPage.recoveryPosition = (lastIntendedPosition !== -1) ? lastIntendedPosition : position;
                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
            }

            function performSafeSeek(newPos) {
                if (!seekable || duration <= 0) return;
                if (newPos > duration) newPos = duration;
                if (newPos < 0) newPos = 0;

                lastIntendedPosition = newPos;
                shortsPage.isSeeking = true;
                var wasPlaying = shortsPage.isPlaying;

                if (wasPlaying) pause();
                position = newPos;
                play();

                if (!wasPlaying) shortsPage.isSeeking = false;
            }
        }
    }

    Loader {
        id: videoLoader
        anchors.fill: parent
    }

    Item {
        id: uiOverlay
        anchors.fill: parent

        Image {
            id: spinner
            anchors.centerIn: parent
            source: "../Assets/player/reload.png"
            width: 48; height: 48
            visible: {
                if (shortsPage.isLoading) return true;
                if (videoLoader.item === null) return true;
                var st = videoLoader.item.status;
                return (st === Video.Loading);
            }
            NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible }
        }

        Rectangle {
            anchors.centerIn: parent; color: "#CC000000"; radius: 8;
            width: errorText.width + 40; height: errorText.height + 20
            visible: {
                if (videoLoader.item === null) return false;
                var st = videoLoader.item.status;
                return (st === Video.InvalidMedia || st === Video.NoMedia);
            }
            Text { id: errorText; anchors.centerIn: parent; color: "white"; font.pixelSize: 18; text: qsTr("Ошибка воспроизведения") }
        }

        MouseArea {
            anchors.fill: parent
            property int startY: 0
            property bool isSwiping: false

            onPressed: {
                startY = mouse.y;
                isSwiping = false;
            }

            onPositionChanged: {
                if (Math.abs(mouse.y - startY) > 20) {
                    isSwiping = true;
                }
            }

            onReleased: {
                if (isSwiping) {
                    var dy = mouse.y - startY;
                    if (dy < -80 && currentIndex < shortsList.length - 1) {
                        currentIndex++; loadCurrentShort();
                    } else if (dy > 80 && currentIndex > 0) {
                        currentIndex--; loadCurrentShort();
                    }
                } else {
                    if (mouse.x < parent.width - 60 && videoLoader.item !== null) {
                        if (isPlaying) {
                            videoLoader.item.pause();
                            shortsPage.showPlayIcon = true;
                            playIconTimer.stop();
                        } else {
                            videoLoader.item.play();
                            shortsPage.showPlayIcon = true;
                            playIconTimer.restart();
                        }
                    }
                }
            }
        }

        Timer {
            id: playIconTimer
            interval: 1500
            onTriggered: shortsPage.showPlayIcon = false
        }

        Image {
            id: playPauseIcon
            anchors.centerIn: parent
            width: 64; height: 64
            source: isPlaying ? "../Assets/player/pause.png" : "../Assets/player/play.png"
            opacity: 0.8
            visible: {
                if (shortsPage.showPlayIcon) return true;
                if (videoLoader.item === null) return false;
                if (!isPlaying) {
                    var st = videoLoader.item.status;
                    if (st === Video.Loaded || st === Video.EndOfMedia) return true;
                }
                return false;
            }
        }

        Rectangle {
            id: volumeOsd
            width: 8
            height: 150
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: "#66000000"
            opacity: 0

            Timer {
                id: volumeOsdTimer
                interval: 2000
                onTriggered: volumeFadeOut.start()
            }

            Connections {
                target: typeof VolumeKeys !== "undefined" ? VolumeKeys : null
                onVolumeChanged: {
                    volumeOsd.opacity = 1.0;
                    volumeFadeOut.stop();
                    volumeOsdTimer.restart();
                    Config.persistentVolume = VolumeKeys.volume / 100.0;
                }
            }

            SequentialAnimation {
                id: volumeFadeOut
                running: false
                NumberAnimation { target: volumeOsd; property: "opacity"; to: 0.0; duration: 500 }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                radius: 4
                color: "white"
                height: typeof VolumeKeys !== "undefined" ? (parent.height * (VolumeKeys.volume / 100.0)) : parent.height

                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom; width: parent.width; height: 4
            color: "#66FFFFFF";
            Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                color: "white"
                width: (videoLoader.item !== null && videoLoader.item.duration > 0) ? (shortsPage.uiPosition / videoLoader.item.duration) * parent.width : 0
            }
        }

        Column {
            anchors.left: parent.left; anchors.bottom: parent.bottom
            anchors.margins: 16; anchors.bottomMargin: 24
            anchors.right: rightButtons.left
            spacing: 8

            MouseArea {
                width: parent.width; height: 40
                onClicked: {
                    var channelId = currentVideoDetails ? currentVideoDetails["channel_custom_url"] : null;
                    if (channelId) root.navigateToChannel(channelId);
                }
                Row {
                    spacing: 8; anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 36; height: 36; radius: 18; color: "#333"; clip: true
                        SafeImage {
                            anchors.fill: parent
                            source: {
                                if (!currentVideoDetails) return "";
                                var originalUrl = currentVideoDetails["channel_thumbnail"];
                                if (!originalUrl) return "";
                                var parts = originalUrl.split("channel_icon/");

                                if (parts.length < 2) return "";
                                var baseUrl = parts[0].replace("https://", "http://") + "channel_icon/";
                                var cleanTail = decodeURIComponent(decodeURIComponent(parts[1]));
                                var encodedTail = encodeURIComponent(cleanTail);
                                var fullString = baseUrl + encodedTail;
                                return "image://rounded/" + encodeURIComponent(fullString);
                            }
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: currentVideoDetails ? (currentVideoDetails["author"] || "") : ""
                        color: "white"; font.pixelSize: 16; font.bold: true

                    }
                }
            }

            Text {
                text: currentShortInfo ? currentShortInfo.title : ""
                color: "white"; font.pixelSize: 14; width: parent.width
                wrapMode: Text.WordWrap; elide: Text.ElideRight; clip: true
                height: 38

            }
        }

        Column {
            id: rightButtons
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 16; anchors.bottomMargin: 30; spacing: 20

            Column {
                spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                Image { source: "../Assets/player/like.png"; width: 32; height: 32; MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentShortInfo.video_id, "like") } }
                Text { text: currentVideoDetails ? (currentVideoDetails["likes"] || qsTr("Лайк")) : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }
            Image { source: "../Assets/player/dislike.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter; MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentShortInfo.video_id, "dislike") } }
            Column {
                spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                Image { source: "../Assets/player/comments.png"; width: 32; height: 32; MouseArea { anchors.fill: parent; onClicked: { ApiManager.getComments(currentShortInfo.video_id, ""); commentsSheet.state = "visible"; } } }
                Text { text: currentVideoDetails ? (currentVideoDetails["comment_count"] || "0") : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }
            Image { source: "../Assets/player/send.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter; MouseArea { anchors.fill: parent; onClicked: shareSheet.state = "visible" } }
        }

        Rectangle {
            id: commentsSheet
            anchors.fill: parent; color: "#E6000000"; visible: state === "visible"; z: 50
            state: "hidden"
            states:[ State { name: "visible"; PropertyChanges { target: commentsPanel; y: root.height - commentsPanel.height } }, State { name: "hidden"; PropertyChanges { target: commentsPanel; y: root.height } } ]
            transitions: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: commentsSheet.state = "hidden" }

            Rectangle {
                id: commentsPanel
                width: parent.width; height: root.height * 0.75
                anchors.bottom: parent.bottom; color: "#282828"
                MouseArea { anchors.fill: parent }

                Column {
                    anchors.fill: parent; anchors.margins: 16; spacing: 10
                    Rectangle { width: 40; height: 5; radius: 2.5; color: "gray"; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: qsTr("Комментарии"); color: "white"; font.pixelSize: 18; font.bold: true }

                    ListView {
                        width: parent.width; height: parent.height - 40
                        model: shortsPage.commentsModel
                        clip: true
                        spacing: 12
                        delegate: Row {
                            spacing: 10
                            Rectangle {
                                width: 36; height: 36; radius: 18; color: "#333"; clip: true
                                SafeImage { anchors.fill: parent; source: modelData.authorThumbnail; fillMode: Image.PreserveAspectCrop }
                            }
                            Column {
                                width: parent.width - 46
                                Text { text: modelData.author; color: "gray"; font.pixelSize: 12; font.bold: true }
                                Text { text: modelData.text; color: "white"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
                                Text { text: modelData.publishedAt; color: "#666"; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: shareSheet
            anchors.fill: parent; color: "#E6000000"; visible: state === "visible"; z: 50
            state: "hidden"
            states:[
                State { name: "visible"; PropertyChanges { target: sharePanel; y: root.height - sharePanel.height } },
                State { name: "hidden"; PropertyChanges { target: sharePanel; y: root.height } }
            ]
            transitions: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: shareSheet.state = "hidden" }

            Rectangle {
                id: sharePanel
                width: parent.width; height: 180
                anchors.bottom: parent.bottom; color: "#282828"
                MouseArea { anchors.fill: parent }

                Column {
                    anchors.fill: parent; anchors.margins: 16; spacing: 16
                    Text { text: qsTr("Поделиться"); color: "white"; font.pixelSize: 18; font.bold: true }

                    Rectangle {
                        width: parent.width; height: 45; color: "#1F1F1F"; radius: 5
                        Text { text: currentShortInfo ? "https://youtu.be/" + currentShortInfo.video_id : ""; color: "white"; anchors.centerIn: parent; font.pixelSize: 14 }
                    }

                    Rectangle {
                        width: parent.width; height: 45; color: "#007ACC"; radius: 5
                        Text { text: qsTr("Скопировать ссылку"); color: "white"; anchors.centerIn: parent; font.bold: true }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (currentShortInfo) {
                                    ApiManager.copyToClipboard("https://youtu.be/" + currentShortInfo.video_id);
                                }
                                shareSheet.state = "hidden";
                            }
                        }
                    }
                }
            }
        }
    }
}
