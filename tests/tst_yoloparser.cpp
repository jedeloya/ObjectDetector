#include <QTest>
#include <../model/yoloparser.h>

// add necessary includes here

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
        // Box 1
        320.f, // cx
        240.f, // cy
        100.f, // w
        80.f,  // h
        0.9f,  // class 0
        0.1f,  // class 1
        // Box 2 (overlapping)
        325.f, // cx
        245.f, // cy
        100.f, // w
        80.f,  // h
        0.85f, // class 0
        0.15f  // class 1
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
