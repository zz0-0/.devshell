#!/usr/bin/env bash
# 当前构图的指纹：compositions.txt 里列的文件的 sha256，取前 12 位。
# 构图一改，指纹就变——静帧门的批准随之失效。
set -euo pipefail
cd "$(dirname "$0")/.."

files=$(sed '/^#/d;/^$/d' scripts/compositions.txt | head -1)
[ $# -gt 0 ] && files=$1
[ -n "$files" ] || { echo "compositions.txt 是空的：先写第一行" >&2; exit 1; }

# shellcheck disable=SC2086
sha256sum $files | sha256sum | cut -c1-12
