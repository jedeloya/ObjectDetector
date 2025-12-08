// -*- mode: objc++; -*-
#import "cameramodel.hpp"
#include <QDebug>
#include <QFile>
#include <QDir>

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>

CameraModel::CameraModel(QObject *parent)
    : QObject{parent}, model(nil)
{
  loadModel();
}

CameraModel::~CameraModel() {}

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

    qInfo() << "CoreML model successfully loaded: " << QString::fromUtf8([[model description] UTF8String]);
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

static CVPixelBufferRef resizePixelBuffer(CVPixelBufferRef source,
                                          size_t width,
                                          size_t height)
{
    if (!source) return nullptr;

    NSDictionary *attrs = @{
        (id)kCVPixelBufferWidthKey: @(width),
        (id)kCVPixelBufferHeightKey: @(height),
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };

    CVPixelBufferRef output = nullptr;

    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          width,
                                          height,
                                          kCVPixelFormatType_32BGRA,
                                          (__bridge CFDictionaryRef)attrs,
                                          &output);

    if (status != kCVReturnSuccess) {
        qWarning() << "Failed to create resized PB";
        return nullptr;
    }

    CIImage *inputImage = [CIImage imageWithCVPixelBuffer:source];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    [context render:inputImage
    toCVPixelBuffer:output
             bounds:CGRectMake(0, 0, width, height)
         colorSpace:colorSpace];

    CGColorSpaceRelease(colorSpace);

    return output;
}

/**
 * @brief Converts from QVideoFrame to CVPixelBufferRef.
 * @param frame
 * @return frame in CVPixelBufferRef format.
 */
static CVPixelBufferRef QVideoFrame_to_CVPixelBuffer(QVideoFrame frame)
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
        CVPixelBufferRef resizedPB = resizePixelBuffer(pb, 640, 640);
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
        CVPixelBufferRef resizedPB = resizePixelBuffer(pb, 640, 640);
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
  NSArray *shape = @[@2, @3, @640, @640];
  MLMultiArray *batch = [[MLMultiArray alloc] initWithShape:shape dataType:MLMultiArrayDataTypeFloat32 error:nil];
  float *dst = (float*)batch.dataPointer;

  for(int b=0; b<2; b++) {
    MLMultiArray *img = pixelBufferToNCHW(frames[b]);
    float *src = (float*)img.dataPointer;

    int imgSize = 3*640*640;
    memcpy(dst + b * imgSize, src, imgSize*sizeof(float));
  }
  return batch;
}

/**
 * @brief Process a batch of two frames at time in model.
 */
void CameraModel::processBatch()
{
#ifdef __OBJC__
    @autoreleasepool {

        if (!model) return;

        // Build ML input array
        MLMultiArray *batch = makeBatch(batchFrames);
        MLFeatureValue *fv = [MLFeatureValue featureValueWithMultiArray:batch];

        NSDictionary *inputDict = @{ @"image": fv };

        NSError *err = nil;
        MLDictionaryFeatureProvider *inputs =
            [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputDict error:&err];

        if (err || !inputs) {
            qWarning() << "Failed to build feature provider";
            return;
        }

        id<MLFeatureProvider> output =
            [model predictionFromFeatures:inputs error:&err];

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
        float *data = (float*)raw.dataPointer;

        qDebug() << "Batch prediction OK, output count:" << raw.count;

        // TODO: run postprocessing here (one NMS per batch element)
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
  if(!model) return;

  CVPixelBufferRef pb = QVideoFrame_to_CVPixelBuffer(frame);

  if(!pb) return;

  CFRetain(pb);
  batchFrames.push_back(pb);

  if(batchFrames.size() == 2) {
    processBatch();
    for(auto &p : batchFrames) CFRelease(p);
    batchFrames.clear();
  }
  CVPixelBufferRelease(pb);

    // You will later connect this to detection signals
#endif
}

/**
 * @brief Process frame by frame.
 * @param frame
 */
void CameraModel::processFrame(const QVideoFrame& frame )
{
#ifdef __OBJC__
  if(!model) return;

  CVPixelBufferRef pb = QVideoFrame_to_CVPixelBuffer(frame);

  if(!pb) return;

  processWithCoreML(pb);
  CVPixelBufferRelease(pb);


    // You will later connect this to detection signals
#endif
}
