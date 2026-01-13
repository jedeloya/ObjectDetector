#!/usr/bin/env bash

set -e

# -----------------------------
# Config
# -----------------------------
APP_NAME="appObjectDetector"
QT_PATH="$HOME/Qt/6.10.0/macos"
BUILD_TYPE="${2:-Debug}"
BUILD_DIR="build-${BUILD_TYPE}"

# -----------------------------
# Helpers
# -----------------------------
usage() {
    echo "Usage:"
    echo "  ./build.sh build [Debug|Release|RelWithDebInfo]"
    echo "  ./build.sh run   [Debug|Release|RelWithDebInfo]"
    echo "  ./build.sh clean [Debug|Release|RelWithDebInfo]"
    exit 1
}

# -----------------------------
# Commands
# -----------------------------
case "$1" in
build)
    echo "🔧 Building (${BUILD_TYPE})"

    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    cmake .. \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DCMAKE_PREFIX_PATH="${QT_PATH}"

    cmake --build . --parallel
    ;;

run)
    echo "▶️ Running (${BUILD_TYPE})"

    APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

    if [ ! -d "${APP_PATH}" ]; then
        echo "❌ App not found. Build first."
        exit 1
    fi

    open "${APP_PATH}"
    ;;

clean)
    echo "🧹 Cleaning (${BUILD_TYPE})"
    rm -rf "${BUILD_DIR}"
    ;;

*)
    usage
    ;;
esac
