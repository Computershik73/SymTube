import QtQuick 1.0

Rectangle {
    id: settingsPage
    anchors.fill: parent
    color: "black"

    function onNavigatedTo() {
        apiBaseUrlInput.text = Config.apiBaseUrl
        apiKeyInput.text = Config.apiKey
    }

    Flickable {
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: settingsCol.height + 40
        clip: true

        Column {
            id: settingsCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 20

            Text {
                text: "Настройки"
                color: "white"
                font.pixelSize: 28
                font.bold: true
            }

            // Настройка API Base URL
            Column {
                spacing: 8
                width: parent.width
                
                Text {
                    text: "Основной адрес API"
                    color: "#CCFFFFFF"
                    font.pixelSize: 16
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#1F1F1F"
                    border.color: "#333333"
                    border.width: 1
                    
                    TextInput {
                        id: apiBaseUrlInput
                        anchors.fill: parent
                        anchors.margins: 8
                        color: "white"
                        font.pixelSize: 16
                        verticalAlignment: TextInput.AlignVCenter
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#007ACC"
                    
                    Text {
                        text: "Сохранить URL"
                        color: "white"
                        anchors.centerIn: parent
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Config.apiBaseUrl = apiBaseUrlInput.text
                            apiBaseUrlInput.focus = false
                        }
                    }
                }
            }

            // Настройка API Key
            Column {
                spacing: 8
                width: parent.width
                
                Text {
                    text: "Ключ YouTube API"
                    color: "#CCFFFFFF"
                    font.pixelSize: 16
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#1F1F1F"
                    border.color: "#333333"
                    border.width: 1
                    
                    TextInput {
                        id: apiKeyInput
                        anchors.fill: parent
                        anchors.margins: 8
                        color: "white"
                        font.pixelSize: 16
                        verticalAlignment: TextInput.AlignVCenter
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#007ACC"
                    
                    Text {
                        text: "Сохранить Ключ"
                        color: "white"
                        anchors.centerIn: parent
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Config.apiKey = apiKeyInput.text
                            apiKeyInput.focus = false
                        }
                    }
                }
            }

            // Инфо о проекте
            Column {
                width: parent.width
                spacing: 5
                anchors.horizontalCenter: parent.horizontalCenter
                
                Text { text: "YouTube клиент от zemonkamin"; color: "#666666"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Порт на Symbian Qt 4.7"; color: "#666666"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
}