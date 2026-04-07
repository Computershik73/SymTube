import QtQuick 1.0
import QtMultimediaKit 1.1

Rectangle {
    id: videoPage
    color: "black"

    property string currentVideoId: ""
    property variant videoDetails: null
    property bool isPlaying: false

    // Перехватываем альбомную ориентацию
    property bool isLandscape: width > height

    function formatTime(ms) {
        if (ms <= 0) return "0:00";
        var totalSeconds = Math.floor(ms / 1000);
        var m = Math.floor(totalSeconds / 60);
        var s = totalSeconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

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
            var directUrl = Config.getVideoUrl(videoDetails.video_id, "360").replace("https", "http");
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

    // --- БЛОК ПЛЕЕРА ---
    Rectangle {
        id: playerContainer
        width: parent.width
        // В альбомной ориентации занимаем всю высоту экрана
        height: isLandscape ? parent.height : (parent.width * 0.5625)
        anchors.top: parent.top
        color: "black"
        z: 5

        Video {
            id: videoPlayer
            anchors.fill: parent
            fillMode: Video.PreserveAspectFit
            onResumed: { isPlaying = true; controlsTimer.restart(); }
            onStarted: { isPlaying = true; controlsTimer.restart(); }
            onPaused: { isPlaying = false; controlsTimer.stop(); controlsOverlay.visible = true; }
            onStopped: { isPlaying = false; controlsTimer.stop(); controlsOverlay.visible = true; }
        }

        // Индикаторы загрузки/ошибки
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

        // --- ГЛОБАЛЬНАЯ ЗОНА КЛИКА ПО ВИДЕО ---
        // Она всегда активна и перехватывает тапы для показа/скрытия интерфейса
        MouseArea {
            anchors.fill: parent
            onClicked: {
                controlsOverlay.visible = !controlsOverlay.visible;
                if (controlsOverlay.visible && isPlaying) {
                    controlsTimer.restart();
                } else {
                    controlsTimer.stop();
                }
            }
        }

        // --- УПРАВЛЕНИЕ ПЛЕЕРОМ (ОВЕРЛЕЙ) ---
        Item {
            id: controlsOverlay
            anchors.fill: parent
            visible: true

            Timer {
                id: controlsTimer
                interval: 3000 // Скрывать через 3 секунды
                onTriggered: controlsOverlay.visible = false
            }

            // Темное затенение
            Rectangle {
                anchors.fill: parent
                color: "#66000000"
            }

            // Кнопка Play/Pause по центру
            Image {
                anchors.centerIn: parent
                width: 64; height: 64
                source: isPlaying ? "../Assets/player/pause.png" : "../Assets/player/play.png"


                MouseArea {
                    anchors.fill: parent
                    // Перехватываем клик, чтобы он не дошел до глобальной зоны и не скрыл оверлей
                    onClicked: {
                        if (isPlaying) videoPlayer.pause();
                        else videoPlayer.play();
                        controlsTimer.restart();
                    }
                }
            }

            // Нижняя панель с ползунком
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 40
                color: "#B3000000"
                // ОШИБКА БЫЛА ЗДЕСЬ. Условие visible удалено.

                // Заглушка, чтобы клики по нижней панели не скрывали интерфейс
                MouseArea {
                    anchors.fill: parent
                    onClicked: { controlsTimer.restart(); } // Просто обновляем таймер
                }

                // Текущее время
                Text {
                    id: currentTimeText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    color: "white"
                    font.pixelSize: 14
                    text: formatTime(videoPlayer.position)
                }

                // Оставшееся время
                Text {
                    id: totalTimeText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 10
                    color: "white"
                    font.pixelSize: 14
                    text: videoPlayer.duration > 0 ? formatTime(videoPlayer.duration) : "0:00"
                }

                // Прогрессбар
                Item {
                    anchors.left: currentTimeText.right
                    anchors.right: totalTimeText.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    height: 30

                    // Серая полоска (фон)
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        height: 4; color: "#666666"; radius: 2
                    }

                    // Красная полоска (прогресс)
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        height: 4; color: "red"; radius: 2
                        width: videoPlayer.duration > 0 ? (videoPlayer.position / videoPlayer.duration) * parent.width : 0
                    }

                    // Ползунок (кружок)
                    Rectangle {
                        width: 16; height: 16; radius: 8; color: "red"
                        anchors.verticalCenter: parent.verticalCenter
                        x: (videoPlayer.duration > 0 ? (videoPlayer.position / videoPlayer.duration) * parent.width : 0) - 8
                    }

                    // Обработка перемотки
                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -10
                        anchors.bottomMargin: -10

                        function seekToMouse(mouseX, areaWidth) {
                            if (videoPlayer.duration <= 0) return;
                            var ratio = mouseX / areaWidth;
                            if (ratio < 0) ratio = 0;
                            if (ratio > 1) ratio = 1;
                            videoPlayer.position = ratio * videoPlayer.duration;
                        }

                        onClicked: { seekToMouse(mouse.x, width); controlsTimer.restart(); }
                        onPositionChanged: { seekToMouse(mouse.x, width); controlsTimer.restart(); }
                    }
                }
            }
        }
    }

    // --- ОСНОВНОЙ КОНТЕНТ (Скрывается в полноэкранном режиме) ---
    Flickable {
        anchors.top: playerContainer.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        contentWidth: parent.width; contentHeight: contentColumn.height + 40; clip: true

        // Скрываем ленту под видео, если телефон повернут (полноэкранный режим)
        visible: !isLandscape

        Column {
            id: contentColumn
            width: parent.width; spacing: 0

            Item { width: parent.width; height: titleText.height + 32
                Text {
                    id: titleText; x: 16; y: 16; width: parent.width - 32
                    text: videoDetails ? (videoDetails["title"] || "Загрузка...") : ""
                    color: "white"; font.pixelSize: 18; font.bold: true
                    wrapMode: Text.WordWrap
                    //font.family: "Nokia Pure Text"
                }
            }

            Text { x: 16; text: videoDetails ? ((videoDetails["views"] || "0") + " просмотров") : ""; color: "gray"; font.pixelSize: 14 }

            Item {
                width: parent.width; height: 60
                Row {
                    x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    Rectangle {
                        width: 40; height: 40; radius: 20; color: "#333"; clip: true
                        Image { anchors.fill: parent; source: videoDetails ? (videoDetails["channel_thumbnail"].replace("yt.modyleprojects.ru", "yt.swlbst.ru") || "") : ""; fillMode: Image.PreserveAspectCrop }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 100
                        Text {
                            text: videoDetails ? (videoDetails["author"]) : ""; color: "white"; font.pixelSize: 16; font.bold: true
                            //font.family: "Nokia Pure Text";
                            width: parent.width; elide: Text.ElideRight
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
                    color: "white"; font.pixelSize: 14; wrapMode: Text.WordWrap; elide: Text.ElideRight
                    //font.family: "Nokia Pure Text"
                }
                MouseArea { anchors.fill: parent; onClicked: descriptionSheet.state = "visible" }
            }
        }
    }

    // Шторка с описанием (без изменений)
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
                            color: "white"; font.pixelSize: 16; wrapMode: Text.WordWrap
                            //; font.family: "Nokia Pure Text"
                        }
                    }
                }
            }
        }
    }
}
