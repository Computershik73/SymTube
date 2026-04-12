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

    Connections {
        target: ApiManager

        // Получили список Shorts
        onShortsReady: {
            isLoading = false;
            sequenceToken = seqToken;

            if (shortsList.length > 0) {
                // Добавляем новые шортсы к старым (бесконечная лента)
                var combined = shortsPlayer.shortsList;
                for (var i=0; i<shortsList.length; i++) {
                    combined.push(shortsList[i]);
                }
                shortsPlayer.shortsList = combined;

                // Если это первая загрузка - запускаем первое видео
                if (currentIndex === 0 && !currentShortInfo) {
                    loadCurrentShort();
                }
            }
        }

        // Получили ссылку на MP4 файл для текущего шортса
        onVideoInfoReady: {

            if (currentShortInfo && videoDetailsMap.video_id !== currentShortInfo.video_id) {
                return; // Игнорируем старые ответы, если пользователь быстро листал
            }
            console.log("Получили инфо для видео: " + videoDetailsMap.video_id);
            // Устанавливаем детали, что автоматически обновит UI
            currentVideoDetails = videoDetailsMap;

            // --- ПРИНУДИТЕЛЬНЫЙ ВЫЗОВ ПЛЕЕРА ---


            var directUrl = Config.getVideoUrl(currentVideoDetails.video_id, "360").replace("https", "http").replace("yt.swlbst.ru", "yt.modyleprojects.ru");

            if (videoPlayer.source.toString() !== directUrl) {
                console.log("Установка нового URL для Shorts: " + directUrl);
                videoPlayer.stop();
                videoPlayer.source = directUrl;
                videoPlayer.play();
            } else {
                // Если URL тот же, просто убеждаемся, что он играет
                if (videoPlayer.status === Video.Loaded) videoPlayer.play();
            }
        }
    }

    function startPlaying() {
        if (shortsList.length === 0 && !isLoading) {
            isLoading = true;
            ApiManager.getShorts(""); // Запрашиваем первую партию
        } else if (currentShortInfo && !isPlaying) {
            videoPlayer.play();
        }
    }

    function stopVideo() {
        videoPlayer.stop();
        videoPlayer.source = "";
        isPlaying = false;
    }

    // Загрузка шортса по индексу
    function loadCurrentShort() {
        if (currentIndex < 0 || currentIndex >= shortsList.length) {
            console.log("Ошибка: индекс вне границ: " + currentIndex);
            return;
        }

        var videoId = shortsList[currentIndex].video_id;
        console.log("Загружаем видео ID: " + videoId);
        if (videoPlayer.source !== "") {
            //videoPlayer.stop();
            //videoPlayer.source = "";
        }
        ApiManager.getVideoInfo(videoId);

        // Подгрузка следующей страницы, если осталось 2 видео
        if (currentIndex >= shortsList.length - 2 && sequenceToken !== "" && !isLoading) {
            isLoading = true;
            ApiManager.getShorts(sequenceToken); // sequenceToken здесь БЕЗ кодирования
        }
    }

    // --- ПЛЕЕР ---
    Video {
        id: videoPlayer
        anchors.fill: parent
        // Важно: Crop обрежет края, чтобы вертикальное видео заняло весь экран
        fillMode: Video.PreserveAspectCrop
        onResumed: isPlaying = true
        onStarted: isPlaying = true
        onPaused: isPlaying = false
        onStopped: isPlaying = false
        volume: 1.0
        source: ""

        onStatusChanged: {
            // Зацикливаем видео
            if (status === Video.EndOfMedia) {
                //videoPlayer.position = 0;
                //videoPlayer.play();
            }
            if (status === Video.InvalidMedia) {
                console.log("--- КРИТИЧЕСКАЯ ОШИБКА ---");
                console.log("URL плеера: " + videoPlayer.source);
                console.log("Ошибка: " + videoPlayer.errorString);
            }
        }
        onError: {
            console.log("Video Error [" + error + "]: " + errorString);
            console.log("Video Error URL: " + videoPlayer.source);

            // Если это ошибка перемотки и мы не в процессе восстановления
            /* if (errorString.indexOf("-36") !== -1 && playerContainer.recoveryAttempts < 3) {
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
            }*/
        }
    }

    // Спиннер загрузки
    Image {
        id: spinner
        anchors.centerIn: parent
        source: "../Assets/player/reload.png"
        width: 48; height: 48
        visible: isLoading || videoPlayer.status === Video.Loading || videoPlayer.status === 7 // Buffering
        NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible }
    }

    // --- УПРАВЛЕНИЕ СВАЙПАМИ ---
    MouseArea {
        anchors.fill: parent
        property int startY: 0

        onPressed: {
            startY = mouse.y;
            // Если тапнули по экрану, а не свайпали - пауза/плей
            clickTimer.start();
        }

        onReleased: {
            clickTimer.stop();
            var dy = mouse.y - startY;

            if (dy < -100) {
                // Свайп ВВЕРХ (Следующее видео)
                if (currentIndex < shortsList.length - 1) {
                    currentIndex++;
                    loadCurrentShort();
                }
            } else if (dy > 100) {
                // Свайп ВНИЗ (Предыдущее видео)
                if (currentIndex > 0) {
                    currentIndex--;
                    loadCurrentShort();
                }
            }
        }

        Timer {
            id: clickTimer
            interval: 200
            onTriggered: {
                if (isPlaying) videoPlayer.pause();
                else videoPlayer.play();
            }
        }
    }

    // Иконка паузы по центру
    Image {
        anchors.centerIn: parent
        width: 64; height: 64
        source: "../Assets/player/play.png"
        visible: !isPlaying && videoPlayer.status === Video.Loaded
    }

    // --- ИНТЕРФЕЙС ПОВЕРХ ВИДЕО ---

    // Инфо снизу слева (Название, Автор)
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 16
        anchors.right: rightButtons.left // Не заезжаем на кнопки
        spacing: 8

        Row {
            spacing: 8
            Rectangle {
                width: 32; height: 32; radius: 16; color: "#333"; clip: true
                SafeImage {
                    anchors.fill: parent;
                    source: currentVideoDetails ? ("http://yt.modyleprojects.ru/channel_icon/"+currentVideoDetails["video_id"]) : "";
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

        Text {
            text: currentShortInfo ? currentShortInfo.title : ""
            color: "white"; font.pixelSize: 14
            width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideRight
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

        // Лайк
        Column {
            spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
            Image {
                source: "../Assets/player/like.png"; width: 32; height: 32
                MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentVideoId, "like") }
            }
            Text { text: currentVideoDetails ? (currentVideoDetails["likes"] || "Лайк") : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // Дизлайк
        Image {
            source: "../Assets/player/dislike.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter
            MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentVideoId, "dislike") }
        }

        // Комментарии
        Column {
            spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
            Image {
                source: "../Assets/player/comments.png"; width: 32; height: 32 // НУЖНО ДОБАВИТЬ ЭТУ ИКОНКУ!
                MouseArea { anchors.fill: parent; onClicked: commentsSheet.state = "visible" }
            }
            Text { text: currentVideoDetails ? (currentVideoDetails["comment_count"] || "0") : ""; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // Поделиться
        Image {
            source: "../Assets/player/send.png"; width: 32; height: 32; anchors.horizontalCenter: parent.horizontalCenter
            MouseArea { anchors.fill: parent; /* Логика "Поделиться" */ }
        }
    }

    // --- ВЫЕЗЖАЮЩАЯ ШТОРКА С КОММЕНТАРИЯМИ ---
    Rectangle {
        id: commentsSheet
        anchors.fill: parent; color: "#E6000000"; visible: state === "visible"; z: 50
        state: "hidden"
        states:[
            State { name: "visible"; PropertyChanges { target: commentsPanel; y: root.height - commentsPanel.height } },
            State { name: "hidden"; PropertyChanges { target: commentsPanel; y: root.height } }
        ]
        transitions: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad } }
        MouseArea { anchors.fill: parent; onClicked: commentsSheet.state = "hidden" }

        Rectangle {
            id: commentsPanel
            width: parent.width; height: root.height * 0.65 // На 65% экрана
            anchors.bottom: parent.bottom; color: "#282828"

            MouseArea { anchors.fill: parent } // Блокируем клики сквозь панель

            Item {
                anchors.fill: parent; anchors.margins: 16
                Column {
                    anchors.fill: parent; spacing: 10
                    Rectangle { width: 40; height: 5; radius: 2.5; color: "gray"; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "Комментарии"; color: "white"; font.pixelSize: 18; font.bold: true }

                    // Заглушка. Чтобы вывести реальные комментарии, нужно извлечь их из currentVideoDetails["comments"]
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
