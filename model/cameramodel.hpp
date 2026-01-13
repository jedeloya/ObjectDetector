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

#ifndef CAMERAMODEL_H
#define CAMERAMODEL_H

#include <QObject>
#include <QList>
#include <QString>
#include <QVideoFrame>
#include <QVariantList>
#include <QVector>

#include "yoloparser.h"

#ifdef __OBJC__
#import <CoreML/CoreML.h>
#import <CoreVideo/CoreVideo.h>
#endif


class CameraModel : public QObject
{
    Q_OBJECT

public:
    explicit CameraModel(QObject *parent = nullptr);
    ~CameraModel();

    QImage getFrame();

    void processFrameInBatch(const QVideoFrame& frame);
    void processFrame(const QVideoFrame& frame );

private:
    YoloParser *parser = nullptr;
    QThread *parseThread = nullptr;
    std::atomic_bool batchInFligt{false};
#ifdef __OBJC__
    std::vector<CVPixelBufferRef> inFlightFrames;
#endif
    QVector<YoloParser::LetterboxInfo> letterboxInfo;

    void loadModel();
signals:
    void rawBatchReady(QByteArray data, int batchCount, int channels, int boxes, QVector<YoloParser::LetterboxInfo> letterboxInfo);
    void inferenceFinished(double ms);
    void parsingFinished(double ms);
    void detectionsReady(int batchIdx, QList<Detection> detections);
private slots:
    void handleDetections(int batchIndex, QList<Detection> detections);
#ifdef __OBJC__
    void processWithCoreML(CVPixelBufferRef pb);
    void processBatch(std::vector<CVPixelBufferRef> frames);
    MLModel *model;  // CoreML model
    std::vector<CVPixelBufferRef> batchFrames;
#endif
};

#endif // CAMERAMODEL_H
