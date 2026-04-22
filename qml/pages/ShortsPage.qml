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

    // Текущие данные для отображения
    property variant currentShortInfo: null
    property variant currentVideoDetails: null

    // Флаг для управления видимостью иконки Play/Pause после тапа
    property bool showPlayIcon: false

    Connections {
        target: SymbianApp
        onInBackground: {
            if (isPlaying) videoPlayer.play(); // Сохраняем аудиопоток в фоне
        }
        onInFocus: {
            if (isPlaying) {
                var currentPos = videoPlayer.position;
                videoPlayer.pause();
                videoPlayer.position = currentPos;
                videoPlayer.play();
            }
        }
    }

    Connections {
        target: ApiManager
        onShortsReady: {
            isLoading = false;
            sequenceToken = seqToken;
            if (shortsList.length > 0) {
                var combined = shortsPlayer.shortsList;
                for (var i = 0; i < shortsList.length; i++) combined.push(shortsList[i]);
                shortsPlayer.shortsList = combined;
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

        // Сброс UI перед новым видео
        shortsPlayer.showPlayIcon = false;
        playIconTimer.stop();

        currentShortInfo = shortsList[currentIndex];
        currentVideoDetails = null;
        ApiManager.getVideoInfo(currentShortInfo.video_id);

        if (currentIndex >= shortsList.length - 2 && sequenceToken !== "" && !isLoading) {
            isLoading = true;
            ApiManager.getShorts(sequenceToken);
        }
    }

    // --- 1. ПЛЕЕР (НА САМОМ НИЖНЕМ СЛОЕ) ---
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
                videoPlayer.position = 0;
                videoPlayer.play(); // Бесшовное зацикливание
            }
        }
    }

    // --- 2. ПРОЗРАЧНЫЙ КОНТЕЙНЕР ПОВЕРХ ПЛЕЕРА (ИНТЕРФЕЙС) ---
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
            visible: isLoading || videoPlayer.status === Video.Loading || videoPlayer.status === 7 // 7 = Buffering
            NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible }
        }

        // Ошибка
        Rectangle {
            anchors.centerIn: parent; color: "#CC000000"; radius: 8; z: 100
            width: errorText.width + 40; height: errorText.height + 20
            visible: videoPlayer.status === Video.InvalidMedia || videoPlayer.status === Video.NoMedia
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
                            shortsPlayer.showPlayIcon = true;
                            playIconTimer.stop(); // Оставляем иконку висеть на экране
                        } else {
                            if (videoPlayer.status === Video.Loaded || videoPlayer.status === Video.Paused || videoPlayer.status === Video.EndOfMedia) {
                                videoPlayer.play();
                                shortsPlayer.showPlayIcon = true;
                                playIconTimer.restart(); // Показываем иконку и скрываем через 1.5с
                            }
                        }
                    }
                }
            }
        }

        // Таймер скрытия иконки
        Timer {
            id: playIconTimer
            interval: 1500
            onTriggered: shortsPlayer.showPlayIcon = false
        }

        // Иконка Play/Pause по центру
        Image {
            id: playPauseIcon
            anchors.centerIn: parent
            width: 64; height: 64
            source: isPlaying ? "../Assets/player/pause.png" : "../Assets/player/play.png"
            opacity: 0.8
            // Всегда видна на паузе, либо видна временно при запуске воспроизведения
            visible: (!isPlaying && (videoPlayer.status === Video.Loaded || videoPlayer.status === Video.Paused)) || shortsPlayer.showPlayIcon
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
                width: videoPlayer.duration > 0 ? (videoPlayer.position / videoPlayer.duration) * parent.width : 0
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
