import QtQuick 1.0

Rectangle {
    id: navbarRoot
    color: "#111111" // Тёмно-серый цвет в стиле YouTube
    
    signal searchRequested(string query)
    signal backClicked()
    
    property bool showBackButton: false
    property bool isSearchMode: false

    // Основной режим: Логотип и кнопка поиска
    Item {
        id: defaultMode
        anchors.fill: parent
        visible: !isSearchMode

        // Кнопка "Назад"
        Image {
            id: backIcon
            source: "../Assets/player/back.png" // Используем доступную иконку из UWP проекта
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 16
            width: 24
            height: 24
            visible: showBackButton
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    navbarRoot.backClicked();
                }
            }
        }

        // Логотип YouTube
        Image {
            id: ytLogo
            source: "../Assets/ytlogo.png"
            anchors.left: showBackButton ? backIcon.right : parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            height: 32
            fillMode: Image.PreserveAspectFit
        }

        // Кнопка поиска
        Image {
            id: searchIcon
            source: "../Assets/search.png"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 16
            width: 24
            height: 24
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    isSearchMode = true;
                    searchInput.forceActiveFocus();
                }
            }
        }
    }

    // Режим поиска
    Item {
        id: searchMode
        anchors.fill: parent
        visible: isSearchMode

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            color: "#222222"
            radius: 4

            // --- КНОПКА ПОИСКА (НАДЕЖНЫЙ ТРИГГЕР) ---
            Rectangle {
                id: searchBtn
                anchors.right: closeSearchBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40
                color: "transparent"

                Image {
                    anchors.centerIn: parent
                    source: "../Assets/search.png" // Или ваш путь к иконке
                    width: 24; height: 24
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (searchInput.text.length > 0) {
                            navbarRoot.searchRequested(searchInput.text);
                            isSearchMode = false;
                            searchInput.text = "";
                            searchInput.focus = false; // Скрываем клавиатуру
                        }
                    }
                }
            }

            // Кнопка закрытия (X)
            Text {
                id: closeSearchBtn
                text: "X"
                color: "#717171"
                font.pixelSize: 18
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 12

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: {
                        isSearchMode = false;
                        searchInput.text = "";
                        searchInput.focus = false;
                    }
                }
            }

            // Поле ввода
            TextInput {
                id: searchInput
                anchors.left: parent.left
                anchors.right: searchBtn.left // Теперь ограничиваемся кнопкой поиска
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                color: "white"
                font.pixelSize: 16

                Text {
                    text: qsTr("Поиск")
                    color: "gray"
                    font.pixelSize: 16
                    visible: parent.text.length === 0 && !parent.activeFocus
                }
            }
        }
    }

    // Нижняя граница (разделитель)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#222222"
    }
}
