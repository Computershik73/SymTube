import QtQuick 1.0

Rectangle {
    id: navbarRoot
    color: "#111111"

    signal searchRequested(string query)
    signal backClicked()

    property bool showBackButton: false
    property bool isSearchMode: false

    Item {
        id: defaultMode
        anchors.fill: parent
        visible: !isSearchMode

        Image {
            id: backIcon
            source: "../Assets/player/back.png"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 16
            width: 24; height: 24
            visible: showBackButton

            MouseArea {
                anchors.fill: parent
                onClicked: { navbarRoot.backClicked(); }
            }
        }

        Image {
            id: ytLogo
            source: "../Assets/ytlogo.png"
            anchors.left: showBackButton ? backIcon.right : parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            height: 32
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: searchIcon
            source: "../Assets/search.png"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 16
            width: 24; height: 24

            MouseArea {
                anchors.fill: parent
                anchors.margins: -15
                onClicked: {
                    isSearchMode = true;
                    searchInput.forceActiveFocus();
                }
            }
        }
    }

    Item {
        id: searchMode
        anchors.fill: parent
        visible: isSearchMode
        z: 100

        property variant suggestionsModel:[]

        Connections {
            target: ApiManager
            onSearchSuggestionsReady: {
                if (isSearchMode) searchMode.suggestionsModel = suggestions;
            }
        }

        Timer {
            id: searchDebounce
            interval: 350
            repeat: false
            onTriggered: {
                if (searchInput.text.length > 0) ApiManager.getSearchSuggestions(searchInput.text);
                else searchMode.suggestionsModel =[];
            }
        }

        Rectangle {
            id: searchBarBg
            anchors.fill: parent
            anchors.margins: 8
            color: "#222222"
            radius: 4

            Rectangle {
                id: searchBtn
                anchors.right: closeSearchBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 50; height: parent.height
                color: "transparent"

                Image {
                    anchors.centerIn: parent
                    source: "../Assets/search.png"
                    width: 24; height: 24
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (searchInput.text.length > 0) {
                            navbarRoot.searchRequested(searchInput.text);
                            isSearchMode = false;
                            searchInput.text = "";
                            searchInput.focus = false;
                            searchMode.suggestionsModel =[];
                        }
                    }
                }
            }

            Text {
                id: closeSearchBtn
                text: "X"
                color: "#717171"
                font.pixelSize: 18
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 12
                width: 50; height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: {
                        isSearchMode = false;
                        searchInput.text = "";
                        searchInput.focus = false;
                        searchMode.suggestionsModel =[];
                    }
                }
            }

            TextInput {
                id: searchInput
                anchors.left: parent.left
                anchors.right: searchBtn.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                color: "white"
                font.pixelSize: 16

                onTextChanged: {
                    if (isSearchMode && activeFocus) {
                        if (text.length > 0) searchDebounce.restart();
                        else {
                            searchDebounce.stop();
                            searchMode.suggestionsModel =[];
                        }
                    }
                }

                onAccepted: {
                    if (text.length > 0) {
                        navbarRoot.searchRequested(text);
                        isSearchMode = false;
                        text = "";
                        focus = false;
                        searchMode.suggestionsModel =[];
                    }
                }

                Text {
                    text: qsTr("Поиск")
                    color: "gray"
                    font.pixelSize: 16
                    visible: parent.text.length === 0 && !parent.activeFocus
                }
            }
        }

        Rectangle {
            id: dropdown
            anchors.top: searchBarBg.bottom
            anchors.left: searchBarBg.left
            anchors.right: searchBarBg.right
            anchors.topMargin: 2
            height: Math.min(suggestionsList.count * 40, 240)
            color: "#222222"
            border.color: "#333"
            border.width: 1
            radius: 4
            visible: searchMode.suggestionsModel.length > 0 && isSearchMode

            ListView {
                id: suggestionsList
                anchors.fill: parent
                model: searchMode.suggestionsModel
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: parent.width
                    height: 40
                    color: mouseArea.pressed ? "#444" : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: "white"
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        onClicked: {
                            searchInput.text = modelData;
                            navbarRoot.searchRequested(modelData);
                            isSearchMode = false;
                            searchInput.focus = false;
                            searchMode.suggestionsModel =[];
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#222222"
    }
}
