import QtQuick 1.0
import QtMultimediaKit 1.1

Rectangle {
    id: videoPage
    anchors.fill: parent
    color: "black"

    property string currentVideoId: ""
    property variant videoDetails: null
    property bool isPlaying: false

    Connections {
        target: ApiManager
        onVideoInfoReady: {
            videoDetails = videoDetailsMap;



            HistoryManager.addToHistory({
                                        "video_id": videoDetails.video_id, "title": videoDetails.title,
                                        "author": videoDetails.author, "thumbnail": videoDetails.thumbnail
        });
            var directUrl = Config.getVideoUrl(videoDetails.video_id, "360").replace("https", "http");
            videoPlayer.source = directUrl;
            videoPlayer.play();
        }

        onAuthImageReady: {
                channelIcon.visible = true;
                // Трюк для обновления
                var temp = channelIcon.source;
                channelIcon.source = "";
                channelIcon.source = "image://qr/auth";
            }
    }

    function loadVideo(videoId) {
        currentVideoId = videoId;
        videoDetails = null;
        videoPlayer.stop(); videoPlayer.source = "";
        ApiManager.getVideoInfo(videoId);
    }

    function getValidIconUrl(url) {
        if (!url) return "";

        // 1. Декодируем все, чтобы избавиться от любых слоев %25, %3A и т.д.
        var decoded = decodeURIComponent(url);

        // 2. Теперь кодируем один раз (все : / ? станут безопасными для URL)
        // Но! Сервер ожидает channel_icon/https%3A...
        // Поэтому мы кодируем только часть после channel_icon/
        var prefix = "channel_icon/";
        var index = decoded.indexOf(prefix);

        if (index !== -1) {
            var baseUrl = decoded.substring(0, index + prefix.length);
            var path = decoded.substring(index + prefix.length);
            return baseUrl + encodeURIComponent(path);
        }
        return url;
    }
	
    // Функция для однократного декодирования части ссылки
    function getSingleEncodedUrl(fullUrl) {
        if (!fullUrl) return "";

        var prefix = "channel_icon/";
        var index = fullUrl.indexOf(prefix);

        // Если префикса нет, возвращаем как есть
        if (index === -1) return fullUrl;

        var baseUrl = fullUrl.substring(0, index + prefix.length);
        var encodedPart = fullUrl.substring(index + prefix.length);

        // Заменяем все вхождения %25 на % (декодируем один уровень)
        // Глобальная замена через регулярное выражение
        var fixedPart = encodedPart.replace(/%25/g, "%");

        // Для отладки:
        console.log("Original: " + encodedPart);
        console.log("Fixed: " + fixedPart);

        return baseUrl + fixedPart;
    }

        function getEncodedIconUrl(rawUrl) {
    if (!rawUrl) return "";
    // 1. Декодируем всё, чтобы получить чистый URL (http://...)
    // 2. Кодируем один раз (все : / ? будут заменены на %3A %2F и т.д.)
    return encodeURIComponent(decodeURIComponent(rawUrl));
        }

    Rectangle {
        id: playerContainer
        width: parent.width; height: parent.width * 0.5625
        anchors.top: parent.top; color: "black"

        Video {
            id: videoPlayer
            anchors.fill: parent; fillMode: Video.Stretch
            onStarted: isPlaying = true; onResumed: isPlaying = true; onPaused: isPlaying = false; onStopped: isPlaying = false
            MouseArea { anchors.fill: parent; onClicked: { if (isPlaying) videoPlayer.pause(); else videoPlayer.play(); } }
        }

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

        Rectangle {
            anchors.bottom: parent.bottom; width: parent.width; height: 30; color: "#80000000"
            visible: videoPlayer.status === Video.Loaded || videoPlayer.status === Video.Playing || videoPlayer.status === Video.Paused
            Text {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 10
                color: "white"; font.pixelSize: 12
                text: Math.floor(videoPlayer.position / 1000) + " / " + (videoPlayer.duration > 0 ? Math.floor(videoPlayer.duration / 1000) : "-1") + " сек"
            }
        }
    }

    // Основной контент
    Flickable {
        id: contentFlickable
        anchors.top: playerContainer.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        contentWidth: parent.width
        contentHeight: contentColumn.height + 40 // Запас для прокрутки
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            spacing: 0

            // 1. Заголовок (отступ 16)
            Item { width: parent.width; height: titleText.height + 32
                Text {
                    id: titleText
                    x: 16; y: 16; width: parent.width - 32
                    text: videoDetails ? (videoDetails["title"] || "Загрузка...") : ""
                    color: "white"; font.pixelSize: 18; font.bold: true
                    wrapMode: Text.WordWrap; font.family: "Nokia Pure Text"
                }
            }

            // 2. Просмотры
            Text {
                x: 16; text: videoDetails ? ((videoDetails["views"] || "0") + " просмотров") : ""; color: "gray"; font.pixelSize: 14
            }

            // 3. Автор и аватарка (Grid для выравнивания)
            Item {
                width: parent.width; height: 60
                
                Row {
                    x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    
                    Rectangle {
                        width: 40; height: 40; radius: 20; color: "#333"; clip: true
                        Image {
                            id: channelIcon
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: videoDetails ? (videoDetails["channel_thumbnail"] || "") : ""
                            visible: false
                        }
                    }
                    Text { 
                        anchors.verticalCenter: parent.verticalCenter
                        text: videoDetails ? (videoDetails["author"] || "") : ""; color: "white"; font.pixelSize: 16; font.bold: true
                        font.family: "Nokia Pure Text"
                    }
                }
            }

            // 4. Краткое описание (Свернутое)
            Item {
                x: 16; width: parent.width - 32; height: 80
                
                Rectangle {
                    anchors.fill: parent
                    color: "#272727"; radius: 12; clip: true
                    
                    Text {
                        anchors.fill: parent; anchors.margins: 12
                        text: videoDetails ? (videoDetails["description"] || "Нет описания") : ""
                        color: "white"; font.pixelSize: 14; wrapMode: Text.WordWrap
                        font.family: "Nokia Pure Text"
                    }
                    MouseArea { anchors.fill: parent; onClicked: descriptionSheet.state = "visible" }
                }
            }
        }
    }

    // --- Шторка (BOTTOM SHEET) ДЛЯ ПОЛНОГО ОПИСАНИЯ ---
    Rectangle {
        id: descriptionSheet
        anchors.fill: parent
        color: "#E6000000"
        visible: state === "visible"
        z: 20

        state: "hidden"
        states: [
            State { name: "visible"; PropertyChanges { target: descriptionPanel; y: root.height - descriptionPanel.height } },
            State { name: "hidden"; PropertyChanges { target: descriptionPanel; y: root.height } }
        ]
        transitions: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad } }

        MouseArea { anchors.fill: parent; onClicked: descriptionSheet.state = "hidden" }

        Rectangle {
                    id: descriptionPanel
                    width: parent.width; height: root.height * 0.75
                    anchors.bottom: parent.bottom; color: "#282828"

                    // Item служит контейнером с отступами (вместо padding)
                    Item {
                        anchors.fill: parent
                        anchors.margins: 16

                        Column {
                            anchors.fill: parent
                            spacing: 10

                            // Ручка для перетаскивания
                            Rectangle {
                                width: 40; height: 5; radius: 2.5; color: "gray"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Заголовок
                            Text {
                                text: "Описание"
                                color: "white"
                                font.pixelSize: 18
                                font.bold: true
                            }

                            // Область описания
                            Flickable {
                                width: parent.width
                                // Вычисляем высоту: вся высота колонки минус высота заголовка и ручки (прим. 60px)
                                height: parent.height - 60
                                contentWidth: width
                                contentHeight: descriptionText.height
                                clip: true

                                Text {
                                    id: descriptionText
                                    width: parent.width
                                    text: videoDetails ? (videoDetails["description"] || "") : ""
                                    color: "white"; font.pixelSize: 16; wrapMode: Text.WordWrap
                                    font.family: "Nokia Pure Text"
                                }
                            }
                        }
                    }
                }
    }
}
