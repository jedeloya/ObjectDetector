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
    void onDetectionsReady(int batchIndex, const QList<YoloParser::Detection>& detections);
private:
    CameraModel *m_camera = nullptr;
    QString m_inferenceTime;
    QString m_parseTime;
    QVariantList m_detections;
};

#endif // DETECTIONCONTROLLER_H
