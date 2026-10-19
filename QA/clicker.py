"""
clicker.py — 自动点击选项 / 填写答案
"""

import time
import json
import pyautogui
import pyperclip

with open('config.json', 'r', encoding='utf-8') as f:
    CONFIG = json.load(f)

# 安全模式：移动到屏幕角落时停止
pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.1


def click_answer(pos: tuple, delay: float = None):
    """
    点击屏幕坐标
    pos: (x, y)
    """
    if delay is None:
        delay = CONFIG.get('click_delay', 0.5)
    x, y = pos
    print(f"[点击] 坐标 ({x}, {y})")
    time.sleep(delay)
    pyautogui.moveTo(x, y, duration=0.2)
    time.sleep(0.1)
    pyautogui.click(x, y)


def type_answer(pos: tuple, text: str, delay: float = None):
    """
    点击输入框并粘贴答案（支持中文）
    pos: 输入框坐标
    text: 要输入的文字
    """
    if delay is None:
        delay = CONFIG.get('click_delay', 0.5)
    x, y = pos
    print(f"[填写] 坐标 ({x}, {y}) → '{text}'")
    time.sleep(delay)
    pyautogui.click(x, y)
    time.sleep(0.2)
    # 全选清空已有内容
    pyautogui.hotkey('ctrl', 'a')
    time.sleep(0.1)
    # 用剪贴板粘贴支持中文
    pyperclip.copy(text)
    pyautogui.hotkey('ctrl', 'v')
    time.sleep(0.2)


def find_fill_input(ocr_items: list) -> tuple | None:
    """
    在OCR结果中定位填空框（含 ___ 或输入框标志）
    """
    import re
    pattern = re.compile(r'_{2,}|（\s*）|\(\s*\)|请.*输入|填写')
    for item in ocr_items:
        if pattern.search(item['text']):
            return item['center']
    return None


def execute_answer(match_result: dict, ocr_items: list) -> bool:
    """
    根据匹配结果和OCR坐标执行答题操作
    返回: True 操作成功, False 未能定位坐标
    """
    if not CONFIG.get('auto_click', True):
        print(f"[提示模式] 答案: {match_result['answer']} (不自动点击)")
        return True

    q_type = match_result['type']
    answer = match_result['answer']

    if q_type in ('mcq', 'truefalse'):
        from matcher import find_answer_position
        pos = find_answer_position(ocr_items, answer, q_type)
        if pos:
            click_answer(pos)
            return True
        else:
            print(f"[警告] 未能在截图中定位答案选项: {answer}")
            return False

    elif q_type == 'fill':
        pos = find_fill_input(ocr_items)
        if pos:
            type_answer(pos, answer)
            return True
        else:
            print(f"[警告] 未能定位填空输入框，答案: {answer}")
            return False

    return False
