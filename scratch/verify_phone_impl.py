# -*- coding: utf-8 -*-
"""
RL-IMPL-01 逻辑级验证器（拟真手机UI闭环）
纯文本解析 .gd 中的字典字面量，不依赖 Godot runtime。
校验项见 GDD §5.2 校验规则 + 任务 VALIDATION 清单。
"""
import ast
import re
import sys
from pathlib import Path

ROOT = Path(r"D:\zkgame")
WECHAT = ROOT / "scripts" / "WeChatUI.gd"
INITIATIVE = ROOT / "scripts" / "InitiativeManager.gd"

CHAR_META_KEYS = {
    "yutong", "jingjing", "wanqing", "xiaoxia", "keke",
    "yifei", "zicheng", "beichen", "jingjing_m", "zijun",
}

failures = []
notes = []


def fail(msg):
    failures.append(msg)


def check(cond, msg):
    if not cond:
        fail(msg)
    return cond


# ── GDScript 字面量提取 ────────────────────────────────────────
def extract_literal(text: str, header: str) -> str:
    """从 `header` 之后提取一个完整的 [...] 或 {...} 字面量（跳过字符串内的括号）。"""
    i = text.index(header) + len(header)
    while text[i] in " \t\r\n":
        i += 1
    opener = text[i]
    closer = {"[": "]", "{": "}"}[opener]
    depth = 0
    in_str = False
    quote = ""
    j = i
    while j < len(text):
        ch = text[j]
        if in_str:
            if ch == "\\":
                j += 2
                continue
            if ch == quote:
                in_str = False
        else:
            if ch in "\"'":
                in_str = True
                quote = ch
            elif ch == opener:
                depth += 1
            elif ch == closer:
                depth -= 1
                if depth == 0:
                    return text[i:j + 1]
        j += 1
    raise ValueError("unbalanced literal after %r" % header)


def gd_to_py(src: str):
    """Color("#xxx") -> "#xxx"；其余语法与 Python 字面量兼容。"""
    src = re.sub(r'Color\(\s*("(?:[^"\\]|\\.)*")\s*\)', r"\1", src)
    src = src.replace("true", "True").replace("false", "False")
    return ast.literal_eval(src)


wechat_src = WECHAT.read_text(encoding="utf-8")
init_src = INITIATIVE.read_text(encoding="utf-8")

moments_db = gd_to_py(extract_literal(wechat_src, "var moments_db ="))
chats_db = gd_to_py(extract_literal(wechat_src, "var chats_db ="))
openers = gd_to_py(extract_literal(init_src, "const NIGHT_CHAT_OPENERS ="))

# ── 1. moments_db ─────────────────────────────────────────────
check(len(moments_db) == 10, "moments_db 条目数应为 10，实际 %d" % len(moments_db))

NEW_POST_IDS = {
    "post_zijun_sketch", "post_jingjing_m_bike", "post_zicheng_match",
    "post_yifei_recital", "post_keke_transfer", "post_beichen_moon",
}
found_new = {p["id"] for p in moments_db} & NEW_POST_IDS
check(found_new == NEW_POST_IDS, "缺失新帖: %s" % (NEW_POST_IDS - found_new))

for post in moments_db:
    pid = post["id"]
    check(post["char_id"] in CHAR_META_KEYS,
          "%s: char_id %r 不在 char_meta 键中" % (pid, post["char_id"]))
    if pid not in NEW_POST_IDS:
        continue
    comments = post["comments"]
    check(len(comments) == 2, "%s: comments 应为 2 项，实际 %d" % (pid, len(comments)))
    affs = [c["aff"] for c in comments]
    for a in affs:
        check(4 <= a <= 12, "%s: aff %s 越界 [4,12]" % (pid, a))
    check(len(set(affs)) == len(affs), "%s: 两条评论 aff 相同 (%s)" % (pid, affs))

for cid in ("keke", "beichen"):
    posts = [p for p in moments_db if p["char_id"] == cid]
    check(bool(posts), "%s 缺少朋友圈帖子" % cid)
    for p in posts:
        check(p["unlock_day"] >= 300,
              "%s: unlock_day %d 应 >= 300（char_meta.unlockDay 硬约束）" % (p["id"], p["unlock_day"]))

# ── 2. chats_db 覆盖 ──────────────────────────────────────────
check(len(chats_db) == 10, "chats_db 应有 10 个角色，实际 %d" % len(chats_db))
missing = CHAR_META_KEYS - set(chats_db.keys())
check(not missing, "chats_db 缺失角色: %s" % missing)
extra = set(chats_db.keys()) - CHAR_META_KEYS
check(not extra, "chats_db 出现非 char_meta 角色（拼写错误？）: %s" % extra)

