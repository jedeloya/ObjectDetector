#include <QTest>
#

// add necessary includes here

class TestYoloParser : public QObject
{
    Q_OBJECT

public:
    TestYoloParser();
    ~TestYoloParser();

private slots:
    void initTestCase();
    void init();
    void cleanupTestCase();
    void cleanup();
    void test_case1();
};

TestYoloParser::TestYoloParser() {}

TestYoloParser::~TestYoloParser() {}

void TestYoloParser::initTestCase()
{
    // code to be executed before the first test function
}

void TestYoloParser::init()
{
    // code to be executed before each test function
}

void TestYoloParser::cleanupTestCase()
{
    // code to be executed after the last test function
}

void TestYoloParser::cleanup()
{
    // code to be executed after each test function
}

void TestYoloParser::test_case1() {}

QTEST_APPLESS_MAIN(TestYoloParser)

#include "tst_yoloparser.moc"
