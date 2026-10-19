"""
overlay.py — 置顶透明悬浮答案提示窗
"""

import tkinter as tk
import threading


class OverlayWindow:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("答题助手")
        self.root.attributes('-topmost', True)
        self.root.attributes('-alpha', 0.92)
        self.root.overrideredirect(False)  # 保留标题栏方便拖动
        self.root.geometry("380x160+20+20")
        self.root.configure(bg='#1a1a2e')
        self.root.resizable(False, False)

        # 标题
        tk.Label(
            self.root, text="🎯 答题助手",
            bg='#1a1a2e', fg='#e0e0e0',
            font=('微软雅黑', 11, 'bold')
        ).pack(pady=(8, 0))

        # 题目摘要
        self.lbl_question = tk.Label(
            self.root, text="等待截图...",
            bg='#1a1a2e', fg='#aaaaaa',
            font=('微软雅黑', 9),
            wraplength=360, justify='left'
        )
        self.lbl_question.pack(padx=10, pady=(4, 0), anchor='w')

        # 答案
        self.lbl_answer = tk.Label(
            self.root, text="",
            bg='#1a1a2e', fg='#00ff88',
            font=('微软雅黑', 18, 'bold')
        )
        self.lbl_answer.pack(pady=(4, 0))

        # 置信度
        self.lbl_score = tk.Label(
            self.root, text="",
            bg='#1a1a2e', fg='#888888',
            font=('微软雅黑', 9)
        )
        self.lbl_score.pack(pady=(2, 6))

        # 提示
        tk.Label(
            self.root, text="按 F9 触发 | 移到角落紧急停止",
            bg='#1a1a2e', fg='#555566',
            font=('微软雅黑', 8)
        ).pack()

    def update(self, match_result: dict | None, clicked: bool = False):
        """更新显示内容"""
        if match_result is None:
            self.lbl_question.config(text="未找到匹配题目", fg='#ff6666')
            self.lbl_answer.config(text="—", fg='#ff6666')
            self.lbl_score.config(text="")
            return

        score = match_result['score']
        q_type_label = {'mcq': '选择题', 'truefalse': '判断题', 'fill': '填空题'}.get(
            match_result['type'], match_result['type']
        )

        # 截断题目显示
        q = match_result['question']
        if len(q) > 40:
            q = q[:40] + '…'
        self.lbl_question.config(
            text=f"[{q_type_label}] {q}", fg='#aaaaaa'
        )

        ans_text = match_result['answer']
        if clicked:
            ans_text += " ✓"

        # 颜色：按置信度
        if score >= 80:
            color = '#00ff88'
        elif score >= 60:
            color = '#ffcc00'
        else:
            color = '#ff6666'

        self.lbl_answer.config(text=ans_text, fg=color)
        self.lbl_score.config(text=f"匹配度 {score:.1f}%")

    def run(self):
        self.root.mainloop()

    def update_threadsafe(self, match_result, clicked=False):
        """线程安全更新"""
        self.root.after(0, lambda: self.update(match_result, clicked))


if __name__ == '__main__':
    # 测试悬浮窗
    win = OverlayWindow()
    win.update({
        'question': '下列哪一项不是火灾预防的基本原则？',
        'type': 'mcq',
        'answer': 'B',
        'options': ['A.控制可燃物', 'B.增加氧气', 'C.消除点火源'],
        'score': 92.5
    }, clicked=True)
    win.run()
