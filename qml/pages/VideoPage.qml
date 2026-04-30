import QtQuick 1.0
import QtMultimediaKit 1.1
import "../components"

Rectangle {
    id: videoPage
    color: "black"

    property string currentVideoId: ""
    property variant videoDetails: null
    property bool isPlaying: false
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



    property int uiPosition: 0

    Timer {
        id: uiTimer
        interval: 500 // Обновляем интерфейс всего 2 раза в секунду
        repeat: true
        // Таймер работает ТОЛЬКО когда видео играет и панель открыта
        running: videoPage.isPlaying && controlsOverlay.visible
        onTriggered: {
            if (videoLoader.item) {
                videoPage.uiPosition = videoLoader.item.position;
            }
        }
    }

    function formatTime(ms) {
        if (ms <= 0) return "0:00";
        var totalSeconds = Math.floor(ms / 1000);
        var m = Math.floor(totalSeconds / 60);
        var s = totalSeconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Connections {
        target: SymbianApp
        onInBackground: {
            if (videoLoader.item && videoPage.isPlaying) {
                console.log("УХОД В ФОН: Уничтожаем плеер...");
                videoPage.recoveryPosition = videoLoader.item.position;
                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
            }
        }
        onInFocus: {
            if (videoLoader.item && isPlaying) {
                console.log("ВОЗВРАТ ИЗ ФОНА: Пересоздаем плеер...");
                //videoPage.recoveryPosition = videoLoader.item.position;
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
        running: SymbianApp.foreground()
        onTriggered: {
            if (typeof SymbianApp !== "undefined") {
                SymbianApp.keepScreenOn(); // Сбрасываем системный таймер гашения экрана
            }
        }
    }

    Connections {
        target: ApiManager
        onVideoInfoReady: {
            videoDetails = videoDetailsMap;
            HistoryManager.addToHistory({
                                        "video_id": videoDetails.video_id,
                                        "title": videoDetails.title,
                                        "author": videoDetails.author,
                                        "thumbnail": "https://i.ytimg.com/vi/" + videoDetails.video_id + "/mqdefault.jpg"
        });

            // Получаем прямую ссылку из ответа API
            videoPage.currentVideoUrl = videoDetails.video_url;
            console.log(videoPage.currentVideoUrl)

            videoPage.recoveryAttempts = 0;
            videoLoader.sourceComponent = undefined;
            recreateTimer.start();
        }
        onRelatedVideosReady: {
            if (!videoPage.visible) return;
            relatedVideos = videos;
            // Принудительно сбрасываем скролл
            mainList.contentY = 0;
        }
    }



    function changeQuality(newUrl) {
        if (!videoDetails || currentVideoUrl === newUrl) return;

        var pos = 0;
        if (videoLoader.item) {
            pos = videoLoader.item.position;
            videoLoader.item.stop();
        }
        videoPage.recoveryPosition = pos;
        videoPage.recoveryAttempts = 0;
        videoPage.currentVideoUrl = newUrl;

        videoLoader.sourceComponent = undefined;
        recreateTimer.start();
    }

    function loadVideo(videoId) {
        currentVideoId = videoId;
        videoDetails = null;
        relatedVideos =[];
        videoPage.currentVideoUrl = "";
        videoLoader.sourceComponent = undefined;
        isPlaying = false;
        isSeeking = false;
        ApiManager.getVideoInfo(videoId);
        ApiManager.getRelatedVideos(videoId, 0);
    }

    // --- ШАБЛОН ПЛЕЕРА ---
    Component {
        id: videoComponent
        Video {
            anchors.fill: parent
            fillMode: Video.PreserveAspectFit
            source: videoPage.currentVideoUrl
            volume: Config.persistentVolume

            property int lastIntendedPosition: -1



            onStarted: { videoPage.isSeeking = false; videoPage.isPlaying = true; controlsTimer.restart(); videoPage.recoveryAttempts = 0; }
            onResumed: { videoPage.isSeeking = false; videoPage.isPlaying = true; controlsTimer.restart(); videoPage.recoveryAttempts = 0; }
            onPaused: { videoPage.isPlaying = false; controlsTimer.stop(); controlsOverlay.visible = true; }
            onStopped: { videoPage.isPlaying = false; videoPage.isSeeking = false; controlsTimer.stop(); controlsOverlay.visible = true; }

            onStatusChanged: {
                if (status === Video.Loaded) {

                    if (typeof VolumeKeys !== "undefined") {
                        VolumeKeys.volume = Config.persistentVolume * 100;
                    }
                    if (videoPage.recoveryPosition !== -1) {
                        var target = videoPage.recoveryPosition;
                        videoPage.recoveryPosition = -1;
                        performSafeSeek(target);
                    } else {
                        play();
                    }
                }
                if (status === Video.InvalidMedia || status === Video.NoMedia || status === Video.EndOfMedia) {
                    if (videoPage.recoveryPosition === -1) {
                        videoPage.isSeeking = false;
                        videoPage.isPlaying = false;
                    }
                }
            }

            onError: {
                if (errorString.indexOf("-36") !== -1 && videoPage.recoveryAttempts < 3) {
                    videoPage.recoveryAttempts++;
                    videoPage.recoveryPosition = (lastIntendedPosition !== -1) ? lastIntendedPosition : position;
                    videoLoader.sourceComponent = undefined;
                    recreateTimer.start();
                } else {
                    videoPage.isSeeking = false;
                    videoPage.isPlaying = false;
                    videoPage.recoveryPosition = -1;
                }
            }

            function performSafeSeek(newPos) {
                if (!seekable || duration <= 0) return;
                if (newPos > duration) newPos = duration;
                if (newPos < 0) newPos = 0;

                lastIntendedPosition = newPos;
                videoPage.isSeeking = true;
                var wasPlaying = videoPage.isPlaying;

                if (wasPlaying) pause();
                position = newPos;
                play();


                if (!wasPlaying) videoPage.isSeeking = false;
            }
        }
    }

    Timer {
        id: seekAccumulatorTimer
        interval: 500; repeat: false
        onTriggered: {
            if (videoPage.pendingSeekSeconds !== 0 && videoLoader.item) {
                var targetPos = videoLoader.item.position + (videoPage.pendingSeekSeconds * 1000);
                videoLoader.item.performSafeSeek(targetPos);
                videoPage.pendingSeekSeconds = 0;
            }
        }
    }

    // --- БЛОК КОНТЕЙНЕРА (ВЕРХНЯЯ ЧАСТЬ ЭКРАНА) ---
    Rectangle {
        id: playerContainer
        width: parent.width
        height: root.isFullscreen ? parent.height : (root.isLandscape ? parent.height * 0.6 : parent.width * 0.5625)
        anchors.top: parent.top
        color: "black"
        z: 5

        Loader {
            id: videoLoader
            anchors.fill: parent
        }



        // ИСПРАВЛЕНИЕ: Безопасные проверки на null для visible
        Rectangle {
            anchors.centerIn: parent; color: "#CC000000"; radius: 8; z: 10
            width: errorText.width + 40; height: errorText.height + 20
            visible: (videoLoader.item !== null) ? (videoLoader.item.status === Video.InvalidMedia && !videoPage.isSeeking) : false
            Text { id: errorText; anchors.centerIn: parent; color: "white"; font.pixelSize: 18; text: qsTr("Ошибка воспроизведения") }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (spinner.visible) return;
                controlsOverlay.visible = !controlsOverlay.visible;
                if (controlsOverlay.visible && videoPage.isPlaying) controlsTimer.restart();
                else controlsTimer.stop();
            }
            onDoubleClicked: {
                if (spinner.visible || videoPage.isSeeking || !videoLoader.item) return;
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

        Item {
            id: controlsOverlay
            anchors.fill: parent
            visible: true
            Timer { id: controlsTimer; interval: 3000; onTriggered: controlsOverlay.visible = false }

            Rectangle { anchors.fill: parent; color: "#66000000" }

            SafeImage {
                anchors.centerIn: parent; width: 64; height: 64
                source: videoPage.isPlaying ? "../Assets/player/pause.png" : "../Assets/player/play.png"
                visible: videoPage.pendingSeekSeconds === 0 && !videoPage.isSeeking && (videoLoader.item !== null ? videoLoader.item.status !== Video.Loading : true)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!videoLoader.item) return;
                        if (videoPage.isPlaying) videoLoader.item.pause(); else videoLoader.item.play();
                        controlsTimer.restart();
                    }
                }
            }

            Image {
                id: qualityIcon
                source: "../Assets/player/settings.png"
                width: 32; height: 32
                anchors.top: parent.top; anchors.right: parent.right
                anchors.margins: 16
                visible: videoPage.pendingSeekSeconds === 0 && !videoPage.isSeeking && (videoLoader.item !== null ? videoLoader.item.status !== Video.Loading : true)
                opacity: 0.8
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        controlsTimer.stop();
                        qualitySheet.state = "visible";
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom; width: parent.width; height: 40; color: "#B3000000"
                visible: videoPage.pendingSeekSeconds === 0 && !videoPage.isSeeking && (videoLoader.item !== null ? videoLoader.item.status !== Video.Loading : false)

                Item {
                    id: fullscreenBtnItem
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 50; height: parent.height // Создаем огромную зону для пальца (50x40 пикселей)
                    z: 10 // Гарантируем, что панель под ней не перехватит клик

                    Image {
                        id: fullscreenBtn
                        anchors.centerIn: parent
                        width: 24; height: 24
                        source: root.isFullscreen ? "../Assets/player/exit_fullscreen.png" : "../Assets/player/fullscreen.png"
                        opacity: 0.8
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!videoLoader.item) return;
                            controlsTimer.restart();

                            // Мгновенное переключение! Никаких пауз и черных экранов.
                            if (root.isFullscreen) {
                                root.forceFullscreen = 1; // Выйти в окно
                            } else {
                                root.forceFullscreen = 2; // В полный экран
                            }
                        }
                    }
                }


                MouseArea { anchors.fill: parent; z: -1; onClicked: controlsTimer.restart() }

                Text {
                    id: currentTimeText
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 10
                    color: "white"; font.pixelSize: 14
                    text: formatTime(videoPage.uiPosition)
                }

                Text {
                    id: totalTimeText
                    // СТАЛО:
                    anchors.right: fullscreenBtnItem.left; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 5

                    color: "white"; font.pixelSize: 14
                    text: (videoLoader.item && videoLoader.item.duration > 0) ? formatTime(videoLoader.item.duration) : "0:00"
                }

                Item {
                    anchors.left: currentTimeText.right; anchors.right: totalTimeText.left
                    anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 10; anchors.rightMargin: 10; height: 30

                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 4; color: "#444444"; radius: 2 }

                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; height: 4; color: "#888888"; radius: 2
                        width: (videoLoader.item && videoLoader.item.bufferProgress !== undefined) ? videoLoader.item.bufferProgress * parent.width : 0
                    }

                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; height: 4; color: "red"; radius: 2
                        width: (videoLoader.item && videoLoader.item.duration > 0) ? (videoPage.isUserDraggingSlider ? videoPage.sliderDragRatio : (videoPage.uiPosition / videoLoader.item.duration)) * parent.width : 0
                    }

                    Rectangle {
                        width: 16; height: 16; radius: 8; color: "red"
                        anchors.verticalCenter: parent.verticalCenter
                        x: ((videoLoader.item && videoLoader.item.duration > 0) ? (videoPage.isUserDraggingSlider ? videoPage.sliderDragRatio : (videoPage.uiPosition / videoLoader.item.duration)) * parent.width : 0) - 8
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
                            if (!videoPage.isUserDraggingSlider || !videoLoader.item) return;
                            videoPage.isUserDraggingSlider = false;
                            var targetPos = videoPage.sliderDragRatio * videoLoader.item.duration;
                            videoLoader.item.performSafeSeek(targetPos);
                            controlsTimer.restart();
                        }
                    }
                }
            }



        }


        Rectangle {
            id: volumeOsd
            width: 8
            height: 150
            // Позиционируем слева или справа (выбрал слева для примера)
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: "#66000000" // Темный полупрозрачный фон
            opacity: 0 // Скрыт по умолчанию

            Timer {
                id: volumeOsdTimer
                interval: 2000 // Исчезает через 2 секунды
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

            // Белая полоска-индикатор уровня
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                radius: 4
                color: "white"
                // Вычисляем высоту в зависимости от громкости (0-100)
                height: typeof VolumeKeys !== "undefined" ? (parent.height * (VolumeKeys.volume / 100.0)) : parent.height

                // Добавляем плавность изменения самого уровня
                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
            }
        }

        // ИСПРАВЛЕНИЕ: Безопасные проверки для спиннера
        SafeImage {
            id: spinner
            anchors.centerIn: parent; z: 100
            source: "../Assets/player/reload.png"
            width: 48; height: 48
            visible: {
                if (videoPage.isSeeking) return true;
                if (videoLoader.item === null) return true;
                var st = videoLoader.item.status;
                return (st === Video.Loading || st === Video.Buffering || st === Video.Stalled);
            }
            NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible }
        }
    }

    // --- ОСНОВНОЙ КОНТЕНТ (СПИСОК) ---
    ListView {
        id: mainList
        anchors.top: playerContainer.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.isFullscreen

        snapMode: ListView.NoSnap
        highlightMoveDuration: 0
        cacheBuffer: 1000

        // --- ИСПРАВЛЕНИЕ: Четкая структура Header'а, чтобы ListView не путался ---
        header: Column {
            id: contentColumn
            width: mainList.width
            spacing: 0

            // Название
            Item {
                width: parent.width; height: titleText.height + 32
                Text {
                    id: titleText; x: 16; y: 16; width: parent.width - 32
                    text: videoDetails ? (videoDetails["title"] || qsTr("Загрузка...")) : ""
                    color: "white"; font.pixelSize: 18; font.bold: true
                    wrapMode: Text.WordWrap; font.family: "Nokia Pure Text"
                }
            }

            // Просмотры
            Text { x: 16; text: videoDetails ? ((videoDetails["views"] || "0") + qsTr(" просмотров")) : ""; color: "gray"; font.pixelSize: 14 }

            // Автор
            Item {
                width: parent.width; height: 60
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var channelId = videoDetails["channel_custom_url"];
                        if (channelId) root.navigateToChannel(channelId);
                    }
                }
                Row {
                    x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    Rectangle {
                        width: 40; height: 40; radius: 20; color: "#333"; clip: true
                        SafeImage { anchors.fill: parent; source: videoDetails && videoDetails["channel_thumbnail"] ? "image://rounded/" + encodeURIComponent(videoDetails["channel_thumbnail"]) : "../Assets/placeholder.png"; fillMode: Image.PreserveAspectCrop }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: videoPage.width - 100
                        Text {
                            text: videoDetails ? (videoDetails["author"] || qsTr("Неизвестно")) : ""; color: "white"; font.pixelSize: 16; font.bold: true
                            font.family: "Nokia Pure Text"; width: parent.width; elide: Text.ElideRight
                        }
                        Text { text: videoDetails ? (videoDetails["subscriberCount"] || "") + qsTr(" подписчиков") : ""; color: "gray"; font.pixelSize: 12 }
                    }
                }
            }

            // Краткое описание
            Item {
                width: parent.width; height: 96 // Отступы + высота (80 + 16)
                Rectangle {
                    x: 16; width: parent.width - 32; height: 80
                    color: "#272727"; radius: 12; clip: true
                    Text {
                        x: 12; y: 12; width: parent.width - 24; height: 56
                        text: videoDetails ? (videoDetails["description"] || qsTr("Нет описания")) : ""
                        color: "white"; font.pixelSize: 14; wrapMode: Text.WordWrap; elide: Text.ElideRight; font.family: "Nokia Pure Text"
                    }
                    MouseArea { anchors.fill: parent; onClicked: descriptionSheet.state = "visible" }
                }
            }

            // Заголовок похожих видео (Обернут в Item для стабильности высоты)
            Item {
                width: parent.width; height: 40
                Text {
                    x: 16; y: 8; text: qsTr("Похожие видео")
                    color: "white"; font.pixelSize: 18; font.bold: true
                    font.family: "Nokia Pure Text"
                    visible: relatedVideos.length > 0
                }
            }
        }

        // Данные и делегат списка
        model: relatedVideos
        delegate: VideoCard {
            modelData: model.modelData
            onClicked: {
                root.navigateToVideo(videoId)
            }
        }
    }

    // --- Шторка описания ---
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
                    Text { text: qsTr("Описание"); color: "white"; font.pixelSize: 18; font.bold: true }
                    Flickable {
                        width: parent.width; height: parent.height - 60
                        contentWidth: width; contentHeight: descriptionText.height; clip: true
                        Text {
                            id: descriptionText; width: parent.width
                            text: videoDetails ? (videoDetails["description"] || qsTr("Нет описания")) : ""
                            color: "white"; font.pixelSize: 16; wrapMode: Text.WordWrap; font.family: "Nokia Pure Text"
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: qualitySheet
        anchors.fill: parent; color: "#E6000000"; visible: state === "visible"; z: 20
        state: "hidden"
        states:[
            State { name: "visible"; PropertyChanges { target: qualityPanel; y: root.height - qualityPanel.height } },
            State { name: "hidden"; PropertyChanges { target: qualityPanel; y: root.height } }
        ]
        transitions: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad } }
        MouseArea {
            anchors.fill: parent;
            onClicked: {
                qualitySheet.state = "hidden";
                if (videoPage.isPlaying) controlsTimer.restart();
            }
        }

        Rectangle {
            id: qualityPanel
            width: parent.width; height: 280
            anchors.bottom: parent.bottom; color: "#282828"
            MouseArea { anchors.fill: parent } // Блокируем клики сквозь панель
            Item {
                anchors.fill: parent; anchors.margins: 16
                Column {
                    anchors.fill: parent; spacing: 10
                    Rectangle { width: 40; height: 5; radius: 2.5; color: "gray"; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: qsTr("Качество видео"); color: "white"; font.pixelSize: 18; font.bold: true; font.family: "Nokia Pure Text" }

                    ListView {
                        width: parent.width; height: parent.height - 40
                        model: videoDetails ? videoDetails["qualities"] : []
                        clip: true

                        delegate: Rectangle {
                            width: parent.width; height: 40
                            color: videoPage.currentVideoUrl === modelData.url ? "#333333" : "transparent"
                            radius: 5

                            Text {
                                text: modelData.label + (modelData.hasAudio ? "" : " (без звука)")
                                color: videoPage.currentVideoUrl === modelData.url ? "#007ACC" : "white"
                                font.pixelSize: 16
                                font.bold: videoPage.currentVideoUrl === modelData.url
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: 10
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    qualitySheet.state = "hidden";
                                    videoPage.changeQuality(modelData.url);
                                    if (videoPage.isPlaying) controlsTimer.restart();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
