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
                // Если список успешно загружен, обновляем модель комбобокса
                apiCombo.model = servers;
            } else {
                // Если загрузка не удалась, показываем текст с подсказкой
                qtlsText.visible = true;
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
                text: qsTr("Настройки")
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
                    text: qsTr("Основной адрес API")
                    color: "#CCFFFFFF"
                    font.pixelSize: 16
                }

                CustomComboBox {
                    id: apiCombo
                    width: parent.width
                    // Жестко зашитый список серверов
                    model:[
                        "http://yt.swlbst.ru/"
                    ]
                }

                Row {
                    id: qtlsText
                    spacing: 4
                    visible: false // Показываем только если список не загрузился

                    Text {
                        text: qsTr("Не грузится список серверов? Установите патч QTLS по ")
                        color: "gray"
                        font.pixelSize: 12
                    }
                    Text {
                        text: qsTr("ссылке")
                        color: "#0099FF" // Цвет ссылки
                        font.underline: true
                        font.pixelSize: 12

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Qt.openUrlExternally("http://nnproject.cc/qtls/")
                            }
                        }
                    }
                }

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
                        apiCombo.isOpen = false;
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
                        { label: "Исходный код клиента (GitHub)", url: "https://github.com/Computershik73/SymTube" },
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
