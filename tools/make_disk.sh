#!/bin/sh
# Build a disk image a buyer can run without Godot installed.
# The cake app carries its own Mach-O runtime. Mushroom Ears sits beside it,
# not inside the bundle (a nested helper receives silence).
set -e
cd "$(dirname "$0")/.."
godot="/Applications/Godot.app/Contents/MacOS/Godot"
if [ ! -x "$godot" ]; then
  echo "build machine needs Godot at /Applications/Godot.app" >&2
  exit 1
fi

sh ears/build.sh
"$godot" --headless --path . --import --quit
mkdir -p build
"$godot" --headless --path . --export-pack "macOS" "build/cake.pck"

stage="build/stage"
rm -rf "$stage"
app="$stage/Mushroom Widget.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$godot" "$app/Contents/MacOS/cake-runtime"
cp build/cake.pck "$app/Contents/Resources/cake.pck"
cp icon.png "$app/Contents/Resources/icon.png" 2>/dev/null || true
clang -O2 -o "$app/Contents/MacOS/Mushroom Widget" tools/cake_main.c
chmod +x "$app/Contents/MacOS/cake-runtime" "$app/Contents/MacOS/Mushroom Widget"
cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>local.mushroom-widget</string>
	<key>CFBundleName</key><string>Mushroom Widget</string>
	<key>CFBundleDisplayName</key><string>Mushroom Widget</string>
	<key>CFBundleExecutable</key><string>Mushroom Widget</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.2.0</string>
	<key>CFBundleVersion</key><string>2</string>
	<key>LSMinimumSystemVersion</key><string>14.2</string>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
# The copied Godot binary keeps Prehensile Tales' signature, and macOS kills it
# once it is outside Godot.app. Sign it as this app so the process can start.
# Developer ID replaces this in tools/notarize.sh when that identity exists.
codesign --force --sign - --identifier local.mushroom-widget.runtime "$app/Contents/MacOS/cake-runtime"
codesign --force --sign - --identifier local.mushroom-widget "$app/Contents/MacOS/Mushroom Widget"
codesign --force --sign - "$app"
cp -R ears/MushroomEars.app "$stage/MushroomEars.app"
cat > "$stage/Read Me.txt" <<'EOF'
Mushroom Widget

Keep both apps in this same folder. The cake starts its own copy of the
runtime. It does not need Godot. The first launch asks for permission so
Mushroom Ears can hear what the Mac is playing. Nothing is recorded.

Drag the folder somewhere you can leave it, or copy both apps into the same
Applications folder. Do not put Mushroom Ears inside Mushroom Widget.app.
EOF

sh tools/check_bundle.sh "$stage"

rm -f build/MushroomWidget.dmg
hdiutil create -volname "Mushroom Widget" -srcfolder "$stage" -ov -format UDZO "build/MushroomWidget.dmg"
sh tools/check_bundle.sh "build/MushroomWidget.dmg"
echo "built build/MushroomWidget.dmg"
