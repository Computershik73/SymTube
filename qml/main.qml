import QtQuick 1.0
import QtMultimediaKit 1.1
import "components"

Rectangle {
    id: root
    width: 360
    height: 640
    color: "black"

    property string currentTab: "Home"
    property bool isLandscape: width > height
    property bool isVideoPageOpen: contentLoader.source.toString().indexOf("VideoPage.qml") !== -1
    property int forceFullscreen: 1
    property bool isFullscreen: isVideoPageOpen && forceFullscreen === 2

    onIsLandscapeChanged: {
        if (!isLandscape && forceFullscreen === 2) {
            forceFullscreen = 1;
        }
    }

    Loader {
        id: kickstartLoader
        anchors.fill: parent
        z: 999 // Поверх всего приложения
        sourceComponent: kickstartComponent
    }

    Component {
        id: kickstartComponent
        Rectangle {
            color: "black" // Черный экран загрузки


            Video {
                anchors.fill: parent
                source: "../qml/Assets/dummy.mp4" // Путь к пустышке
                fillMode: Video.Stretch

                volume: 0.1 // Без звука, чтобы не пугать пользователя

                onStarted: {
                    console.log("success.");
                    kickstartLoader.sourceComponent = undefined; // Полностью выгружаем из памяти
                }

                onStatusChanged: {
                    if (status === Video.InvalidMedia || status === Video.NoMedia) {
                        console.log("not found.");
                        kickstartLoader.sourceComponent = undefined;
                    }
                }
            }

            // Предохранитель: если плеер зависнет, через 2 секунды убираем экран
            Timer {
                interval: 2000
                running: true
                onTriggered: {
                    if (kickstartLoader.sourceComponent !== undefined) {
                        console.log("Таймаут кикстарта.");
                        kickstartLoader.sourceComponent = undefined;
                    }
                }
            }
        }
    }

    Navbar {
        id: navbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: isFullscreen ? 0 : 56
        visible: !isFullscreen
        z: 10

        onSearchRequested: {
            root.pendingQuery = query;
            safeLoadPage("pages/SearchPage.qml");
        }
        onBackClicked: {
            switchToTab(currentTab);
        }
    }

    // --- БЕЗОПАСНАЯ АСИНХРОННАЯ ЗАГРУЗКА ---
    property string pendingVideoId: ""
    property string pendingChannelId: ""
    property string pendingQuery: ""

    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        color: "black"
        z: 100
        visible: false
        Text {
            anchors.centerIn: parent
            text: qsTr("Загрузка...")
            color: "gray"
            font.pixelSize: 18
        }
        MouseArea { anchors.fill: parent } // Блокировка случайных нажатий
    }

    Loader {
        id: contentLoader
        anchors.top: isFullscreen ? parent.top : navbar.bottom
        anchors.bottom: isFullscreen ? parent.bottom : tabbar.top
        anchors.left: parent.left; anchors.right: parent.right

        onLoaded: {
            loadingOverlay.visible = false;
            if (!item) return;

            var src = source.toString();
            if (src.indexOf("VideoPage.qml") !== -1 && root.pendingVideoId !== "") {
                item.loadVideo(root.pendingVideoId);
                root.pendingVideoId = "";
            } else if (src.indexOf("ChannelPage.qml") !== -1 && root.pendingChannelId !== "") {
                item.loadChannel(root.pendingChannelId);
                root.pendingChannelId = "";
            } else if (src.indexOf("SearchPage.qml") !== -1 && root.pendingQuery !== "") {
                item.performSearch(root.pendingQuery);
                root.pendingQuery = "";
            } else if (src.indexOf("ShortsPage.qml") !== -1) {
                if (typeof item.startPlaying !== "undefined") item.startPlaying();
            } else if (typeof item.onNavigatedTo !== "undefined") {
                item.onNavigatedTo();
            }
        }
    }

    Timer {
        id: pageLoadTimer
        interval: 10 // Минимальная задержка, чтобы UI успел показать черный экран с текстом "Загрузка..."
        repeat: false
        property string nextSource: ""
        onTriggered: {
            contentLoader.source = nextSource;
        }
    }

    function safeLoadPage(pageSource) {
        var currentStr = contentLoader.source.toString();
        if (currentStr.indexOf(pageSource) !== -1) {
            // Если страница уже открыта - не перезагружаем компонент, а просто обновляем
            loadingOverlay.visible = false;
            if (contentLoader.item) {
                if (pageSource.indexOf("VideoPage.qml") !== -1 && root.pendingVideoId !== "") {
                    contentLoader.item.loadVideo(root.pendingVideoId);
                    root.pendingVideoId = "";
                } else if (pageSource.indexOf("ChannelPage.qml") !== -1 && root.pendingChannelId !== "") {
                    contentLoader.item.loadChannel(root.pendingChannelId);
                    root.pendingChannelId = "";
                } else if (pageSource.indexOf("SearchPage.qml") !== -1 && root.pendingQuery !== "") {
                    contentLoader.item.performSearch(root.pendingQuery);
                    root.pendingQuery = "";
                } else if (pageSource.indexOf("ShortsPage.qml") !== -1) {
                    if (typeof contentLoader.item.startPlaying !== "undefined") contentLoader.item.startPlaying();
                } else if (typeof contentLoader.item.onNavigatedTo !== "undefined") {
                    contentLoader.item.onNavigatedTo();
                }
            }
        } else {
            loadingOverlay.visible = true;
            pageLoadTimer.nextSource = pageSource;
            pageLoadTimer.start();
        }
    }

    function switchToTab(tabName) {
        currentTab = tabName;
        navbar.showBackButton = false;
        tabbar.activeTab = tabName;

        var src = "";
        if (tabName === "Home") src = "pages/HomePage.qml";
        else if (tabName === "Subscriptions") src = "pages/SubscriptionsPage.qml";
        else if (tabName === "Account") src = "pages/AccountPage.qml";
        else if (tabName === "Shorts") src = "pages/ShortsPage.qml";

        if (src !== "") {
            safeLoadPage(src);
        }
    }

    Component.onCompleted: {
        switchToTab("Home");
    }

    function navigateToVideo(videoId) {
        forceFullscreen = 1;
        navbar.showBackButton = true;
        root.pendingVideoId = videoId;
        safeLoadPage("pages/VideoPage.qml");
    }

    function navigateToChannel(author) {
        navbar.showBackButton = true;
        root.pendingChannelId = author;
        safeLoadPage("pages/ChannelPage.qml");
    }

    function navigateToSettings() {
        navbar.showBackButton = true;
        safeLoadPage("pages/SettingsPage.qml");
    }

    Tabbar {
        id: tabbar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: isFullscreen ? 0 : 50
        visible: !isFullscreen
        z: 10

        onTabClicked: {
            root.switchToTab(tabName);
        }
    }
}
