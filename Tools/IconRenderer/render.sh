#!/bin/bash
# Repaints the app icon from the app's own palette, grain and layout code.
#
# The renderer has to run on iOS rather than on the Mac, because Theme and
# WoodGrain are built on UIKit. So it is compiled for the simulator and spawned
# inside one; any booted simulator will do. Pass a directory to write somewhere
# other than the asset set.
set -e
cd "$(dirname "$0")/../.."
OUT="${1:-Piano/Resources/Assets.xcassets/AppIcon.appiconset}"
UD="${2:-booted}"
BIN="$(mktemp -d)/iconrenderer"

xcrun -sdk iphonesimulator swiftc -O \
  -target x86_64-apple-ios17.0-simulator \
  Tools/IconRenderer/main.swift \
  Piano/App/Theme.swift Piano/App/WoodGrain.swift \
  Piano/Model/KeyboardLayout.swift Piano/Model/PianoNote.swift \
  -o "$BIN"

xcrun simctl spawn "$UD" "$BIN" "$(cd "$OUT" && pwd)"
