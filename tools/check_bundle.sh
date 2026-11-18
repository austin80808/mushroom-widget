#!/bin/sh
# Fail unless a shipped folder (or disk image) contains a cake app with its own
# Mach-O runtime and a sibling Mushroom Ears app. A launcher that starts
# /Applications/Godot.app or a godot on PATH fails.
set -e
root="${1:?usage: check_bundle.sh <folder-or-dmg>}"
mount=""
cleanup() {
  if [ -n "$mount" ]; then
    hdiutil detach "$mount" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [ -f "$root" ]; then
  mount="$(mktemp -d)"
  hdiutil attach "$root" -nobrowse -mountpoint "$mount" >/dev/null
  root="$mount"
fi

cake="$root/Mushroom Widget.app"
ears="$root/MushroomEars.app"
if [ ! -d "$cake" ]; then
  echo "missing cake app: $cake" >&2
  exit 1
fi
if [ ! -d "$ears" ]; then
  echo "missing sibling helper: $ears" >&2
  exit 1
fi
if [ -d "$cake/MushroomEars.app" ] || [ -d "$cake/Contents/MacOS/MushroomEars.app" ] || [ -d "$cake/Contents/Resources/MushroomEars.app" ]; then
  echo "helper is nested inside the cake app" >&2
  exit 1
fi

runtime=""
for f in "$cake/Contents/MacOS/"*; do
  [ -f "$f" ] || continue
  kind="$(file -b "$f" || true)"
  case "$kind" in
    *Mach-O*) runtime="$f"; break ;;
  esac
done
if [ -z "$runtime" ]; then
  echo "cake app has no Mach-O runtime" >&2
  exit 1
fi

ears_bin="$ears/Contents/MacOS/MushroomEars"
if [ ! -f "$ears_bin" ]; then
  echo "helper has no binary" >&2
  exit 1
fi
case "$(file -b "$ears_bin")" in
  *Mach-O*) ;;
  *) echo "helper binary is not Mach-O" >&2; exit 1 ;;
esac

# Scripts only. The runtime binary contains the word godot as the engine name.
for f in "$cake/Contents/MacOS/"*; do
  [ -f "$f" ] || continue
  case "$(file -b "$f")" in
    *Mach-O*) continue ;;
  esac
  if grep -n -E '/Applications/Godot\.app|command -v godot|exec .*godot' "$f"; then
    echo "launcher starts a system Godot: $f" >&2
    exit 1
  fi
done

echo "ok runtime=$runtime helper=$ears_bin"
