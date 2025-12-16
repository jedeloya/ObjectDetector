#include "yoloparser.h"
#include <algorithm>
#include <numeric>
#include <unordered_map>
#include <cmath>

#include <QDebug>
#include <QFuture>
#include <QtConcurrent/QtConcurrent>

const QStringList YoloParser::YOLO_CLASSES = {
    "person","bicycle","car","motorcycle","airplane","bus","train","truck",
    "boat","traffic light","fire hydrant","stop sign","parking meter","bench",
    "bird","cat","dog","horse","sheep","cow","elephant","bear","zebra",
    "giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee",
    "skis","snowboard","sports ball","kite","baseball bat","baseball glove",
    "skateboard","surfboard","tennis racket","bottle","wine glass","cup",
    "fork","knife","spoon","bowl","banana","apple","sandwich","orange",
    "broccoli","carrot","hot dog","pizza","donut","cake","chair","couch",
    "potted plant","bed","dining table","toilet","tv","laptop","mouse",
    "remote","keyboard","cell phone","microwave","oven","toaster","sink",
    "refrigerator","book","clock","vase","scissors","teddy bear","hair drier",
    "toothbrush"
};

YoloParser::YoloParser(QObject *parent)
    : QObject{parent}
{}

/**
 * @brief This function computes the Intersection over Union (IoU) between two rectangles.
 * @param a
 * @param b
 * @return
 */
float YoloParser::iou(float ax, float ay, float aw, float ah,
                      float bx, float by, float bw, float bh) {
    float ax1 = ax - aw / 2.f;
    float ay1 = ay - ah / 2.f;
    float ax2 = ax + aw / 2.f;
    float ay2 = ay + ah / 2.f;

    float bx1 = bx - bw / 2.f;
    float by1 = by - bh / 2.f;
    float bx2 = bx + bw / 2.f;
    float by2 = by + bh / 2.f;

    float inter_x1 = std::max(ax1, bx1);
    float inter_y1 = std::max(ay1, by1);
    float inter_x2 = std::min(ax2, bx2);
    float inter_y2 = std::min(ay2, by2);

    float w = std::max(0.f, inter_x2 - inter_x1);
    float h = std::max(0.f, inter_y2 - inter_y1);

    float inter = w * h;
    float areaA = (ax2 - ax1) * (ay2-ay1);
    float areaB = (bx2 - bx1) * (by2-by1);
    float unionArea = areaA +  areaB - inter;
    return unionArea > 0.0f ? inter / unionArea : 0.0f;
}

/**
 * @brief This function performs Non-Maximum Suppression (NMS) on a list of bounding boxes.
 * @param boxes
 * @param iouThreshold
 * @return
 */
std::vector<int> YoloParser::nms(const std::vector<float>& xs,
                           const std::vector<float>& ys,
                           const std::vector<float>& ws,
                           const std::vector<float>& hs,
                           const std::vector<float>& scores,
                           float iouThreshold) {
    size_t N = scores.size();
    std::vector<int> idxs(N);
    std::iota(idxs.begin(), idxs.end(), 0);

    // Sort indexes based on scores in descending order
    std::sort(idxs.begin(), idxs.end(),
              [&scores](int i1, int i2) { return scores[i1] > scores[i2]; });
    std::vector<char> removed(N,0);
    std::vector<int> keep;
    keep.reserve(N);
    for(size_t _i = 0; _i < N; ++_i) {
        int i = idxs[_i];
        if(removed[i]) continue;
        keep.push_back(i);
        // Compare with remaining boxes
        for(size_t _j = _i + 1; _j < N; ++_j) {
            int j = idxs[_j];
            if(removed[j]) continue;
            if(iou(xs[i], ys[i], ws[i], hs[i],
                   xs[j], ys[j], ws[j], hs[j]) > iouThreshold) {
                removed[j] = 1;
            }
        }
    }
    return keep;
}

