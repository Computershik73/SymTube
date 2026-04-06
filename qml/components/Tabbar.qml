import QtQuick 1.0

Rectangle {
    id: tabbarRoot
    color: "black"

    signal tabClicked(string tabName)
    property string activeTab: "Home"

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 2
        color: "#222222"
    }

    Row {
        anchors.fill: parent
        anchors.topMargin: 2

        // 1. Главная
        Item {
            width: parent.width / 4
            height: parent.height
            
            Column {
                anchors.centerIn: parent
                spacing: 2
                Image {
                    source: activeTab === "Home" ? "../Assets/tabbar/home-icon-active.png" : "../Assets/tabbar/home-icon.png"
                    width: 24
                    height: 24
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Главная"
                    color: "white"
                    font.pixelSize: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    activeTab = "Home";
                    tabbarRoot.tabClicked("Home");
                }
            }
        }

        // 2. Shorts (Disabled)
        Item {
            width: parent.width / 4
            height: parent.height
            opacity: 0.5 // Отключено
            
            Column {
                anchors.centerIn: parent
                spacing: 2
                Image {
                    source: "../Assets/tabbar/shorts-icon.png"
                    width: 24
                    height: 24
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Shorts"
                    color: "gray"
                    font.pixelSize: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // 3. Подписки
        Item {
            width: parent.width / 4
            height: parent.height
            // Проверка на токен
            opacity: Config.userToken !== "" ? 1.0 : 0.5
            
            Column {
                anchors.centerIn: parent
                spacing: 2
                Image {
                    source: activeTab === "Subscriptions" ? "../Assets/tabbar/sub-icon-active.png" : "../Assets/tabbar/sub-icon.png"
                    width: 24
                    height: 24
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Подписки"
                    color: Config.userToken !== "" ? "white" : "gray"
                    font.pixelSize: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (Config.userToken !== "") {
                        activeTab = "Subscriptions";
                        tabbarRoot.tabClicked("Subscriptions");
                    }
                }
            }
        }

        // 4. Аккаунт (Вы)
        Item {
            width: parent.width / 4
            height: parent.height
            
            Column {
                anchors.centerIn: parent
                spacing: 2
                Image {
                    source: activeTab === "Account" ? "../Assets/tabbar/user-icon-active.png" : "../Assets/tabbar/user-icon.png"
                    width: 24
                    height: 24
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Вы"
                    color: "white"
                    font.pixelSize: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    activeTab = "Account";
                    tabbarRoot.tabClicked("Account");
                }
            }
        }
    }
}