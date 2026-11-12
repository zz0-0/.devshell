#!/usr/bin/env bash
# 这个项目"什么算完成"。模板给起点，项目继续加。
set -euo pipefail
cd "$(dirname "$0")"

# 不在环境里就自动进一次，这样从任何 shell 跑都对。
if [ -z "${DIRENV_IN_ENVRC:-}" ] && command -v direnv >/dev/null 2>&1; then
  exec direnv exec . "$0" "$@"
fi

nix flake check

echo "== 工具"
./scripts/check-tools.sh
