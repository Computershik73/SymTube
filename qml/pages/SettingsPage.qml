import QtQuick 1.0
import "../components"

Rectangle {
    id: settingsPage
    anchors.fill: parent
    color: "black"

    Connections {
        target: ApiManager
        onServerListReady: {
            if (servers && servers.length > 0) {

            } else {

            }
        }
    }

    function onNavigatedTo() {
        // Подгружаем текущий URL из C++ при открытии
        //apiCombo.text = Config.apiBaseUrl;
        langCombo.text = TranslationManager.currentLanguage;
        ApiManager.fetchServerList();
    }

    // Закрытие списка и клавиатуры при клике в пустое место
    MouseArea {
        anchors.fill: parent
        onClicked: {

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
                text: qsTr("Настройки")
                color: "white"
                font.pixelSize: 28
                font.bold: true
            }

            Column {
                spacing: 8
                width: parent.width
                z: 9 // Обязательно Z-индекс ниже, чем у комбобокса API-URL, чтобы списки не перекрывались!

                Text {
                    text: qsTr("Язык / Language")
                    color: "#CCFFFFFF"
                    font.pixelSize: 16
                }

                CustomComboBox {
                    id: langCombo
                    width: parent.width
                    // Модель автоматически получает список доступных языков из C++
                    model: TranslationManager.availableLanguages
                }

                Text {
                    text: qsTr("* Изменения вступят в силу после перезапуска")
                    color: "gray"
                    font.pixelSize: 12
                }
            }

            // Кнопка сохранения
            Rectangle {
                width: parent.width
                height: 45
                color: "#007ACC"
                radius: 5
                
                Text {
                    text: qsTr("Сохранить")
                    color: "white"
                    anchors.centerIn: parent
                    font.bold: true
                    font.pixelSize: 16
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        //apiCombo.isOpen = false;
                        langCombo.isOpen = false;
                        // Отправляем новый URL в C++
                        //Config.apiBaseUrl = apiCombo.text;

                        TranslationManager.setLanguage(langCombo.text);
                        
                        saveText.visible = true;
                        saveTimer.start();
                    }
                }
            }

            // Индикатор успешного сохранения
            Text {
                id: saveText
                text: qsTr("Настройки сохранены!")
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
                text: qsTr("О приложении")
                color: "white"
                font.pixelSize: 20
                font.bold: true
                font.family: "Nokia Pure Text"
            }

            // Lorem Ipsum
            Text {
                width: parent.width
                text: qsTr("SymTube - это клиент для YouTube, созданный специально для Symbian. Мы стремимся вернуть жизнь в старые устройства, предоставляя доступ к современному контенту.")
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
                        { label: "Разработчик - Computershik", url: "https://4pda.to/forum/index.php?showuser=4458524" },
                        { label: "Исходный код клиента (GitHub)", url: "https://github.com/Computershik73/SymTube" },
                        { label: "Подсказал с InnerTube API - Zemonkamin", url: "https://github.com/ZendoMusic/yt-api-legacy" },
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
