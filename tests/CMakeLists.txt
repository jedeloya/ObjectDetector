cmake_minimum_required(VERSION 3.16)

project(ObjectDetectorTests LANGUAGES CXX)

enable_testing()

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Test Core)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Test Core)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(SRC_FILES
    tst_yoloparser.cpp
)

add_executable(testObjectDetector
    ${SRC_FILES}
)

target_link_libraries(testObjectDetector
    PRIVATE
    ObjectDetectorCore
    Qt${QT_VERSION_MAJOR}::Test
    Qt${QT_VERSION_MAJOR}::Core
)

set_target_properties(testObjectDetector PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests"
)

add_test(
    NAME testObjectDetector
    COMMAND testObjectDetector
)

