import QtQuick 1.0
import "../components"

Rectangle {
    id: homePage
    anchors.fill: parent
    color: "black"

    property variant videosModel:[]
    property bool isLoading: false

    Connections {
        target: ApiManager
        
        onHomeVideosReady: {
            isLoading = false
            loadingIndicator.visible = false
            errorPanel.visible = false
            videosModel = videos // Присваиваем QVariantList напрямую
        }
        
        onRequestFailed: {
            if (endpoint === "HomeVideos") {
                isLoading = false
                loadingIndicator.visible = false
                errorPanel.visible = true
            }
        }
    }

    // Вызывается из main.qml при загрузке
    function onNavigatedTo() {
        if (videosModel.length === 0 && !isLoading) {
            refreshData()
        }
    }

    function refreshData() {
        isLoading = true
        loadingIndicator.visible = true
        errorPanel.visible = false
        videosModel =[]
        ApiManager.getHomeVideos("")
    }

    // Индикатор загрузки
    Text {
        id: loadingIndicator
        text: "Загрузка..."
        color: "white"
        font.pixelSize: 18
        anchors.centerIn: parent
        visible: false
    }

    // Панель ошибки
    Column {
        id: errorPanel
        anchors.centerIn: parent
        spacing: 10
        visible: false

        Image {
            source: "../Assets/NoInternet.png"
            width: 100; height: 100
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
        }
        
        Text {
            text: "Не удалось получить данные"
            color: "white"
            font.pixelSize: 18
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            width: 150; height: 40
            color: "#333333"
            radius: 5
            anchors.horizontalCenter: parent.horizontalCenter
            
            Text {
                text: "ПОВТОРИТЬ"
                color: "white"
                anchors.centerIn: parent
                font.bold: true
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: refreshData()
            }
        }
    }

    // Список видео
    ListView {
        id: listView
        anchors.fill: parent
        model: videosModel
        visible: !isLoading && !errorPanel.visible
        spacing: 10
        
        delegate: VideoCard {
            modelData: model.modelData // В QtQuick 1.0 так передается объект из QVariantList
            onClicked: {
                root.navigateToVideo(videoId)
            }
        }
    }
}
