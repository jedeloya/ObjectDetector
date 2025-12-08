#ifndef CAMERAMODEL_H
#define CAMERAMODEL_H

#include <QObject>
#include <QRect>
#include <QList>
#include <QString>
#include <QVideoFrame>

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

    struct Detection {
        QRect rect;
        QString label;
        float score;
    };

private:
    void loadModel();
#ifdef __OBJC__
    void processWithCoreML(CVPixelBufferRef pb);
    void processBatch();
    MLModel *model;  // CoreML model
    std::vector<CVPixelBufferRef> batchFrames;
#endif
};

#endif // CAMERAMODEL_H
