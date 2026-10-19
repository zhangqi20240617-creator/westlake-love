"""
pdf_parser.py — PDF题库解析器
支持选择题、判断题、填空题
用法: python pdf_parser.py <题库.pdf>
"""

import re
import json
import sys
import pdfplumber

# ──────────────────────────────────────────
# 正则表达式
# ──────────────────────────────────────────
# 题目序号：1. / 1、/ 一、/ （1） / 1）
RE_QUESTION_NUM = re.compile(
    r'^[\(（]?\s*(\d+|[一二三四五六七八九十百]+)\s*[.、）)]\s+'
)

# 选项行：A. A、A） (A)
RE_OPTION = re.compile(
    r'^[\(（]?\s*([A-Da-d])\s*[.、）)]\s*(.+)'
)

# 答案行：答案：A / 答案:正确 / 正确答案：B
RE_ANSWER = re.compile(
    r'[答案正确答案]{2,}[：:]\s*(.+)',
    re.IGNORECASE
)

# 判断题标志
RE_TRUEFALSE_ANSWER = re.compile(
    r'^(正确|错误|对|错|√|×|true|false|是|否)$',
    re.IGNORECASE
)

# 填空题空格标志
RE_FILL_BLANK = re.compile(r'_{2,}|（\s*）|\(\s*\)')


def extract_text_from_pdf(pdf_path: str) -> str:
    """提取PDF全部文本"""
    lines = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if text:
                lines.append(text)
    return '\n'.join(lines)


def detect_question_type(question_text: str, options: list) -> str:
    """判断题型"""
    if options:
        return 'mcq'
    if RE_FILL_BLANK.search(question_text):
        return 'fill'
    return 'truefalse'


def parse_questions(text: str) -> list:
    """解析题目列表"""
    questions = []
    lines = [line.strip() for line in text.splitlines() if line.strip()]

    current_q = None
    current_options = {}
    current_answer = None

    def save_question():
        nonlocal current_q, current_options, current_answer
        if current_q:
            q_type = detect_question_type(current_q, current_options)
            # 标准化答案
            ans = current_answer or ''
            if q_type == 'mcq':
                # 取第一个大写字母作为答案
                m = re.search(r'[A-Da-d]', ans)
                ans = m.group(0).upper() if m else ans.strip()
            elif q_type == 'truefalse':
                ans = normalize_truefalse(ans)

            entry = {
                'id': len(questions) + 1,
                'type': q_type,
                'question': current_q,
                'options': [f"{k}. {v}" for k, v in sorted(current_options.items())],
                'answer': ans
            }
            questions.append(entry)
        current_q = None
        current_options = {}
        current_answer = None

    for line in lines:
        # 检测答案行
        m_ans = RE_ANSWER.match(line)
        if m_ans:
            current_answer = m_ans.group(1).strip()
            continue

        # 检测选项行
        m_opt = RE_OPTION.match(line)
        if m_opt and current_q:
            letter = m_opt.group(1).upper()
            content = m_opt.group(2).strip()
            current_options[letter] = content
            continue

        # 检测题目序号
        m_num = RE_QUESTION_NUM.match(line)
        if m_num:
            save_question()
            current_q = RE_QUESTION_NUM.sub('', line).strip()
            current_options = {}
            current_answer = None
            continue

        # 续接上一题题目文本（多行题目）
        if current_q and not m_opt:
            # 若行看起来像答案（判断题）
            if RE_TRUEFALSE_ANSWER.match(line) and not current_answer:
                current_answer = line
            else:
                current_q += ' ' + line

    save_question()  # 保存最后一题
    return questions


def normalize_truefalse(text: str) -> str:
    """统一判断题答案格式"""
    text = text.strip()
    if text in ('正确', '对', '√', 'true', '是', 'T', 't'):
        return '正确'
    if text in ('错误', '错', '×', 'false', '否', 'F', 'f'):
        return '错误'
    return text


def parse_pdf_to_json(pdf_path: str, output_path: str = 'question_bank.json'):
    """主函数：PDF → JSON"""
    print(f"[PDF解析] 读取: {pdf_path}")
    text = extract_text_from_pdf(pdf_path)
    questions = parse_questions(text)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(questions, f, ensure_ascii=False, indent=2)
    print(f"[PDF解析] 完成！共解析 {len(questions)} 道题 → {output_path}")

    # 统计
    types = {}
    for q in questions:
        types[q['type']] = types.get(q['type'], 0) + 1
    for t, c in types.items():
        label = {'mcq': '选择题', 'truefalse': '判断题', 'fill': '填空题'}.get(t, t)
        print(f"  {label}: {c} 题")

    return questions


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: python pdf_parser.py <题库.pdf> [输出.json]")
        sys.exit(1)
    pdf_path = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else 'question_bank.json'
    parse_pdf_to_json(pdf_path, out)