/**
 * @brief This function parses the YOLO output tensor to extract detections.
 * @param data, pointer to the output tensor data
 * @param shape, shape of the tensor
 * @param batchIndex, index of the batch to parse
 * @param confThreshold, confidence threshold
 * @param iouThreshold, IOU threshold
 * @param inputW, width of the input image
 * @param inputH, height of the input image
 * @return
 */
QList<YoloParser::Detection> YoloParser::parse(
    const float* data,
    const TensorShape &shape,
    const LetterboxInfo& letterbox,
    int batchIndex,
    float confThreshold,
    float iouThreshold,
    int inputW,
    int inputH)
{
    QList<YoloParser::Detection> detections;
    if(!data) return detections;
    if(batchIndex < 0 || batchIndex >= shape.batch) return detections;

    int C = shape.channels;
    int N = shape.boxes;

    qDebug() << "Channels:" << C << "Boxes:" << N << "BatchIndex" << batchIndex;

    if(C < 6) return detections; // At least x,y,w,h,obj + 1 class

    const long classOffset = 4;
    const int classes = C - 4;

    //Offset to the start of the batch
    const int batchOffset = batchIndex * (int)(C) * (int)(N);

    std::vector<float> cand_cx; cand_cx.reserve(256);
    std::vector<float> cand_cy; cand_cy.reserve(256);
    std::vector<float> cand_w;  cand_w .reserve(256);
    std::vector<float> cand_h;  cand_h .reserve(256);
    std::vector<float> cand_score; cand_score.reserve(256);
    std::vector<int> cand_class; cand_class.reserve(256);

    for(int i = 0; i < N; ++i) {
        float cx = data[batchOffset + 0*N + i];
        float cy = data[batchOffset + 1*N + i];
        float w  = data[batchOffset + 2*N + i];
        float h  = data[batchOffset + 3*N + i];

        // Find best class
        int bestClass = -1;
        float bestScore = -1e9f;
        for(int c = 0; c < classes; c++) {
            float v = data[batchOffset + (classOffset+c)*N + i];
            if (v > bestScore) {
                bestScore = v;
                bestClass = c;
            }
        }

        if(bestScore < confThreshold) continue;

        //keep normalized cx/cy/w/h scaled to pixel coords (defer QRect creation)
        cand_cx.push_back(cx);
        cand_cy.push_back(cy);
        cand_w .push_back(w);
        cand_h .push_back(h);
        cand_score.push_back(bestScore);
        cand_class.push_back(bestClass);
    }

    if(cand_score.empty()) return detections;

    // Now perform class-wise grouping and NMS
    // Build maps of indexes per class
    std::unordered_map<int, std::vector<int>> classBuckets;
    classBuckets.reserve(16);
    const int K = static_cast<int>(cand_score.size());
    //Group indices by class

    for(int i = 0; i < K; ++i)
        classBuckets[cand_class[i]].push_back(i);

    //For each class, perform NMS
    for (const auto& kv : classBuckets) {
        const std::vector<int>& indexes = kv.second;
        if(indexes.empty()) continue;

        std::vector<float> xs, ys, ws, hs, ss;
        xs.reserve(indexes.size());
        ys.reserve(indexes.size());
        ws .reserve(indexes.size());
        hs .reserve(indexes.size());
        ss .reserve(indexes.size());
        for(int idx : indexes) {
            xs.push_back(cand_cx[idx]);
            ys.push_back(cand_cy[idx]);
            ws.push_back(cand_w [idx]);
            hs.push_back(cand_h [idx]);
            ss.push_back(cand_score[idx]);
        }
        std::vector<int> keep = nms(xs, ys, ws, hs, ss, iouThreshold);
        for(int k : keep) {
            int id = indexes[k];

            float x = (cand_cx[id] - cand_w[id]/2.f - letterbox.padX) / letterbox.scale;
            float y = (cand_cy[id] - cand_h[id]/2.f - letterbox.padY) / letterbox.scale;
            float bw = cand_w[id] / letterbox.scale;
            float bh = cand_h[id] / letterbox.scale;

            x = std::clamp(x, 0.f, float(letterbox.origW - 1));
            y =  std::clamp(y, 0.f, float(letterbox.origH - 1));

            float x2 = x + bw;
            float y2 = y + bh;

            x2 = std::clamp(x2, 0.f, float(letterbox.origW));
            y2 = std::clamp(y2, 0.f, float(letterbox.origH));

            float finalW = x2 - x;
            float finalH = y2 - y;

            if (finalW <= 1 || finalH <= 1)
                continue;

            Detection det;
            det.classId = cand_class[id];
            det.rect = QRect(int(x),
                             int(y),
                             int(finalW),
                             int(finalH));
            det.label = YOLO_CLASSES.value(cand_class[id], "unknown");
            det.score = cand_score[id];
            det.origW = letterbox.origW;
            det.origH = letterbox.origH;
            qWarning() << "detection:"
                       << "classId" << det.classId
                       << "label" << det.label
                       << "score" << det.score
                       << "rect" << det.rect
                       << "origW" << det.origW
                       << "origH" << det.origH;
            detections.append(det);
        }
    }

    return detections;
}

