#include "detectioncontroller.h"
#include "model/cameramodel.hpp"

#include <QTimer>
#include <QDebug>
#include <QVariant>

DetectionController::DetectionController(QObject *parent)
    : QObject{parent}
{
    m_camera = new CameraModel(this);
    qRegisterMetaType<QRect>("QRect");
    connect(m_camera, &CameraModel::inferenceFinished,
            this, [this](double ms){
        m_inferenceTime = "Inference time: " + QString::number(ms, 'f', 2) + " ms";
        emit inferenceTimeChanged();
    });
    connect(m_camera, &CameraModel::parsingFinished,
            this, [this](double ms){
        m_parseTime = "Parse time: " + QString::number(ms, 'f', 2) + " ms";
        emit parseTimeChanged();
    });
    connect(m_camera, &CameraModel::detectionsReady,
            this, &DetectionController::onDetectionsReady);
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

void DetectionController::onDetectionsReady(int batchIndex, const QList<YoloParser::Detection> &detections)
{
    QVariantList list;
    list.reserve(detections.size());
    Q_UNUSED(batchIndex);
    m_detections.clear();
    for(const auto& det : detections) {
        QVariantMap map;
        map["rect"] = det.rect;
        map["label"] = det.label;
        map["score"] = det.score;
        map["origH"] = det.origH;
        map["origW"] = det.origW;
        list.append(map);
    }
    m_detections = list;
    emit detectionsChanged();
}
