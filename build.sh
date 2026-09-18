#!/bin/zsh
# Builds Teleprompter.app from the Xcode project. Usage: ./build.sh [--run]
# Xcode is the source of truth; regenerate the project with `xcodegen generate` after
# editing project.yml.
set -e
cd "$(dirname "$0")"
ARCH=$(uname -m)

# pure-logic self-check first, so a broken matcher fails before a five-minute build
swiftc -swift-version 5 -target "$ARCH-apple-macosx14.0" Sources/WordMatcher.swift Tests/main.swift -o "${TMPDIR:-/tmp}/tp-check"
"${TMPDIR:-/tmp}/tp-check"

xcodebuild -project Teleprompter.xcodeproj -scheme Teleprompter \
  -configuration Release -derivedDataPath build build

APP="build/Build/Products/Release/Teleprompter.app"
echo "built $APP"
[[ "$1" == "--run" ]] && open "$APP"
