import re
from pathlib import Path

ROOT = Path(r'C:\Users\31243\WorkBuddy\2026-07-19-15-04-20\schedule_time_app\lib')


def find_matching_paren(text: str, start: int) -> int:
    """start 指向 '(' 后面的第一个字符，返回对应的 ')' 下标。"""
    depth = 1
    i = start
    in_string = None
    while i < len(text) and depth > 0:
        ch = text[i]
        if in_string:
            if ch == '\\':
                i += 2
                continue
            if ch == in_string:
                in_string = None
        else:
            if ch in ('"', "'"):
                in_string = ch
            elif ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
        i += 1
    return i - 1 if depth == 0 else -1


def is_inside_comment(text: str, pos: int) -> bool:
    """粗略判断 pos 是否在 // 或 /* */ 注释中（仅用于跳过误替换）。"""
    line_start = text.rfind('\n', 0, pos) + 1
    if '//' in text[line_start:pos]:
        return True
    # 简单检查是否在 /* ... */ 中
    before = text[:pos]
    block_open = before.rfind('/*')
    block_close = before.rfind('*/')
    if block_open != -1 and block_open > block_close:
        return True
    return False


def process_file(path: Path) -> int:
    content = path.read_text(encoding='utf-8')
    original = content
    # 从后往前替换，避免下标偏移
    matches = list(re.finditer(r'\bTextStyle\(', content))
    inserts = []
    for m in matches:
        open_pos = m.end()
        if is_inside_comment(content, open_pos):
            continue
        close_pos = find_matching_paren(content, open_pos)
        if close_pos < 0:
            continue
        inner = content[open_pos:close_pos]
        # 已含 decoration 相关字段则跳过
        if re.search(r'\bdecoration\s*:', inner):
            continue
        # 在参数列表开头插入 decoration: TextDecoration.none
        if inner.strip() == '':
            inserts.append((open_pos, close_pos, 'decoration: TextDecoration.none'))
        else:
            inserts.append((open_pos, close_pos, 'decoration: TextDecoration.none, '))

    if not inserts:
        return 0

    # 从后往前应用，避免偏移
    for open_pos, close_pos, insertion in reversed(inserts):
        content = content[:open_pos] + insertion + content[open_pos:]

    if content != original:
        path.write_text(content, encoding='utf-8')
    return len(inserts)


def main():
    total = 0
    for path in ROOT.rglob('*.dart'):
        n = process_file(path)
        if n:
            print(f'{path.relative_to(ROOT.parent)}: +{n}')
            total += n
    print(f'\n共处理 {total} 处 TextStyle')


if __name__ == '__main__':
    main()
