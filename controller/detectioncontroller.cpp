#include "detectioncontroller.h"
#include "model/cameramodel.hpp"

#include <QTimer>
#include <QDebug>

DetectionController::DetectionController(QObject *parent)
    : QObject{parent}
{
    m_camera = new CameraModel(this);
}

void DetectionController::handleFrame(const QVideoFrame &frame)
{
    if(!frame.isValid()) return;
    if(!m_camera) return;

    m_camera->processFrameInBatch(frame);
}

void DetectionController::setVideoSink(QVideoSink* sink)
{
    if (!sink) return;

    connect(sink, &QVideoSink::videoFrameChanged,
            this, &DetectionController::handleFrame);
}
