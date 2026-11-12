#!/usr/bin/env bash
# 渲染前门：上屏数字 + hyperframes check + 静帧批准。红 = 别渲。
# 还没建构图时不拦：只提示缺什么。
set -uo pipefail
self=$(readlink -f "$0")
cd "$(dirname "$self")/.."

if [ -z "${DIRENV_IN_ENVRC:-}" ] && command -v direnv >/dev/null 2>&1; then
  export DIRENV_LOG_FORMAT=
  exec direnv exec . "$self" "$@"
fi

fail=0
comp=$(sed '/^#/d;/^$/d' scripts/compositions.txt | head -1)

if [ -z "$comp" ] || [ ! -f "$comp" ]; then
  printf 'ok   还没有构图（scripts/compositions.txt 第一行）——先建片再进这道门\n'
  exit 0
fi

[ -f content/FACTS.md ] && { python3 scripts/check-onscreen.py || fail=1; }

printf '== hyperframes check\n'
if (cd "$(dirname "$comp")" && npx --yes hyperframes check --json >/dev/null 2>&1); then
  printf 'ok   hyperframes check 0 error（warn 看 .hyperframes/artifacts/checks/）\n'
else
  printf 'FAIL hyperframes check 有 error → 看 %s/.hyperframes/artifacts/checks/ 最新报告\n' "$(dirname "$comp")" >&2
  fail=1
fi

hash=$(scripts/composition-hash.sh 2>/dev/null || true)
approved=""
[ -f deliver/stills/APPROVED ] && approved=$(sed -n 's/^hash=//p' deliver/stills/APPROVED | head -1)
if [ -z "$hash" ]; then
  printf 'FAIL 静帧门：算不出构图指纹\n' >&2; fail=1
elif [ -z "$approved" ]; then
  printf 'FAIL 静帧门：还没人看过当前构图 → scripts/stills.sh，看完再 --approve\n' >&2; fail=1
elif [ "$approved" != "$hash" ]; then
  printf 'FAIL 静帧门：批准的是旧构图（%s），现在是 %s → 重跑 scripts/stills.sh\n' "$approved" "$hash" >&2; fail=1
else
  printf 'ok   静帧门：构图 %s 已批准\n' "$hash"
fi

if [ "$fail" -eq 0 ]; then printf '\npre-render: green\n'; else printf '\npre-render: red（先改再渲）\n' >&2; fi
exit "$fail"
