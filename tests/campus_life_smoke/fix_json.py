#!/usr/bin/env python3
"""
一次性修复 events_birthday / vacation / campus JSON 文件中的非法内嵌双引号
策略：将 JSON 字符串值（text 字段）中的 ASCII 双引号 " 替换为中文引号 " "
"""
import re, pathlib, json

SCRIPTS = pathlib.Path(r'd:\zkgame\scripts')
TARGETS = ['events_birthday.json', 'events_vacation.json', 'events_campus.json']

def fix_json_file(fpath):
    raw = fpath.read_bytes()
    if raw.startswith(b'\xef\xbb\xbf'):
        raw = raw[3:]
    text = raw.decode('utf-8')

    # 策略：把 JSON 字符串值中出现的 U+201C/U+201D（中文引号）不动
    # 把 "text": "...\"...\\"..." 模型中多余的 unescaped " 处理
    # 最简单可靠：把文件里 :\t"..."  里面嵌套的ASCII引号换成 【】
    # 实际问题：JSON text 字段里面直接有 " 内容 "，即形如 "text": "...\"内容\"",...
    # 方法：逐字符重新序列化——先用 json load 无法成功，所以手动替换
    
    # 将文件内所有 \u201c (") 和 \u201d (") 中文引号先保护
    # 然后针对 text/label 字段值里的裸 ASCII (") 替换为 \\\"
    # 实际最快做法：把行内 "string"," 里的裸 " 修正
    # 用 ast.literal_eval 也不行，改用分行扫描
    
    # 最直接：对 "text"/"label" 等字段的值做正则替换
    # 匹配：": "...内容..." 格式，允许内部有未转义的引号，修正为 \\\"
    
    def fix_string_value(m):
        key = m.group(1)
        inner = m.group(2)
        # 把 inner 中未转义的 ASCII 双引号替换为中文引号对
        # 统计：如果 inner 中有裸 " 则替换前一个为 " 后一个为 "
        # 简化处理：把所有裸 " 替换为 \\\"
        fixed = inner.replace('"', '\\"')
        return f'"{key}": "{fixed}"'
    
    # 方法2：直接把 JSON 文件中所有 text 字段里的裸引号用 sed 处理
    # 最直接可靠：逐行处理 "text":  "..." 的内容
    # 找出 value 是字符串的行，修复其中的引号
    
    lines = text.splitlines(keepends=True)
    out = []
    for line in lines:
        # 匹配 "text": "内容" 或 "label": "内容" 等字段的内容行
        # 简单规则：如果行里有 \"text\": \" 开头的模式，修复引号
        # 更通用：只有当去掉外部 JSON 引号后，里面还有奇数个 " 才需要修复
        stripped = line.lstrip()
        # 检查是否是字符串值行（以 "xxx": "...开头）
        m = re.match(r'^(\s*"[^"]+"\s*:\s*)"(.*)"([,\s]*)$', line, re.DOTALL)
        if m:
            pre, val, post = m.group(1), m.group(2), m.group(3)
            # 计算 val 中裸 " 的数量（不是 \\\" 的那种）
            # 把真正未转义的 " 替换为 \"
            # val 里面 \\\" 已经是转义的，不管；把裸 " 替换
            fixed_val = re.sub(r'(?<!\\)"', '\\"', val)
            out.append(f'{pre}"{fixed_val}"{post}\n')
        else:
            out.append(line)
    return ''.join(out)

for fname in TARGETS:
    fpath = SCRIPTS / fname
    fixed = fix_json_file(fpath)
    # 验证
    try:
        json.loads(fixed)
        fpath.write_text(fixed, encoding='utf-8')
        print(f'FIXED: {fname}')
    except json.JSONDecodeError as e:
        print(f'STILL_BROKEN: {fname} line={e.lineno} col={e.colno} {e.msg}')
