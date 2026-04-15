import QtQuick 1.0
import "../components"

Rectangle {
    id: settingsPage
    anchors.fill: parent
    color: "black"

    function onNavigatedTo() {
        // Подгружаем текущий URL из C++ при открытии
        apiCombo.text = Config.apiBaseUrl;
    }

    // Закрытие списка и клавиатуры при клике в пустое место
    MouseArea {
        anchors.fill: parent
        onClicked: {
            apiCombo.isOpen = false;
            settingsPage.focus = true;
        }
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
            spacing: 24

            Text {
                text: "Настройки"
                color: "white"
                font.pixelSize: 28
                font.bold: true
            }

            // Блок настройки API URL
            Column {
                spacing: 8
                width: parent.width
                // Z-индекс здесь критичен, чтобы выпадающий список 
                // комбобокса вылез поверх кнопки "Сохранить"
                z: 10 

                Text {
                    text: "Основной адрес API"
                    color: "#CCFFFFFF"
                    font.pixelSize: 16
                }

                CustomComboBox {
                    id: apiCombo
                    width: parent.width
                    // Жестко зашитый список серверов
                    model:[
                        "http://yt.modyleprojects.ru/",
                        "http://yt.swlbst.ru/",
                        "http://192.168.1.183:8890/"
                    ]
                }
            }

            // Кнопка сохранения
            Rectangle {
                width: parent.width
                height: 45
                color: "#007ACC"
                radius: 5
                
                Text {
                    text: "Сохранить"
                    color: "white"
                    anchors.centerIn: parent
                    font.bold: true
                    font.pixelSize: 16
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        apiCombo.isOpen = false;
                        // Отправляем новый URL в C++
                        Config.apiBaseUrl = apiCombo.text;
                        
                        saveText.visible = true;
                        saveTimer.start();
                    }
                }
            }

            // Индикатор успешного сохранения
            Text {
                id: saveText
                text: "Настройки сохранены!"
                color: "#4CAF50" // Зеленый цвет успеха
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
                visible: false

                Timer {
                    id: saveTimer
                    interval: 2000
                    onTriggered: saveText.visible = false
                }
            }

            // Блок информации
            // --- РАЗДЕЛ "О ПРИЛОЖЕНИИ" ---

            // Визуальный разделитель
            Rectangle {
                width: parent.width; height: 1; color: "#333333"; anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "О приложении"
                color: "white"
                font.pixelSize: 20
                font.bold: true
                font.family: "Nokia Pure Text"
            }

            // Lorem Ipsum
            Text {
                width: parent.width
                text: "SymTube - это клиент для YouTube, созданный специально для Symbian. Мы стремимся вернуть жизнь в старые устройства, предоставляя доступ к современному контенту."
                color: "#AAAAAA"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                font.family: "Nokia Pure Text"
            }

            // --- СПИСОК ССЫЛОК (СТАБИЛЬНЫЙ ВАРИАНТ) ---
            Column {
                width: parent.width
                spacing: 10

                // Модель данных для ссылок
                Repeater {
                    model: [
                        { label: "Исходный код клиента (GitHub)", url: "https://github.com/Computershik73/" },
                        { label: "API Сервер (Rust)", url: "https://github.com/ZendoMusic/yt-api-legacy" },
                        { label: "Группа в Telegram", url: "https://t.me/cmplog" }
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        height: 30
                        color: "transparent"

                        Text {
                            text: modelData.label
                            // Если нажато (mouseArea.pressed), цвет меняется
                            color: mouseArea.pressed ? "#007ACC" : "#0099FF"
                            font.pixelSize: 14
                            font.underline: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            onClicked: Qt.openUrlExternally(modelData.url)
                        }
                    }
                }
            }


        }
    }
}
