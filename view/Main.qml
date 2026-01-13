/*
 * ObjectRecognition
 *
 * Copyright (C) 2025 José de Jesús Deloya Cruz
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// SPDX-License-Identifier: GPL-3.0-or-later
// Project: ObjectRecognition
// Copyright (C) 2025 José de Jesús Deloya Cruz

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtMultimedia
import QtCore

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

    Component.onCompleted: {
        cameraPermission.request()
        controller.videoSink = videoOutput1.videoSink
    }

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
