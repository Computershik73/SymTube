import QtQuick 1.0
import "../components"

Rectangle {
    id: historyPage
    anchors.fill: parent
    color: "black"

    property variant historyModel:[]

    function onNavigatedTo() {
        historyModel = HistoryManager.getHistory();
    }

    Connections {
        target: HistoryManager
        onHistoryChanged: {
            historyModel = HistoryManager.getHistory();
        }
    }

    Text {
        id: header
        text: qsTr("История просмотров")
        color: "white"
        font.pixelSize: 22
        font.bold: true
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
    }

    Text {
        text: qsTr("История пуста")
        color: "gray"
        font.pixelSize: 16
        anchors.centerIn: parent
        visible: historyModel.length === 0
    }

    ListView {
        id: historyList
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 16
        model: historyModel
        spacing: 10
        
        delegate: VideoCard {
            modelData: model.modelData
            onClicked: {
                root.navigateToVideo(videoId)
            }
        }
    }
}
