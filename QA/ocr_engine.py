"""
ocr_engine.py — 截图 + EasyOCR 中文识别
返回识别到的文字行及其屏幕坐标
"""

import json
import mss
import numpy as np
import easyocr

# 加载配置
with open('config.json', 'r', encoding='utf-8') as f:
    CONFIG = json.load(f)

# 初始化OCR（只初始化一次；首次运行会下载约 100MB 中文模型）
_reader = None

def get_reader():
    global _reader
    if _reader is None:
        print("[OCR] 初始化 EasyOCR（首次运行需下载中文模型，请稍候）...")
        _reader = easyocr.Reader(['ch_sim', 'en'], gpu=False, verbose=False)
        print("[OCR] 初始化完成")
    return _reader


def capture_screen(region=None):
    """
    截取屏幕区域
    region: (left, top, width, height) 或 None 表示全屏
    返回: (numpy array RGB, monitor dict)
    """
    with mss.mss() as sct:
        if region:
            left, top, w, h = region
            monitor = {"left": left, "top": top, "width": w, "height": h}
        else:
            monitor = sct.monitors[1]  # 主屏幕
        screenshot = sct.grab(monitor)
        img = np.array(screenshot)[:, :, :3]  # BGR→去掉alpha
        return img, monitor


def run_ocr(region=None) -> list:
    """
    截图并识别文字
    返回: list of dict:
        {
            'text': str,
            'confidence': float,
            'center': (abs_x, abs_y)   # 屏幕绝对坐标
        }
    """
    img, monitor = capture_screen(region)
    reader = get_reader()
    # detail=1 返回 [([box], text, conf), ...]
    results = reader.readtext(img, detail=1)

    offset_x = monitor.get('left', 0)
    offset_y = monitor.get('top', 0)

    parsed = []
    for (box, text, conf) in results:
        xs = [pt[0] for pt in box]
        ys = [pt[1] for pt in box]
        cx = offset_x + int(sum(xs) / len(xs))
        cy = offset_y + int(sum(ys) / len(ys))
        parsed.append({
            'text': text,
            'confidence': float(conf),
            'center': (cx, cy)
        })

    return parsed


def extract_full_text(region=None) -> str:
    """返回识别到的所有文字拼接成字符串（用于题库匹配）"""
    lines = run_ocr(region)
    return '\n'.join(item['text'] for item in lines)


if __name__ == '__main__':
    print("[OCR测试] 截图识别中...")
    items = run_ocr()
    for item in items:
        print(f"  [{item['confidence']:.2f}] {item['text']}  @ {item['center']}")
    print(f"\n共识别 {len(items)} 行文字")
