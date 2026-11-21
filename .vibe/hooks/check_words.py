"""掃分析頁的字有沒有不用的字（.analytics/07-圖表與文案.md 的「不用的字」）。

用法：PYTHONIOENCODING=utf-8 python .vibe/hooks/check_words.py ios-native
只看 Design/WordsInsight.swift 裡引號裡的字（畫面上會出現的），不看註解。
掃到不一定是錯：「提早做完」這種固定名稱列在 ALLOW 裡；新的誤判人工看過再加進去。
"""
import io
import pathlib
import sys

BANNED = [
    "只", "才", "僅", "竟然", "！", "!", "應該", "必須", "記得", "別再", "加油",
    "放棄", "失敗", "偷懶", "分心", "中斷", "專注力", "效率", "表現", "好棒", "自律",
    "平均", "比上週", "比昨天", "多了", "少了", "完成", "做完", "達成", "成功",
]
ALLOW = ["提早做完"]
FILES = ["Douzhang/Design/WordsInsight.swift"]


def literals(line):
    """一行裡每一段引號裡的字。跳脫的引號不算結尾。"""
    found, current, inside, skip = [], "", False, False
    for char in line:
        if skip:
            current += char
            skip = False
        elif char == "\\" and inside:
            skip = True
        elif char == '"':
            if inside:
                found.append(current)
            current, inside = "", not inside
        elif inside:
            current += char
    return found


root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "ios-native")
problems = 0
for name in FILES:
    text = io.open(root / name, encoding="utf-8").read()
    for number, line in enumerate(text.split("\n"), 1):
        if line.strip().startswith("//"):
            continue
        for literal in literals(line):
            shown = literal
            for word in ALLOW:
                shown = shown.replace(word, "")
            hits = [word for word in BANNED if word in shown]
            if hits:
                problems += 1
                print(f"{name}:{number}: {'、'.join(hits)} ← {literal}")
print(f"不用的字: {problems}")
sys.exit(1 if problems else 0)
