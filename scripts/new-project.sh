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

# 通用骨架：与语言无关，所有项目一致。
if [ -d "$root/scaffold" ]; then
  (cd "$root/scaffold" && find . -type f -print) | while IFS= read -r f; do
    dest="$dir/${f#./}"
    [ -e "$dest" ] && continue
    mkdir -p "$(dirname "$dest")"
    cp "$root/scaffold/${f#./}" "$dest"
  done
fi

[ -f "$dir/check.sh" ] && chmod +x "$dir/check.sh"

name="$(basename "$dir")"
cat >"$dir/AGENTS.md" <<EOF
# $name

<一句话：这个项目为谁存在、让谁不用再做什么>

## 入口

    ./check.sh     # 什么算完成

## 闸门

<哪些动作影响运行中的东西，谁点头；没有就写「没有」>

## 不要

- <这个项目特有的禁令，没有就删掉这一节>
EOF

if command -v direnv >/dev/null 2>&1; then
  (cd "$dir" && direnv allow) || printf 'warning: direnv allow failed; run it yourself\n' >&2
else
  printf 'warning: direnv not found; run nix develop instead\n' >&2
fi

cat >&2 <<EOF

created: $dir

next:
  cd $dir
  ./scripts/setup.sh     # 装 git hooks
  ./check.sh             # 模板自带一条：环境能否构建
  业务检查：写好后先让它对着旧代码红一次，再让它绿
  缺工具：在 flake.nix 里给 devshell.lib.<system>.$lang 传 extraPackages
EOF
