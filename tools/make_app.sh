#!/bin/sh
# Builds "Mushroom Widget.app" and installs it to ~/Applications.
# The app carries a copy of this project (and the audio helper) and runs it with the
# Godot installed on this Mac, so it needs Godot 4.7 but no export templates.
# Re-run after changing the project to update the installed app.
set -e
cd "$(dirname "$0")/.."
app="build/Mushroom Widget.app"
sh ears/build.sh
rm -rf "$app" && mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/project"
touch build/.gdignore
rsync -a --exclude build --exclude docs --exclude tools --exclude .git --exclude '*.bak' \
  --exclude override.cfg --exclude MushroomEars.app ./ "$app/Contents/Resources/project/"

cat > "$app/Contents/MacOS/launcher" <<'LAUNCH'
#!/bin/sh
here="$(cd "$(dirname "$0")" && pwd)"
godot="/Applications/Godot.app/Contents/MacOS/Godot"
[ -x "$godot" ] || godot="$(command -v godot)"
exec "$godot" --path "$here/../Resources/project" "$@"
LAUNCH
chmod +x "$app/Contents/MacOS/launcher"

# Icon from icon.png.
set="build/icon.iconset"
rm -rf "$set" && mkdir -p "$set"
for s in 16 32 128 256; do
  sips -z $s $s icon.png --out "$set/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) icon.png --out "$set/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$set" -o "$app/Contents/Resources/icon.icns"
rm -rf "$set"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>local.mushroom-widget</string>
	<key>CFBundleName</key><string>Mushroom Widget</string>
	<key>CFBundleExecutable</key><string>launcher</string>
	<key>CFBundleIconFile</key><string>icon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
</dict>
</plist>
PLIST

mkdir -p "$HOME/Applications"
# The audio helper is installed beside the app, not inside it: macOS feeds a helper
# nested in another app bundle silence instead of system audio.
rm -rf "$HOME/Applications/MushroomEars.app"
cp -R ears/MushroomEars.app "$HOME/Applications/"
rm -rf "$HOME/Applications/Mushroom Widget.app"
cp -R "$app" "$HOME/Applications/"
echo "installed $HOME/Applications/Mushroom Widget.app"
