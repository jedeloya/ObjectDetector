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

// -*- mode: objc++; -*-
#import "cameramodel.hpp"
#include <QDebug>
#include <QFile>
#include <QDir>
#include <QThread>
#include <QVector>

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>

CameraModel::CameraModel(QObject *parent)
    : QObject{parent}, model(nil)
{
  parser = new YoloParser();
  parseThread = new QThread(this);
  parser->moveToThread(parseThread);

  parseThread->start();

  connect(parseThread, &QThread::finished,
         parser, &QObject::deleteLater);

  connect(this, &CameraModel::rawBatchReady,
          parser, &YoloParser::parseBatch,
          Qt::QueuedConnection);

  connect(parser, &YoloParser::detectionsReady,
          this, &CameraModel::handleDetections,
          Qt::QueuedConnection);

  connect(parser, &YoloParser::parsingFinished,
          this, [this](double ms) {
          qWarning() << "Batch parsing finished, releasing in-flight frames";
          @autoreleasepool {
            for(auto& pb : inFlightFrames) {
              if(pb) CVPixelBufferRelease(pb);
            }
            inFlightFrames.clear();
            batchInFligt = false;
          }
          emit parsingFinished(ms);
        },
          Qt::QueuedConnection);
}

CameraModel::~CameraModel() {
  qWarning() << "CameraModel destroyed in thread"
             << QThread::currentThread();
  if(parseThread) {
    parseThread->quit();
    parseThread->wait();
  }

#ifdef __OBJC__
  @autoreleasepool {
    // Release all in-flight buffers
    for(auto &pb : inFlightFrames) {
      if(pb) CVPixelBufferRelease(pb);
    }
    inFlightFrames.clear();

    // Release any leftover batch frames
    for(auto &pb : batchFrames) {
      if(pb) CVPixelBufferRelease(pb);
    }
    batchFrames.clear();

    // Release Core ML model
    model = nil;
  }
#endif
}

void CameraModel::loadModel()
{
#ifdef __OBJC__
  @autoreleasepool {
    NSString *name = @"yolo11n";
    NSString *modelPath = [[NSBundle mainBundle] pathForResource:name ofType:@"mlmodelc"];
    if(modelPath == nil) {
      qWarning() << "Could not find " << QString::fromUtf8([name UTF8String]) << "mlmodelc in bundle";
      model = nullptr;
      return;
    }
    // Log actual path for debugging
    qInfo() << "Found model bundle at:" << QString::fromUtf8([modelPath UTF8String]);
    NSURL *url = [NSURL fileURLWithPath:modelPath];
    if(!url) {
      qWarning() << "Failed to create URL";
    }

    NSError *error = nil;
    MLModelConfiguration *config = [[MLModelConfiguration alloc] init];
    config.computeUnits = MLComputeUnitsAll;
    MLModel* loaded = nil;
    if([MLModel respondsToSelector:@selector(modelWithContentsOfURL:configuration:error:)]) {
      loaded = [MLModel modelWithContentsOfURL:url configuration:config error:&error];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      loaded = [MLModel modelWithContentsOfURL:url error:&error];
#pragma clang diagnostic pop
    }

    if(error) {
      NSString *desc = error.localizedDescription ?: @"(no description)";
      qWarning() << "CoreML model load error:" << QString::fromUtf8([desc UTF8String]);
      model = nil;
      return;
    }

    if(!loaded) {
      qWarning() << "CoreML returned nil model pointer";
      model = nil;
      return;
    }
    qInfo() << "Compute units:"
        << (config.computeUnits == MLComputeUnitsAll ? "All (ANE/GPU/CPU)" :
            config.computeUnits == MLComputeUnitsCPUAndGPU ? "CPU+GPU" :
            "CPU only");
    model = loaded;

    // qInfo() << "CoreML model successfully loaded: " << QString::fromUtf8([[model description] UTF8String]);
    qInfo() << "CoreML model successfully loaded";
  }
#endif
}

