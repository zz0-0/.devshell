#!/usr/bin/env bash
# 交付检查：按 scripts/deliver.manifest 逐行验规格。只验当前版。
set -uo pipefail
self=$(readlink -f "$0")
cd "$(dirname "$self")/.."

if [ -z "${DIRENV_IN_ENVRC:-}" ] && command -v direnv >/dev/null 2>&1; then
  export DIRENV_LOG_FORMAT=
  exec direnv exec . "$self" "$@"
fi

MANIFEST="scripts/deliver.manifest"
fail=0
ok() { printf 'ok   %s\n' "$*"; }
no() { printf 'FAIL %s\n' "$*" >&2; fail=$((fail + 1)); }
probe() { ffprobe -v error "$@"; }

if ! grep -qE '^[^#]' "$MANIFEST" 2>/dev/null; then
  printf 'ok   清单是空的（还没有交付物）\n'
  exit 0
fi

check_video() {
  local name=$1 f=$2 spec=$3 d wh fps vcodec acodec sr ch loud I P
  if [ ! -f "$f" ]; then no "$name $f 不存在"; return; fi
  d=$(probe -show_entries format=duration -of default=nw=1:nk=1 "$f")
  if awk -v d="$d" 'BEGIN{exit !(d > 0 && d <= 60)}'; then ok "$name 时长 ${d}s"; else no "$name 时长 ${d}s（要 ≤60s）"; fi
  wh=$(probe -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$f")
  [ "$wh" = "$spec" ] && ok "$name 画幅 $wh" || no "$name 画幅 $wh（要 $spec）"
  fps=$(probe -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$f")
  [ "$fps" = "30/1" ] && ok "$name 30fps" || no "$name 帧率 $fps"
  vcodec=$(probe -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$f")
  [ "$vcodec" = "h264" ] && ok "$name H.264" || no "$name 视频编码 $vcodec"
  acodec=$(probe -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$f" || true)
  sr=$(probe -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$f" || true)
  ch=$(probe -select_streams a:0 -show_entries stream=channels -of default=nw=1:nk=1 "$f" || true)
  if [ "$acodec" = "aac" ] && [ "$sr" = "48000" ] && [ "$ch" = "2" ]; then ok "$name AAC 48k stereo"; else no "$name 音频 $acodec / $sr / ${ch}ch"; fi
  loud=$(ffmpeg -v info -i "$f" -filter_complex ebur128=peak=true -f null - 2>&1)
  I=$(printf '%s\n' "$loud" | sed -n 's/^ *I: *\([-0-9.]*\) LUFS.*/\1/p' | tail -1)
  P=$(printf '%s\n' "$loud" | sed -n 's/^ *Peak: *\([-0-9.]*\) dBFS.*/\1/p' | tail -1)
  if [ -n "$I" ] && [ -n "$P" ] && awk -v i="$I" -v p="$P" 'BEGIN{exit !(i >= -15 && i <= -13 && p <= -1.0)}'; then
    ok "$name 响度 ${I} LUFS / peak ${P} dBFS"
  else
    no "$name 响度 ${I:-?} LUFS / peak ${P:-?} dBFS（要 -15..-13 / ≤ -1）"
  fi
}

check_cover() {
  local name=$1 f=$2 spec=$3 dims
  if [ ! -f "$f" ]; then no "$name $f 不存在"; return; fi
  dims=$(probe -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$f")
  [ "$dims" = "$spec" ] && ok "$name $dims" || no "$name $dims（要 $spec）"
}

n=0
while IFS='|' read -r name kind path spec; do
  case "$name" in ''|'#'*) continue ;; esac
  n=$((n + 1))
  case "$kind" in
    video) check_video "$name" "$path" "$spec" ;;
    cover) check_cover "$name" "$path" "$spec" ;;
    *) no "清单第 $n 行类型不认识：$kind" ;;
  esac
done <"$MANIFEST"

if [ "$fail" -eq 0 ]; then
  printf '\ndelivery: green（%s 件）\n' "$n"
else
  printf '\ndelivery: red（%s 项）\n' "$fail" >&2
  exit 1
fi
