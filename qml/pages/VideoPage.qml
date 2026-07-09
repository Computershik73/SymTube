import QtQuick 1.1
import QtMultimediaKit 1.1
import "../components"

Rectangle {
    id: videoPage
    color: "black"

    property string currentVideoId: ""

    property string currentPlaylistId: ""
    property variant playlistVideos: []
    property int currentPlaylistIndex: -1
    property string playlistTitle: ""

    property variant videoDetails: null
    property bool isPlaying: false
    property variant relatedVideos:[]
    property variant commentsModel:[]
    property variant firstComment: null

    property bool isSeeking: false
    property bool isLandscape: width > height

    property string currentVideoUrl: ""
    property int recoveryPosition: -1
    property int pendingSeekSeconds: 0
    property bool isUserDraggingSlider: false
    property real sliderDragRatio: 0.0
    property int recoveryAttempts: 0
    property bool isVideoEnded: false
    property bool hasAttemptedPipedFallback: false
    property string lastPlaySourceType: "youtube"
    property variant pendingQualities: null

    property int uiPosition: 0

    focus: true

    Component.onCompleted: {
        videoPage.forceActiveFocus();
    }

    Timer {
        id: stallWatchdog
        interval: 12000; repeat: false
        onTriggered: {
            console.log("[Watchdog] Поток завис, переключаю источник");
            videoPage.isSeeking = false;
            handlePlaybackFailure();
        }
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_Space) {
            if (videoLoader.item) {
                if (isPlaying) videoLoader.item.pause();
                else videoLoader.item.play();
            }
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Right) {
            // Перемотка вперед на 10 секунд
            if (videoLoader.item) {
                var targetPosForward = videoLoader.item.position + 10000;
                videoLoader.item.performSafeSeek(targetPosForward);
            }
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Left) {
            // Перемотка назад на 10 секунд
            if (videoLoader.item) {
                var targetPosBackward = videoLoader.item.position - 10000;
                videoLoader.item.performSafeSeek(targetPosBackward);
            }
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Up) {
            // Увеличить громкость
            var volUp = Math.min(100, VolumeKeys.volume + 10);
            VolumeKeys.volume = volUp;
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Down) {
            // Уменьшить громкость
            var volDown = Math.max(0, VolumeKeys.volume - 10);
            VolumeKeys.volume = volDown;
            event.accepted = true;
        }
        else if (event.key === Qt.Key_N) {
            // Кнопка N (Next) - следующее видео
            if (currentPlaylistId !== "" && playlistVideos.length > 0) {
                playNextVideo();
            }
            event.accepted = true;
        }
        else if (event.key === Qt.Key_P) {
            // Кнопка P (Previous) - предыдущее видео
            if (currentPlaylistId !== "" && playlistVideos.length > 0) {
                playPreviousVideo();
            }
            event.accepted = true;
        }
    }

    Binding {
        target: CompositorFix
        property: "active"
        value: videoPage.isPlaying
    }

    Timer {
        id: pipedFallbackTimer
        interval: 4000 // 4 секунды на загрузку Piped, далее автоматический откат на YouTube
        repeat: false
        onTriggered: {
            console.log("[Piped] Превышено время ожидания. Автоматический откат на YouTube...");
            playInnerTubeStreamDirectly();
        }
    }

    function playInnerTubeStreamDirectly() {
        if (!videoDetails) return;

        if (!videoDetails.video_url) {
            console.log("[Player] Нет прямого YouTube-URL (бот-блок). Прямое воспроизведение невозможно.");
            return;
        }


        var rawUrl = videoDetails.video_url;
        var isGoogleVideo = rawUrl.indexOf("googlevideo.com") !== -1;
        if (Config.enableProxy && isGoogleVideo) {
            videoPage.currentVideoUrl = "http://127.0.0.1:8081/?url=" + Qt.btoa(rawUrl);
        } else {
            videoPage.currentVideoUrl = rawUrl;
        }

        videoPage.recoveryAttempts = 0;
        videoLoader.sourceComponent = undefined;
        recreateTimer.start();
    }

    Timer {
        id: uiTimer
        interval: 500
        repeat: true
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
                videoPage.recoveryPosition = videoLoader.item.position;
                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
            }
        }
        onInFocus: {
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
        onRequestFailed: {
            if (endpoint === "VideoInfo") {
                console.log("[Player] C++ сообщил об ошибке доступа (403/бот-блок). Срочный запуск Piped...");
                handlePlaybackFailure();
            }
        }
        onVideoInfoReady: {
            // Отбрасываем опоздавшие ответы от предыдущего трека
            if (videoDetailsMap.video_id !== undefined && videoDetailsMap.video_id !== "" &&
                    currentVideoId !== "" && videoDetailsMap.video_id !== currentVideoId) {
                console.log("[Player] Отброшен устаревший videoInfo для " + videoDetailsMap.video_id);
                return;
            }


            var temp = {};
            if (videoDetails) {
                for (var k in videoDetails) {
                    temp[k] = videoDetails[k];
                }
            }
            for (var key in videoDetailsMap) {
                temp[key] = videoDetailsMap[key];
            }

            if (videoDetailsMap.meta_only === undefined) {
                var initialQualities = [{
                                        label: "360p (InnerTube)",
                                        url: temp.video_url,
                                        hasAudio: true
            }];
                temp["qualities"] = initialQualities;
            }

            videoDetails = temp;

            HistoryManager.addToHistory({
                                        "video_id": videoDetails.video_id,
                                        "title": videoDetails.title,
                                        "author": videoDetails.author,
                                        "thumbnail": "https://i.ytimg.com/vi/" + videoDetails.video_id + "/mqdefault.jpg"
        });

            // ИСПРАВЛЕНИЕ: Запускаем фоновые запросы качеств и комментариев только ОДИН раз
            // (при первом получении данных от YouTube). Если метаданные пришли от Piped,
            // этот шаг пропускается во избежание вечного зацикливания сети.
            if (videoDetailsMap.is_piped_meta === undefined && videoDetailsMap.meta_only === undefined) {
                ApiManager.fetchAlternativeQualities(videoDetails.video_id);
                ApiManager.getComments(videoDetails.video_id, "");
            }

            // При meta_only воспроизведение НЕ запускаем: следом придёт requestFailed,
            // и handlePlaybackFailure сам запустит Piped-фолбэк
            if (videoDetailsMap.meta_only === undefined) {
                // Запускаем проигрывание
                if (lastPlaySourceType === "piped") {
                    console.log("[Player] Ожидание потоков Piped...");
                    pipedFallbackTimer.start();
                } else {
                    console.log("[Player] Запуск прямого воспроизведения YouTube...");
                    playInnerTubeStreamDirectly();
                }
            }

            // Вливаем качества, пришедшие раньше метаданных (гонка при бот-блоке).
            // Важно: именно ПОСЛЕ блока запуска — applyQualities остановит
            // pipedFallbackTimer и сразу запустит Piped-поток, если он есть.
            if (pendingQualities !== null) {
                var pq = pendingQualities;
                pendingQualities = null;
                applyQualities(pq);
            }
        }

        onAlternativeQualitiesReady: {
            if (qualities === undefined || qualities === null) {
                    console.log("[Player] alternativeQualitiesReady пришёл без списка качеств, игнорирую");
                    return;
                }
            // videoDetails ещё не создан (бот-блок: качества пришли раньше меты) — буферизуем
            if (!videoDetails || videoId !== videoDetails.video_id) {
                if (videoId === currentVideoId) {
                    pendingQualities = qualities;
                }
                return;
            }
            applyQualities(qualities);
        }

        onCommentsReady: {
            videoPage.commentsModel = comments;
            if (comments.length > 0) {
                videoPage.firstComment = comments[0];
            } else {
                videoPage.firstComment = null;
            }
        }

        onVideoExtraInfoReady: {
            var temp = {}
            if (videoDetails) {
                for (var k in videoDetails) temp[k] = videoDetails[k];
            }
            for (var key in extraDetails) {
                temp[key] = extraDetails[key];
            }
            videoDetails = temp;
        }

        onRelatedVideosReady: {
            if (!videoPage.visible) return;
            relatedVideos = videos;
            mainList.contentY = 0;
        }

        onPlaylistDetailsReady: {
            if (!videoPage.visible) return;

            var incoming = playlistDetails.videos || [];

            if (playlistVideos.length > 0) {
                // Джем уже загружен: YouTube пересортировывает микс вокруг нового
                // якорного видео — порядок НЕ трогаем, только доливаем новые треки
                var existing = {};
                for (var e = 0; e < playlistVideos.length; e++) {
                    existing[playlistVideos[e].video_id] = true;
                }
                var merged = playlistVideos;
                var added = false;
                for (var n = 0; n < incoming.length; n++) {
                    if (!existing[incoming[n].video_id]) {
                        merged.push(incoming[n]);
                        added = true;
                    }
                }
                if (added) playlistVideos = merged; // переприсваивание дёргает биндинги
            } else {
                playlistVideos = incoming;
                playlistTitle = playlistDetails.title || "Playlist";
            }

            if (playlistVideos.length > 0) {
                if (currentVideoId === "") {
                    currentPlaylistIndex = 0;
                    playPlaylistItem(0);
                } else {
                    var idx = -1;
                    for (var i = 0; i < playlistVideos.length; i++) {
                        if (playlistVideos[i].video_id === currentVideoId) {
                            idx = i;
                            break;
                        }
                    }
                    currentPlaylistIndex = idx;
                }
            }
        }
    }

    // Вливает список качеств в videoDetails и, если ждём Piped, запускает его поток
    function applyQualities(qualities) {
        if (!videoDetails || qualities === undefined || qualities === null) return;

        var temp = {};
        for (var k in videoDetails) {
            temp[k] = videoDetails[k];
        }
        var q = temp["qualities"] || [];
        for (var i = 0; i < qualities.length; i++) {
            q.push(qualities[i]);
        }
        temp["qualities"] = q;
        videoDetails = temp;

        // Если активен Piped и плеер ждёт ответа от него
        if (lastPlaySourceType === "piped") {
            if (pipedFallbackTimer.running) {
                pipedFallbackTimer.stop();
            }

            var pipedStreamUrl = "";
            for (var j = 0; j < q.length; j++) {
                if (q[j].label.indexOf("Piped") !== -1 && q[j].hasAudio) {
                    pipedStreamUrl = q[j].url;
                    break;
                }
            }

            if (pipedStreamUrl !== "") {
                console.log("[Player] Piped-поток успешно найден. Запуск...");
                videoPage.currentVideoUrl = pipedStreamUrl;
                videoPage.recoveryAttempts = 0;
                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
            } else {
                console.log("[Player] Piped не вернул рабочих потоков. Запуск отката...");
                handlePlaybackFailure();
            }
        }
    }

    function changeQuality(newUrl) {
        var wrappedUrl;

        // Проверяем, является ли ссылка оригинальным потоком Google Video
        var isGoogleVideo = newUrl.indexOf("googlevideo.com") !== -1;

        // Оборачиваем только оригинальные ссылки Google Video и только если прокси включен
        if (Config.enableProxy && isGoogleVideo) {
            var base64Url = Qt.btoa(newUrl);
            wrappedUrl = "http://127.0.0.1:8081/?url=" + base64Url;
        } else {
            wrappedUrl = newUrl; // Ссылки от Piped/NotPipe отдаются как есть
        }

        if (!videoDetails || currentVideoUrl === wrappedUrl) return;

        var pos = 0;
        if (videoLoader.item) {
            pos = videoLoader.item.position;
            videoLoader.item.stop();
        }
        videoPage.recoveryPosition = pos;
        videoPage.recoveryAttempts = 0;
        videoPage.currentVideoUrl = wrappedUrl;

        videoLoader.sourceComponent = undefined;
        recreateTimer.start();
    }

    function handlePlaybackFailure() {
        if (hasAttemptedPipedFallback) {
            console.log("[Fallback] Обе попытки (YouTube и Piped) провалились. Остановка.");
            videoPage.currentVideoUrl = "";
            videoLoader.sourceComponent = undefined; // убираем вечный спиннер
            videoPage.isSeeking = false;
            return;
        }

        hasAttemptedPipedFallback = true;

        if (lastPlaySourceType === "youtube") {
            lastPlaySourceType = "piped";
            console.log("[Fallback] YouTube заблокирован. Срочный запуск Piped для: " + currentVideoId);

            var pipedStreamUrl = "";
            if (videoDetails && videoDetails["qualities"]) {
                var q = videoDetails["qualities"];
                for (var i = 0; i < q.length; i++) {
                    if (q[i].label.indexOf("Piped") !== -1 && q[i].hasAudio) {
                        pipedStreamUrl = q[i].url;
                        break;
                    }
                }
            }

            if (pipedStreamUrl !== "") {
                videoPage.currentVideoUrl = pipedStreamUrl;
                videoPage.recoveryAttempts = 0;
                videoLoader.sourceComponent = undefined;
                recreateTimer.start();
            } else {
                // ИСПРАВЛЕНИЕ: Принудительно пинаем C++ сделать запрос к Piped,
                // так как YouTube упал раньше, чем QML успел отправить этот запрос!
                ApiManager.fetchAlternativeQualities(currentVideoId);
                pipedFallbackTimer.start();
            }
        }
        else if (lastPlaySourceType === "piped") {
            lastPlaySourceType = "youtube";
            console.log("[Fallback] Ошибка Piped. Возврат на YouTube...");
            playInnerTubeStreamDirectly();
        }
    }

    // ==========================================
    // УНИФИЦИРОВАННЫЙ СБРОС СОСТОЯНИЯ ТРЕКА
    // ==========================================
    function resetTrackState() {
        hasAttemptedPipedFallback = false;
        lastPlaySourceType = Config.usePiped ? "piped" : "youtube";
        pendingQualities = null;
        videoDetails = null;
        relatedVideos = [];
        commentsModel = [];
        firstComment = null;
        videoPage.currentVideoUrl = "";
        videoLoader.sourceComponent = undefined;
        isPlaying = false;
        isSeeking = false;

        pipedFallbackTimer.stop(); // Останавливаем любые запущенные таймеры ожидания
        stallWatchdog.stop();
        videoPage.forceActiveFocus(); // Возвращаем фокус ввода клавиатуры
    }

    // ==========================================
    // МЕТОДЫ ЗАГРУЗКИ И ПЕРЕКЛЮЧЕНИЯ ПОТОКОВ
    // ==========================================
    function loadVideo(videoId, playlistId) {
        currentVideoId = videoId || "";
        currentPlaylistId = playlistId || "";

        // Сбрасываем флаги контроля зацикливания перед каждым новым видео!
        resetTrackState();

        if (currentPlaylistId !== "") {
            // Если это автогенерируемый джем (RD...) — запрашиваем его через getRelatedVideos (next)
            if (currentPlaylistId.indexOf("RD") === 0) {
                playlistVideos = [];
                currentPlaylistIndex = -1;

                if (currentVideoId !== "") {
                    ApiManager.getVideoInfo(currentVideoId);
                }
                ApiManager.getRelatedVideos(currentVideoId, currentPlaylistId);
            } else {
                // Для обычных плейлистов (PL...) используем стандартный browse
                ApiManager.getPlaylistDetails(currentPlaylistId);
                if (currentVideoId !== "") {
                    ApiManager.getVideoInfo(currentVideoId);
                    ApiManager.getRelatedVideos(currentVideoId, currentPlaylistId);
                }
            }
        } else {
            playlistVideos = [];
            currentPlaylistIndex = -1;
            playlistTitle = "";
            ApiManager.getVideoInfo(currentVideoId);
            ApiManager.getRelatedVideos(currentVideoId, "");
        }
    }

    function playPlaylistItem(index) {
        if (index < 0 || index >= playlistVideos.length) return;

        currentPlaylistIndex = index;
        var targetVideo = playlistVideos[index];

        // Сбрасываем флаги контроля зацикливания перед переключением трека внутри плейлиста!
        resetTrackState();
        currentVideoId = targetVideo.video_id;

        ApiManager.getVideoInfo(targetVideo.video_id);
        ApiManager.getRelatedVideos(targetVideo.video_id, currentPlaylistId);
    }

    function playNextVideo() {
        if (playlistVideos.length > 0 && currentPlaylistIndex < playlistVideos.length - 1) {
            playPlaylistItem(currentPlaylistIndex + 1);
        }
    }

    function playPreviousVideo() {
        if (playlistVideos.length > 0 && currentPlaylistIndex > 0) {
            playPlaylistItem(currentPlaylistIndex - 1);
        }
    }

    Component {
        id: videoComponent
        Video {
            anchors.fill: parent
            fillMode: Video.PreserveAspectFit
            source: videoPage.currentVideoUrl
            volume: Config.persistentVolume

            property int lastIntendedPosition: -1

            Rectangle {
                anchors.fill: parent
                color: "black"
                z: -1
            }

            onStarted: { stallWatchdog.stop(); videoPage.isSeeking = false; videoPage.isPlaying = true; controlsTimer.restart(); videoPage.recoveryAttempts = 0; }
            onResumed: { stallWatchdog.stop(); videoPage.isSeeking = false; videoPage.isPlaying = true; controlsTimer.restart(); videoPage.recoveryAttempts = 0; }
            onPaused: { stallWatchdog.stop(); videoPage.isPlaying = false; controlsTimer.stop(); controlsOverlay.visible = true; }
            onStopped: { stallWatchdog.stop(); videoPage.isPlaying = false; videoPage.isSeeking = false; controlsTimer.stop(); controlsOverlay.visible = true; }

            onStatusChanged: {
                // Сторож: если поток грузится/буферизуется дольше 12 сек — считаем его мёртвым
                if (status === Video.Loading || status === Video.Buffering || status === Video.Stalled) {
                    stallWatchdog.restart();
                } else if (status === Video.Loaded) {
                    stallWatchdog.stop();
                }

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

                // ОБНОВЛЕННЫЙ БЛОК:
                if (status === Video.EndOfMedia) {
                    if (currentPlaylistId !== "" && playlistVideos.length > 0) {
                        playNextVideo();
                    } else {
                        videoPage.isSeeking = false;
                        videoPage.isPlaying = false;
                    }
                }
                else if (status === Video.InvalidMedia || status === Video.NoMedia) {
                    if (videoPage.recoveryPosition === -1) {
                        videoPage.isSeeking = false;
                        videoPage.isPlaying = false;
                        handlePlaybackFailure(); // При сбое формата сразу пробуем откат
                    }
                }
            }

            onError: {
                console.log("[Video] Ошибка воспроизведения: " + errorString);

                // 1. СОХРАНЯЕМ СИСТЕМНОЕ ВОССТАНОВЛЕНИЕ ИЗ ФОНА SYMBIAN:
                // Если это ошибка -36 (потеря контекста экрана/памяти при сворачивании),
                // то восстанавливаем плеер на той же секунде (до 3 попыток).
                if (errorString.indexOf("-36") !== -1 && videoPage.recoveryAttempts < 3) {
                    console.log("[Video] Обнаружен уход в фон (-36). Перезапуск сессии...");
                    videoPage.recoveryAttempts++;
                    videoPage.recoveryPosition = (lastIntendedPosition !== -1) ? lastIntendedPosition : position;
                    videoLoader.sourceComponent = undefined;
                    recreateTimer.start();
                }
                // 2. УМНЫЙ ОТКАТ ДЛЯ ВСЕХ ОСТАЛЬНЫХ ОШИБОК:
                // Если это сетевая ошибка, битый URL или блокировка со стороны YouTube,
                // переключаемся на альтернативный источник (Piped или обратно на YouTube).
                else {
                    console.log("[Video] Критическая ошибка потока. Запуск переключения источника...");
                    handlePlaybackFailure();
                }
            }

            function performSafeSeek(newPos) {
                if (!seekable || duration <= 0) return;
                if (newPos > duration) newPos = duration;
                if (newPos < 0) newPos = 0;

                lastIntendedPosition = newPos;
                videoPage.isSeeking = true;
                stallWatchdog.restart();
                var wasPlaying = videoPage.isPlaying;

                if (wasPlaying) pause();
                position = newPos;
                play();

                if (!wasPlaying) videoPage.isSeeking = false;
            }
            Component.onCompleted: {
                play();
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

    Rectangle {
        id: playerContainer
        width: parent.width
        height: root.isFullscreen ? parent.height : (root.isLandscape ? parent.height * 0.6 : parent.width * 0.5625)
        anchors.top: parent.top
        color: "black"
        z: 5
        clip: true
        Loader {
            id: videoLoader
            anchors.fill: parent
            onLoaded: {
                if (item) {
                    item.play();
                }
            }
        }

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

            // Контейнер элементов управления воспроизведением
            Row {
                anchors.centerIn: parent
                spacing: 32
                visible: videoPage.pendingSeekSeconds === 0 && !videoPage.isSeeking && (videoLoader.item !== null ? videoLoader.item.status !== Video.Loading : true)

                // Кнопка НАЗАД по плейлисту
                Image {
                    source: "../Assets/player/back.png"
                    width: 40; height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: currentPlaylistIndex > 0 ? 0.8 : 0.3
                    visible: currentPlaylistId !== ""

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            controlsTimer.restart();
                            playPreviousVideo();
                        }
                    }
                }

                // Центральная кнопка PLAY / PAUSE
                SafeImage {
                    width: 64; height: 64
                    source: videoPage.isPlaying ? "../Assets/player/pause.png" : "../Assets/player/play.png"
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!videoLoader.item) return;
                            if (videoPage.isPlaying) videoLoader.item.pause(); else videoLoader.item.play();
                            controlsTimer.restart();
                        }
                    }
                }

                // Кнопка ВПЕРЕД по плейлисту
                Image {
                    source: "../Assets/player/skip.png"
                    width: 40; height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: currentPlaylistIndex < playlistVideos.length - 1 ? 0.8 : 0.3
                    visible: currentPlaylistId !== ""

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            controlsTimer.restart();
                            playNextVideo();
                        }
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
                    width: 50; height: parent.height
                    z: 10

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

                            if (root.isFullscreen) {
                                root.forceFullscreen = 1;
                            } else {
                                root.forceFullscreen = 2;
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
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: "#66000000"
            opacity: 0

            Timer {
                id: volumeOsdTimer
                interval: 2000
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

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                radius: 4
                color: "white"
                height: typeof VolumeKeys !== "undefined" ? (parent.height * (VolumeKeys.volume / 100.0)) : parent.height

                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
            }
        }

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
        }
    }

    ListView {
        id: mainList
        anchors.top: playerContainer.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.isFullscreen
        clip: true
        snapMode: ListView.NoSnap
        highlightMoveDuration: 0
        cacheBuffer: 1000

        header: Column {
            id: contentColumn
            width: mainList.width
            spacing: 0

            Item {
                width: parent.width; height: titleText.height + 32
                Text {
                    id: titleText; x: 16; y: 16; width: parent.width - 32
                    text: videoDetails ? (videoDetails["title"] || qsTr("Загрузка...")) : ""
                    color: "white"; font.pixelSize: 18; font.bold: true
                    wrapMode: Text.WordWrap;
                }
            }

            Text { x: 16; text: videoDetails ? ((videoDetails["views"] || "0") + qsTr(" просмотров")) : ""; color: "gray"; font.pixelSize: 14 }

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
                        SafeImage { anchors.fill: parent; source: videoDetails && videoDetails["channel_thumbnail"] ? "image://rounded/" + encodeURIComponent(videoDetails["channel_thumbnail"].replace("https://", "http://")) : "../Assets/placeholder.png"; fillMode: Image.PreserveAspectCrop }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: videoPage.width - 100
                        Text {
                            text: videoDetails ? (videoDetails["author"] || qsTr("Неизвестно")) : ""; color: "white"; font.pixelSize: 16; font.bold: true
                            width: parent.width; elide: Text.ElideRight
                        }
                        Text { text: videoDetails && videoDetails["subscriberCount"] ? videoDetails["subscriberCount"] : ""; color: "gray"; font.pixelSize: 12 }
                    }
                }
            }

            // Buttons (Like, Dislike, Share)
            Item {
                width: parent.width; height: 60
                Row {
                    x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 12

                    Rectangle {
                        width: 100; height: 40; color: "#272727"; radius: 20
                        Row {
                            anchors.centerIn: parent; spacing: 8
                            Image { source: "../Assets/player/like.png"; width: 20; height: 20 }
                            Text { text: videoDetails ? (videoDetails["likes"] || qsTr("Лайк")) : qsTr("Лайк"); color: "white"; font.pixelSize: 14 }
                        }
                        MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentVideoId, "like") }
                    }

                    Rectangle {
                        width: 60; height: 40; color: "#272727"; radius: 20
                        Image { source: "../Assets/player/dislike.png"; width: 20; height: 20; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; onClicked: ApiManager.rateVideo(currentVideoId, "dislike") }
                    }

                    Rectangle {
                        width: 120; height: 40; color: "#272727"; radius: 20
                        Row {
                            anchors.centerIn: parent; spacing: 8
                            Image { source: "../Assets/player/send.png"; width: 20; height: 20 }
                            Text { text: qsTr("Поделиться"); color: "white"; font.pixelSize: 14 }
                        }
                        MouseArea { anchors.fill: parent; onClicked: shareSheet.state = "visible" }
                    }
                }
            }

            Item {
                width: parent.width; height: 96
                Rectangle {
                    x: 16; width: parent.width - 32; height: 80
                    color: "#272727"; radius: 12; clip: true
                    Text {
                        x: 12; y: 12; width: parent.width - 24; height: 56
                        text: videoDetails ? (videoDetails["description"] || qsTr("Нет описания")) : ""
                        color: "white"; font.pixelSize: 14; wrapMode: Text.WordWrap; elide: Text.ElideRight;
                    }
                    MouseArea { anchors.fill: parent; onClicked: descriptionSheet.state = "visible" }
                }
            }



            // Comments preview
            Item {
                width: parent.width; height: 110
                visible: videoPage.firstComment !== null
                Rectangle {
                    x: 16; width: parent.width - 32; height: 94
                    color: "#272727"; radius: 12; clip: true
                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6
                        Row {
                            spacing: 8
                            Text { text: qsTr("Комментарии"); color: "white"; font.pixelSize: 14; font.bold: true }
                            Text { color: "gray"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter; text: videoPage.firstComment ? videoPage.firstComment.publishedAt : "" }
                        }
                        Row {
                            width: parent.width
                            spacing: 8
                            Rectangle {
                                width: 24; height: 24; radius: 12; color: "#333"; clip: true
                                Image {
                                    anchors.fill: parent;
                                    source: videoPage.firstComment && videoPage.firstComment.authorThumbnail ? "image://rounded/" + encodeURIComponent(String(videoPage.firstComment.authorThumbnail).replace("https://", "http://")) : "";
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                                }
                            }
                            Column {
                                width: parent.width - 32
                                Text { color: "gray"; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; width: parent.width; text: videoPage.firstComment ? videoPage.firstComment.author : "" }
                                Text {
                                    color: "white"; font.pixelSize: 13;
                                    elide: Text.ElideRight; wrapMode: Text.Wrap;
                                    width: parent.width; height: 32; clip: true
                                    text: videoPage.firstComment ? videoPage.firstComment.text : ""
                                }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: commentsSheet.state = "visible" }
                }
            }

            Item {
                width: parent.width; height: 40
                Text {
                    x: 16; y: 8; text: qsTr("Похожие видео")
                    color: "white"; font.pixelSize: 18; font.bold: true
                    visible: relatedVideos.length > 0
                }
            }
        }

        model: relatedVideos
        delegate: VideoCard {
            modelData: model.modelData
            onClicked: {
                root.navigateToVideo(videoId, playlistId)
            }
        }
    }

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
                            color: "white"; font.pixelSize: 16; wrapMode: Text.WordWrap;
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
            MouseArea { anchors.fill: parent }
            Item {
                anchors.fill: parent; anchors.margins: 16
                Column {
                    anchors.fill: parent; spacing: 10
                    Rectangle { width: 40; height: 5; radius: 2.5; color: "gray"; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: qsTr("Качество видео"); color: "white"; font.pixelSize: 18; font.bold: true;  }

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

    Rectangle {
        id: commentsSheet
        anchors.fill: parent; color: "#E6000000"; visible: state === "visible"; z: 50
        state: "hidden"
        states:[ State { name: "visible"; PropertyChanges { target: commentsPanel; y: root.height - commentsPanel.height } }, State { name: "hidden"; PropertyChanges { target: commentsPanel; y: root.height } } ]
        transitions: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad } }
        MouseArea { anchors.fill: parent; onClicked: commentsSheet.state = "hidden" }

        Rectangle {
            id: commentsPanel
            width: parent.width; height: root.height * 0.75
            anchors.bottom: parent.bottom; color: "#282828"
            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 10
                Rectangle { width: 40; height: 5; radius: 2.5; color: "gray"; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: qsTr("Комментарии"); color: "white"; font.pixelSize: 18; font.bold: true }

                ListView {
                    id: commentsListView
                    width: parent.width; height: parent.height - 40
                    model: videoPage.commentsModel
                    clip: true
                    spacing: 12
                    delegate: Item {
                        width: commentsListView.width
                        height: Math.max(36, commentCol.height)
                        Row {
                            anchors.fill: parent
                            spacing: 10
                            Rectangle {
                                width: 36; height: 36; radius: 18; color: "#333"; clip: true
                                Image {
                                    anchors.fill: parent;
                                    source: modelData.authorThumbnail ? "image://rounded/" + encodeURIComponent(String(modelData.authorThumbnail).replace("https://", "http://")) : "";
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                                }
                            }
                            Column {
                                id: commentCol
                                width: commentsListView.width - 46
                                Text { text: modelData.author; color: "gray"; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; width: parent.width }
                                Text { text: modelData.text; color: "white"; font.pixelSize: 14; wrapMode: Text.Wrap; width: parent.width }
                                Text { text: modelData.publishedAt; color: "#666"; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: shareSheet
        anchors.fill: parent; color: "#E6000000"; visible: state === "visible"; z: 20
        state: "hidden"
        states:[
            State { name: "visible"; PropertyChanges { target: sharePanel; y: root.height - sharePanel.height } },
            State { name: "hidden"; PropertyChanges { target: sharePanel; y: root.height } }
        ]
        transitions: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad } }
        MouseArea { anchors.fill: parent; onClicked: shareSheet.state = "hidden" }

        Rectangle {
            id: sharePanel
            width: parent.width; height: 180
            anchors.bottom: parent.bottom; color: "#282828"
            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 16
                Text { text: qsTr("Поделиться"); color: "white"; font.pixelSize: 18; font.bold: true }

                Rectangle {
                    width: parent.width; height: 45; color: "#1F1F1F"; radius: 5
                    Text { text: "https://youtu.be/" + currentVideoId; color: "white"; anchors.centerIn: parent; font.pixelSize: 14 }
                }

                Rectangle {
                    width: parent.width; height: 45; color: "#007ACC"; radius: 5
                    Text { text: qsTr("Скопировать ссылку"); color: "white"; anchors.centerIn: parent; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            ApiManager.copyToClipboard("https://youtu.be/" + currentVideoId);
                            shareSheet.state = "hidden";
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: VolumeKeys

        onPlayPressed: {
            if (videoLoader.item) videoLoader.item.play();
        }
        onPausePressed: {
            if (videoLoader.item) videoLoader.item.pause();
        }
        onStopPressed: {
            if (videoLoader.item) videoLoader.item.stop();
        }
        onNextPressed: {
            if (currentPlaylistId !== "" && playlistVideos.length > 0) {
                playNextVideo();
            }
        }
        onPreviousPressed: {
            if (currentPlaylistId !== "" && playlistVideos.length > 0) {
                playPreviousVideo();
            }
        }
    }


    // ==========================================
    // ПАРЯЩИЙ "ОСТРОВОК" ПЛЕЙЛИСТА (СВЕРНУТЫЙ ВИД)
    // ==========================================
    Rectangle {
        id: playlistFloatingIsland
        height: 62
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        radius: 14
        color: "#F2161616" // Слегка прозрачный темно-серый фон
        border.color: "#2C2C2C"
        border.width: 1
        z: 45 // Поверх основного контента страницы

        // Видим только если запущен плейлист И свернуты панели джема/комментариев
        visible: currentPlaylistId !== "" && playlistVideos.length > 0 && playlistSheet.state !== "visible" && commentsSheet.state !== "visible" && !root.isFullscreen

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            // Иконка беспроводного вещания / джема
            Text {
                text: "((•))"
                color: "#3EA6FF"
                font.pixelSize: 18
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            // Текстовая информация (Что играет дальше)
            Column {
                width: parent.width - 86
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: {
                        if (playlistVideos.length > 0 && currentPlaylistIndex < playlistVideos.length - 1) {
                            return qsTr("Далее: ") + playlistVideos[currentPlaylistIndex + 1].title;
                        }
                        return qsTr("Конец плейлиста");
                    }
                    color: "white"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: "Джем • " + playlistTitle
                    color: "#AAAAAA"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            // Кнопка развертывания
            Text {
                text: "▲"
                color: "white"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                playlistSheet.state = "visible";
            }
        }
    }

    // ==========================================
    // ВЫДВИЖНАЯ ПАНЕЛЬ ПЛЕЙЛИСТА (РАЗВЕРНУТЫЙ ВИД)
    // ==========================================
    Rectangle {
        id: playlistSheet
        anchors.fill: parent
        color: "#B3000000" // Затемнение фона
        visible: state === "visible"
        state: "hidden"
        z: 60 // Выше парящего островка

        states: [
            State {
                name: "visible"
                PropertyChanges { target: playlistPanel; y: root.height - playlistPanel.height }
            },
            State {
                name: "hidden"
                PropertyChanges { target: playlistPanel; y: root.height }
            }
        ]
        transitions: Transition {
            NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: playlistSheet.state = "hidden"
        }

        Rectangle {
            id: playlistPanel
            width: parent.width
            height: root.isFullscreen ? parent.height : (parent.height - (root.isLandscape ? parent.height * 0.6 : parent.width * 0.5625))
            anchors.bottom: parent.bottom
            color: "#161616"
            radius: 16

            MouseArea { anchors.fill: parent } // Блокировка кликов сквозь панель

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Шапка панели
                Row {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: "((•))"
                        color: "#3EA6FF"
                        font.pixelSize: 20
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - 64
                        spacing: 2
                        Text {
                            text: playlistTitle
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: qsTr("Плейлист • Создан специально для вас")
                            color: "gray"
                            font.pixelSize: 12
                        }
                    }

                    // Кнопка закрытия панели
                    Text {
                        text: "✕"
                        color: "white"
                        font.pixelSize: 20
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: playlistSheet.state = "hidden"
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#2C2C2C"
                }

                // Вертикальный список воспроизведения
                ListView {
                    id: playlistVerticalList
                    width: parent.width
                    height: parent.height - 70
                    model: playlistVideos
                    clip: true
                    spacing: 10
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: playlistVerticalList.width
                        height: 76
                        color: currentPlaylistIndex === index ? "#262626" : "transparent"
                        radius: 8

                        Row {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 12

                            // Драг-хэндл маркер
                            Text {
                                text: "＝"
                                color: "#444444"
                                font.pixelSize: 15
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Превью трека
                            Rectangle {
                                width: 110
                                height: 62
                                color: "black"
                                radius: 6
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    anchors.fill: parent
                                    source: modelData.thumbnail || ""
                                    fillMode: Image.PreserveAspectCrop
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                    color: "#CC000000"
                                    radius: 3
                                    width: tText.width + 8
                                    height: tText.height + 4
                                    visible: modelData.duration !== ""

                                    Text {
                                        id: tText
                                        anchors.centerIn: parent
                                        text: modelData.duration || ""
                                        color: "white"
                                        font.pixelSize: 10
                                    }
                                }
                            }

                            // Метаданные трека
                            Column {
                                width: parent.width - 164
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: modelData.title || ""
                                    color: currentPlaylistIndex === index ? "#3EA6FF" : "white"
                                    font.pixelSize: 13
                                    font.bold: currentPlaylistIndex === index
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Text {
                                    text: modelData.author || ""
                                    color: "gray"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                playPlaylistItem(index);
                                playlistSheet.state = "hidden";
                            }
                        }
                    }
                }
            }
        }
    }

}
