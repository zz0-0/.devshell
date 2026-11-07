#!/usr/bin/env bash
# 冒烟：把每个模板复制到临时目录，实例化它的 devShell，不构建。
# 用 --override-input 指到本地仓库，测的是当前改动，不是 GitHub 上那份。
# 用法：./scripts/check-templates.sh [system] [template...]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
system="${1:-x86_64-linux}"
shift || true

names=("$@")
if [ "${#names[@]}" -eq 0 ]; then
  for d in "$root"/templates/*/; do
    names+=("$(basename "$d")")
  done
fi

fail=0
for name in "${names[@]}"; do
  src="$root/templates/$name"
  if [ ! -d "$src" ]; then
    printf 'no such template: %s\n' "$name" >&2
    fail=1
    continue
  fi
  tmp="$(mktemp -d)"
  cp -a "$src"/. "$tmp"/
  if (cd "$tmp" && nix eval --raw \
        --override-input devshell "path:$root" \
        ".#devShells.$system.default.drvPath" >/dev/null 2>&1); then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n' "$name" >&2
    fail=1
  fi
  rm -rf "$tmp"
done

exit "$fail"
