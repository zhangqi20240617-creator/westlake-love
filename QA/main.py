"""
main.py — 微信自动答题助手入口
用法:
  python main.py                    # 启动答题模式（F9 触发）
  python main.py --parse <pdf路径>  # 解析题库 PDF → question_bank.json
"""

import sys
import os
import json
import threading
import time
import keyboard

# ──────────────────────────────────────────
# 加载配置
# ──────────────────────────────────────────
CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'config.json')
with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
    CONFIG = json.load(f)

HOTKEY = CONFIG.get('hotkey', 'F9')
THRESHOLD = CONFIG.get('confidence_threshold', 60)
REGION = CONFIG.get('wechat_region', None)  # None = 全屏

# ──────────────────────────────────────────
# 全局状态
# ──────────────────────────────────────────
_processing = False  # 防止重复触发


def run_once():
    """单次答题流程：截图 → OCR → 匹配 → 点击"""
    global _processing
    if _processing:
        return
    _processing = True

    try:
        from ocr_engine import run_ocr, extract_full_text
        from matcher import match_question
        from clicker import execute_answer

        print("\n" + "="*50)
        print(f"[{time.strftime('%H:%M:%S')}] 触发答题流程...")

        # 1. OCR
        print("[1/3] 截图识别中...")
        ocr_items = run_ocr(region=REGION)
        if not ocr_items:
            print("  ⚠️  未识别到任何文字，请确认微信窗口可见")
            overlay.update_threadsafe(None)
            return

        full_text = '\n'.join(item['text'] for item in ocr_items)
        print(f"  识别到 {len(ocr_items)} 行文字")

        # 2. 匹配
        print("[2/3] 题库匹配中...")
        result = match_question(full_text, threshold=THRESHOLD)

        if not result:
            print(f"  ⚠️  未找到匹配（置信度阈值={THRESHOLD}%）")
            overlay.update_threadsafe(None)
            return

        print(f"  ✅ 匹配: {result['question'][:30]}...")
        print(f"     答案: {result['answer']}  (匹配度 {result['score']:.1f}%)")

        # 3. 点击
        print("[3/3] 执行答题...")
        clicked = execute_answer(result, ocr_items)
        overlay.update_threadsafe(result, clicked=clicked)

        print(f"  {'✅ 完成' if clicked else '⚠️ 需手动操作'}")

    except Exception as e:
        print(f"[错误] {e}")
        import traceback
        traceback.print_exc()
    finally:
        _processing = False


def hotkey_listener():
    """在后台线程监听热键"""
    print(f"[热键] 监听 {HOTKEY}，按下触发答题")
    keyboard.add_hotkey(HOTKEY, lambda: threading.Thread(target=run_once, daemon=True).start())
    keyboard.wait()  # 阻塞


# ──────────────────────────────────────────
# 主入口
# ──────────────────────────────────────────
if __name__ == '__main__':

    # ── 模式：解析题库 ──
    if '--parse' in sys.argv:
        idx = sys.argv.index('--parse')
        if idx + 1 >= len(sys.argv):
            print("用法: python main.py --parse <题库.pdf> [输出.json]")
            sys.exit(1)
        pdf_path = sys.argv[idx + 1]
        out_path = sys.argv[idx + 2] if idx + 2 < len(sys.argv) else 'question_bank.json'
        from pdf_parser import parse_pdf_to_json
        parse_pdf_to_json(pdf_path, out_path)
        sys.exit(0)

    # ── 模式：自动答题 ──
    # 检查题库是否存在
    if not os.path.exists('question_bank.json'):
        print("❌ 未找到 question_bank.json！")
        print("   请先运行: python main.py --parse <你的题库.pdf>")
        sys.exit(1)

    print("="*50)
    print(" 微信答题助手 已启动")
    print("="*50)
    print(f" 热键    : {HOTKEY}")
    print(f" 置信阈值: {THRESHOLD}%")
    print(f" 截图区域: {'全屏' if not REGION else REGION}")
    print(f" 自动点击: {'开启' if CONFIG.get('auto_click', True) else '关闭（仅提示）'}")
    print("="*50)
    print(" 移动鼠标到屏幕左上角可紧急停止")
    print()

    # 启动悬浮窗（主线程）
    from overlay import OverlayWindow
    overlay = OverlayWindow()

    # 热键监听在后台线程
    t = threading.Thread(target=hotkey_listener, daemon=True)
    t.start()

    # 主线程运行 tkinter 事件循环
    overlay.run()
