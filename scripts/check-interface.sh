#!/usr/bin/env bash
# 公共接口检查：lib.<system>.<lang> 的参数名就是接口。
# 改名或删参数会被这里抓到——那属于破坏性变更。
# 用法：./scripts/check-interface.sh [system]
#       ./scripts/check-interface.sh --update   # 确认是有意的变更后，重写基线
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ "${1:-}" = "--update" ]; then
  system="${2:-x86_64-linux}"
  update=1
else
  system="${1:-x86_64-linux}"
  update=0
fi

file="interface.json"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
  printf '{\n'
  first=1
  for f in languages/*.nix; do
    lang="$(basename "$f" .nix)"
    [ "$lang" = common ] && continue
    args="$(nix eval --json ".#lib.$system.$lang" --apply 'f: builtins.functionArgs f')"
    [ "$first" = 1 ] || printf ',\n'
    printf '  "%s": %s' "$lang" "$args"
    first=0
  done
  printf '\n}\n'
} >"$tmp"

if [ "$update" = 1 ]; then
  mv "$tmp" "$file"
  printf 'wrote %s\n' "$file"
  exit 0
fi

if ! diff -u "$file" "$tmp"; then
  printf '\n接口变了。如果是有意的，跑 ./scripts/check-interface.sh --update 并提交；否则改回去。\n' >&2
  exit 1
fi

printf 'ok   interface (%s)\n' "$system"
