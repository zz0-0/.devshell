#!/usr/bin/env bash
# 画面 / 声音检查：黑帧、静止、平帧、响度，外加一张接触表。
# 用法：scripts/check-qc.sh [mp4] [--sheet out.png]
# 默认验 scripts/deliver.manifest 里第一条 video；没有就跳过。
set -uo pipefail
self=$(readlink -f "$0")
cd "$(dirname "$self")/.."

if [ -z "${DIRENV_IN_ENVRC:-}" ] && command -v direnv >/dev/null 2>&1; then
  export DIRENV_LOG_FORMAT=
  exec direnv exec . "$self" "$@"
fi

f=""; sheet=""
while [ $# -gt 0 ]; do
  case "$1" in --sheet) sheet=$2; shift 2 ;; *) f=$1; shift ;; esac
done
[ -n "$f" ] || f=$(awk -F'|' '$2=="video"{print $3; exit}' scripts/deliver.manifest 2>/dev/null)
if [ -z "$f" ]; then printf 'ok   清单里还没有 video，跳过\n'; exit 0; fi
[ -f "$f" ] || { echo "FAIL 找不到 $f" >&2; exit 1; }
[ -n "$sheet" ] || sheet="deliver/qc_$(basename "${f%.mp4}")_contact.png"

fail=0; warn=0
ok() { printf 'ok    %s\n' "$*"; }
no() { printf 'FAIL  %s\n' "$*" >&2; fail=$((fail + 1)); }
wa() { printf 'warn  %s\n' "$*"; warn=$((warn + 1)); }

echo "== $f"
n_v=$(ffprobe -v error -select_streams v:0 -show_entries stream=index -of csv=p=0 "$f")
n_a=$(ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 "$f")
[ -n "$n_v" ] && ok "有视频流" || no "没有视频流"
[ -n "$n_a" ] && ok "有音频流" || no "没有音频流"

blk=$(ffmpeg -v info -i "$f" -vf "blackdetect=d=0.3:pix_th=0.10" -an -f null - 2>&1 | grep -o 'black_start:[0-9.]*' | tr '\n' ' ' || true)
[ -z "$blk" ] && ok "没有 ≥0.3s 黑帧" || no "黑帧：$blk"

frz=$(ffmpeg -v info -i "$f" -vf "freezedetect=n=0.003:d=1.0" -an -f null - 2>&1 | grep -o 'freeze_start: [0-9.]*' | sed 's/freeze_start: //' | tr '\n' ' ' || true)
[ -z "$frz" ] && ok "没有 ≥1s 完全静止" || wa "静止 ≥1s 的起点：$frz（有意的停顿写进审片记录）"

read -r run at ratio < <(ffmpeg -v error -i "$f" -map 0:v -f framemd5 - 2>/dev/null | awk -F', *' '
  /^[0-9]/ {n++; h=$NF; if (h==prev) {r++; same++} else {r=1; prev=h}
            if (r>max) {max=r; at=n}}
  END {printf "%d %.1f %.2f\n", max, at/30, (same+0)/n}')
if awk -v r="${ratio:-0}" 'BEGIN{exit !(r > 0.5)}'; then no "平帧占 ${ratio}（>50%）：画面没在动"
elif [ "${run:-0}" -gt 15 ]; then wa "最长完全静止 ${run} 帧（起于 ${at}s）"
else ok "平帧 ${ratio:-?}，最长 ${run:-?} 帧（起于 ${at}s）"; fi

loud=$(ffmpeg -v info -i "$f" -filter_complex ebur128=peak=true -f null - 2>&1)
I=$(printf '%s\n' "$loud" | sed -n 's/^ *I: *\([-0-9.]*\) LUFS.*/\1/p' | tail -1)
P=$(printf '%s\n' "$loud" | sed -n 's/^ *Peak: *\([-0-9.]*\) dBFS.*/\1/p' | tail -1)
if [ -n "$I" ] && [ -n "$P" ] && awk -v i="$I" -v p="$P" 'BEGIN{exit !(i >= -15 && i <= -13 && p <= -1.0)}'; then
  ok "响度 ${I} LUFS / peak ${P} dBFS"
else
  no "响度 ${I:-?} LUFS / peak ${P:-?} dBFS（要 -15..-13 / ≤ -1）"
fi

mkdir -p "$(dirname "$sheet")"
if ffmpeg -v error -y -i "$f" -vf "fps=1/2,scale=240:-1,tile=6x4:padding=4:margin=4" -frames:v 1 "$sheet"; then ok "接触表 $sheet"; else no "接触表生成失败"; fi

printf '\nqc: %s（%s 条 FAIL，%s 条 warn）\n' "$([ "$fail" -eq 0 ] && echo green || echo red)" "$fail" "$warn"
[ "$fail" -eq 0 ]
