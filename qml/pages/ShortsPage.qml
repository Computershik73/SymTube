import QtQuick 1.0
import QtMultimediaKit 1.1
import "../components"

Rectangle {
    id: shortsPlayer
    color: "black"

    property variant shortsList:[]
    property int currentIndex: 0
    property string sequenceToken: ""
    property bool isLoading: false
    property bool isPlaying: false
    property variant currentShortInfo: null
    property variant currentVideoDetails: null

    Connections {
        target: ApiManager
        onShortsReady: {
            isLoading = false;
            sequenceToken = seqToken;
            if (shortsList.length > 0) {
                var combined = shortsPlayer.shortsList;
                for (var i=0; i<shortsList.length; i++) combined.push(shortsList[i]);
                shortsPlayer.shortsList = combined;
                if (currentIndex === 0 && !currentShortInfo) loadCurrentShort();
            }
        }
        onVideoInfoReady: {
            if (currentShortInfo && videoDetailsMap.video_id !== currentShortInfo.video_id) return;
            currentVideoDetails = videoDetailsMap;
            var directUrl = Config.getVideoUrl(currentVideoDetails.video_id, "360").replace("https", "http");
            if (videoPlayer.source.toString() !== directUrl) {
                videoPlayer.stop();
                videoPlayer.source = directUrl;
                videoPlayer.play();
            } else {
                if (videoPlayer.status === Video.Loaded) videoPlayer.play();
            }
        }
    }

    function startPlaying() {
        if (shortsList.length === 0 && !isLoading) {
            isLoading = true;
            ApiManager.getShorts("");
        } else if (currentShortInfo && !isPlaying) {
            videoPlayer.play();
        }
    }

    function stopVideo() {
        videoPlayer.stop();
        videoPlayer.source = "";
        isPlaying = false;
    }

    function loadCurrentShort() {
        if (currentIndex < 0 || currentIndex >= shortsList.length) return;
        currentShortInfo = shortsList[currentIndex];
        currentVideoDetails = null;
        ApiManager.getVideoInfo(currentShortInfo.video_id);
        if (currentIndex >= shortsList.length - 2 && sequenceToken !== "" && !isLoading) {
            isLoading = true;
            ApiManager.getShorts(sequenceToken);
        }
    }

    // --- 1. ПЛЕЕР (ТЕПЕРЬ НА САМОМ НИЖНЕМ СЛОЕ, z=0) ---
    Video {
        id: videoPlayer
        anchors.fill: parent
        fillMode: Video.PreserveAspectCrop
        source: ""
        volume: typeof VolumeKeys !== "undefined" ? (VolumeKeys.volume / 100.0) : 1.0
        onResumed: isPlaying = true
        onStarted: isPlaying = true
        onPaused: isPlaying = false
        onStopped: isPlaying = false
        onStatusChanged: {
            if (status === Video.EndOfMedia) {
                videoPlayer.stop();
                videoPlayer.position = 0;
                videoPlayer.play();
            }
        }
    }

    // --- 2. ВСЕ ОСТАЛЬНОЕ - ПРОЗРАЧНЫЙ КОНТЕЙНЕР ПОВЕРХ ПЛЕЕРА ---
    Item {
        id: uiOverlay
        anchors.fill: parent

        // Спиннер загрузки
        Image {
            id: spinner
            anchors.centerIn: parent
            source: "../Assets/player/reload.png"
            width: 48; height: 48
            z: 100
            visible: isLoading || videoPlayer.status === Video.Loading || videoPlayer.status === 7
            NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible }
        }

        // Управление свайпами и паузой
        MouseArea {
            anchors.fill: parent
            property int startY: 0
            onPressed: { startY = mouse.y; clickTimer.start(); }
            onReleased: {
                clickTimer.stop();
                var dy = mouse.y - startY;
                if (dy < -100) { // Свайп ВВЕРХ
                    if (currentIndex < shortsList.length - 1) { currentIndex++; loadCurrentShort(); }
                } else if (dy > 100) { // Свайп ВНИЗ
                    if (currentIndex > 0) { currentIndex--; loadCurrentShort(); }
                }
            }
            Timer {
                id: clickTimer; interval: 200
                onTriggered: { if (isPlaying) videoPlayer.pause(); else videoPlayer.play(); }
            }
        }

        // Иконка Play, когда на паузе
        Image {
            anchors.centerIn: parent
            width: 64; height: 64
            source: "../Assets/player/play.png"
            visible: !isPlaying && (videoPlayer.status === Video.Loaded || videoPlayer.status === Video.Paused)
        }

        // Прогрессбар снизу
        Rectangle {
            anchors.bottom: parent.bottom; width: parent.width; height: 4
            color: "#66FFFFFF"; z: 10
            Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                color: "white" // Белая полоска для Shorts
                width: videoPlayer.duration > 0 ? (videoPlayer.position / videoPlayer.duration) * parent.width : 0
            }
        }

        // Инфо (Название, Автор)
        Column {
            anchors.left: parent.left; anchors.bottom: parent.bottom
            anchors.margins: 16; anchors.right: rightButtons.left
            spacing: 8

            Row {
                spacing: 8
                Rectangle {
                    width: 32; height: 32; radius: 16; color: "#333"; clip: true
                    SafeImage { anchors.fill: parent; source: currentVideoDetails ? (currentVideoDetails["channel_thumbnail"] || "") : ""; fillMode: Image.PreserveAspectCrop }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: currentVideoDetails ? (currentVideoDetails["author"] || "") : ""
                    color: "white"; font.pixelSize: 16; font.bold: true
                    font.family: "Nokia Pure Text"
                }
            }
            Text {
                text: currentShortInfo ? currentShortInfo.title : ""
                color: "white"
                font.pixelSize: 14
                width: parent.width
                wrapMode: Text.WordWrap // 1. Разрешаем перенос
                elide: Text.ElideRight // 2. Добавляем многоточие, если не влезло

                // 3. Жестко задаем высоту, равную примерно двум строкам
                // (14px * 2 строки + небольшой межстрочный интервал)
                height: 32

                // 4. Обрезаем все, что выходит за эту высоту
                clip: true

                font.family: "Nokia Pure Text"
            }
        }

        // Кнопки справа
        Column {
            id: rightButtons
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 16; anchors.bottomMargin: 30
            spacing: 20

            // Лайк
            Column {
                spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                Image { source: "../Assets/player/like.png"; width: 32; height: 32 }
                Text { text: currentVideoDetails ? (currentVideoDetails["likes"] || "Лайк") : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }
            // Дизлайк
            Image { source: "../Assets/player/dislike.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter }
            // Комментарии
            Column {
                spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                Image { source: "../Assets/player/comments.png"; width: 32; height: 32; MouseArea { anchors.fill: parent; onClicked: commentsSheet.state = "visible" } }
                Text { text: currentVideoDetails ? (currentVideoDetails["comment_count"] || "0") : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }
            // Поделиться
            Image { source: "../Assets/player/send.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // Шторка с комментариями
        Rectangle {
            id: commentsSheet
            anchors.fill: parent; color: "#E6000000"; visible: state === "visible"; z: 50
            state: "hidden"
            states:[ State { name: "visible"; PropertyChanges { target: commentsPanel; y: root.height - commentsPanel.height } }, State { name: "hidden"; PropertyChanges { target: commentsPanel; y: root.height } } ]
            transitions: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: commentsSheet.state = "hidden" }

            Rectangle {
                id: commentsPanel
                width: parent.width; height: root.height * 0.65
                anchors.bottom: parent.bottom; color: "#282828"
                MouseArea { anchors.fill: parent }

                Item {
                    anchors.fill: parent; anchors.margins: 16
                    Column {
                        anchors.fill: parent; spacing: 10
                        Rectangle { width: 40; height: 5; radius: 2.5; color: "gray"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "Комментарии"; color: "white"; font.pixelSize: 18; font.bold: true }
                        Flickable {
                            width: parent.width; height: parent.height - 40
                            contentWidth: width; contentHeight: commentsText.height; clip: true
                            Text {
                                id: commentsText; width: parent.width
                                text: "Функция комментариев в разработке..."
                                color: "white"; font.pixelSize: 14; wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
