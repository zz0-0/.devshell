#!/usr/bin/env bash
# 冒烟：把每个模板复制到临时目录，真正进一次 devShell（nix develop --command true）。
# 用 --override-input 指到本地仓库，测的是当前改动，不是 GitHub 上那份。
# EVAL_ONLY=1 时只实例化 deriv，不构建——快，但抓不到运行期问题。
# 用法：./scripts/check-templates.sh [system] [template...]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
system="${1:-x86_64-linux}"
shift || true
mode="${EVAL_ONLY:+eval}"
mode="${mode:-full}"

# --changed：只验这次改到的模板。改共享文件时退化成全部。
# 基准默认 HEAD~1，可以用 CHECK_BASE 指到别处（例如 pre-push 的 merge-base）。
changed_template_names() {
  local base="${CHECK_BASE:-HEAD~1}" files name all=0
  files="$(git -C "$root" diff --name-only "$base" -- . 2>/dev/null || true)"
  [ -n "$files" ] || return 0
  case "$files" in
    *languages/common.nix* | *flake.nix* | *scripts/* | *interface.json*)
      all=1
      ;;
  esac
  if [ "$all" -eq 1 ]; then
    for d in "$root"/templates/*/; do printf '%s\n' "$(basename "$d")"; done
    return 0
  fi
  printf '%s\n' "$files" | while IFS= read -r f; do
    case "$f" in
      languages/*.nix)
        name="$(basename "$f" .nix)"
        [ "$name" = common ] || printf '%s\n' "$name"
        ;;
      templates/*)
        printf '%s\n' "${f#templates/}" | cut -d/ -f1
        ;;
    esac
  done | sort -u | while IFS= read -r name; do
    [ -d "$root/templates/$name" ] && printf '%s\n' "$name"
  done
}

if [ "${1:-}" = "--changed" ]; then
  shift
  mapfile -t names < <(changed_template_names)
  if [ "${#names[@]}" -eq 0 ]; then
    printf 'ok   templates（这次没改到任何模板）\n'
    exit 0
  fi
else
  names=("$@")
fi

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
  ok=0
  if [ "$mode" = eval ]; then
    (cd "$tmp" && nix eval --raw \
      --override-input devshell "path:$root" \
      ".#devShells.$system.default.drvPath" >/dev/null 2>&1) && ok=1
  else
    (cd "$tmp" && nix develop \
      --override-input devshell "path:$root" \
      --command true >/dev/null 2>&1) && ok=1
  fi
  if [ "$ok" = 1 ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n' "$name" >&2
    fail=1
  fi
  rm -rf "$tmp"
done

exit "$fail"