static MLMultiArray* pixelBufferToNCHW(CVPixelBufferRef pb)
{
    CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);

    size_t width  = CVPixelBufferGetWidth(pb);
    size_t height = CVPixelBufferGetHeight(pb);
    uint8_t *src  = (uint8_t*)CVPixelBufferGetBaseAddress(pb);
    size_t stride = CVPixelBufferGetBytesPerRow(pb);

    NSArray *shape = @[@1, @3, @(height), @(width)];
    MLMultiArray *arr = [[MLMultiArray alloc]
        initWithShape:shape
              dataType:MLMultiArrayDataTypeFloat32
                 error:nil];

    float *dst = (float*)arr.dataPointer;

    if(!src || !dst) {
        qWarning() << "Failed to get pixel buffer base address or MLMultiArray data pointer";
        CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
        return nil;
    }

    for (int y = 0; y < height; y++) {
        uint8_t *row = src + y * stride;

        for (int x = 0; x < width; x++) {
            uint8_t b = row[4*x + 0];
            uint8_t g = row[4*x + 1];
            uint8_t r = row[4*x + 2];

            int idx = y * width + x;

            dst[idx + 0 * width * height] = r / 255.0f;
            dst[idx + 1 * width * height] = g / 255.0f;
            dst[idx + 2 * width * height] = b / 255.0f;
        }
    }

    CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);

    return arr;
}

static CVPixelBufferRef letterboxPixelBuffer(CVPixelBufferRef source,
                                             int inputSize,
                                             float &scale,
                                             int &padX,
                                             int &padY)
{
    size_t srcW = CVPixelBufferGetWidth(source);
    size_t srcH = CVPixelBufferGetHeight(source);

    scale = std::min((float)inputSize / srcW,
                     (float)inputSize / srcH);

    int newW = (int)(srcW * scale);
    int newH = (int)(srcH * scale);

    padX = (inputSize - newW) / 2;
    padY = (inputSize - newH) / 2;

    NSDictionary *attrs = @{
        (id)kCVPixelBufferWidthKey: @(inputSize),
        (id)kCVPixelBufferHeightKey: @(inputSize),
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };

    CVPixelBufferRef out = nullptr;
    CVReturn ret = CVPixelBufferCreate(kCFAllocatorDefault,
                        inputSize,
                        inputSize,
                        kCVPixelFormatType_32BGRA,
                        (__bridge CFDictionaryRef)attrs,
                        &out);

    if (ret != kCVReturnSuccess || !out) {
      qWarning() << "CVPixelBufferCreate failed:" << ret;
      return nullptr;
    }

    CIImage *srcImg = [CIImage imageWithCVPixelBuffer:source];
    CIImage *scaled =
        [srcImg imageByApplyingTransform:
            CGAffineTransformMakeScale(scale, scale)];

    CIImage *translated =
        [scaled imageByApplyingTransform:
            CGAffineTransformMakeTranslation(padX, padY)];

    static CIContext *ctx = [CIContext context];
    [ctx render:translated toCVPixelBuffer:out];

    return out;
}

/**
 * @brief Converts from QVideoFrame to CVPixelBufferRef.
 * @param frame, Input frame.
 * @param info, Letterbox info output.
 * @return frame in CVPixelBufferRef format.
 */
