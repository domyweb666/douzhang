"""推上雲端前的粗檢查：畫面用到的 Tokens.*、Words.*、Params.* 是不是都有定義；有定義卻沒人用的也列出來。

本機沒有 Swift 編譯器，這只能抓打錯名字這一類。用法：python check_refs.py <ios-native 資料夾>
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
sources = {
    path: path.read_text(encoding="utf-8")
    for path in root.rglob("*.swift")
    if path.name != "DomyTokens.swift"
}
everything = "\n".join(sources.values())


def members(text, opener):
    """opener 那個 enum（或 extension）大括號裡宣告的 static 名字，含巢狀 enum 的名字。"""
    start = text.find(opener)
    if start < 0:
        return set()
    depth = 0
    end = start
    for index in range(text.index("{", start), len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                end = index
                break
    body = text[start:end]
    names = set(re.findall(r"static (?:let|var|func) ([A-Za-z0-9_]+)", body))
    names |= set(re.findall(r"enum ([A-Za-z0-9_]+)", body))
    return names


def defined(owner):
    names = set()
    for text in sources.values():
        for opener in (f"enum {owner} {{", f"extension {owner} {{"):
            names |= members(text, opener)
    return names


problems = 0
for owner in ("Words", "Params"):
    have = defined(owner)
    used = set(re.findall(rf"\b{owner}\.([A-Za-z0-9_]+)", everything))
    for name in sorted(used - have):
        print(f"沒定義：{owner}.{name}")
        problems += 1
    for name in sorted(have - used - {owner}):
        inside = len(re.findall(rf"\b{name}\b", everything))
        if inside <= 1:
            print(f"沒人用：{owner}.{name}")

tokens_text = next(text for path, text in sources.items() if path.name == "Tokens.swift")
groups = set(re.findall(r"    enum ([A-Za-z0-9_]+)", tokens_text))
for group in sorted(groups):
    have = members(tokens_text, f"enum {group} {{")
    used = set(re.findall(rf"\bTokens\.{group}\.([A-Za-z0-9_]+)", everything))
    for name in sorted(used - have):
        print(f"沒定義：Tokens.{group}.{name}")
        problems += 1
    for name in sorted(have - used):
        inside = len(re.findall(rf"\b{name}\b", tokens_text))
        if inside <= 1:
            print(f"沒人用：Tokens.{group}.{name}")
used_groups = set(re.findall(r"\bTokens\.([A-Za-z0-9_]+)\.", everything))
for group in sorted(used_groups - groups):
    print(f"沒定義：Tokens.{group}")
    problems += 1
print("沒定義的數目:", problems)