# ── 3. 深夜树可达性 ───────────────────────────────────────────
night_ok = 0
for cid, chat in chats_db.items():
    nodes = chat["nodes"]
    if not check("night_start" in nodes, "%s: 缺 night_start" % cid):
        continue
    if not check("night_end" in nodes, "%s: 缺 night_end" % cid):
        continue

    # 从 night_start 走图：所有 next 必须存在，night_end 必须可达
    seen = set()
    stack = ["night_start"]
    reached_end = False
    dangling = []
    while stack:
        key = stack.pop()
        if key in seen:
            continue
        seen.add(key)
        node = nodes[key]
        if key == "night_end" or not node["choices"]:
            if key == "night_end":
                reached_end = True
            continue
        for ch in node["choices"]:
            nxt = ch.get("next", "")
            if nxt not in nodes:
                dangling.append("%s.%s -> %r" % (cid, key, nxt))
            else:
                stack.append(nxt)
    check(not dangling, "%s: 悬空 next: %s" % (cid, dangling))
    check(reached_end, "%s: night_start 无法到达 night_end" % cid)

    # 规约：sender 拼写、aff/stress 区间
    for key, node in nodes.items():
        if not key.startswith("night_"):
            continue
        check(node["sender"] == cid, "%s.%s: sender %r 与 char_id 不符" % (cid, key, node["sender"]))
        for ch in node["choices"]:
            check(3 <= ch.get("aff", 0) <= 6, "%s.%s: 深夜 aff %s 越界 [3,6]" % (cid, key, ch.get("aff")))
            check(-5 <= ch.get("stress", 0) <= 2, "%s.%s: 深夜 stress %s 越界 [-5,2]" % (cid, key, ch.get("stress")))
    if reached_end and not dangling:
        night_ok += 1

# 日常树也顺带查悬空 next（回归保护）
for cid, chat in chats_db.items():
    for key, node in chat["nodes"].items():
        for ch in node["choices"]:
            nxt = ch.get("next", "")
            check(nxt in chat["nodes"], "%s.%s: next %r 不存在" % (cid, key, nxt))

# ── 4. NIGHT_CHAT_OPENERS ─────────────────────────────────────
check(set(openers.keys()) == CHAR_META_KEYS,
      "NIGHT_CHAT_OPENERS 键不匹配 char_meta：缺 %s / 多 %s"
      % (CHAR_META_KEYS - set(openers.keys()), set(openers.keys()) - CHAR_META_KEYS))
for cid, text in openers.items():
    if cid in chats_db and "night_start" in chats_db[cid]["nodes"]:
        check(text == chats_db[cid]["nodes"]["night_start"]["text"],
              "%s: NIGHT_CHAT_OPENERS 文本与 night_start 不一致" % cid)

# ── 5. 集成点存在性（轻量文本断言）─────────────────────────────
check('night_chat_pending_" + char_id' in wechat_src,
      "WeChatUI: 未找到 night_chat_pending 注入分支")
check('"深夜 23:47"' in wechat_src, "WeChatUI: 未找到深夜时间戳")
check('"[深夜] "' in wechat_src, "WeChatUI: 未找到 [深夜] 预览前缀")
check("#7DA7D9" in wechat_src, "WeChatUI: 未找到月光蓝高亮色")
gm_src = (ROOT / "scripts" / "GameManager.gd").read_text(encoding="utf-8")
check("InitiativeManager.check_night_chat()" in gm_src,
      "GameManager: advance_time 未挂接 check_night_chat")

# ── 缩进一致性（禁止 tab/space 混用）──────────────────────────
for path, want in ((WECHAT, "space"), (ROOT / "scripts" / "GameManager.gd", "space"),
                   (INITIATIVE, "tab")):
    lines = path.read_text(encoding="utf-8").splitlines()
    bad = [n + 1 for n, ln in enumerate(lines)
           if (ln.startswith("\t") if want == "space" else ln.startswith(" "))
           and ln.strip()]
    check(not bad, "%s: 缩进混用（期望 %s），行 %s" % (path.name, want, bad[:10]))

# ── 报告 ──────────────────────────────────────────────────────
print("=" * 62)
print("RL-IMPL-01 逻辑验证")
print("=" * 62)
print("moments_db 条目        : %d (新增 %d)" % (len(moments_db), len(found_new)))
print("chats_db 角色          : %d -> %s" % (len(chats_db), ", ".join(chats_db.keys())))
print("深夜树 night_start→end : %d / 10 可达且无悬空" % night_ok)
print("NIGHT_CHAT_OPENERS     : %d 个角色" % len(openers))
for n in notes:
    print("NOTE: " + n)
print("-" * 62)
if failures:
    print("FAIL (%d)" % len(failures))
    for f in failures:
        print("  ✗ " + f)
    sys.exit(1)
print("PASS — 全部校验通过")
sys.exit(0)
