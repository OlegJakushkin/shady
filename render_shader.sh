#!/usr/bin/env bash
set -euo pipefail

FPS=${FPS:-30}
RES=${RES:-3840x2160}            # override with `-e RES=1920x1080`
OUT=${3:-output_4k.mp4}

[[ $# -lt 2 ]] && { echo "Usage: $0 shader.frag audio.mp3 [output.mp4]"; exit 1; }
SHADER=$1
AUDIO=$2

# length → frame count
DUR=$(ffprobe -v error -show_entries format=duration \
              -of default=noprint_wrappers=1:nokey=1 "$AUDIO")
FRAMES=$(python3 -c "import math,sys; dur=float(sys.argv[1]); fps=float(sys.argv[2]); \
                      print(math.ceil(dur*fps))" "$DUR" "$FPS")

# bail out early if the calc failed
if [[ -z $FRAMES || $FRAMES == 0 ]]; then
  echo "❌  Could not compute frame count (DUR=$DUR, FPS=$FPS)" >&2
  exit 1
fi

# render (shady) → pipe raw RGB → encode (ffmpeg) + mux audio
shady -i "$SHADER" -g "$RES" -f "$FPS" -n "$FRAMES" \
      -ofmt rgb24 -map iChannel0=audio:"$AUDIO" | \
ffmpeg -y -f rawvideo -pixel_format rgb24 -video_size "$RES" -framerate "$FPS" \
       -i - -i "$AUDIO" \
       -c:v libx264 -preset slow -pix_fmt yuv420p -crf 18 -c:a copy "$OUT"
echo "✅  Done ➜ $OUT"
