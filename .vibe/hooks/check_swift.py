"""檢查 ios-native 的 Swift 檔：行寬（照字數算）、函式長度的粗估、短識別字、強制解包。"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
problems = 0
for path in sorted(root.rglob("*.swift")):
    lines = path.read_text(encoding="utf-8").split("\n")
    code_lines = [line for line in lines if line.strip() and not line.strip().startswith("//")]
    if len(lines) > 300:
        print(f"{path}: 檔案 {len(lines)} 行，超過 300")
        problems += 1
    for number, line in enumerate(lines, 1):
        if len(line) > 100:
            print(f"{path}:{number}: {len(line)} 字")
            problems += 1
        if line != line.rstrip():
            print(f"{path}:{number}: 行尾有空白")
            problems += 1
        if "\t" in line:
            print(f"{path}:{number}: 有 tab")
            problems += 1
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        for name in re.findall(r"\b(?:let|var|case let|for)\s+([A-Za-z_][A-Za-z0-9_]*)\b", line):
            if len(name) < 3 and name not in {"id", "x", "y", "z", "ms"}:
                print(f"{path}:{number}: 識別字太短 {name}")
                problems += 1
        if re.search(r"[A-Za-z0-9_\)\]]!(?!=)", stripped) and '"' not in stripped:
            print(f"{path}:{number}: 可能有強制解包")
            problems += 1
    # 函式本體長度粗估：從 func 那行到同縮排的收尾大括號
    for index, line in enumerate(lines):
        match = re.match(r"^(\s*)(?:private |static |final |override )*func ", line)
        if not match:
            continue
        indent = match.group(1)
        body = 0
        opened = False
        for follow in lines[index:]:
            if not opened:
                if follow.rstrip().endswith("{"):
                    opened = True
                continue
            if follow == indent + "}":
                break
            if follow.strip() and not follow.strip().startswith("//"):
                body += 1
        if body > 40:
            print(f"{path}:{index + 1}: 函式本體約 {body} 行，超過 40")
            problems += 1
    print(f"{path.relative_to(root)}: {len(lines)} 行（程式 {len(code_lines)} 行）")
print("問題數:", problems)
