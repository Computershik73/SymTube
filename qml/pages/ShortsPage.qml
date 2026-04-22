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

    // Текущие данные для отображения
    property variant currentShortInfo: null
    property variant currentVideoDetails: null

    // Флаг для управления видимостью иконки Play/Pause после тапа
    property bool showPlayIcon: false

    property string currentVideoId: ""
    property variant videoDetails: null

    property variant relatedVideos:[]

    property bool isSeeking: false
    property bool isLandscape: width > height

    // Переменные для фоновой магии и перемотки
    property string currentVideoUrl: ""
    property int recoveryPosition: -1
    property int pendingSeekSeconds: 0
    property bool isUserDraggingSlider: false
    property real sliderDragRatio: 0.0
    property int recoveryAttempts: 0
    property bool isVideoEnded: false


    Connections {
        target: SymbianApp
        onInBackground: {
            if (videoLoader.item && isPlaying) {
                console.log("УХОД В ФОН: Уничтожаем плеер...");
                shortsPage.recoveryPosition = videoLoader.item.position;
                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
            }
        }
        onInFocus: {
            if (videoLoader.item && isPlaying) {
                console.log("ВОЗВРАТ ИЗ ФОНА: Пересоздаем плеер...");
                //shortsPage.recoveryPosition = videoLoader.item.position;
                //videoLoader.sourceComponent = undefined;
                //recreateTimer.start();
            }
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
        interval: 5000 // Каждые 5 секунд
        repeat: true
        running: shortsPage.isPlaying // Работает только пока видео реально играет
        onTriggered: {
            if (typeof SymbianApp !== "undefined") {
                SymbianApp.keepScreenOn(); // Сбрасываем системный таймер гашения экрана
            }
        }
    }

    Connections {
        target: ApiManager
        onShortsReady: {
            isLoading = false;
            sequenceToken = seqToken;
            if (shortsList.length > 0) {
                var combined = shortsPage.shortsList;
                for (var i = 0; i < shortsList.length; i++) combined.push(shortsList[i]);
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

            var directUrl = Config.getVideoUrl(currentVideoDetails.video_id, "360").replace("https://", "http://").replace("yt.swlbst.ru", "yt.modyleprojects.ru");

            if (shortsPage.currentVideoUrl !== directUrl) {
                shortsPage.currentVideoUrl = directUrl;
                shortsPage.recoveryAttempts = 0;
                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
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

        // Сброс UI перед новым видео
        shortsPage.showPlayIcon = false;
        controlsTimer.stop();

        currentShortInfo = shortsList[currentIndex];
        currentVideoDetails = null;
        ApiManager.getVideoInfo(currentShortInfo.video_id);

        if (currentIndex >= shortsList.length - 2 && sequenceToken !== "" && !isLoading) {
            isLoading = true;
            ApiManager.getShorts(sequenceToken);
        }
    }

    // --- 1. ПЛЕЕР (НА САМОМ НИЖНЕМ СЛОЕ) ---
    Component {
        id: videoComponent
        Video {
            id: videoPlayer
            anchors.fill: parent
            fillMode: Video.PreserveAspectFit
            source: shortsPage.currentVideoUrl
            volume: typeof VolumeKeys !== "undefined" ? (VolumeKeys.volume / 100.0) : 1.0

            property int lastIntendedPosition: -1

            onStarted: { shortsPage.isSeeking = false; shortsPage.isPlaying = true; controlsTimer.restart(); shortsPage.recoveryAttempts = 0; }
            onResumed: { shortsPage.isSeeking = false; shortsPage.isPlaying = true; controlsTimer.restart(); shortsPage.recoveryAttempts = 0; }
            onPaused: { shortsPage.isPlaying = false; controlsTimer.stop(); controlsOverlay.visible = true; }
            onStopped: { shortsPage.isPlaying = false; shortsPage.isSeeking = false; controlsTimer.stop(); controlsOverlay.visible = true; }



            onStatusChanged: {
                if (status === Video.Loaded) {
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
                if (errorString.indexOf("-36") !== -1 && shortsPage.recoveryAttempts < 3) {
                    shortsPage.recoveryAttempts++;
                    shortsPage.recoveryPosition = (lastIntendedPosition !== -1) ? lastIntendedPosition : position;
                    videoLoader.sourceComponent = undefined;
                    recreateTimer.start();
                } else {
                    shortsPage.isSeeking = false;
                    shortsPage.isPlaying = false;
                    shortsPage.recoveryPosition = -1;
                }
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

    // --- 2. ПРОЗРАЧНЫЙ КОНТЕЙНЕР ПОВЕРХ ПЛЕЕРА (ИНТЕРФЕЙС) ---
    Item {
        id: controlsOverlay
        anchors.fill: parent
        visible: true

        Timer { id: controlsTimer; interval: 3000; onTriggered: controlsOverlay.visible = false }

        Loader {
            id: videoLoader
            anchors.fill: parent
        }

        // Спиннер загрузки
        SafeImage {
            id: spinner
            anchors.centerIn: parent; z: 100
            source: "../Assets/player/reload.png"
            width: 48; height: 48
            visible: {
                if (shortsPage.isSeeking) return true;
                if (videoLoader.item === null) return true;
                var st = videoLoader.item.status;
                return (st === Video.Loading || st === Video.Buffering || st === Video.Stalled);
            }
            NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible }
        }

        // Ошибка
        Rectangle {
            anchors.centerIn: parent; color: "#CC000000"; radius: 8; z: 10
            width: errorText.width + 40; height: errorText.height + 20
            visible: (videoLoader.item !== null) ? (videoLoader.item.status === Video.InvalidMedia && !shortsPage.isSeeking) : false
            Text { id: errorText; anchors.centerIn: parent; color: "white"; font.pixelSize: 18; text: "Ошибка воспроизведения" }
        }

        // --- УПРАВЛЕНИЕ СВАЙПАМИ И КЛИКАМИ ---
        MouseArea {
            anchors.fill: parent
            property int startY: 0
            property bool isSwiping: false

            onPressed: {
                startY = mouse.y;
                isSwiping = false;
            }

            onPositionChanged: {
                // Если палец сдвинулся больше чем на 20px, это свайп, а не клик
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
                    // Обработка КЛИКА (Пауза/Плей)
                    // Блокируем зону кнопок справа (ширина 60px от правого края)
                    if (mouse.x < parent.width - 60) {
                        if (isPlaying) {
                            videoPlayer.pause();
                            shortsPage.showPlayIcon = true;
                            controlsTimer.stop(); // Оставляем иконку висеть на экране
                        } else {
                            if (videoLoader.item.status === Video.Loaded || videoLoader.item.status === Video.Paused || videoLoader.item.status === Video.EndOfMedia) {
                                videoLoader.item.play();
                                shortsPage.showPlayIcon = true;
                                controlsTimer.restart(); // Показываем иконку и скрываем через 1.5с
                            }
                        }
                    }
                }
            }
        }


        // Иконка Play/Pause по центру
        Image {
            id: playPauseIcon
            anchors.centerIn: parent
            width: 64; height: 64
            source: isPlaying ? "../Assets/player/pause.png" : "../Assets/player/play.png"
            opacity: 0.8
            // Всегда видна на паузе, либо видна временно при запуске воспроизведения
            visible: !isPlaying && videoLoader.item && (videoLoader.item.status === Video.Loaded || videoLoader.item.status === Video.Paused)
        }

        Rectangle {
            id: volumeOsd
            anchors.centerIn: parent
            width: 150; height: 50
            color: "#CC000000"
            radius: 8
            z: 150 // Выше всех оверлеев
            opacity: 0

            // Таймер для скрытия
            Timer {
                id: volumeOsdTimer
                interval: 2000 // Исчезает через 2 секунды
                onTriggered: volumeFadeOut.start()
            }

            // Реакция на изменение громкости
            Connections {
                target: VolumeKeys
                onVolumeChanged: {
                    volumeOsd.opacity = 1.0;
                    volumeFadeOut.stop();
                    volumeOsdTimer.restart();
                }
            }

            // Анимация исчезновения
            SequentialAnimation {
                id: volumeFadeOut
                running: false
                NumberAnimation { target: volumeOsd; property: "opacity"; to: 0.0; duration: 500 }
            }

            Row {
                anchors.centerIn: parent
                spacing: 10

                Image {
                    source: VolumeKeys.volume > 0 ? "../Assets/player/volume_up.png" : "../Assets/player/volume_mute.png"
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: VolumeKeys.volume + "%"
                    color: "white"
                    font.pixelSize: 18
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // --- ПОСТОЯННЫЙ ИНТЕРФЕЙС (не скрывается) ---

        // Прогрессбар снизу (в стиле Shorts)
        Rectangle {
            anchors.bottom: parent.bottom; width: parent.width; height: 4
            color: "#66FFFFFF" // Полупрозрачный фон
            z: 10

            Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                color: "white"
                 width: (videoLoader.item && videoLoader.item.duration > 0) ? (videoLoader.item.position / videoLoader.item.duration) * parent.width : 0
            }
        }

        // Инфо снизу слева (Аватар, Автор, Название)
        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 16
            anchors.bottomMargin: 24 // Приподнимаем над прогрессбаром
            anchors.right: rightButtons.left // Не заезжаем на кнопки справа
            spacing: 8

            MouseArea {
                width: parent.width; height: 40
                onClicked: {
                    var channelId = currentVideoDetails ? currentVideoDetails["channel_custom_url"] : null;
                    if (channelId) root.navigateToChannel(channelId);
                }

                Row {
                    spacing: 8; anchors.verticalCenter: parent.verticalCenter

                    // Аватарка
                    Rectangle {
                        width: 36; height: 36; radius: 18; color: "#333"; clip: true
                        SafeImage {
                            anchors.fill: parent;
                            // ИСПРАВЛЕНИЕ: Очищаем двойное кодирование на лету!
                            source: currentVideoDetails ? (currentVideoDetails["channel_thumbnail"] || "").replace(/%25/g, "%") : "";
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    // Имя
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: currentVideoDetails ? (currentVideoDetails["author"] || "") : ""
                        color: "white"; font.pixelSize: 16; font.bold: true; font.family: "Nokia Pure Text"
                    }
                }
            }

            // Название видео
            Text {
                text: currentShortInfo ? currentShortInfo.title : ""
                color: "white"; font.pixelSize: 14; width: parent.width
                wrapMode: Text.WordWrap; elide: Text.ElideRight; clip: true
                height: 38 // Строго максимум 2 строки
                font.family: "Nokia Pure Text"
            }
        }

        // Кнопки справа (Лайк, Дизлайк, Комменты, Поделиться)
        Column {
            id: rightButtons
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            anchors.bottomMargin: 30
            spacing: 20

            Column {
                spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                Image {
                    source: "../Assets/player/like.png"; width: 32; height: 32
                    MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentVideoId, "like") }
                }
                Text { text: currentVideoDetails ? (currentVideoDetails["likes"] || "Лайк") : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }

            Image {
                source: "../Assets/player/dislike.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter
                MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentVideoId, "dislike") }
            }

            Column {
                spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                Image {
                    source: "../Assets/player/comments.png"; width: 32; height: 32
                    MouseArea { anchors.fill: parent; onClicked: commentsSheet.state = "visible" }
                }
                Text { text: currentVideoDetails ? (currentVideoDetails["comment_count"] || "0") : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }

            Image {
                source: "../Assets/player/send.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // --- ВЫЕЗЖАЮЩАЯ ШТОРКА С КОММЕНТАРИЯМИ ---
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

                MouseArea { anchors.fill: parent } // Блокируем клики сквозь панель

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
