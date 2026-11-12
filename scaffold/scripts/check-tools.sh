#!/usr/bin/env bash
# 工具表：tools.txt 一行一个命令，缺一个就红。
# 在 devshell 里跑（check.sh 已经进环境）；没有 tools.txt 就跳过。
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f tools.txt ] || { echo "ok   没有 tools.txt，跳过"; exit 0; }

missing=""
n=0
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  t=${line%%[[:space:]]*}
  n=$((n + 1))
  command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
done <tools.txt

if [ -n "$missing" ]; then
  printf 'FAIL 缺工具:%s（见 tools.txt）\n' "$missing" >&2
  exit 1
fi
printf 'ok   %s 个工具都在\n' "$n"
