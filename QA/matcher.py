"""
matcher.py — 模糊题库匹配引擎
"""

import json
import re
import sys
from rapidfuzz import process, fuzz

BANK_PATH = 'question_bank.json'

_bank = None

def load_bank(path: str = BANK_PATH) -> list:
    global _bank
    if _bank is None:
        with open(path, 'r', encoding='utf-8') as f:
            _bank = json.load(f)
    return _bank


def clean_text(text: str) -> str:
    """去除序号、标点，标准化空白"""
    text = re.sub(r'^[\(（]?\s*\d+\s*[.、）)]\s*', '', text)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def match_question(ocr_text: str, threshold: int = 60) -> dict | None:
    """
    从OCR文本中匹配题库
    返回最佳匹配结果，或 None
    结果格式:
    {
        'question': str,
        'type': str,
        'answer': str,
        'options': list,
        'score': float    # 0-100 相似度
    }
    """
    bank = load_bank()
    if not bank:
        return None

    # 提取OCR文本中的"题目部分"（忽略选项行）
    lines = ocr_text.splitlines()
    question_lines = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        # 跳过看起来像选项的行
        if re.match(r'^[A-Da-d][.、）)]\s*', line):
            continue
        question_lines.append(line)

    query = clean_text(' '.join(question_lines[:5]))  # 最多取前5行拼接
    if not query:
        return None

    # 构建候选列表
    candidates = [clean_text(q['question']) for q in bank]

    # 模糊匹配
    result = process.extractOne(
        query, candidates,
        scorer=fuzz.partial_ratio,
        score_cutoff=threshold
    )

    if not result:
        return None

    best_text, score, idx = result
    matched = bank[idx]

    return {
        'question': matched['question'],
        'type': matched['type'],
        'answer': matched['answer'],
        'options': matched.get('options', []),
        'score': score
    }


def find_answer_position(ocr_items: list, answer: str, q_type: str) -> tuple | None:
    """
    在OCR坐标列表中找到答案选项的屏幕坐标
    返回: (x, y) 或 None
    """
    if q_type == 'mcq':
        # 找包含答案字母开头的选项行，如 "A.", "A、", "(A)"
        pattern = re.compile(
            rf'^[\(（]?\s*{re.escape(answer)}\s*[.、）)]',
            re.IGNORECASE
        )
        for item in ocr_items:
            if pattern.match(item['text'].strip()):
                return item['center']
        # 宽松匹配：行以答案字母开头
        for item in ocr_items:
            if item['text'].strip().upper().startswith(answer.upper()):
                return item['center']

    elif q_type == 'truefalse':
        # 找"正确"或"错误"文字
        for item in ocr_items:
            t = item['text'].strip()
            if answer in t or t in answer:
                return item['center']

    return None


if __name__ == '__main__':
    query = sys.argv[1] if len(sys.argv) > 1 else "下列哪项不是防火的基本原则"
    print(f"[匹配测试] 查询: {query}")
    r = match_question(query, threshold=50)
    if r:
        print(f"  题目: {r['question']}")
        print(f"  类型: {r['type']}")
        print(f"  答案: {r['answer']}")
        print(f"  相似度: {r['score']:.1f}%")
    else:
        print("  未找到匹配题目")
