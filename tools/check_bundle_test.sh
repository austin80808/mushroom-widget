#!/bin/sh
# Drives tools/check_bundle.sh. A launcher that execs system Godot must fail.
# A folder with its own Mach-O and a sibling helper must pass.
set -e
cd "$(dirname "$0")/.."
check="./tools/check_bundle.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bad="$tmp/bad"
mkdir -p "$bad/Mushroom Widget.app/Contents/MacOS" "$bad/MushroomEars.app/Contents/MacOS"
cp /bin/echo "$bad/Mushroom Widget.app/Contents/MacOS/cake-runtime"
cp /bin/echo "$bad/MushroomEars.app/Contents/MacOS/MushroomEars"
cat > "$bad/Mushroom Widget.app/Contents/MacOS/launcher" <<'EOF'
#!/bin/sh
godot="/Applications/Godot.app/Contents/MacOS/Godot"
[ -x "$godot" ] || godot="$(command -v godot)"
exec "$godot" --path "$here/../Resources/project" "$@"
EOF
if "$check" "$bad"; then
  echo "bad bundle was accepted" >&2
  exit 1
fi

good="$tmp/good"
mkdir -p "$good/Mushroom Widget.app/Contents/MacOS" "$good/MushroomEars.app/Contents/MacOS"
cp /bin/echo "$good/Mushroom Widget.app/Contents/MacOS/cake-runtime"
cp /bin/echo "$good/MushroomEars.app/Contents/MacOS/MushroomEars"
cat > "$good/Mushroom Widget.app/Contents/MacOS/launcher" <<'EOF'
#!/bin/sh
here="$(cd "$(dirname "$0")" && pwd)"
exec "$here/cake-runtime" --main-pack "$here/../Resources/cake.pck" "$@"
EOF
"$check" "$good" | grep -q "ok runtime="
echo "check_bundle_test passed"
