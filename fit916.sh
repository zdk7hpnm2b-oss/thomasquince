#!/bin/bash
# Usage: fit916.sh entree.mp4 sortie.mp4 "Texte d'accroche" "Crédit"
# Vidéo entière au centre (rien n'est coupé), fond flou derrière, 1080x1920 pour TikTok.
in="$1"; out="$2"
tmp=$(mktemp -d)
python3 - "$3" "$4" "$tmp" <<'PY'
import sys, textwrap, re
hook, credit, d = sys.argv[1], sys.argv[2], sys.argv[3]
strip = lambda s: re.sub(r"[^\u0000-￿]|[☀-➿️]", "", s).strip()
open(f"{d}/hook.txt", "w").write("\n".join(textwrap.wrap(strip(hook).upper(), 20)))
open(f"{d}/credit.txt", "w").write(strip(credit))
PY
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
ffmpeg -loglevel error -y -i "$in" -filter_complex "\
[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=25:2,eq=brightness=-0.15[bg];\
[0:v]scale=1080:-2[fg];\
[bg][fg]overlay=(W-w)/2:(H-h)/2,\
drawtext=fontfile=$FONT:textfile=$tmp/hook.txt:fontsize=72:line_spacing=14:fontcolor=white:borderw=7:bordercolor=black:x=(w-text_w)/2:y=h*0.30-text_h,\
drawtext=fontfile=$FONT:textfile=$tmp/credit.txt:fontsize=42:fontcolor=white:borderw=4:bordercolor=black:x=(w-text_w)/2:y=h*0.72[v]" \
-map "[v]" -map 0:a? -c:v libx264 -preset veryfast -crf 20 -c:a aac -b:a 160k -movflags +faststart "$out"
rm -rf "$tmp"
