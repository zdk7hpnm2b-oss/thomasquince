#!/bin/bash
# Vidéo de comparaison verticale GTA 5 vs GTA 6 pour TikTok (1080x1920).
# Usage : comparaison.sh gta5.mp4 gta6.mp4 sortie.mp4 "Accroche" ["Question finale"] [debut5_sec] [debut6_sec] [duree_sec]
# Disposition : accroche en haut, GTA 5 au-dessus, GTA 6 en dessous (image entière), question en bas, fond flou.
set -e
g5="$1"; g6="$2"; out="$3"; hook="$4"; ask="${5:-Lequel est le meilleur ?}"
s5="${6:-0}"; s6="${7:-0}"; dur="${8:-}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
python3 - "$hook" "$ask" "$tmp" <<'PY'
import sys, textwrap, re
hook, ask, d = sys.argv[1:4]
strip = lambda s: re.sub(r"[^\u0000-￿]|[☀-➿️]", "", s).strip()
open(f"{d}/hook.txt", "w").write("\n".join(textwrap.wrap(strip(hook).upper(), 22)))
open(f"{d}/ask.txt", "w").write("\n".join(textwrap.wrap(strip(ask).upper(), 26)))
open(f"{d}/l5.txt", "w").write("GTA 5")
open(f"{d}/l6.txt", "w").write("GTA 6")
PY
if [ -z "$dur" ]; then
  d5=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$g5"); d6=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$g6")
  dur=$(python3 -c "print(min(float('$d5')-$s5, float('$d6')-$s6, 60))")
fi
F=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
# Chaque panneau : 1080x608 (16:9 entier). Positions : GTA 5 y=330, GTA 6 y=962.
ffmpeg -loglevel error -y -ss "$s5" -t "$dur" -i "$g5" -ss "$s6" -t "$dur" -i "$g6" -filter_complex "\
[1:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=30:2,eq=brightness=-0.25,setsar=1[bg];\
[0:v]scale=1080:608:force_original_aspect_ratio=decrease,pad=1080:608:(ow-iw)/2:(oh-ih)/2,setsar=1[a];\
[1:v]scale=1080:608:force_original_aspect_ratio=decrease,pad=1080:608:(ow-iw)/2:(oh-ih)/2,setsar=1[b];\
[bg][a]overlay=0:330[t1];[t1][b]overlay=0:962,\
drawbox=x=0:y=326:w=1080:h=4:color=white@0.9:t=fill,drawbox=x=0:y=1570:w=1080:h=4:color=white@0.9:t=fill,\
drawbox=x=24:y=350:w=210:h=74:color=0x1f6feb@0.92:t=fill,drawtext=fontfile=$F:textfile=$tmp/l5.txt:fontsize=50:fontcolor=white:x=24+(210-text_w)/2:y=350+(74-text_h)/2,\
drawbox=x=24:y=982:w=210:h=74:color=0xe0306b@0.95:t=fill,drawtext=fontfile=$F:textfile=$tmp/l6.txt:fontsize=50:fontcolor=white:x=24+(210-text_w)/2:y=982+(74-text_h)/2,\
drawtext=fontfile=$F:textfile=$tmp/hook.txt:fontsize=70:line_spacing=12:fontcolor=white:borderw=7:bordercolor=black:x=(w-text_w)/2:y=300-text_h-24,\
drawtext=fontfile=$F:textfile=$tmp/ask.txt:fontsize=58:line_spacing=10:fontcolor=white:borderw=6:bordercolor=black:x=(w-text_w)/2:y=1620[v];\
[0:a]volume=0.35[a5];[1:a]volume=1.0[a6];[a5][a6]amix=inputs=2:duration=shortest:normalize=0[aud]" \
-map "[v]" -map "[aud]" -t "$dur" -r 30 -c:v libx264 -preset veryfast -crf 19 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart "$out"
echo "OK -> $out ($dur s)"
