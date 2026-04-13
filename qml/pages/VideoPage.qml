import QtQuick 1.0
import QtMultimediaKit 1.1
import "../components"

Rectangle {
    id: videoPage
    color: "black"

    property bool isSeeking: false

    property string currentVideoId: ""
    property variant videoDetails: null
    property bool isPlaying: false
    property variant relatedVideos:[]

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
            var directUrl = Config.getVideoUrl(videoDetails.video_id, "360").replace("https", "http").replace("yt.swlbst.ru", "yt.modyleprojects.ru");
            videoPlayer.source = directUrl;
            videoPlayer.play();
        }
        onRelatedVideosReady: {
            if (!videoPage.visible) return;
            relatedVideos = videos;
        }
    }

    function loadVideo(videoId) {
        currentVideoId = videoId;
        videoDetails = null;
        relatedVideos =[];
        videoPlayer.stop();
        videoPlayer.source = "";
        isPlaying = false;
        ApiManager.getVideoInfo(videoId);
        ApiManager.getRelatedVideos(videoId, 0);
    }

    // --- БЛОК ПЛЕЕРА ---
    // --- БЛОК ПЛЕЕРА ---
    // --- БЛОК ПЛЕЕРА ---
    Rectangle {
        id: playerContainer
        width: parent.width
        height: isLandscape ? parent.height : (parent.width * 0.5625)
        anchors.top: parent.top
        color: "black"
        z: 5

        // Переменные для перемотки
        property int pendingSeekSeconds: 0
        property bool isUserDraggingSlider: false
        property real sliderDragRatio: 0.0

        property int recoveryPosition: -1
        property string savedSource: ""
        property int recoveryAttempts: 0
        property int lastIntendedPosition: -1

        Timer {
            id: recoveryTimer
            interval: 200 // Ждем 200 мс, чтобы Symbian "успокоился"
            repeat: false
            onTriggered: {
                console.log("Выполняем безопасный сброс источника...");
                videoPlayer.source = "";
                videoPlayer.source = playerContainer.savedSource;
                // Плеер начнет грузить видео. onStatusChanged поймает Loaded и перемотает.
            }
        }

        Video {
            id: videoPlayer
            anchors.fill: parent
            fillMode: Video.PreserveAspectFit
            volume: 1.0

            // --- НАТИВНЫЕ СИГНАЛЫ СОГЛАСНО ДОКУМЕНТАЦИИ ---
            onStarted: {
                videoPage.isSeeking = false;
                isPlaying = true;
                controlsTimer.restart();
                playerContainer.recoveryAttempts = 0;
            }
            onResumed: {
                videoPage.isSeeking = false;
                isPlaying = true;
                controlsTimer.restart();
                playerContainer.recoveryAttempts = 0;
            }
            onPaused: {
                isPlaying = false;
                controlsTimer.stop();
                controlsOverlay.visible = true;
            }
            onStopped: {
                isPlaying = false;
                videoPage.isSeeking = false;
                controlsTimer.stop();
                controlsOverlay.visible = true;
            }

            // Отслеживание буферизации
            onStatusChanged: {
                if (status === Video.Loaded) {
                    // Если мы восстанавливаемся после ошибки
                    if (playerContainer.recoveryPosition !== -1) {
                        console.log("Восстановление: прыжок на " + playerContainer.recoveryPosition);
                        // Вызываем safeSeek напрямую, чтобы сохранить цепочку
                        var target = playerContainer.recoveryPosition;
                        playerContainer.recoveryPosition = -1;
                        playerContainer.performSafeSeek(target);
                    }
                }

                if (status === Video.InvalidMedia || status === Video.NoMedia || status === Video.EndOfMedia) {
                    // Если это не наша контролируемая ошибка
                    if (playerContainer.recoveryPosition === -1) {
                        videoPage.isSeeking = false;
                        isPlaying = false;

                    }
                }
            }

            // Логгирование реальных ошибок Symbian
            onError: {
                console.log("Video Error [" + error + "]: " + errorString);

                // Если это ошибка перемотки и мы не в процессе восстановления
                if (errorString.indexOf("-36") !== -1 && playerContainer.recoveryAttempts < 3) {
                    console.log("Зафиксирован краш декодера. Подготовка к восстановлению...");

                    playerContainer.recoveryAttempts++;

                    if (playerContainer.lastIntendedPosition !== -1) {
                        playerContainer.recoveryPosition = playerContainer.lastIntendedPosition;
                    } else {
                        playerContainer.recoveryPosition = videoPlayer.position;
                    }

                    // Сохраняем ссылку как строку, чтобы не потерять
                    playerContainer.savedSource = videoPlayer.source.toString();

                    videoPlayer.stop();

                    // Запускаем таймер и ВЫХОДИМ ИЗ СИГНАЛА! Это спасет от краха 0x0.
                    recoveryTimer.start();

                } else {
                    // Если это другая ошибка - просто останавливаем
                    videoPage.isSeeking = false;
                    isPlaying = false;
                    playerContainer.recoveryPosition = -1;
                }
            }
        }

        // --- БЕЗОПАСНАЯ ПЕРЕМОТКА ---
        function  performSafeSeek(newPos) {
            if (!videoPlayer.seekable || videoPlayer.duration <= 0) return;

            if (newPos > videoPlayer.duration) newPos = videoPlayer.duration;
            if (newPos < 0) newPos = 0;

            // СОХРАНЯЕМ позицию на случай краха -36
            playerContainer.lastIntendedPosition = newPos;

            videoPage.isSeeking = true;
            var wasPlaying = isPlaying;

            if (wasPlaying) videoPlayer.pause();

            videoPlayer.position = newPos;

            videoPlayer.play();
            if (!wasPlaying) videoPage.isSeeking = false;
        }

        // Таймер для накопления тапов (+10/-10)
        Timer {
            id: seekAccumulatorTimer
            interval: 500
            repeat: false
            onTriggered: {
                if (playerContainer.pendingSeekSeconds !== 0) {
                    var targetPos = videoPlayer.position + (playerContainer.pendingSeekSeconds * 1000);
                    playerContainer.performSafeSeek(targetPos);
                    playerContainer.pendingSeekSeconds = 0;
                }
            }
        }

        // Глобальная зона клика
        MouseArea {
            anchors.fill: parent

            onClicked: {
                if (spinner.visible) return;
                controlsOverlay.visible = !controlsOverlay.visible;
                if (controlsOverlay.visible && isPlaying) controlsTimer.restart();
                else controlsTimer.stop();
            }

            onDoubleClicked: {
                if (spinner.visible) return;
                if (videoPage.isSeeking) return;

                var zone = mouse.x / width;
                if (zone < 0.35) {
                    playerContainer.pendingSeekSeconds -= 10;
                    seekAccumulatorTimer.restart();
                } else if (zone > 0.65) {
                    playerContainer.pendingSeekSeconds += 10;
                    seekAccumulatorTimer.restart();
                }
            }
        }

        // Текст индикатора накопленных секунд (+10 / -20)
        Text {
            anchors.centerIn: parent; z: 10
            color: "white"; font.pixelSize: 36; font.bold: true
            style: Text.Outline; styleColor: "black"
            text: playerContainer.pendingSeekSeconds !== 0 ? (playerContainer.pendingSeekSeconds > 0 ? "+" + playerContainer.pendingSeekSeconds : playerContainer.pendingSeekSeconds) : ""
            visible: playerContainer.pendingSeekSeconds !== 0
        }

        // --- УПРАВЛЕНИЕ ПЛЕЕРОМ (ОВЕРЛЕЙ) ---
        Item {
            id: controlsOverlay
            anchors.fill: parent
            visible: true

            Timer { id: controlsTimer; interval: 3000; onTriggered: controlsOverlay.visible = false }

            Rectangle { anchors.fill: parent; color: "#66000000" }

            SafeImage {
                anchors.centerIn: parent
                width: 64; height: 64
                source: isPlaying ? "../Assets/player/pause.png" : "../Assets/player/play.png"
                visible: playerContainer.pendingSeekSeconds === 0 && !videoPage.isSeeking && videoPlayer.status !== Video.Loading

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (isPlaying) videoPlayer.pause(); else videoPlayer.play();
                        controlsTimer.restart();
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom; width: parent.width; height: 40; color: "#B3000000"
                visible: playerContainer.pendingSeekSeconds === 0 && !videoPage.isSeeking && videoPlayer.status !== Video.Loading

                MouseArea { anchors.fill: parent; onClicked: controlsTimer.restart() }

                Text {
                    id: currentTimeText
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 10
                    color: "white"; font.pixelSize: 14
                    text: formatTime(videoPlayer.position)
                }

                Text {
                    id: totalTimeText
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 10
                    color: "white"; font.pixelSize: 14
                    text: videoPlayer.duration > 0 ? formatTime(videoPlayer.duration) : "0:00"
                }

                Item {
                    anchors.left: currentTimeText.right; anchors.right: totalTimeText.left
                    anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 30

                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 4; color: "#444444"; radius: 2 }

                    // Буфер (теперь, когда сервер на Rust отдает Content-Length, эта полоска будет работать честно!)
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        height: 4; color: "#888888"; radius: 2
                        width: (videoPlayer.bufferProgress !== undefined ? videoPlayer.bufferProgress : 0) * parent.width
                    }

                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        height: 4; color: "red"; radius: 2
                        width: videoPlayer.duration > 0 ? (playerContainer.isUserDraggingSlider ? playerContainer.sliderDragRatio : (videoPlayer.position / videoPlayer.duration)) * parent.width : 0
                    }

                    Rectangle {
                        width: 16; height: 16; radius: 8; color: "red"
                        anchors.verticalCenter: parent.verticalCenter
                        x: (videoPlayer.duration > 0 ? (playerContainer.isUserDraggingSlider ? playerContainer.sliderDragRatio : (videoPlayer.position / videoPlayer.duration)) * parent.width : 0) - 8
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -15; anchors.bottomMargin: -15

                        onPressed: {
                            if (videoPage.isSeeking || videoPlayer.duration <= 0) return;
                            playerContainer.isUserDraggingSlider = true;
                            controlsTimer.stop();

                            var ratio = mouse.x / width;
                            if (ratio < 0) ratio = 0; if (ratio > 1) ratio = 1;
                            playerContainer.sliderDragRatio = ratio;
                        }

                        onPositionChanged: {
                            if (!playerContainer.isUserDraggingSlider) return;
                            var ratio = mouse.x / width;
                            if (ratio < 0) ratio = 0; if (ratio > 1) ratio = 1;
                            playerContainer.sliderDragRatio = ratio;
                        }

                        onReleased: {
                            if (!playerContainer.isUserDraggingSlider) return;
                            playerContainer.isUserDraggingSlider = false;

                            var targetPos = playerContainer.sliderDragRatio * videoPlayer.duration;
                            playerContainer.performSafeSeek(targetPos);

                            controlsTimer.restart();
                        }
                    }
                }
            }
        }

        // --- СПИННЕР ЗАГРУЗКИ ---
        SafeImage {
            id: spinner
            anchors.centerIn: parent
            z: 100
            source: "../Assets/player/reload.png"
            width: 48; height: 48
            // Согласно документации, отображаем спиннер при Loading, Buffering и Stalled.
            // Плюс добавляем наш флаг isSeeking.
            visible: videoPage.isSeeking || videoPlayer.status === Video.Loading || videoPlayer.status === Video.Buffering || videoPlayer.status === Video.Stalled

            NumberAnimation on rotation {
                from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible
            }
        }

        // --- СООБЩЕНИЕ ОБ ОШИБКЕ ---
        Rectangle {
            anchors.centerIn: parent; color: "#CC000000"; radius: 8; z: 100
            width: errorText.width + 40; height: errorText.height + 20
            visible: !videoPage.isSeeking && (videoPlayer.status === Video.InvalidMedia)
            Text { id: errorText; anchors.centerIn: parent; color: "white"; font.pixelSize: 18; text: "Ошибка воспроизведения" }
        }
    }

    // --- ОСНОВНОЙ КОНТЕНТ (Скрывается в полноэкранном режиме) ---
    Flickable {
        anchors.top: playerContainer.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        contentWidth: parent.width; contentHeight: contentColumn.height + 40; clip: true
        visible: !isLandscape

        Column {
            id: contentColumn
            width: parent.width; spacing: 0

            // Название
            Item { width: parent.width; height: titleText.height + 32
                Text {
                    id: titleText; x: 16; y: 16; width: parent.width - 32
                    text: videoDetails ? (videoDetails["title"] || "Загрузка...") : ""
                    color: "white"; font.pixelSize: 18; font.bold: true
                    wrapMode: Text.WordWrap; font.family: "Nokia Pure Text"
                }
            }

            // Просмотры
            Text { x: 16; text: videoDetails ? ((videoDetails["views"] || "0") + " просмотров") : ""; color: "gray"; font.pixelSize: 14 }

            // --- КЛИКАБЕЛЬНЫЙ БЛОК АВТОРА ---
            Item {
                width: parent.width; height: 60

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // Переходим на канал по custom_url или имени автора
                        var channelId = videoDetails["channel_custom_url"];
                        if (channelId) {
                            root.navigateToChannel(channelId);
                        }
                    }
                }

                Row {
                    x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    Rectangle {
                        width: 40; height: 40; radius: 20; color: "#333"; clip: true
                        SafeImage { anchors.fill: parent; source: videoDetails ? ("http://yt.modyleprojects.ru/channel_icon/"+videoDetails["video_id"]) : ""; fillMode: Image.PreserveAspectCrop }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        // ИСПРАВЛЕНИЕ: Явная ширина относительно ширины страницы минус отступы
                        width: videoPage.width - 100
                        Text {
                            text: videoDetails ? (videoDetails["author"] || "Неизвестно") : ""; color: "white"; font.pixelSize: 16; font.bold: true
                            font.family: "Nokia Pure Text"; width: parent.width; elide: Text.ElideRight
                        }
                        Text { text: videoDetails ? (videoDetails["subscriberCount"] || "") + " подписчиков" : ""; color: "gray"; font.pixelSize: 12 }
                    }
                }
            }

            // Краткое описание
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

            // --- СВЯЗАННЫЕ ВИДЕО (РЕКОМЕНДАЦИИ) ---
            Item { width: parent.width; height: 20 } // Отступ

            Text {
                x: 16; text: "Похожие видео"
                color: "white"; font.pixelSize: 18; font.bold: true
                font.family: "Nokia Pure Text"
                visible: relatedVideos.length > 0
            }

            Item { width: parent.width; height: 12 } // Отступ

            ListView {
                width: parent.width
                spacing: 12
                // В QML 1.0 Repeater используется для создания списка внутри Column, чтобы он прокручивался вместе со страницей
                height: 600
                    model: relatedVideos
                    delegate: VideoCard {
                        // QVariantList передает элементы через model.modelData
                        modelData: model.modelData
                        onClicked: {
                            root.navigateToVideo(videoId)
                        }
                    }

            }
        }
    }

    // --- Шторка описания (без изменений) ---
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
