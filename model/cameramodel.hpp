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
    void detectionsReady(int batchIdx, QList<YoloParser::Detection> detections);
private slots:
    void handleDetections(int batchIndex, QList<YoloParser::Detection> detections);
#ifdef __OBJC__
    void processWithCoreML(CVPixelBufferRef pb);
    void processBatch(std::vector<CVPixelBufferRef> frames);
    MLModel *model;  // CoreML model
    std::vector<CVPixelBufferRef> batchFrames;
#endif
};

#endif // CAMERAMODEL_H
