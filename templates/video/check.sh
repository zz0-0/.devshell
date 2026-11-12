#!/usr/bin/env bash
# 这个项目"什么算完成"：环境能构建 + 工具在 + 文档指针 + 上屏数字 + 交付规格。
# 画面走 scripts/check-qc.sh，渲前走 scripts/pre-render.sh——都不在每次 push 跑。
set -euo pipefail
cd "$(dirname "$0")"

if [ -z "${DIRENV_IN_ENVRC:-}" ] && command -v direnv >/dev/null 2>&1; then
  export DIRENV_LOG_FORMAT=
  exec direnv exec . "$0" "$@"
fi

echo "== 环境"
# 检查已被缓存时 nix 会打印 "0 flake checks"，那不算通过——所以下面再加一段更硬的。
nix flake check

echo "== 工具"
./scripts/check-tools.sh

echo "== 文档指针"; ./scripts/check-doc-pointers.sh
echo "== 上屏"; python3 scripts/check-onscreen.py
echo "== 交付"; ./scripts/check-delivery.sh
