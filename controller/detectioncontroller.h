#ifndef DETECTIONCONTROLLER_H
#define DETECTIONCONTROLLER_H

#include <QObject>
#include <QVideoFrame>
#include <QVideoSink>

class CameraModel;

class DetectionController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVideoSink* videoSink WRITE setVideoSink)
public:
    explicit DetectionController(QObject *parent = nullptr);
    void setVideoSink(QVideoSink* sink);

signals:
    void detectionsReady();

private slots:
    void handleFrame(const QVideoFrame& frame);
private:
    CameraModel *m_camera = nullptr;
};

#endif // DETECTIONCONTROLLER_H
