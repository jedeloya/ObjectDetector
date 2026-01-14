#include <QTest>
#include "../model/yoloparser.h"

/** Uncomment the following lines to enable debug logging for this test cases. **/
// #include <QLoggingCategory>
// static void enableDebugLogs() {
//     QLoggingCategory::setFilterRules("*.debug=true");
// }

// Q_CONSTRUCTOR_FUNCTION(enableDebugLogs)

class TestYoloParser : public QObject
{
    Q_OBJECT

public:
    TestYoloParser();
    ~TestYoloParser();

private slots:
    void singleHighConfidenceDetection();
    void detectionBelowConfidenceIsIgnored();
    void highestClassScoreIsSelected();
    void emptyOutputProducesNoDetections();
    void overlappingBoxesAreSuppressed();
    void invalidBatchIndexReturnsEmpty();
    void nullDataReturnsEmpty();

};

TestYoloParser::TestYoloParser() {}

TestYoloParser::~TestYoloParser() {}

void TestYoloParser::singleHighConfidenceDetection()
{
    YoloParser parser;
    YoloParser::TensorShape shape = {1,6,1};

    float data[] = {
        320.f, // cx
        240.f, // cy
        100.f, // w
        80.f,  // h
        0.9f,  // class 0
        0.1f   // class 1
    };

    YoloParser::LetterboxInfo letterbox;
    letterbox.scale = 1.0f;
    letterbox.padX = 0;
    letterbox.padY = 0;
    letterbox.origW = 640;
    letterbox.origH = 480;

    auto detections = parser.parse(data, shape, letterbox, 0, 0.25f, 0.5f, 640, 480);
    QCOMPARE(detections.size(), 1);
    QCOMPARE(detections[0].classId, 0);
    QCOMPARE(detections[0].label, QString("person"));
    QVERIFY(detections[0].score > 0.8f);
    QVERIFY(detections[0].rect.width() > 0);
    QVERIFY(detections[0].rect.height() > 0);
}

void TestYoloParser::detectionBelowConfidenceIsIgnored()
{
    YoloParser parser;
    YoloParser::TensorShape shape = {1,6,1};

    float data[] = {
        320.f, // cx
        240.f, // cy
        100.f, // w
        80.f,  // h
        0.2f,  // class 0
        0.05f   // class 1
    };

    YoloParser::LetterboxInfo letterbox;
    letterbox.scale = 1.0f;
    letterbox.padX = 0;
    letterbox.padY = 0;
    letterbox.origW = 640;
    letterbox.origH = 480;

    auto detections = parser.parse(data, shape, letterbox, 0, 0.25f, 0.5f, 640, 480);
    QCOMPARE(detections.size(), 0);
}

void TestYoloParser::highestClassScoreIsSelected()
{
    YoloParser parser;
    YoloParser::TensorShape shape = {1,6,1};

    float data[] = {
        320.f, // cx
        240.f, // cy
        100.f, // w
        80.f,  // h
        0.4f,  // class 0
        0.7f   // class 1
    };

    YoloParser::LetterboxInfo letterbox;
    letterbox.scale = 1.0f;
    letterbox.padX = 0;
    letterbox.padY = 0;
    letterbox.origW = 640;
    letterbox.origH = 480;

    auto detections = parser.parse(data, shape, letterbox, 0, 0.25f, 0.5f, 640, 480);
    QCOMPARE(detections.size(), 1);
    QCOMPARE(detections[0].classId, 1);
    QCOMPARE(detections[0].label, QString("bicycle"));
}

void TestYoloParser::emptyOutputProducesNoDetections()
{
    YoloParser parser;
    YoloParser::TensorShape shape = {1,6,1};

    float data[] = {
        0.f, // cx
        0.f, // cy
        0.f, // w
        0.f,  // h
        0.f,  // class 0
        0.f   // class 1
    };

    YoloParser::LetterboxInfo letterbox;
    letterbox.scale = 1.0f;
    letterbox.padX = 0;
    letterbox.padY = 0;
    letterbox.origW = 640;
    letterbox.origH = 480;

    auto detections = parser.parse(data, shape, letterbox, 0, 0.25f, 0.5f, 640, 480);
    QCOMPARE(detections.size(), 0);
}

void TestYoloParser::overlappingBoxesAreSuppressed()
{
    YoloParser parser;
    YoloParser::TensorShape shape = {1,6,2};

    float data[] = {
        // cx (channel 0)
        320.f, 325.f,

        // cy (channel 1)
        240.f, 245.f,

        // w (channel 2)
        100.f, 100.f,

        // h (channel 3)
        80.f, 80.f,

        // class 0 scores (channel 4)
        0.9f, 0.85f,

        // class 1 scores (channel 5)
        0.1f, 0.15f
    };

    YoloParser::LetterboxInfo letterbox;
    letterbox.scale = 1.0f;
    letterbox.padX = 0;
    letterbox.padY = 0;
    letterbox.origW = 640;
    letterbox.origH = 480;

    auto detections = parser.parse(data, shape, letterbox, 0, 0.25f, 0.5f, 640, 480);
    QCOMPARE(detections.size(), 1); // Only one box should remain after NMS
}

void TestYoloParser::invalidBatchIndexReturnsEmpty()
{
    YoloParser parser;
    YoloParser::TensorShape shape = {1,6,1};

    float data[] = {0};

    YoloParser::LetterboxInfo letterbox;
    letterbox.scale = 1.0f;
    letterbox.padX = 0;
    letterbox.padY = 0;
    letterbox.origW = 640;
    letterbox.origH = 480;

    auto detections = parser.parse(data, shape, letterbox, 5, 0.25f, 0.5f, 640, 480); // Invalid batch index
    QCOMPARE(detections.size(), 0);
}

void TestYoloParser::nullDataReturnsEmpty()
{
    YoloParser parser;
    YoloParser::TensorShape shape = {1,6,1};

    YoloParser::LetterboxInfo letterbox;
    letterbox.scale = 1.0f;
    letterbox.padX = 0;
    letterbox.padY = 0;
    letterbox.origW = 640;
    letterbox.origH = 480;

    auto detections = parser.parse(nullptr, shape, letterbox, 0, 0.25f, 0.5f, 640, 480);
    QCOMPARE(detections.size(), 0);
}

QTEST_APPLESS_MAIN(TestYoloParser)

#include "tst_yoloparser.moc"
