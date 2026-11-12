#!/usr/bin/env bash
# 静帧门（still gate）：全片渲染之前，按时间点抽静帧，人看完再放行。
# 做法：hyperframes render 只渲 --start..--end 这一小段，ffmpeg 抽 1 帧。
# 用法：scripts/stills.sh [--wide] [--approve] [--times a,b,c]
set -uo pipefail
self=$(readlink -f "$0")
cd "$(dirname "$self")/.."

if [ -z "${DIRENV_IN_ENVRC:-}" ] && command -v direnv >/dev/null 2>&1; then
  export DIRENV_LOG_FORMAT=
  exec direnv exec . "$self" "$@"
fi

comp="$(sed '/^#/d;/^$/d' scripts/compositions.txt | head -1)"
wide=0; approve=0; times=""
while [ $# -gt 0 ]; do
  case "$1" in
    --wide) wide=1; comp="$(sed '/^#/d;/^$/d' scripts/compositions.txt | sed -n 2p)"; shift ;;
    --approve) approve=1; shift ;;
    --times) times=$2; shift 2 ;;
    *) echo "未知参数 $1" >&2; exit 2 ;;
  esac
done
[ -n "$comp" ] && [ -f "$comp" ] || { echo "ok   还没有构图（scripts/compositions.txt）——先建片再抽静帧"; exit 0; }

hash=$(scripts/composition-hash.sh "$comp")
[ "$wide" -eq 1 ] && hash="$hash-wide"
dir="deliver/stills/$hash"
contact="$dir/contact.png"
[ -n "$times" ] && dir="deliver/stills/try"

if [ "$approve" -eq 1 ]; then
  [ -f "$contact" ] || { echo "FAIL 没有 $contact：先跑 scripts/stills.sh，看完再批准" >&2; exit 1; }
  { printf 'hash=%s\n' "$hash"; printf 'when=%s\n' "$(date -Iseconds)"; printf 'composition=%s\n' "$comp"; printf 'contact=%s\n' "$contact"; } >deliver/stills/APPROVED
  echo "approved: $hash → deliver/stills/APPROVED"; exit 0
fi

[ -n "$times" ] || times=$(sed '/^#/d;/^$/d' scripts/stills.txt | tr -s '\n' ' ')
times=${times//,/ }
read -r -a list <<<"$times"
[ "${#list[@]}" -gt 0 ] || { echo "FAIL 没有时间点（scripts/stills.txt）" >&2; exit 1; }

mkdir -p "$dir"
rm -f "$dir"/*.png
fail=0
ok() { printf 'ok    %s\n' "$*"; }
no() { printf 'FAIL  %s\n' "$*" >&2; fail=$((fail + 1)); }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

i=0
for t in "${list[@]}"; do
  i=$((i + 1))
  end=$(awk -v t="$t" 'BEGIN{printf "%.2f", t + 0.12}')
  out="$tmp/$i.mp4"
  printf '\n== %s  %ss\n' "$comp" "$t"
  if ! (cd "$(dirname "$comp")" && npx --yes hyperframes render . -c "$(basename "$comp")" \
      --start "$t" --end "$end" --format mp4 -o "$out" >/dev/null 2>&1); then
    no "渲染 $t s 失败"; continue
  fi
  name=$(printf 'at-%05.1fs.png' "$t")
  [ "$wide" -eq 1 ] && name=$(printf 'wide-at-%05.1fs.png' "$t")
  ffmpeg -v error -y -i "$out" -frames:v 1 "$dir/$name" && ok "$name" || no "抽帧 $t s 失败"
done

n_png=$(find "$dir" -name '*.png' | wc -l)
[ "$n_png" -eq "${#list[@]}" ] && ok "静帧 $n_png 张" || no "静帧 $n_png 张，要 ${#list[@]} 张"
want="1080x1920"; [ "$wide" -eq 1 ] && want="1920x1080"
bad_dim=""; blank=""
for f in "$dir"/*.png; do
  [ -f "$f" ] || continue
  dim=$(identify -format '%wx%h' "$f"); [ "$dim" = "$want" ] || bad_dim="$bad_dim $(basename "$f")=$dim"
  sd=$(identify -format '%[fx:standard_deviation]' "$f"); awk -v s="$sd" 'BEGIN{exit !(s < 0.005)}' && blank="$blank $(basename "$f")"
done
[ -z "$bad_dim" ] && ok "尺寸都是 $want" || no "尺寸不对：$bad_dim"
[ -z "$blank" ] && ok "没有空白帧" || no "空白帧：$blank"

uniq=$(md5sum "$dir"/*.png 2>/dev/null | awk '{print $1}' | sort -u | wc -l)
if [ "$n_png" -eq 0 ]; then no "没有静帧可检"
elif [ "$uniq" -le 1 ] && [ "$n_png" -gt 1 ]; then no "全部静帧一样：seek 没生效？"
elif [ "$uniq" -lt "$n_png" ]; then printf 'warn  %s 张里有 %s 种（有重复，静止镜头可接受）\n' "$n_png" "$uniq"; ok "静帧 $uniq 种"
else ok "静帧 $uniq 种（各不相同）"; fi

if montage -background '#111111' -tile 3x -geometry 320x+8+8 \
    $(ls "$dir"/*.png 2>/dev/null | grep -v '/contact\.png$' | sort -V) "$contact" 2>/dev/null; then
  ok "接触表 $contact"
else
  no "接触表生成失败"
fi

if [ -f deliver/stills/APPROVED ]; then
  approved=$(sed -n 's/^hash=//p' deliver/stills/APPROVED | head -1)
  if [ "$approved" = "$hash" ]; then ok "这版构图已批准（$hash）"; else printf 'warn  构图变了：批准的是 %s，现在是 %s——看完再 --approve\n' "$approved" "$hash"; fi
else
  printf 'warn  还没人看过这版静帧：看完跑 scripts/stills.sh --approve\n'
fi

printf '\nstills: %s（%s 条 FAIL）\n' "$([ "$fail" -eq 0 ] && echo green || echo red)" "$fail"
printf '看这一排（按顺序：%s）：%s\n' "${list[*]}" "$contact"
[ "$fail" -eq 0 ]
