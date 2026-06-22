import QtQuick 1.0
import "../components"

Rectangle {
    id: cardRoot
    width: parent.width
    height: 300
    color: "black"

    property variant modelData

    signal clicked(string videoId)

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 12

        Rectangle {
            width: parent.width
            height: 202
            color: "#1A1A1A"
            radius: 8
            clip: true

            SafeImage {
                anchors.fill: parent
                source: modelData && modelData.thumbnail ? modelData.thumbnail.replace("https", "http") : ""
                fillMode: Image.PreserveAspectCrop
                clip: true
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                color: "#CC000000"
                width: durationText.width + 12
                height: durationText.height + 4
                radius: 4
                visible: modelData && modelData.duration !== undefined && modelData.duration !== ""

                Text {
                    id: durationText
                    anchors.centerIn: parent
                    text: modelData && modelData.duration ? modelData.duration : ""
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }
        }

        Row {
            width: parent.width
            spacing: 12

            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: "#333333"
                clip: true
                visible: Config.enableChannelThumbnails && modelData && modelData.channel_thumbnail !== undefined && modelData.channel_thumbnail !== ""

                SafeImage {
                    anchors.fill: parent
                    source: modelData && modelData.channel_thumbnail ? modelData.channel_thumbnail : "../Assets/placeholder.png"
                    fillMode: Image.PreserveAspectCrop
                }
            }

            Column {
                width: parent.width - (parent.children[0].visible ? 48 : 0)
                spacing: 4

                Text {
                    text: modelData && modelData.title ? modelData.title : ""
                    color: "white"
                    font.pixelSize: 16
                    width: parent.width
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight

                    height: 38
                    clip: true
                }

                Text {
                    text: modelData && modelData.author ? modelData.author : ""
                    color: "gray"
                    font.pixelSize: 14
                    width: parent.width
                    elide: Text.ElideRight

                }

                Row {
                    spacing: 4
                    Text {
                        text: modelData && modelData.views ? modelData.views : ""
                        color: "#AAAAAA"
                        font.pixelSize: 12
                    }
                    Text {
                        text: " • "
                        color: "#AAAAAA"
                        font.pixelSize: 12
                        visible: modelData && modelData.published_at !== undefined && modelData.published_at !== ""
                    }
                    Text {
                        text: modelData && modelData.published_at ? modelData.published_at : ""
                        color: "#AAAAAA"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (modelData && modelData.video_id) {
                cardRoot.clicked(modelData.video_id);
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: "#111111"
    }
}