static CVPixelBufferRef QVideoFrame_to_CVPixelBuffer(
    QVideoFrame frame,
    YoloParser::LetterboxInfo &info
)
{
#ifdef __OBJC__
  @autoreleasepool {

    QVideoFrame f(frame);
    if (!f.map(QVideoFrame::ReadOnly)) {
        qWarning() << "Failed to map video frame";
        return nullptr;
    }

    const int width  = f.width();
    const int height = f.height();
    QVideoFrameFormat::PixelFormat fmt = f.surfaceFormat().pixelFormat();

    CVPixelBufferRef pb = nullptr;

    // ---- CASE 1: Qt gives NV12 (common on macOS) ---------------------
    if (fmt == QVideoFrameFormat::Format_NV12) {

        NSDictionary *attrs = @{
            (id)kCVPixelBufferWidthKey  : @(width),
            (id)kCVPixelBufferHeightKey : @(height),
            (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        };

        CVReturn err = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            (__bridge CFDictionaryRef)attrs,
            &pb
        );

        if (err != kCVReturnSuccess) {
            qWarning() << "Failed to create NV12 pixel buffer";
            f.unmap();
            return nullptr;
        }

        CVPixelBufferLockBaseAddress(pb, 0);

        // Write Y plane
        {
            uint8_t *dstY = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pb, 0);
            size_t dstStrideY = CVPixelBufferGetBytesPerRowOfPlane(pb, 0);

            const uint8_t *srcY = f.bits(0);
            size_t srcStrideY = f.bytesPerLine(0);

            for (int y=0; y<height; ++y)
                memcpy(dstY + y*dstStrideY, srcY + y*srcStrideY, srcStrideY);
        }

        // Write UV plane
        {
            uint8_t *dstUV = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pb, 1);
            size_t dstStrideUV = CVPixelBufferGetBytesPerRowOfPlane(pb, 1);

            const uint8_t *srcUV = f.bits(1);
            size_t srcStrideUV = f.bytesPerLine(1);

            for (int y=0; y<height/2; ++y)
                memcpy(dstUV + y*dstStrideUV, srcUV + y*srcStrideUV, srcStrideUV);
        }

        CVPixelBufferUnlockBaseAddress(pb, 0);
        f.unmap();
        float scale;
        int padX, padY;
        CVPixelBufferRef resizedPB = letterboxPixelBuffer(pb, 640, scale, padX, padY);
        info.scale = scale;
        info.padX = padX;
        info.padY = padY;
        info.origW = width;
        info.origH = height;
        CVPixelBufferRelease(pb);
        return resizedPB;
    }

    // ---- CASE 2: ARGB32/BGRA32 --------------------------------------
    if (fmt == QVideoFrameFormat::Format_ARGB8888 ||
        fmt == QVideoFrameFormat::Format_BGRA8888 ||
        fmt == QVideoFrameFormat::Format_XRGB8888)
    {
        NSDictionary *attrs = @{
            (id)kCVPixelBufferCGImageCompatibilityKey : @YES,
            (id)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES
        };

        CVReturn status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            (__bridge CFDictionaryRef)attrs,
            &pb
        );

        if (status != kCVReturnSuccess) {
            qWarning() << "Failed to create BGRA buffer";
            f.unmap();
            return nullptr;
        }

        CVPixelBufferLockBaseAddress(pb, 0);

        uint8_t *dst = (uint8_t *)CVPixelBufferGetBaseAddress(pb);
        size_t dstStride = CVPixelBufferGetBytesPerRow(pb);

        const uint8_t *src = f.bits(0);
        size_t srcStride = f.bytesPerLine(0);

        for (int y = 0; y < height; y++)
            memcpy(dst + y*dstStride, src + y*srcStride, srcStride);

        CVPixelBufferUnlockBaseAddress(pb, 0);
        f.unmap();
        float scale;
        int padX, padY;
        CVPixelBufferRef resizedPB = letterboxPixelBuffer(pb, 640, scale, padX, padY);
        info.scale = scale;
        info.padX = padX;
        info.padY = padY;
        info.origW = width;
        info.origH = height;
        CVPixelBufferRelease(pb);
        return resizedPB;
    }

    f.unmap();
    qWarning() << "Unsupported QVideoFrame format:" << fmt;
    return nullptr;
  }
#endif
  return nullptr;
}

static MLMultiArray* makeBatch(const std::vector<CVPixelBufferRef> &frames)
{
  if(frames.size() != 2) {
    qWarning() << "makeBatch requires exactly 2 frames";
    return nil;
  }
  if (!frames[0] || !frames[1]) {
    qWarning() << "Null frame in batch";
    return nil;
  }
  for (auto &pb : frames) {
    if (CVPixelBufferGetWidth(pb) != 640 ||
      CVPixelBufferGetHeight(pb) != 640) {
      qWarning() << "Unexpected pixel buffer size";
      return nil;
    }
  }
  NSError* error = nil;

  MLMultiArray* batch = [[MLMultiArray alloc]
      initWithShape:@[@2, @3, @640, @640]
            dataType:MLMultiArrayDataTypeFloat32
               error:&error];

  if (error || !batch) {
      qWarning() << "Failed to create MLMultiArray for batch";
      return nil;
  }

  float* dst = (float*)batch.dataPointer;
  NSArray* bs = batch.strides;
  int strideB = [bs[0] intValue];
  int strideC = [bs[1] intValue];
  int strideY = [bs[2] intValue];
  int strideX = [bs[3] intValue];

  const bool contiguous =
      strideX == 1 &&
      strideY == 640 &&
      strideC == 640 * 640 &&
      strideB == 3 * 640 * 640;
  const int imgSize = 3 * 640 * 640;
  for(int b = 0; b<2; ++b) {
    @autoreleasepool {
      MLMultiArray* imgArr = pixelBufferToNCHW(frames[b]);
      if(!imgArr) {
        qWarning() << "Failed to convert frame to NCHW MLMultiArray";
        return nil;
      }
      float* src = (float*)imgArr.dataPointer;
      NSArray* is = imgArr.strides;
      const int icS = [is[1] intValue];
      const int iyS = [is[2] intValue];
      const int ixS = [is[3] intValue];

      const bool imgContiguous =
          ixS == 1 &&
          iyS == 640 &&
          icS == 640 * 640;

      if (contiguous && imgContiguous) {
        memcpy(dst + b * imgSize,
                src,
                imgSize * sizeof(float));
      } else {
        for(int c=0; c<3; c++)
        for(int y=0; y<640; y++)
        for(int x=0; x<640; x++) {
          int srcIdx = c * 640 * 640 + y * 640 + x;
          int dstIdx = b * strideB + c * strideC + y * strideY + x * strideX;
          dst[dstIdx] = src[srcIdx];
        }
      }
    }
  }
  return batch;
}

