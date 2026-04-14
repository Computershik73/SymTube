import QtQuick 1.0
import QtMultimediaKit 1.1
import "../components"

Rectangle {
    id: videoPage
    color: "black"

    property bool isSeeking: false

    // --- ПЕРЕМЕННЫЕ ДЛЯ ФОНОВОЙ МАГИИ И ПЕРЕМОТКИ ---
    property string currentVideoUrl: ""
    property int recoveryPosition: -1
    property int pendingSeekSeconds: 0
    property bool isUserDraggingSlider: false
    property real sliderDragRatio: 0.0
    property int recoveryAttempts: 0

    // --- ОБРАБОТКА ФОНОВОГО И АКТИВНОГО РЕЖИМА ---
    Connections {
        target: SymbianApp

        onInBackground: {
            if (videoLoader.item && isPlaying) {
                console.log("УХОД В ФОН: Уничтожаем плеер...");
                // 1. Запоминаем, где остановились
                videoPage.recoveryPosition = videoLoader.item.position;

                // 2. ФИЗИЧЕСКИ УНИЧТОЖАЕМ ПЛЕЕР (освобождаем видео-оверлей)
                videoLoader.sourceComponent = undefined;

                // 3. Запускаем таймер для пересоздания плеера в фоне (только с аудио)
                recreateTimer.start();
            }
        }

        onInFocus: {
            if (videoLoader.item && isPlaying) {
                console.log("ВОЗВРАТ ИЗ ФОНА: Пересоздаем плеер для возврата картинки...");
                // 1. Фоновый плеер играл только звук. Запоминаем текущую фоновую позицию.
                videoPage.recoveryPosition = videoLoader.item.position;

                // 2. Уничтожаем фоновый плеер
                videoLoader.sourceComponent = undefined;

                // 3. Запускаем таймер для пересоздания полноценного плеера с картинкой
                recreateTimer.start();
            }
        }
    }

    // Таймер для безопасного пересоздания компонента
    Timer {
        id: recreateTimer
        interval: 150 // Ждем 150 мс, чтобы Symbian успел очистить память от старого плеера
        repeat: false
        onTriggered: {
            console.log("ПЕРЕСОЗДАНИЕ: Загружаем компонент заново...");
            videoLoader.sourceComponent = videoComponent;
        }
    }

    // Обработчик загрузки видео из сети
    Connections {
        target: ApiManager
        onVideoInfoReady: {
            videoDetails = videoDetailsMap;
            HistoryManager.addToHistory({
                                        "video_id": videoDetails.video_id, "title": videoDetails.title,
                                        "author": videoDetails.author, "thumbnail": videoDetails.thumbnail
        });

            // Сохраняем ссылку в свойство страницы, чтобы она пережила уничтожение плеера
            videoPage.currentVideoUrl = Config.getVideoUrl(videoDetails.video_id, "360").replace("https://", "http://").replace("yt.swlbst.ru", "yt.modyleprojects.ru");

            // Сбрасываем попытки и создаем новый плеер
            videoPage.recoveryAttempts = 0;
            videoLoader.sourceComponent = undefined;
            recreateTimer.start();
        }
    }

    function loadVideo(videoId) {
        currentVideoId = videoId;
        videoDetails = null;
        videoPage.currentVideoUrl = "";
        videoLoader.sourceComponent = undefined; // Уничтожаем старый плеер
        isPlaying = false;
        ApiManager.getVideoInfo(videoId);
    }

    // --- ШАБЛОН ПЛЕЕРА (Создается и уничтожается на лету) ---
    Component {
        id: videoComponent
        Video {
            anchors.fill: parent
            fillMode: Video.PreserveAspectFit

            // Берем ссылку из свойства страницы
            source: videoPage.currentVideoUrl

            // Привязываем громкость к аппаратным кнопкам Symbian (от 0.0 до 1.0)
            // Добавлена проверка на наличие VolumeKeys
            volume: typeof VolumeKeys !== "undefined" ? (VolumeKeys.volume / 100.0) : 1.0

            onStarted: { videoPage.isSeeking = false; videoPage.isPlaying = true; controlsTimer.restart(); }
            onResumed: { videoPage.isSeeking = false; videoPage.isPlaying = true; controlsTimer.restart(); }
            onPaused: { videoPage.isPlaying = false; controlsTimer.stop(); controlsOverlay.visible = true; }
            onStopped: { videoPage.isPlaying = false; videoPage.isSeeking = false; controlsTimer.stop(); controlsOverlay.visible = true; }

            onStatusChanged: {
                if (status === Video.Loaded) {
                    // ЕСЛИ МЫ ВОССТАНАВЛИВАЕМСЯ (Из фона или после краша)
                    if (videoPage.recoveryPosition !== -1) {
                        console.log("Плеер загружен. Перематываем на: " + videoPage.recoveryPosition);
                        var target = videoPage.recoveryPosition;
                        videoPage.recoveryPosition = -1; // Сбрасываем флаг

                        // Меняем позицию и запускаем
                        position = target;
                        play();
                    } else {
                        // Обычный запуск нового видео
                        play();
                    }
                }

                if (status === Video.InvalidMedia || status === Video.NoMedia || status === Video.EndOfMedia) {
                    if (videoPage.recoveryPosition === -1) {
                        videoPage.isSeeking = false;
                    }
                }
            }

            onError: {
                console.log("Video Error [" + error + "]: " + errorString);

                // Если краш декодера -36, делаем "горячее" пересоздание
                if (errorString.indexOf("-36") !== -1 && videoPage.recoveryAttempts < 3) {
                    videoPage.recoveryAttempts++;
                    videoPage.recoveryPosition = position;
                    videoLoader.sourceComponent = undefined; // Уничтожаем себя!
                    recreateTimer.start(); // Возрождаемся через 150 мс
                } else {
                    videoPage.isSeeking = false;
                    videoPage.isPlaying = false;
                }
            }
        }
    }

    // --- БЛОК КОНТЕЙНЕРА ---
    Rectangle {
        id: playerContainer
        width: parent.width
        height: isLandscape ? parent.height : (parent.width * 0.5625)
        anchors.top: parent.top
        color: "black"
        z: 5

        // ЗАГРУЗЧИК (Здесь физически появляется Video)
        Loader {
            id: videoLoader
            anchors.fill: parent
        }

        // Индикатор ошибки (Смотрит на статус внутри Loader)
        Rectangle {
            anchors.centerIn: parent; color: "#CC000000"; radius: 8; z: 10
            width: errorText.width + 40; height: errorText.height + 20
            visible: videoLoader.item && (videoLoader.item.status === Video.InvalidMedia) && !videoPage.isSeeking
            Text { id: errorText; anchors.centerIn: parent; color: "white"; font.pixelSize: 18; text: "Ошибка воспроизведения" }
        }

        // Глобальная зона клика
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (spinner.visible) return;
                controlsOverlay.visible = !controlsOverlay.visible;
                if (controlsOverlay.visible && videoPage.isPlaying) controlsTimer.restart();
                else controlsTimer.stop();
            }
            onDoubleClicked: {
                if (spinner.visible || videoPage.isSeeking) return;
                var zone = mouse.x / width;
                if (zone < 0.35) { videoPage.pendingSeekSeconds -= 10; seekAccumulatorTimer.restart(); }
                else if (zone > 0.65) { videoPage.pendingSeekSeconds += 10; seekAccumulatorTimer.restart(); }
            }
        }

        Text {
            anchors.centerIn: parent; z: 10; color: "white"; font.pixelSize: 36; font.bold: true; style: Text.Outline; styleColor: "black"
            text: videoPage.pendingSeekSeconds !== 0 ? (videoPage.pendingSeekSeconds > 0 ? "+" + videoPage.pendingSeekSeconds : videoPage.pendingSeekSeconds) : ""
            visible: videoPage.pendingSeekSeconds !== 0
        }

        // Таймер для безопасной перемотки (ручной)
        Timer {
            id: seekAccumulatorTimer
            interval: 500
            repeat: false
            onTriggered: {
                if (videoPage.pendingSeekSeconds !== 0 && videoLoader.item) {
                    var targetPos = videoLoader.item.position + (videoPage.pendingSeekSeconds * 1000);

                    if (targetPos > videoLoader.item.duration) targetPos = videoLoader.item.duration;
                    if (targetPos < 0) targetPos = 0;

                    videoPage.isSeeking = true;
                    videoLoader.item.position = targetPos;

                    videoPage.pendingSeekSeconds = 0;
                }
            }
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
                source: videoPage.isPlaying ? "../Assets/player/pause.png" : "../Assets/player/play.png"
                visible: videoPage.pendingSeekSeconds === 0 && !videoPage.isSeeking && (!videoLoader.item || videoLoader.item.status !== Video.Loading)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!videoLoader.item) return;
                        if (videoPage.isPlaying) videoLoader.item.pause(); else videoLoader.item.play();
                        controlsTimer.restart();
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom; width: parent.width; height: 40; color: "#B3000000"
                visible: videoPage.pendingSeekSeconds === 0 && !videoPage.isSeeking && (!videoLoader.item || videoLoader.item.status !== Video.Loading)

                MouseArea { anchors.fill: parent; onClicked: controlsTimer.restart() }

                Text {
                    id: currentTimeText
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 10
                    color: "white"; font.pixelSize: 14
                    text: videoLoader.item ? formatTime(videoLoader.item.position) : "0:00"
                }

                Text {
                    id: totalTimeText
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 10
                    color: "white"; font.pixelSize: 14
                    text: (videoLoader.item && videoLoader.item.duration > 0) ? formatTime(videoLoader.item.duration) : "0:00"
                }

                Item {
                    anchors.left: currentTimeText.right; anchors.right: totalTimeText.left
                    anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 30

                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 4; color: "#444444"; radius: 2 }

                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        height: 4; color: "#888888"; radius: 2
                        width: (videoLoader.item && videoLoader.item.bufferProgress !== undefined) ? videoLoader.item.bufferProgress * parent.width : 0
                    }

                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        height: 4; color: "red"; radius: 2
                        width: (videoLoader.item && videoLoader.item.duration > 0) ? (videoPage.isUserDraggingSlider ? videoPage.sliderDragRatio : (videoLoader.item.position / videoLoader.item.duration)) * parent.width : 0
                    }

                    Rectangle {
                        width: 16; height: 16; radius: 8; color: "red"
                        anchors.verticalCenter: parent.verticalCenter
                        x: ((videoLoader.item && videoLoader.item.duration > 0) ? (videoPage.isUserDraggingSlider ? videoPage.sliderDragRatio : (videoLoader.item.position / videoLoader.item.duration)) * parent.width : 0) - 8
                    }

                    MouseArea {
                        anchors.fill: parent; anchors.topMargin: -15; anchors.bottomMargin: -15
                        onPressed: {
                            if (videoPage.isSeeking || !videoLoader.item || videoLoader.item.duration <= 0) return;
                            videoPage.isUserDraggingSlider = true;
                            controlsTimer.stop();
                            var ratio = mouse.x / width;
                            if (ratio < 0) ratio = 0; if (ratio > 1) ratio = 1;
                            videoPage.sliderDragRatio = ratio;
                        }
                        onPositionChanged: {
                            if (!videoPage.isUserDraggingSlider) return;
                            var ratio = mouse.x / width;
                            if (ratio < 0) ratio = 0; if (ratio > 1) ratio = 1;
                            videoPage.sliderDragRatio = ratio;
                        }
                        onReleased: {
                            if (!videoPage.isUserDraggingSlider) return;
                            videoPage.isUserDraggingSlider = false;
                            videoPage.isSeeking = true;
                            videoLoader.item.position = videoPage.sliderDragRatio * videoLoader.item.duration;
                            controlsTimer.restart();
                        }
                    }
                }
            }
        }

        // --- СПИННЕР ---
        SafeImage {
            id: spinner
            anchors.centerIn: parent; z: 100
            source: "../Assets/player/reload.png"
            width: 48; height: 48
            // Видно, если грузим, ищем или плеер вообще еще не создан лоадером
            visible: videoPage.isSeeking || !videoLoader.item || videoLoader.item.status === Video.Loading || videoLoader.item.status === Video.Buffering || videoLoader.item.status === Video.Stalled
            NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible }
        }
    }
    // --- ОСНОВНОЙ КОНТЕНТ (Скрывается в полноэкранном режиме) ---
    /*Flickable {
        anchors.top: playerContainer.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        contentWidth: parent.width; contentHeight: contentColumn.height + 40; clip: true
        visible: !isLandscape*/


    // }

    ListView {
        id: mainList
        snapMode: ListView.NoSnap
        highlightMoveDuration: 0
        anchors.top: playerContainer.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        //width: parent.width
        visible: !isLandscape
        onModelChanged: {
            mainList.contentY = 0;
        }
        header: Column {
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
                id: relvidtext
                x: 16; text: "Похожие видео"
                color: "white"; font.pixelSize: 18; font.bold: true
                font.family: "Nokia Pure Text"
                visible: relatedVideos.length > 0
            }

            Item { width: parent.width; height: 12 } // Отступ


        }

        interactive: true
        height: 400
        clip: true
        // В QML 1.0 Repeater используется для создания списка внутри Column, чтобы он прокручивался вместе со страницей
        //height: parent.height - 20 - relvidtext.height - 12 - 80 - 60
        model: relatedVideos
        delegate: VideoCard {
            // QVariantList передает элементы через model.modelData
            modelData: model.modelData
            onClicked: {
                root.navigateToVideo(videoId)
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
