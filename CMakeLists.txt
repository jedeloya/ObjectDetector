cmake_minimum_required(VERSION 3.16)

project(ObjectDetector VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find the Qt6 package and components you need (Core, Quick, Multimedia)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Multimedia)
qt_standard_project_setup(REQUIRES 6.8)

set(SRC_FILES
    main.cpp
    controller/detectioncontroller.cpp
    model/cameramodel.mm)

set(HEADER_FILES
    controller/detectioncontroller.h
    model/cameramodel.hpp)

set_source_files_properties(
    model/cameramodel.mm
    PROPERTIES
        COMPILE_FLAGS "-x objective-c++ -fobjc-arc"
)

# Copy CoreML model into the app bundle
set(MODEL_FILE ${CMAKE_SOURCE_DIR}/resources/yolo11n.mlpackage)


qt_add_executable(appObjectDetector MACOSX_BUNDLE
    ${SRC_FILES}
    ${HEADER_FILES}
)

qt_add_qml_module(appObjectDetector
    URI ObjectDetector
    VERSION 1.0
    QML_FILES view/Main.qml
)

target_link_libraries(appObjectDetector
    PRIVATE Qt6::Quick Qt6::Core Qt6::Multimedia
)

# CoreML is specific to macOS, so we check if we are on macOS
if(APPLE)
    target_link_libraries(appObjectDetector
        PRIVATE
            "-framework Foundation"
            "-framework CoreFoundation"
            "-framework CoreML"
            "-framework Vision"
            "-framework MLCompute"
            "-framework CoreVideo"
            "-framework CoreGraphics"
            "-framework CoreImage"
            "-framework AVFoundation"
            "-framework AVKit"
    )
endif()

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appObjectDetector PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER deloya.jesus.appObjectDetector
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Info.plist"
)

# -------------------------------------------------------------------
# CoreML compilation
# -------------------------------------------------------------------
if(APPLE)
    set(MLMODEL_BUILD_DIR ${CMAKE_BINARY_DIR}/compiled_model)
    set(MLMODEL_STAMP ${MLMODEL_BUILD_DIR}/yolo11n.stamp)

    add_custom_command(
        OUTPUT ${MLMODEL_STAMP}
        DEPENDS ${MODEL_FILE}
        COMMAND ${CMAKE_COMMAND} -E rm -rf "${MLMODEL_BUILD_DIR}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${MLMODEL_BUILD_DIR}"

        # Compile CoreML model
        COMMAND /bin/sh -c "xcrun coremlcompiler compile \"${MODEL_FILE}\" \"${MLMODEL_BUILD_DIR}\" \
                            || xcrun coremlc compile \"${MODEL_FILE}\" \"${MLMODEL_BUILD_DIR}\""

        # Verify compilation produced a folder ending in .mlmodelc
        COMMAND /bin/sh -c "if ! ls \"${MLMODEL_BUILD_DIR}\" | grep -q \"\\.mlmodelc\"; then \
                                echo 'ERROR: CoreML output directory not found'; exit 1; fi"

        COMMAND ${CMAKE_COMMAND} -E touch "${MLMODEL_STAMP}"
        COMMENT "Compiling CoreML model"
        VERBATIM
    )

    add_custom_target(compile_coreml_model ALL DEPENDS ${MLMODEL_STAMP})
    add_dependencies(appObjectDetector compile_coreml_model)

    # Install compiled model into .app bundle
    add_custom_command(
        TARGET appObjectDetector POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:appObjectDetector>/../Resources"

        # Copy model folder (whatever its name is)
        COMMAND /bin/sh -c "for d in \"${MLMODEL_BUILD_DIR}\"/*.mlmodelc; do \
                                ${CMAKE_COMMAND} -E copy_directory \"\$d\" \
                                \"$<TARGET_FILE_DIR:appObjectDetector>/../Resources/\$(basename \"\$d\")\"; \
                            done"
        COMMENT "Copying compiled CoreML model into .app bundle"
        VERBATIM
    )
endif()


include(GNUInstallDirs)
install(TARGETS appObjectDetector
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)



