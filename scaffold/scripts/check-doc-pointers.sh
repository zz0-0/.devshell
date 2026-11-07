#!/usr/bin/env bash
# 检查文档里引用的仓库内路径是否仍然存在。断了就是改名或删文件时忘了同步。
# 只查“第一段在仓库里存在”的路径，所以外部/消费侧路径（.venv/、~/.nixos 之类）自动跳过。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

bad=0

check_ref() {
  local ref="$1" file="$2" first
  case "$ref" in
    ''|'#'*|http*|mailto*) return 0 ;;
    *'*'*|*'<'*|*'>'*|*' '*|*'$'*) return 0 ;;
    */*) ;;
    *) return 0 ;;
  esac
  first="${ref%%/*}"
  [ -n "$first" ] || return 0
  [ -e "$first" ] || return 0
  if [ ! -e "$ref" ]; then
    printf '%s: %s\n' "$file" "$ref" >&2
    bad=1
  fi
  return 0
}

for f in *.md docs/*.md; do
  [ -f "$f" ] || continue
  while IFS= read -r ref; do
    check_ref "$ref" "$f"
  done < <(grep -o '`[^`]*`' "$f" | tr -d '`')
  while IFS= read -r ref; do
    check_ref "$ref" "$f"
  done < <(grep -o '](\([^)]*\))' "$f" | sed 's/^](//; s/)$//')
done

exit "$bad"
