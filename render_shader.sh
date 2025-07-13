#!/usr/bin/env bash
set -euo pipefail

# Tunables
FPS=${FPS:-30}                       # env-override:   FPS=60   ./render ...
RES=${RES:-3840x2160}                # env-override:   RES=1920x1080 ...
A_CODEC=${A_CODEC:-aac}              # “copy” to keep source codec, aac default
A_BITRATE=${A_BITRATE:-192k}
V_CODEC=${V_CODEC:-libx264rgb}
V_PRESET=${V_PRESET:-slow}
V_LOSSLESS=${V_LOSSLESS:--crf 0}   # empty → normal CRF 18 encode
PIX_FMT=${PIX_FMT:-rgb24}

OUT=${3:-output_4k.mp4}              # 3rd arg or fallback

[[ $# -lt 2 ]] && {
  echo "Usage: $0 shader.frag audio.(mp3|wav|flac) [output.mp4]" >&2
  exit 1
}

SHADER=$1
AUDIO=$2

# Length → Frame count
DUR=$(ffprobe -v error -select_streams a:0 \
              -show_entries stream=duration \
              -of default=noprint_wrappers=1:nokey=1 "$AUDIO")

FRAMES=$(python3 - <<'PY' "$DUR" "$FPS"
import math, sys
dur, fps = map(float, sys.argv[1:])
print(math.ceil(dur * fps))
PY
)

[[ -z $FRAMES || $FRAMES -le 0 ]] && {
  echo "❌  Could not compute frame count (DUR=$DUR, FPS=$FPS)" >&2
  exit 1
}

# Render frames → pipe raw RGB → ffmpeg (encode + mux audio)
shady -i "$SHADER" -g "$RES" -f "$FPS" -n "$FRAMES" \
      -ofmt rgb24 -map iChannel0=audio:"$AUDIO" | \
ffmpeg -stats -y \
       -f rawvideo -pixel_format rgb24 -video_size "$RES" -framerate "$FPS" -i - \
       -i "$AUDIO" \
       -map 0:v:0 -map 1:a:0 -shortest \
       -c:v "$V_CODEC" $V_LOSSLESS -preset "$V_PRESET" -pix_fmt "$PIX_FMT" \
       -c:a "$A_CODEC" -b:a "$A_BITRATE" \
       -movflags +faststart "$OUT"

echo "✅  Done ➜ $OUT"
