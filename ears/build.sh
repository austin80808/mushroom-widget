#!/bin/sh
# Builds MushroomEars.app next to this script.
set -e
cd "$(dirname "$0")"
app=MushroomEars.app
# Skip when up to date: every rebuild changes the ad-hoc signature, and macOS then
# withdraws the System Audio Recording permission until it is granted again.
if [ "$app/Contents/MacOS/MushroomEars" -nt main.swift ] && [ "$app/Contents/Info.plist" -nt Info.plist ]; then
  echo "$app is up to date"
  exit 0
fi
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/Info.plist"
xcrun swiftc -O -swift-version 5 main.swift -o "$app/Contents/MacOS/MushroomEars"
codesign --force --sign - "$app"
echo "built $app"