/**
 * @brief This function parses a batch of YOLO outputs.
 * @param blob, byte array containing the output tensor data
 * @param batchCount, number of batches
 * @param channels, number of channels
 * @param boxes, number of boxes
 */
void YoloParser::parseBatch(const QByteArray& blob,
                            int batchCount,
                            int channels,
                            int boxes,
                            QVector<LetterboxInfo> letterboxInfo)
{
    if (channels < 6 || channels > 512) {
        qWarning() << "Invalid channel count:" << channels;
        return;
    }

    if (boxes <= 0 || boxes > 20000) {
        qWarning() << "Invalid box count:" << boxes;
        return;
    }

    if (batchCount <= 0 || batchCount > 4) {
        qWarning() << "Invalid batch count:" << batchCount;
        return;
    }
    if(letterboxInfo.size() < batchCount) {
        qWarning() << "YoloParser::parseBatch letterboxInfo size"
                   << letterboxInfo.size()
                   << "less than batchCount" << batchCount;
        return;
    }
    qDebug() << "ParseBatch Batch:" << batchCount << "Channels:" << channels << "Boxes:" << boxes;
    if(blob.isEmpty()) {
        qWarning() << "YoloParser::parseBatch received empty blob!";
        return;
    }
    if (letterboxInfo.size() < batchCount) {
        qWarning() << "letterboxInfo size mismatch"
                   << letterboxInfo.size()
                   << "batchCount" << batchCount;
        return;
    }
    const float * data = reinterpret_cast<const float*>(blob.constData());
    TensorShape shape {batchCount, channels, boxes};
    qDebug() << "Shape Batch:" << shape.batch << "Channels:" << shape.channels << "Boxes:" << shape.boxes;

    auto startParse = std::chrono::high_resolution_clock::now();

    QFuture<QList<Detection>> futureDetections0 = QtConcurrent::run([=]() {
        return YoloParser::parse(data, shape, letterboxInfo.at(0), 0);
    });
    QFuture<QList<Detection>> futureDetections1;
    if(batchCount > 1) {
        futureDetections1 = QtConcurrent::run([=]() {
            return YoloParser::parse(data, shape, letterboxInfo.at(1), 1);
        });
    }

    QList<Detection> det0 = futureDetections0.result();
    QList<Detection> det1;
    if(batchCount > 1)
        det1 = futureDetections1.result();

    auto endParse = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration<double, std::milli>(endParse - startParse).count();
    emit parsingFinished(ms);

    emit detectionsReady(0, det0);
    if(batchCount > 1)
        emit detectionsReady(1, det1);
}
