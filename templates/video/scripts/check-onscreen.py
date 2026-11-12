#!/usr/bin/env python3
"""上屏检查：把画面里的数字和词，对回 FACTS 台账。

三条规则（只判能机器判的，黑名单的语义判断仍归人）：
  R1 不等于：`A ≠ B` 两侧数字不能相同（相同 = 观众看不出差别，且多半是口径串了）
  R2 算术：`a + b = c` / `a ÷ b = c` 必须成立
  R3 未登记：带单位的数字必须在 FACTS.md 里出现过（warn，不拦）

用法：python3 scripts/check-onscreen.py [--facts content/FACTS.md] <composition.html | data.js>...
默认：content/FACTS.md + scripts/compositions.txt 里列的当前 composition；两者都没有时跳过。
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UNIT = r"(?:mg|毫克|克|g|粒|份|天|%|倍)"
NUM = r"(\d+(?:\.\d+)?)"

fail = 0
warn = 0


def visible_text(path: Path) -> str:
    text = path.read_text(encoding="utf-8", errors="ignore")
    text = re.sub(r"<style[\s\S]*?</style>", " ", text)
    text = re.sub(r"<script[\s\S]*?</script>", " ", text)
    text = re.sub(r"<[^>]+>", " ", text)
    return text


def facts_numbers(facts: Path) -> set[str]:
    text = facts.read_text(encoding="utf-8")
    return set(re.findall(r"\d+(?:\.\d+)?", text))


def load_allow() -> set[str]:
    f = ROOT / "content" / "onscreen-allow.txt"
    if not f.exists():
        return set()
    out = set()
    for line in f.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.add(" ".join(line.split()))
    return out


def check_ne(path: Path, text: str, allow: set[str]) -> None:
    global fail
    skipped = 0
    for m in re.finditer(rf"{NUM}\s*{UNIT}?\s*[≠!≠=]\s*{NUM}\s*{UNIT}?", text):
        a, b = m.group(1), m.group(2)
        snippet = " ".join(m.group(0).split())
        if snippet in allow:
            skipped += 1
            continue
        if a == b:
            fail += 1
            print(f"FAIL {path.name}: 「{snippet}」两侧数字相同（{a} = {b}）→ 换口径或换数字")
    if skipped:
        print(f"ok   {path.name}: 豁免 {skipped} 条（content/onscreen-allow.txt）")


def check_sum(path: Path, text: str) -> None:
    global fail
    for m in re.finditer(rf"{NUM}\s*\+\s*{NUM}\s*=\s*{NUM}", text):
        a, b, c = (float(x) for x in m.groups())
        if abs(a + b - c) > 1e-6:
            fail += 1
            print(f"FAIL {path.name}: 「{m.group(0)}」算错了（{a} + {b} ≠ {c}）")
    for m in re.finditer(rf"{NUM}\s*[÷/]\s*{NUM}\s*=\s*{NUM}", text):
        a, b, c = (float(x) for x in m.groups())
        if b and abs(a / b - c) > 1e-6:
            fail += 1
            print(f"FAIL {path.name}: 「{m.group(0)}」算错了（{a} ÷ {b} ≠ {c}）")


def check_unregistered(path: Path, text: str, allowed: set[str]) -> None:
    global warn
    seen = {n for n in re.findall(rf"{NUM}\s*{UNIT}", text)}
    missing = sorted(seen, key=float) if seen else []
    missing = [n for n in missing if n not in allowed]
    if missing:
        warn += 1
        print(f"warn {path.name}: 带单位的数字没在 FACTS.md 出现 → {', '.join(missing)}（派生值可忽略）")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--facts", default=str(ROOT / "content" / "FACTS.md"))
    ap.add_argument("files", nargs="*")
    args = ap.parse_args()

    if args.files:
        files = [Path(f) for f in args.files]
    else:
        lst = ROOT / "scripts" / "compositions.txt"
        files = [
            ROOT / ln.strip()
            for ln in lst.read_text(encoding="utf-8").splitlines()
            if ln.strip() and not ln.strip().startswith("#")
        ]
    if not files:
        print("ok   还没有构图（scripts/compositions.txt），跳过上屏检查")
        return 0

    facts = Path(args.facts)
    if not facts.exists():
        print("ok   还没有 content/FACTS.md，跳过上屏检查")
        return 0

    allowed = facts_numbers(facts)
    allow = load_allow()
    for f in files:
        text = visible_text(f)
        check_ne(f, text, allow)
        check_sum(f, text)
        check_unregistered(f, text, allowed)

    print(f"\nonscreen: {'red' if fail else 'green'}（{len(files)} 个文件，{fail} 条 FAIL，{warn} 条 warn）")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
