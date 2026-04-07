import QtQuick 1.0
import QtMultimediaKit 1.1
import "components"

Rectangle {
    id: root
    width: 360
    height: 640
    color: "black"

    property string currentTab: "Home"

    // --- СИСТЕМА ИНИЦИАЛИЗАЦИИ QTMULTIMEDIAKIT ПРИ ЗАПУСКЕ ---
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

                volume: 1.0 // Без звука, чтобы не пугать пользователя

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
    // ---------------------------------------------------------

    Navbar {
        id: navbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 56; z: 10

        onSearchRequested: {
            contentLoader.source = "pages/SearchPage.qml";
            if (contentLoader.item) contentLoader.item.performSearch(query);
        }

        onBackClicked: {
            if (currentTab === "Home") contentLoader.source = "pages/HomePage.qml";
            else if (currentTab === "Subscriptions") contentLoader.source = "pages/SubscriptionsPage.qml";
            else if (currentTab === "Account") contentLoader.source = "pages/AccountPage.qml";
            navbar.showBackButton = false;
        }
    }

    Loader {
        id: contentLoader
        anchors.top: navbar.bottom; anchors.bottom: tabbar.top
        anchors.left: parent.left; anchors.right: parent.right
        source: "pages/HomePage.qml"

        onLoaded: {
            if (typeof item.onNavigatedTo !== "undefined") item.onNavigatedTo();
        }
    }

    Tabbar {
        id: tabbar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 50; z: 10

        onTabClicked: {
            root.currentTab = tabName;
            navbar.showBackButton = false;

            if (tabName === "Home") contentLoader.source = "pages/HomePage.qml";
            else if (tabName === "Subscriptions") contentLoader.source = "pages/SubscriptionsPage.qml";
            else if (tabName === "Account") contentLoader.source = "pages/AccountPage.qml";
        }
    }

    // Глобальная функция навигации
    function navigateToVideo(videoId) {
        navbar.showBackButton = true;
        // Грузим чистую страницу видео
        contentLoader.source = "pages/VideoPage.qml";
        if (contentLoader.item && typeof contentLoader.item.loadVideo !== "undefined") {
            contentLoader.item.loadVideo(videoId);
        }
    }

    function navigateToChannel(author) {
        navbar.showBackButton = true;
        contentLoader.source = "pages/ChannelPage.qml";
        if (contentLoader.item && typeof contentLoader.item.loadChannel !== "undefined") {
            contentLoader.item.loadChannel(author);
        }
    }
}
