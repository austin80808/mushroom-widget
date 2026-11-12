#!/bin/sh
# Renders a beat-reactive clip of the cake to a track, as a transparent video.
#   tools/render_loop.sh <track.mp3|wav|ogg> [seconds=30] [from%=40] [to%=88] [species=0] [size=1080]
# The cake makes exactly one turn over the clip and grows from from% to to%.
# Output: build/loop/<track name>.mov (ProRes 4444 with alpha, with the audio).
set -e
track="$1"
[ -f "$track" ] || { echo "usage: $0 <track> [seconds] [from%] [to%] [species] [size]"; exit 1; }
track="$(cd "$(dirname "$track")" && pwd)/$(basename "$track")"
seconds="${2:-30}"; from="${3:-40}"; to="${4:-88}"; species="${5:-0}"; size="${6:-1080}"
cd "$(dirname "$0")/.."
name="$(basename "${track%.*}")"
out="build/loop"
rm -rf "$out/frames" && mkdir -p "$out/frames"
touch build/.gdignore
# The movie writer renders at the project's window size, so override it for this run.
printf '[display]\n\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\n' "$size" "$size" > override.cfg
trap 'rm -f override.cfg' EXIT
godot --path . --write-movie "$out/frames/f.png" --fixed-fps 30 -- \
  --track="$track" --seconds="$seconds" --progress="$from" --grow-to="$to" --species="$species"
ffmpeg -y -loglevel error -framerate 30 -i "$out/frames/f%08d.png" -i "$out/frames/f.wav" \
  -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le -c:a pcm_s16le -shortest "$out/$name.mov"
rm -rf "$out/frames"
echo "wrote $out/$name.mov"
