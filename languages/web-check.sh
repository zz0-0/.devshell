#!/usr/bin/env bash
# 网页的机械错：不看设计判断，只抓那些"没有理由这么写"的。
# 用法：web-check <目录> [<目录>...]
#
# 只收 grep 级别、假阳性低的规则。真做无障碍要 axe/pa11y 跑浏览器，
# 这里查的是它们跑之前就该修掉的那批。
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
findings="$tmp/findings"
: >"$findings"

note() { printf '%s: %s\n' "$1" "$2" >>"$findings"; }

# scan <文件> <正则> <消息>
scan() {
  local f="$1" re="$2" msg="$3" n _rest
  while IFS=: read -r n _rest; do
    [ -n "$n" ] || continue
    note "$f:$n" "$msg"
  done < <(grep -nE -- "$re" "$f" || true)
}

for root in "$@"; do
  [ -d "$root" ] || continue

  mapfile -t html < <(find "$root" -name '*.html' -not -path '*/node_modules/*' -not -path '*/vendor/*')
  mapfile -t css < <(find "$root" -name '*.css' -not -path '*/node_modules/*' -not -path '*/vendor/*')

  # 有动画就必须有 reduced-motion 分支
  if printf '%s\n' "${css[@]}" | xargs grep -lE '(animation|transition):' 2>/dev/null | grep -q .; then
    if ! printf '%s\n' "${css[@]}" | xargs grep -l 'prefers-reduced-motion' 2>/dev/null | grep -q .; then
      note "$root" "有动画，但没有任何 @media (prefers-reduced-motion)"
    fi
  fi

  for f in "${css[@]}"; do
    scan "$f" 'transition:[^;]*\ball\b' 'transition: all——列出具体属性'
    if grep -qE 'outline:\s*(none|0)' "$f" && ! grep -qE ':focus-visible' "$f"; then
      note "$f" "去掉 outline 但没有 :focus-visible 替代"
    fi
  done

  for f in "${html[@]}"; do
    scan "$f" 'user-scalable=no|maximum-scale=1' '禁止缩放'
    scan "$f" '<(div|span)[^>]*onclick' 'div/span 带点击——该是 <button>'

    while IFS=: read -r n line; do
      [ -n "$n" ] || continue
      case "$line" in
        *width=*) ;;
        *) note "$f:$n" '<img> 没有 width，会跳版' ;;
      esac
    done < <(grep -n '<img' "$f" || true)

    grep -qE 'name="viewport"' "$f" || note "$f" "没有 viewport meta"

    # ── 收自 vercel-labs/web-interface-guidelines（只留 grep 能判的）──
    grep -qE '<html[^>]*lang=' "$f" || note "$f" "<html> 没有 lang"
    grep -qE '<title>' "$f" || note "$f" "没有 <title>"
    [ "$(grep -oE '<h1' "$f" 2>/dev/null | wc -l)" -le 1 ] || note "$f" "不止一个 <h1>"

    while IFS=: read -r n line; do
      [ -n "$n" ] || continue
      case "$line" in *alt=*) ;; *) note "$f:$n" "<img> 没有 alt（装饰性的写 alt=空）" ;; esac
    done < <(grep -n '<img' "$f" || true)

    while IFS=: read -r n line; do
      [ -n "$n" ] || continue
      case "$line" in *noopener*|*noreferrer*) ;; *) note "$f:$n" "target=_blank 没有 rel=noopener" ;; esac
    done < <(grep -n 'target="_blank"' "$f" || true)

    while IFS=: read -r n line; do
      [ -n "$n" ] || continue
      case "$line" in *type=*) ;; *) note "$f:$n" "<button> 没有 type——在 form 里会变成 submit" ;; esac
    done < <(grep -n '<button' "$f" || true)

    scan "$f" 'tabindex="[1-9]' "正数 tabindex——插队"
    scan "$f" '<div[^>]*role="button"' "div 冒充按钮"
  done
done

if [ -s "$findings" ]; then
  cat "$findings" >&2
  exit 1
fi
printf 'ok   web rules\n'
