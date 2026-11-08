#!/usr/bin/env bash
# 唯一入口：钩子调它，人也调它。
#
# 两层：
#   默认     —— 守接口。全部 eval + 接口 + 只验这次改到的模板。
#   --all    —— 验集成。全部模板真的进一次 devShell。发布前、或动了 common 之后跑。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

all=0
[ "${1:-}" = "--all" ] && all=1

printf 'check: nix flake check\n' >&2
nix flake check

printf 'check: doc pointers\n' >&2
./scripts/check-doc-pointers.sh

printf 'check: interface\n' >&2
./scripts/check-interface.sh

if [ "$all" -eq 1 ]; then
  printf 'check: templates (all)\n' >&2
  ./scripts/check-templates.sh
else
  printf 'check: templates (changed)\n' >&2
  base="$(git merge-base HEAD '@{push}' 2>/dev/null || echo HEAD~1)"
  CHECK_BASE="$base" ./scripts/check-templates.sh --changed
fi
