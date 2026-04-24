import QtQuick 1.0
import "../components"

Rectangle {
    id: searchPage
    anchors.fill: parent
    color: "black"

    property variant searchResults:[]
    property string currentQuery: ""

    Connections {
        target: ApiManager
        onSearchResultsReady: {
            loadingIndicator.visible = false
            searchResults = videos
        }
        onRequestFailed: {
            if (endpoint === "SearchVideos") {
                loadingIndicator.visible = false
                errorText.visible = true
            }
        }
    }

    function performSearch(query) {
        currentQuery = query
        searchResults =[]
        loadingIndicator.visible = true
        errorText.visible = false
        ApiManager.searchVideos(query)
    }

    Text {
        id: loadingIndicator
        text: qsTr("Поиск...")
        color: "white"
        font.pixelSize: 18
        anchors.centerIn: parent
        visible: false
    }

    Text {
        id: errorText
        text: qsTr("Ничего не найдено. Нажмите для повтора.")
        color: "gray"
        font.pixelSize: 16
        anchors.centerIn: parent
        visible: false
        MouseArea {
            anchors.fill: parent
            onClicked: performSearch(currentQuery)
        }
    }

    ListView {
        id: resultsList
        anchors.fill: parent
        model: searchResults
        spacing: 10
        delegate: VideoCard {
            modelData: model.modelData
            onClicked: {
                root.navigateToVideo(videoId)
            }
        }
    }
}
