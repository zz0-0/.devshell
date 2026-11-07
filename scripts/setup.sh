#!/usr/bin/env bash
# 新 clone 之后跑一次。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

git config core.hooksPath .githooks
direnv allow

printf 'hooksPath: %s\n' "$(git config core.hooksPath)"
