import QtQuick 1.0

Item {
    id: rootCombo
    width: 200
    height: 40
    
    // ВАЖНО: Если список открыт, мы резко повышаем z-индекс, 
    // чтобы он всплывал поверх всех остальных элементов на странице.
    z: isOpen ? 1000 : 1

    property string text: ""
    property variant model:[]
    property bool isOpen: false

    // Синхронизация текста извне
    onTextChanged: {
        if (inputField.text !== text) {
            inputField.text = text;
        }
    }

    // Основное поле (Текст + Кнопка)
    Rectangle {
        id: bgBox
        anchors.fill: parent
        color: "#1F1F1F"
        border.color: "#333333"
        border.width: 1
        radius: 5

        TextInput {
            id: inputField
            anchors.left: parent.left
            anchors.right: arrowBtn.left
            anchors.verticalCenter: parent.verticalCenter // ЭТО ПРАВИЛЬНЫЙ СПОСОБ
            anchors.margins: 10
            color: "white"
            font.pixelSize: 16
            selectByMouse: true

            onTextChanged: {
                if (rootCombo.text !== text) {
                    rootCombo.text = text;
                }
            }
        }

        // Кнопка со стрелочкой
        Rectangle {
            id: arrowBtn
            width: 40
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "transparent"
            
            // Векторная стрелочка через шрифт
            Text {
                text: "▼"
                color: "gray"
                font.pixelSize: 14
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    rootCombo.isOpen = !rootCombo.isOpen;
                    if (rootCombo.isOpen) {
                        inputField.focus = false; // Прячем клавиатуру при открытии списка
                    }
                }
            }
        }
    }

    // Выпадающий список
    Rectangle {
        id: dropDown
        anchors.top: bgBox.bottom
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        // Динамическая высота: до 4-х элементов, дальше скролл
        height: Math.min(rootCombo.model.length * 40, 160)
        color: "#2A2A2A"
        border.color: "#555555"
        border.width: 1
        radius: 5
        visible: rootCombo.isOpen
        clip: true 

        ListView {
            anchors.fill: parent
            model: rootCombo.model
            boundsBehavior: Flickable.StopAtBounds
            
            delegate: Rectangle {
                width: parent.width
                height: 40
                color: itemMouseArea.pressed ? "#007ACC" : "transparent"
                
                Text {
                    text: modelData
                    color: "white"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    elide: Text.ElideRight
                    width: parent.width - 20
                }
                
                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent
                    onClicked: {
                        rootCombo.text = modelData;
                        rootCombo.isOpen = false;
                    }
                }
            }
        }
    }
}
