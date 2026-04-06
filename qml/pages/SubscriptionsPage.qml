import QtQuick 1.0
import "../components"

Rectangle {
    id: subsPage
    anchors.fill: parent
    color: "black"

    property variant subsModel: []
    property variant videosModel:[]

    Connections {
        target: ApiManager
        
        onSubscriptionsReady: {
            loadingIndicator.visible = false
            subsModel = subscriptions
            
            // Если есть подписки, сразу грузим видео первого канала
            if (subscriptions.length > 0) {
                var firstAuthorUrl = subscriptions[0].profile_url
                var author = firstAuthorUrl.split("author=")[1]
                if (author) {
                    loadingIndicator.visible = true
                    ApiManager.getChannelVideos(author)
                }
            }
        }
        
        onChannelVideosReady: {
            loadingIndicator.visible = false
            if (channelData && channelData.videos) {
                videosModel = channelData.videos
            }
        }
    }

    function onNavigatedTo() {
        if (Config.userToken === "") {
            errorText.text = "Требуется авторизация"
            errorText.visible = true
            return
        }
        
        if (subsModel.length === 0) {
            loadingIndicator.visible = true
            errorText.visible = false
            ApiManager.getSubscriptions()
        }
    }

    Text {
        id: loadingIndicator
        text: "Загрузка..."
        color: "white"
        font.pixelSize: 18
        anchors.centerIn: parent
        visible: false
        z: 5
    }

    Text {
        id: errorText
        text: ""
        color: "gray"
        font.pixelSize: 16
        anchors.centerIn: parent
        visible: false
    }

    Column {
        anchors.fill: parent
        visible: !errorText.visible

        // Горизонтальный список подписок
        ListView {
            id: channelsList
            width: parent.width
            height: 120
            orientation: ListView.Horizontal
            model: subsModel
            spacing: 16
            
            delegate: Item {
                width: 80
                height: 120
                
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    
                    Rectangle {
                        width: 70; height: 70; radius: 35
                        color: "#333333"; clip: true
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        Image {
                            anchors.fill: parent
                            source: model.modelData.local_thumbnail ? model.modelData.local_thumbnail : ""
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    
                    Text {
                        text: model.modelData.title ? model.modelData.title : ""
                        color: "white"
                        font.pixelSize: 12
                        width: 80
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var authorUrl = model.modelData.profile_url
                        var author = authorUrl.split("author=")[1]
                        if (author) {
                            videosModel = [] // Очищаем список перед загрузкой нового
                            ApiManager.getChannelVideos(author)
                        }
                    }
                }
            }
        }

        // Список видео текущего выбранного канала
        ListView {
            id: channelVideosList
            width: parent.width
            height: parent.height - 130
            model: videosModel
            spacing: 10
            
            delegate: VideoCard {
                modelData: model.modelData
                onClicked: {
                    root.navigateToVideo(videoId)
                }
            }
        }
    }
}