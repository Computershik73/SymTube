import QtQuick 1.0
import "components"

Rectangle {
    id: root
    width: 360
    height: 640
    color: "black"

    property string currentTab: "Home"

    // Верхняя навигационная панель
    Navbar {
        id: navbar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        z: 10

        onSearchRequested: {
            // При поиске переходим на страницу поиска
            contentLoader.source = "pages/SearchPage.qml";
            if (contentLoader.item) {
                contentLoader.item.performSearch(query);
            }
        }

        onBackClicked: {
            // Простая реализация возврата (можно усложнить через стек)
            if (currentTab === "Home") {
                contentLoader.source = "pages/HomePage.qml";
            } else if (currentTab === "Subscriptions") {
                contentLoader.source = "pages/SubscriptionsPage.qml";
            } else if (currentTab === "Account") {
                contentLoader.source = "pages/AccountPage.qml";
            }
            navbar.showBackButton = false;
        }
    }

    // Загрузчик контента (страниц)
    Loader {
        id: contentLoader
        anchors.top: navbar.bottom
        anchors.bottom: tabbar.top
        anchors.left: parent.left
        anchors.right: parent.right
        source: "pages/HomePage.qml"

        onLoaded: {
            // Если страница поддерживает функцию onNavigatedTo, вызываем её
            if (typeof item.onNavigatedTo !== "undefined") {
                item.onNavigatedTo();
            }
        }
    }

    // Нижняя панель вкладок
    Tabbar {
        id: tabbar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        z: 10

        onTabClicked: {
            root.currentTab = tabName;
            navbar.showBackButton = false; // Сбрасываем кнопку "Назад" при смене вкладки

            if (tabName === "Home") {
                contentLoader.source = "pages/HomePage.qml";
            } else if (tabName === "Subscriptions") {
                contentLoader.source = "pages/SubscriptionsPage.qml";
            } else if (tabName === "Account") {
                contentLoader.source = "pages/AccountPage.qml";
            }
        }
    }

    // Глобальная функция для перехода к видео (вызывается из любой карточки)
    function navigateToVideo(videoId) {
        navbar.showBackButton = true;
        contentLoader.source = "pages/VideoPage.qml";
        if (contentLoader.item && typeof contentLoader.item.loadVideo !== "undefined") {
            contentLoader.item.loadVideo(videoId);
        }
    }

    // Переход к истории
    function navigateToHistory() {
        navbar.showBackButton = true;
        contentLoader.source = "pages/HistoryPage.qml";
    }

    // Переход к настройкам
    function navigateToSettings() {
        navbar.showBackButton = true;
        contentLoader.source = "pages/SettingsPage.qml";
    }
	function navigateToChannel(author) {
        navbar.showBackButton = true;
        contentLoader.source = "pages/ChannelPage.qml";
        if (contentLoader.item && typeof contentLoader.item.loadChannel !== "undefined") {
            contentLoader.item.loadChannel(author);
        }
    }
}
