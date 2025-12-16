import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtMultimedia
import QtCore

import Detector 1.0

Window {
    width: 640
    height: 640
    visible: true
    title: qsTr("Object detector.")

    CameraPermission {
        id: cameraPermission
    }

    Camera {
        id: camera
        cameraDevice: mediaDevices.videoInputs[cameraSelector.currentIndex]
        active: cameraPermission.status === Qt.PermissionStatus.Granted
        onErrorOccurred: console.log("Camera error:", errorString)
    }

    CaptureSession {
        id: captureSession
        camera: camera
        videoOutput: videoOutput1
    }

    Controller {
        id: controller
        videoSink: cameraPermission.status === Qt.PermissionStatus.Granted
                   ? videoOutput1.videoSink
                   : null
    }

    MediaDevices {
        id: mediaDevices
    }

    VideoOutput {
        id: videoOutput1
        anchors.fill: parent
        fillMode: VideoOutput.Stretch
    }

    ComboBox {
        id: cameraSelector
        anchors.left: parent.left
        model: mediaDevices.videoInputs
        textRole: "description"
        valueRole: "id"
        background: Rectangle {
            color: "white"
            radius: 6
        }
    }

    Column {
        id: perfOverlay
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 4

        Rectangle {
            color: "#66000000"
            radius: 6
            width: 200
            height: 40

            Text {
                anchors.centerIn: parent
                text: controller.inferenceTime
                font.pixelSize: 14
                color: "lime"
            }
        }

        Rectangle {
            color: "#66000000"
            radius: 6
            width: 200
            height: 40

            Text {
                anchors.centerIn: parent
                text: controller.parseTime
                font.pixelSize: 14
                color: "cyan"
            }
        }
    }

    Component.onCompleted: cameraPermission.request()

    Rectangle {
        x: videoOutput1.contentRect.x
        y: videoOutput1.contentRect.y
        width: videoOutput1.contentRect.width
        height: videoOutput1.contentRect.height
        border.color: "yellow"
        color: "transparent"
    }

    Item {
        anchors.fill: videoOutput1

        Repeater {
            model: controller.detections

            Rectangle {
                // Map model-space → screen-space
                x: modelData.rect.x * videoOutput1.width / modelData.origW + videoOutput1.contentRect.x
                y: modelData.rect.y * videoOutput1.height / modelData.origH + videoOutput1.contentRect.y
                width: modelData.rect.width * videoOutput1.width / modelData.origW
                height: modelData.rect.height * videoOutput1.height / modelData.origH
                onWidthChanged: console.log("Width changed to", width)
                onHeightChanged: console.log("Height changed to", height)
                onXChanged: console.log("X changed to", x)
                onYChanged: console.log("Y changed to", y)

                color: "transparent"
                border.color: "red"
                border.width: 3

                Text {
                    text: modelData.label
                    color: "lime"
                    font.pixelSize: 14
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 4
                }
            }
        }
    }
}
