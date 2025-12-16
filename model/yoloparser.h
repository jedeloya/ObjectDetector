#ifndef YOLOPARSER_H
#define YOLOPARSER_H

#include <QObject>
#include <QRect>

constexpr float CONF_THRESH = 0.45f;
constexpr float IOU_THRESH  = 0.45f;
constexpr int INPUT_W = 640;
constexpr int INPUT_H = 640;

class YoloParser : public QObject
{
    Q_OBJECT
public:
    explicit YoloParser(QObject *parent = nullptr);

    struct TensorShape {
        int batch;
        int channels;
        int boxes;
    };

    struct Detection {
        int classId;
        QRect rect;
        QString label;
        float score;
        int origW = 0;
        int origH = 0;
    };

    struct LetterboxInfo {
        float scale = 1.f;
        int padX = 0;
        int padY = 0;
        int origW = 0;
        int origH = 0;
    };

    // Public API for parsing YOLO tensors
    static QList<Detection> parse(
        const float* data,
        const TensorShape &shape,
        const LetterboxInfo& letterbox,
        int batchIndex,
        float confThreshold = CONF_THRESH,
        float iouThreshold  = IOU_THRESH,
        int inputW = INPUT_W,
        int inputH = INPUT_H);

    // Parse a batch of YOLO outputs
    // NOTE: parseBatch WILL take the ownership of dataPtr and will free() it.
    void parseBatch(const QByteArray& data,
                    int batchCount,
                    int channels,
                    int boxes,
                    QVector<LetterboxInfo> letterboxInfo);

    static const QStringList YOLO_CLASSES;

signals:
    void detectionsReady(int batchIndex, QList<YoloParser::Detection> detections);
    void parsingFinished(double ms);
private:
    static float sigmoid(float x);
    static float iou(float ax, float ay, float aw, float ah,
              float bx, float by, float bw, float bh);
    static std::vector<int> nms(const std::vector<float>& xs,
                         const std::vector<float>& ys,
                         const std::vector<float>& ws,
                         const std::vector<float>& hs,
                         const std::vector<float>& scores,
                         float iouThreshold);
};

Q_DECLARE_METATYPE(YoloParser::Detection)
Q_DECLARE_METATYPE(QList<YoloParser::Detection>)
Q_DECLARE_METATYPE(YoloParser::LetterboxInfo)

#endif // YOLOPARSER_H
