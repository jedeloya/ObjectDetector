import QtQuick
import QtQuick.Controls
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
        videoSink: videoOutput1.videoSink
    }

    MediaDevices {
        id: mediaDevices
    }

    VideoOutput {
        id: videoOutput1
        anchors.fill: parent
    }

    ComboBox {
        id: cameraSelector
        anchors.left: parent.left
        model: mediaDevices.videoInputs
        textRole: "description"
        valueRole: "id"
    }

    Component.onCompleted: cameraPermission.request()

    // Canvas to display object detection bounding boxes
    // Canvas {
    //     id: detectionCanvas
    //     anchors.fill: parent
    //     onPaint: {
    //         var ctx = getContext("2d")
    //         controller.detections.forEach(function (detection) {
    //             ctx.beginPath()
    //             ctx.rect(detection.x, detection.y, detection.width,
    //                      detection.height)
    //             ctx.lineWidth = 3
    //             ctx.strokeStyle = 'red'
    //             ctx.stroke()
    //         })
    //     }
    // }

    // Controller to handle the camera feed and object detection
}
