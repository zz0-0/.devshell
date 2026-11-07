#!/usr/bin/env bash
# 新 clone 之后跑一次。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init -q
  # flake 只看得见被 git 跟踪的文件；初始化后先把当前内容纳入索引。
  git add -A
fi

git config core.hooksPath .githooks

if command -v direnv >/dev/null 2>&1; then
  direnv allow || printf 'warning: direnv allow failed\n' >&2
fi

printf 'hooksPath: %s\n' "$(git config core.hooksPath)"
