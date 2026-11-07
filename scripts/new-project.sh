#!/usr/bin/env bash
# 新建项目：从模板起一个，进环境，打印下一步。
# 只做确定性的事：校验、复制模板、direnv allow。选包、写代码、git init 都不做。
set -euo pipefail

root="${DEVSHELL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

usage() {
  printf 'usage: new <lang> <dir>\n\navailable templates:\n' >&2
  for d in "$root"/templates/*/; do
    printf '  %s\n' "$(basename "$d")" >&2
  done
  exit 2
}

[ "$#" -eq 2 ] || usage
lang="$1"
dir="$2"

[ -d "$root/templates/$lang" ] || {
  printf 'no such template: %s\n' "$lang" >&2
  usage
}

if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
  printf 'not empty: %s\n' "$dir" >&2
  exit 1
fi

mkdir -p "$dir"
(cd "$dir" && nix flake init -t "$root#$lang")

if command -v direnv >/dev/null 2>&1; then
  (cd "$dir" && direnv allow) || printf 'warning: direnv allow failed; run it yourself\n' >&2
else
  printf 'warning: direnv not found; run nix develop instead\n' >&2
fi

cat >&2 <<EOF

created: $dir

next:
  cd $dir
  check：模板已带一条（环境能否构建）。业务检查写好后，先让它对着旧代码红一次
  缺工具：在 flake.nix 里给 devshell.lib.<system>.$lang 传 extraPackages
EOF