/**
 * @brief Process a batch of two frames at time in model.
 */
void CameraModel::processBatch(std::vector<CVPixelBufferRef> frames)
{
#ifdef __OBJC__
    @autoreleasepool {

        if (!model) {
          qWarning() << "No ML model loaded, attempting to load";
          return;
        }
        // Build ML input array
        MLMultiArray *batch = makeBatch(frames);
        if (!batch) {
          qWarning() << "Batch creation failed, skipping inference";
          return;
        }
        MLFeatureValue *fv = [MLFeatureValue featureValueWithMultiArray:batch];

        NSDictionary *inputDict = @{ @"image": fv };

        NSError *err = nil;
        MLDictionaryFeatureProvider *inputs =
            [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputDict error:&err];

        if (err || !inputs) {
            qWarning() << "Failed to build feature provider";
            return;
        }

        auto inferStart = std::chrono::high_resolution_clock::now();

        id<MLFeatureProvider> output =
            [model predictionFromFeatures:inputs error:&err];

        auto inferEnd = std::chrono::high_resolution_clock::now();
        double inferMs = std::chrono::duration<double, std::milli>(inferEnd - inferStart).count();
        emit inferenceFinished(inferMs);

        if (err || !output) {
            qWarning() << "CoreML prediction failed";
            return;
        }

        // Get YOLO output
        MLFeatureValue *rawVal = [output featureValueForName:@"var_1309"];
        if (!rawVal) {
            qWarning() << "Missing output var_1309";
            return;
        }

        MLMultiArray *raw = rawVal.multiArrayValue;
        NSArray<NSNumber*> *coremlShape = raw.shape;
        NSArray<NSNumber*> *coremlStrides = raw.strides;
        int B = coremlShape[0].intValue;
        int C = coremlShape[1].intValue;
        int N = coremlShape[2].intValue;

        qDebug() << "Raw output shape:" << coremlShape;
        qDebug() << "Raw output strides:" << coremlStrides;

        size_t total = (size_t)B*C*N;

        int strideB = [coremlStrides[0] intValue];
        int strideC = [coremlStrides[1] intValue];
        int strideN = [coremlStrides[2] intValue];

        float *src = (float*)raw.dataPointer;
        BOOL contiguous =
            strideN == 1 &&
            strideC == N &&
            strideB == C * N;
        qWarning() << "CoreML raw shape:"
           << coremlShape
           << "B:" << B
           << "C:" << C
           << "N:" << N;
        QByteArray blob;
        blob.resize(total * sizeof(float));
        float *copy = reinterpret_cast<float*>(blob.data());;
        if (contiguous) {
          memcpy(copy, src, total * sizeof(float));
        } else {
          for(int b=0; b<B; b++)
          for(int c=0; c<C; c++)
          for(int n=0; n<N; n++) {
            int srcIdx = b*strideB + c*strideC + n*strideN;
            int dstIdx = b*C*N + c*N + n;
            copy[dstIdx] = src[srcIdx];
          }
        }

        qWarning() << "Output shape" << coremlShape.count << "Batch:" << coremlShape[0] << "channels" << coremlShape[1] << "boxes" << coremlShape[2];;
        emit rawBatchReady(blob, B, C, N, letterboxInfo);
    }
#endif
}

