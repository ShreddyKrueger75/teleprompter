#!/bin/zsh
# Builds Teleprompter.app next to this script. Usage: ./build.sh [--run]
set -e
cd "$(dirname "$0")"
APP=Teleprompter.app
ARCH=$(uname -m)

# self-check the pure logic first
swiftc -swift-version 5 -target "$ARCH-apple-macosx14.0" Sources/WordMatcher.swift Tests/main.swift -o "${TMPDIR:-/tmp}/tp-check"
"${TMPDIR:-/tmp}/tp-check"

mkdir -p "$APP/Contents/MacOS"
# ponytail: swift 5 language mode keeps AppKit/Carbon callback code free of strict-concurrency churn
swiftc -O -swift-version 5 -target "$ARCH-apple-macosx14.0" Sources/*.swift -o "$APP/Contents/MacOS/Teleprompter"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"   # ad-hoc signature so mic/speech permission prompts stick
echo "built $APP"
[[ "$1" == "--run" ]] && open "$APP"
