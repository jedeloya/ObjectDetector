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

#ifndef DETECTIONCONTROLLER_H
#define DETECTIONCONTROLLER_H

#include <QObject>
#include <QVideoFrame>
#include <QVideoSink>

#include "model/yoloparser.h"

class CameraModel;

class DetectionController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVideoSink* videoSink WRITE setVideoSink)
    Q_PROPERTY(QString inferenceTime READ inferenceTime NOTIFY inferenceTimeChanged)
    Q_PROPERTY(QString parseTime READ parseTime NOTIFY parseTimeChanged)
    Q_PROPERTY(QVariantList detections READ detections NOTIFY detectionsChanged FINAL)
public:
    explicit DetectionController(QObject *parent = nullptr);
    void setVideoSink(QVideoSink* sink);
    QString inferenceTime() const { return m_inferenceTime; }
    QString parseTime() const { return m_parseTime; }
    QVariantList detections() const { return m_detections; }

signals:
    void detectionsReady();
    void inferenceTimeChanged();
    void parseTimeChanged();
    void detectionsChanged();

private slots:
    void handleFrame(const QVideoFrame& frame);
    void onDetectionsReady(int batchIndex, const QList<Detection>& detections);
private:
    CameraModel *m_camera = nullptr;
    QString m_inferenceTime;
    QString m_parseTime;
    QVariantList m_detections;
};

#endif // DETECTIONCONTROLLER_H
