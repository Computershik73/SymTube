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

    property bool showPlayIcon: false
    property string currentVideoUrl: ""
    property int recoveryAttempts: 0
    property int recoveryPosition: -1
    property bool isSeeking: false


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
            if (shortsList.length > 0) {
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

            var directUrl = Config.getVideoUrl(currentVideoDetails.video_id, "360").replace("https://", "http://").replace("yt.swlbst.ru", "yt.modyleprojects.ru");

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
        ApiManager.getVideoInfo(currentShortInfo.video_id);

        if (currentIndex >= shortsList.length - 2 && sequenceToken !== "" && !isLoading) {
            isLoading = true;
            ApiManager.getShorts(sequenceToken);
        }
    }

    // --- 1. ШАБЛОН ПЛЕЕРА ---
    Component {
        id: videoComponent
        Video {

            property int lastIntendedPosition: -1
            anchors.fill: parent
            fillMode: Video.PreserveAspectCrop
            source: shortsPage.currentVideoUrl
            volume: typeof VolumeKeys !== "undefined" ? (VolumeKeys.volume / 100.0) : 1.0
            onResumed: { shortsPage.isSeeking = false; shortsPage.isPlaying = true; shortsPage.recoveryAttempts = 0; }
            onStarted: { shortsPage.isSeeking = false; shortsPage.isPlaying = true; shortsPage.recoveryAttempts = 0; }
            onPaused: shortsPage.isPlaying = false
            onStopped: { shortsPage.isPlaying = false; shortsPage.isSeeking = false; uiOverlay.visible = true; }

            onPositionChanged: {
                // Если мы играем и длительность известна
                if (shortsPage.isPlaying && duration > 0) {
                    // Если до конца осталось меньше 100 миллисекунд
                    if (position >= duration - 500) {
                        console.log("Бесшовный луп!");
                        position = 0;
                    }
                }
            }


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
                //if (errorString.indexOf("-36") !== -1 && shortsPage.recoveryAttempts < 3) {
                shortsPage.recoveryAttempts++;
                shortsPage.recoveryPosition = (lastIntendedPosition !== -1) ? lastIntendedPosition : position;
                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
                /* } else {
                    //shortsPage.isSeeking = false;
                    shortsPage.isPlaying = false;
                    shortsPage.recoveryPosition = -1;
                }*/
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

    // --- 2. ЗАГРУЗЧИК ПЛЕЕРА (Самый нижний слой) ---
    Loader {
        id: videoLoader
        anchors.fill: parent
        //z: 0 // Лежит на дне
    }

    // --- 3. ИНТЕРФЕЙС ПОВЕРХ ПЛЕЕРА (Верхний слой) ---
    Item {
        id: uiOverlay
        anchors.fill: parent
        //z: 10 // Лежит поверх плеера! Никакого моргания.

        // --- ИСПРАВЛЕНИЕ: Спиннер с безопасной проверкой на null ---
        Image {
            id: spinner
            anchors.centerIn: parent
            source: "../Assets/player/reload.png"
            width: 48; height: 48
            //z: 100
            visible: {
                if (shortsPage.isLoading) return true;
                if (videoLoader.item === null) return true;
                var st = videoLoader.item.status;

                return (st === Video.Loading);
            }
            NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible }
        }

        // Ошибка
        Rectangle {
            anchors.centerIn: parent; color: "#CC000000"; radius: 8;
            //z: 100
            width: errorText.width + 40; height: errorText.height + 20
            visible: {
                if (videoLoader.item === null) return false;
                var st = videoLoader.item.status;
                return (st === Video.InvalidMedia || st === Video.NoMedia);
            }
            Text { id: errorText; anchors.centerIn: parent; color: "white"; font.pixelSize: 18; text: qsTr("Ошибка воспроизведения") }
        }

        // Управление свайпами и паузой
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
                    // --- ИСПРАВЛЕНИЕ: Клик работает всегда ---
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

        // Иконка Play/Pause по центру
        Image {
            id: playPauseIcon
            anchors.centerIn: parent
            width: 64; height: 64
            source: isPlaying ? "../Assets/player/pause.png" : "../Assets/player/play.png"
            opacity: 0.8
            // ИСПРАВЛЕНИЕ: Безопасное условие видимости
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

        // Индикатор громкости OSD
        // --- ИНДИКАТОР ГРОМКОСТИ (iOS Style) ---
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

        // Прогрессбар снизу
        Rectangle {
            anchors.bottom: parent.bottom; width: parent.width; height: 4
            color: "#66FFFFFF";
            //z: 10
            Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                color: "white"
                // ИСПРАВЛЕНИЕ: Безопасный расчет ширины
                width: (videoLoader.item !== null && videoLoader.item.duration > 0) ? (videoLoader.item.position / videoLoader.item.duration) * parent.width : 0
            }
        }

        // Инфо снизу слева (Название, Автор)
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
                                if (!currentVideoDetails || !currentVideoDetails.channel_thumbnail) return "";

                                var originalUrl = currentVideoDetails["channel_thumbnail"];
                                var parts = originalUrl.split("channel_icon/");

                                if (parts.length < 2) return "";

                                // Базовая часть (меняем https на http для обхода ошибки SSL на Symbian)
                                var baseUrl = parts[0].replace("https://", "http://") + "channel_icon/";

                                // 1. Декодируем вторую часть ссылки (дважды, чтобы гарантированно снять все наслоения %25)
                                var cleanTail = decodeURIComponent(decodeURIComponent(parts[1]));

                                // 2. Энкодим её один раз
                                var encodedTail = encodeURIComponent(cleanTail);

                                // 3. Полученный результат передаем далее как строку
                                var fullString = baseUrl + encodedTail;

                                // 4. Энкодим ещё раз и передаем в провайдер
                                return "image://rounded/" + encodeURIComponent(fullString);
                            }


                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: currentVideoDetails ? (currentVideoDetails["author"] || "") : ""
                        color: "white"; font.pixelSize: 16; font.bold: true
                        font.family: "Nokia Pure Text"
                    }
                }
            }

            Text {
                text: currentShortInfo ? currentShortInfo.title : ""
                color: "white"; font.pixelSize: 14; width: parent.width
                wrapMode: Text.WordWrap; elide: Text.ElideRight; clip: true
                height: 38
                font.family: "Nokia Pure Text"
            }
        }

        // Кнопки справа (Лайк, Дизлайк, Комменты, Поделиться)
        Column {
            id: rightButtons
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 16; anchors.bottomMargin: 30; spacing: 20

            Column {
                spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                Image { source: "../Assets/player/like.png"; width: 32; height: 32; MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentVideoId, "like") } }
                Text { text: currentVideoDetails ? (currentVideoDetails["likes"] || qsTr("Лайк")) : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }
            Image { source: "../Assets/player/dislike.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter; MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentVideoId, "dislike") } }
            Column {
                spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                Image { source: "../Assets/player/comments.png"; width: 32; height: 32; MouseArea { anchors.fill: parent; onClicked: commentsSheet.state = "visible" } }
                Text { text: currentVideoDetails ? (currentVideoDetails["comment_count"] || "0") : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }
            Image { source: "../Assets/player/send.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // Шторка с комментариями
        Rectangle {
            id: commentsSheet
            anchors.fill: parent; color: "#E6000000"; visible: state === "visible";
            //z: 50
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
                        Text { text: qsTr("Комментарии"); color: "white"; font.pixelSize: 18; font.bold: true }
                        Flickable {
                            width: parent.width; height: parent.height - 40
                            contentWidth: width; contentHeight: commentsText.height; clip: true
                            Text {
                                id: commentsText; width: parent.width
                                text: qsTr("Функция комментариев в разработке...")
                                color: "white"; font.pixelSize: 14; wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
