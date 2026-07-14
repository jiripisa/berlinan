#!/bin/bash
# Run script for Berlinan (adopted from Sampio — development_workflow.md §3)
# Usage: ./run.sh [debug|release]
#
#   debug   — build debug + run in terminal (log output visible) (default)
#   release — build release + open as .app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Berlinan"
MODE="${1:-debug}"

if [ "$MODE" == "debug" ]; then
    APP_BUNDLE="$SCRIPT_DIR/build/debug/$APP_NAME.app"
    EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

    # Auto-build if needed
    NEEDS_BUILD=false
    if [ ! -f "$EXECUTABLE" ]; then
        NEEDS_BUILD=true
    elif [ -n "$(find Sources -name '*.swift' -newer "$EXECUTABLE" 2>/dev/null)" ]; then
        NEEDS_BUILD=true
    elif [ -n "$(find Resources -newer "$EXECUTABLE" 2>/dev/null)" ]; then
        NEEDS_BUILD=true
    fi

    if [ "$NEEDS_BUILD" = true ]; then
        ./build.sh debug
    fi

    # Register the bundle with Launch Services so TCC sees it as a real app
    # (not an "anonymous launch"). `exec` preserves the UX: logs streamed,
    # Ctrl+C → quit.
    LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    if [ -x "$LSREGISTER" ]; then
        "$LSREGISTER" -f "$APP_BUNDLE" >/dev/null 2>&1 || true
    fi

    echo "Running $APP_NAME (debug) — log output below, Ctrl+C to quit"
    echo "---"
    exec "$EXECUTABLE"

elif [ "$MODE" == "release" ]; then
    APP_BUNDLE="$SCRIPT_DIR/build/release/$APP_NAME.app"

    # Auto-build if needed
    if [ ! -d "$APP_BUNDLE" ]; then
        ./build.sh release
    elif [ -n "$(find Sources -name '*.swift' -newer "$APP_BUNDLE" 2>/dev/null)" ]; then
        ./build.sh release
    fi

    echo "Launching $APP_NAME (release)..."
    open "$APP_BUNDLE"

else
    echo "Unknown mode: $MODE"
    echo "Usage: ./run.sh [debug|release]"
    exit 1
fi
