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