/**
 * @brief Process one frame in model.
 * @param pb
 */
void CameraModel::processWithCoreML(CVPixelBufferRef pb)
{
#ifdef __OBJC__
  @autoreleasepool {
    if(!model) {
      qWarning() << "No ML model loaded";
      return;
    }

    NSError *err = nil;

    MLFeatureValue *inputImage = [MLFeatureValue featureValueWithPixelBuffer:pb];
    MLFeatureValue *confTh = [MLFeatureValue featureValueWithDouble:0.25];
    MLFeatureValue *iouTh  = [MLFeatureValue featureValueWithDouble:0.7];
    NSDictionary *inputDict = @{
      @"image": inputImage,
      @"confidenceThreshold": confTh,
      @"iouThreshold": iouTh
    };
    MLDictionaryFeatureProvider *inputs = [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputDict error:&err];

    if (err || inputs == nil) {
      qWarning() << "Error creating input feature provider";
      return;
    }

    id<MLFeatureProvider> output =
        [model predictionFromFeatures:inputs error:&err];

    if (err || !output) {
      NSString *desc = err.localizedDescription ?: @"(no description)";
      qWarning() << "CoreML prediction failed " << QString::fromUtf8([desc UTF8String]);;
      return;
    }

    // -----------------------------------------------------------------
    // YOLOv11 typically returns:
    //  - "confidence"
    //  - "coordinates"
    //  - "confidenceThreshold"
    // Adjust based on actual model output names
    // -----------------------------------------------------------------

    // Example access (adapt once actual output names are known)
    MLFeatureValue *coordsVal =
        [output featureValueForName:@"coordinates"];

    if (!coordsVal) {
        qWarning() << "Model output missing expected key";
        return;
    }

    // TODO:
    // Parse the output tensor according to your YOLO model's structure
    // Emit detections to Qt later. For now, just confirms run:

    // qDebug() << "CoreML inference complete";
  }
#endif
}

/**
 * @brief Process two frames in batch in the model.
 * @param frame
 */
void CameraModel::processFrameInBatch(const QVideoFrame& frame )
{
#ifdef __OBJC__
  if (!frame.isValid() || frame.width() <= 0 || frame.height() <= 0) {
    qWarning() << "Invalid video frame, skipping";
    return;
  }
  if(!model) {
    qWarning() << "No ML model loaded, attempting to load";
    loadModel();
    return;
  }

  if(batchInFligt) {
    qWarning() << "Dropping frame, batch in flight";
    return;
  }

  YoloParser::LetterboxInfo info;
  CVPixelBufferRef pb = QVideoFrame_to_CVPixelBuffer(frame, info);
  if (!pb ||
    CVPixelBufferGetWidth(pb) != 640 ||
    CVPixelBufferGetHeight(pb) != 640) {
    qWarning() << "Invalid pixel buffer, skipping batch";
    // if (pb) CVPixelBufferRelease(pb);
    @autoreleasepool {
      for (auto &buf : inFlightFrames) {
          CVPixelBufferRelease(buf);
      }
      inFlightFrames.clear();
      batchInFligt = false;
    }
    emit parsingFinished(0.0);
    return;
  }
  if(batchFrames.empty()) {
    letterboxInfo.clear();
  }

  letterboxInfo.push_back(info);
  batchFrames.push_back(pb);

  if(batchFrames.size() == 2) {
    batchInFligt = true;
    @autoreleasepool {
      inFlightFrames.swap(batchFrames);
      batchFrames.clear();
      processBatch(inFlightFrames);
    }
  }

#endif
}

/**
 * @brief Process frame by frame.
 * @param frame
 */
void CameraModel::processFrame(const QVideoFrame& frame )
{
#ifdef __OBJC__
  if(!model) {
    qWarning() << "No ML model loaded, attempting to load";
    loadModel();
    return;
  }

  YoloParser::LetterboxInfo info;
  CVPixelBufferRef pb = QVideoFrame_to_CVPixelBuffer(frame, info);

  if(!pb) return;

  processWithCoreML(pb);
    // You will later connect this to detection signals
#endif
}

void CameraModel::handleDetections(int batchIndex, QList<Detection> detections)
{
  qDebug() << "BATCH" << batchIndex << "got" << detections.size() << "detections";
  emit detectionsReady(batchIndex, detections);
}
