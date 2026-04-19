import QtQuick 1.0
import "../components"

Rectangle {
    id: homePage
    anchors.fill: parent
    color: "black"

    property variant videosModel:[]
    property bool isLoading: false
    property bool isLoadingMore: false
    property string nextPageToken: ""

    // --- ИСПРАВЛЕНИЕ: Вместо alias используем простое свойство-флаг ---
    property bool showBottomLoading: false

    Connections {
        target: ApiManager

        onHomeVideosReady: {
            loadingIndicator.visible = false;
            errorPanel.visible = false;

            homePage.nextPageToken = token;

            if (homePage.isLoadingMore) {
                var savedY = mainList.contentY;
                var temp = homePage.videosModel;
                for (var i = 0; i < videos.length; i++) temp.push(videos[i]);
                homePage.videosModel = temp;
                mainList.contentY = savedY;
                homePage.isLoadingMore = false;
            } else {
                homePage.videosModel = videos;
                homePage.isLoading = false;
                mainList.contentY = 0;
            }

            // Управляем флагом
            homePage.showBottomLoading = false;
        }

        onRequestFailed: {
            if (endpoint === "HomeVideos") {
                homePage.isLoading = false;
                homePage.isLoadingMore = false;
                loadingIndicator.visible = false;
                homePage.showBottomLoading = false; // Управляем флагом
                if (homePage.videosModel.length === 0) {
                    errorPanel.visible = true;
                }
            }
        }
    }

    function onNavigatedTo() {
        if (videosModel.length === 0 && !isLoading) refreshData();
    }

    function refreshData() {
        isLoading = true;
        isLoadingMore = false;
        nextPageToken = "";
        loadingIndicator.visible = true;
        errorPanel.visible = false;
        videosModel = [];
        ApiManager.getHomeVideos("");
    }

    // Индикатор загрузки (по центру)
    Rectangle {
        id: loadingIndicator; anchors.centerIn: parent; width: 150; height: 50;
        color: "#222222"; radius: 8; visible: false; z: 10
        Row {
            anchors.centerIn: parent; spacing: 10
            Image { id: spinner; source: "../Assets/player/reload.png"; width: 24; height: 24; RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: spinner.visible } }
            Text { text: "Загрузка..."; color: "white"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // Панель ошибки
    Column {
        id: errorPanel; anchors.centerIn: parent; spacing: 10; visible: false
        Image { source: "../Assets/NoInternet.png"; width: 100; height: 100; anchors.horizontalCenter: parent.horizontalCenter; fillMode: Image.PreserveAspectFit }
        Text { text: "Не удалось получить данные"; color: "white"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
        Rectangle {
            width: 150; height: 40; color: "#333333"; radius: 5; anchors.horizontalCenter: parent.horizontalCenter
            Text { text: "ПОВТОРИТЬ"; color: "white"; anchors.centerIn: parent; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: refreshData() }
        }
    }



    // Главный список видео
    ListView {
        id: mainList
        anchors.fill: parent
        model: videosModel
        visible: !isLoading && !errorPanel.visible
        cacheBuffer: 1200



        delegate: VideoCard {
            modelData: model.modelData
            onClicked: { root.navigateToVideo(videoId) }
        }

        onContentYChanged: {
            if (contentY >= (contentHeight - height * 2) && !isLoadingMore && nextPageToken !== "") {
                isLoadingMore = true;
                homePage.showBottomLoading = true; // Управляем флагом
                ApiManager.getHomeVideos(nextPageToken);
            }
        }

        footer: Rectangle {
            id: bottomLoading
            width: parent.width
            height: 60
            color: "black"

            // --- ИСПРАВЛЕНИЕ: Привязываем visible к свойству-флагу ---
            visible: homePage.showBottomLoading

            Row {
                anchors.centerIn: parent; spacing: 10
                Image { id: bSpinner; source: "../Assets/player/reload.png"; width: 24; height: 24; RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: bSpinner.visible } }
                Text { text: "Загрузка..."; color: "gray"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
