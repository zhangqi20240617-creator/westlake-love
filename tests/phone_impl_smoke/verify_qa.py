# -*- coding: utf-8 -*-
"""
QA-RN-01 — 拟真手机UI闭环 独立逻辑级烟雾测试 / 质量门
Owner: 严守真 (quality-lead)   Independent of scratch/verify_phone_impl.py

Parses .gd sources as text (no Godot runtime), evaluates data blocks via
ast.literal_eval after GDScript->Python literal conversion, and asserts
the design rules from design/realistic_phone_gdd.md (C-1/C-2/C-3 = A/A/A).

Checks:
  A. moments_db      — 10 posts; 6 new posts: 2 comments, aff in [4,12], affs differ,
                       keke/beichen unlock_day >= 300, no min_rel_state key (C-2=A)
  B. chats_db        — exactly 10 keys incl. keke/beichen/jingjing_m/zijun; schema
  C. night trees     — night_start/night_end present; full walk: no dangling next,
                       all paths terminate at night_end; aff in [3,6], stress in [-5,2];
                       setFlag <= 1 per tree (beichen: 2 allowed, mutually exclusive branches);
                       night_start.text == NIGHT_CHAT_OPENERS[cid]
  D. char_meta xcheck— chats_db name/emoji/avatar_color vs GameManager.char_meta
                       (color hex compared case-insensitively; runtime-sync mitigation detected)
  E. logic review    — InitiativeManager.check_night_chat() guard clauses (static asserts)
  F. integration     — advance_time() evening branch calls check_night_chat();
                       EndingScreen NG+ resets flags wholesale + reset_char_initiative (R-4)

Exit code: 0 = PASS / PASS-with-concerns, 1 = FAIL.
Read-only on game code.
"""
import ast
import io
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(r"D:\zkgame")
WECHAT = ROOT / "scripts" / "WeChatUI.gd"
INIT   = ROOT / "scripts" / "InitiativeManager.gd"
GM     = ROOT / "scripts" / "GameManager.gd"
ENDING = ROOT / "scripts" / "EndingScreen.gd"

TEN_CHARS = ["yutong", "jingjing", "wanqing", "xiaoxia", "yifei",
             "zicheng", "keke", "beichen", "jingjing_m", "zijun"]
NEW_POSTS = ["post_zijun_sketch", "post_jingjing_m_bike", "post_zicheng_match",
             "post_yifei_recital", "post_keke_transfer", "post_beichen_moon"]
NEW_CHATS = ["keke", "beichen", "jingjing_m", "zijun"]

failures, concerns, notes = [], [], []
_passed = 0

def ok(msg):
    global _passed
    _passed += 1
    print(f"  [PASS] {msg}")

def fail(msg):
    failures.append(msg)
    print(f"  [FAIL] {msg}")

def concern(msg):
    concerns.append(msg)
    print(f"  [CONCERN] {msg}")

def note(msg):
    notes.append(msg)
    print(f"  [NOTE] {msg}")

def check(cond, msg_ok, msg_fail):
    if cond:
        ok(msg_ok)
    else:
        fail(msg_fail)

# ─────────────────────────────────────────────────────────────────
# GDScript literal block extraction & conversion
# ─────────────────────────────────────────────────────────────────
def extract_block(src: str, anchor: str) -> str:
    """Extract a balanced {...} or [...] literal starting after `anchor`.
    String-aware (double quotes + backslash escapes); '#' comments ignored
    outside strings (hex colors like "#4A7BB7" live inside strings)."""
    i = src.index(anchor) + len(anchor)
    while src[i] not in "[{":
        i += 1
    open_ch = src[i]
    close_ch = "]" if open_ch == "[" else "}"
    depth, in_str, esc = 0, False, False
    start = i
    while i < len(src):
        c = src[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "#":                     # comment outside string
                nl = src.find("\n", i)
                i = nl if nl != -1 else len(src) - 1
            elif c in "[{":
                depth += 1
            elif c in "]}":
                depth -= 1
                if depth == 0 and c == close_ch:
                    return src[start:i + 1]
        i += 1
    raise ValueError(f"unbalanced block for anchor {anchor!r}")

def gd_to_py(block: str) -> str:
    """Convert a GDScript dict/array literal to a Python literal string."""
    out, i, in_str, esc = [], 0, False, False
    while i < len(block):
        c = block[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "#":                            # strip comment
            nl = block.find("\n", i)
            i = nl if nl != -1 else len(block)
            continue
        m = re.match(r"\b(true|false|null)\b", block[i:])
        if m:
            out.append({"true": "True", "false": "False", "null": "None"}[m.group(1)])
            i += m.end()
            continue
        out.append(c)
        i += 1
    text = "".join(out)
    # Color("#xxxxxx") -> "#xxxxxx"   (Color( never appears inside strings here)
    text = re.sub(r'Color\(\s*("([^"\\]|\\.)*")\s*\)', r"\1", text)
    return text

def load_literal(path: Path, anchor: str):
    src = path.read_text(encoding="utf-8")
    return ast.literal_eval(gd_to_py(extract_block(src, anchor)))

def grep_lines(path: Path, pattern: str):
    rx = re.compile(pattern)
    return [(n, line.rstrip()) for n, line in
            enumerate(path.read_text(encoding="utf-8").splitlines(), 1) if rx.search(line)]

# ─────────────────────────────────────────────────────────────────
print("=" * 72)
print("QA-RN-01  独立逻辑级烟雾测试 — 拟真手机UI闭环")
print("=" * 72)

moments   = load_literal(WECHAT, "var moments_db = ")
chats     = load_literal(WECHAT, "var chats_db = ")
openers   = load_literal(INIT,   "const NIGHT_CHAT_OPENERS = ")
char_meta = load_literal(GM,     "var char_meta = ")
wechat_src = WECHAT.read_text(encoding="utf-8")
init_src   = INIT.read_text(encoding="utf-8")

print(f"\n[parse] moments_db={len(moments)} posts, chats_db={len(chats)} chars, "
      f"OPENERS={len(openers)}, char_meta={len(char_meta)}")

# ── A. MOMENTS ───────────────────────────────────────────────────
print("\n--- A. MOMENTS (GDD §5.1 / §1.2) ---")
check(len(moments) == 10, "moments_db has 10 entries",
      f"moments_db has {len(moments)} entries, expected 10")
by_id = {p.get("id"): p for p in moments}
for pid in NEW_POSTS:
    p = by_id.get(pid)
    if p is None:
        fail(f"{pid}: missing from moments_db")
        continue
    cms = p.get("comments", [])
    check(len(cms) == 2, f"{pid}: comments.size()==2",
          f"{pid}: comments.size()=={len(cms)}, expected 2")
    affs = [c.get("aff") for c in cms]
    for a in affs:
        check(isinstance(a, int) and 4 <= a <= 12,
              f"{pid}: comment aff={a} in [4,12]",
              f"{pid}: comment aff={a} out of [4,12]")
    if len(affs) == 2:
        check(affs[0] != affs[1], f"{pid}: two comment affs differ ({affs[0]}/{affs[1]})",
              f"{pid}: both comments have aff={affs[0]} (must differ)")
    check("min_rel_state" not in p, f"{pid}: no min_rel_state key (C-2=A ungated)",
          f"{pid}: contains min_rel_state — violates decision C-2=A")
for cid, floor in (("keke", 300), ("beichen", 300)):
    posts = [p for p in moments if p.get("char_id") == cid]
    for p in posts:
        ud = p.get("unlock_day", -1)
        check(ud >= floor, f"{p['id']}: unlock_day={ud} >= {floor}",
              f"{p['id']}: unlock_day={ud} < {floor} (leaks pre-transfer character)")

# ── B. CHATS ─────────────────────────────────────────────────────
print("\n--- B. CHATS (GDD §3) ---")
keys = list(chats.keys())
check(sorted(keys) == sorted(TEN_CHARS),
      f"chats_db has exactly the 10 expected keys",
      f"chats_db keys mismatch: got {sorted(keys)}")
check("jingjing_m" in chats and "jingjingm" not in chats,
      'char_id "jingjing_m" spelled correctly',
      'char_id spelling wrong: expected "jingjing_m"')
for cid in NEW_CHATS:
    e = chats.get(cid)
    if not isinstance(e, dict):
        fail(f"{cid}: chat entry missing or not a dict")
        continue
    missing = [k for k in ("name", "emoji", "avatar_color", "current_node", "nodes") if k not in e]
    check(not missing, f"{cid}: entry has name/emoji/avatar_color/current_node/nodes",
          f"{cid}: entry missing keys {missing}")

# ── C. NIGHT TREES ───────────────────────────────────────────────
print("\n--- C. NIGHT TREES (GDD §5.2 / §2.3) ---")
for cid in TEN_CHARS:
    nodes = chats.get(cid, {}).get("nodes", {})
    if "night_start" not in nodes or "night_end" not in nodes:
        fail(f"{cid}: missing night_start or night_end node")
        continue
    # walk
    reachable, stack, dangling, bad_terminals = set(), ["night_start"], [], []
    while stack:
        nid = stack.pop()
        if nid in reachable:
            continue
        reachable.add(nid)
        node = nodes.get(nid)
        if node is None:
            dangling.append(nid)
            continue
        ch = node.get("choices", [])
        if not ch and nid != "night_end":
            bad_terminals.append(nid)
        for c in ch:
            stack.append(c.get("next", "<missing-next>"))
    check(not dangling, f"{cid}: no dangling next (reachable={sorted(reachable)})",
          f"{cid}: dangling next -> {dangling}")
    check(not bad_terminals, f"{cid}: all terminal paths end at night_end",
          f"{cid}: terminal nodes other than night_end: {bad_terminals}")
    check("night_end" in reachable, f"{cid}: night_end reachable from night_start",
          f"{cid}: night_end NOT reachable from night_start")
    check(not nodes["night_end"].get("choices", []),
          f"{cid}: night_end is terminal (choices==[])",
          f"{cid}: night_end has choices — not terminal")
    # aff / stress ranges + setFlag census over the night tree only
    set_flags = []
    for nid in sorted(reachable & set(nodes.keys())):
        for c in nodes[nid].get("choices", []):
            a, s = c.get("aff"), c.get("stress")
            if not (isinstance(a, int) and 3 <= a <= 6):
                fail(f"{cid}/{nid}: choice aff={a} out of [3,6]")
            if not (isinstance(s, int) and -5 <= s <= 2):
                fail(f"{cid}/{nid}: choice stress={s} out of [-5,2]")
            if c.get("setFlag"):
                set_flags.append((nid, c["setFlag"]))
    if cid == "beichen":
        if len(set_flags) == 2 and len({n for n, _ in set_flags}) == 2:
            ok(f"beichen: 2 setFlags in mutually-exclusive branches {set_flags} — allowed by design")
        else:
            fail(f"beichen: setFlag layout unexpected: {set_flags} (expected 2 in distinct branches)")
    else:
        check(len(set_flags) <= 1, f"{cid}: night-tree setFlag count={len(set_flags)} <= 1 {set_flags}",
              f"{cid}: night-tree has {len(set_flags)} setFlags {set_flags}, max 1")
    # opener text consistency
    if cid in openers:
        if nodes["night_start"].get("text") == openers[cid]:
            ok(f"{cid}: night_start.text == NIGHT_CHAT_OPENERS[{cid}]")
        else:
            fail(f"{cid}: night_start.text != NIGHT_CHAT_OPENERS — preview/bubble mismatch")
    else:
        fail(f"{cid}: missing from NIGHT_CHAT_OPENERS")
check(sorted(openers.keys()) == sorted(TEN_CHARS),
      "NIGHT_CHAT_OPENERS covers exactly the 10 chars",
      f"NIGHT_CHAT_OPENERS keys mismatch: {sorted(openers.keys())}")

# ── D. CHAR_META CROSS-CHECK ────────────────────────────────────
print("\n--- D. CHAR_META CROSS-CHECK (GameManager.gd ~L105) ---")
sync_block = re.search(
    r'chats_db\[char_id\]\["name"\]\s*=\s*meta\.get\("name".*?'
    r'chats_db\[char_id\]\["avatar_color"\]\s*=\s*Color\(meta\.get\("color"',
    wechat_src, re.S)
has_runtime_sync = sync_block is not None
if has_runtime_sync:
    note("WeChatUI._ready() syncs name/emoji/avatar_color from char_meta at runtime "
         "(WeChatUI.gd ~L1089-1093) — static drift is overwritten before first render")
for cid in TEN_CHARS:
    meta, entry = char_meta.get(cid), chats.get(cid)
    if meta is None or entry is None:
        fail(f"{cid}: missing in char_meta or chats_db")
        continue
    diffs = []
    if entry.get("name") != meta.get("name"):
        diffs.append(f'name "{entry.get("name")}" != "{meta.get("name")}"')
    if entry.get("emoji") != meta.get("emoji"):
        diffs.append(f'emoji "{entry.get("emoji")}" != "{meta.get("emoji")}"')
    c1 = str(entry.get("avatar_color", "")).lstrip("#").lower()
    c2 = str(meta.get("color", "")).lstrip("#").lower()
    if c1 != c2:
        diffs.append(f'color #{c1} != #{c2}')
    if not diffs:
        ok(f"{cid}: name/emoji/avatar_color match char_meta")
    elif cid in NEW_CHATS:
        fail(f"{cid} (NEW char): static mismatch vs char_meta: {'; '.join(diffs)}")
    elif has_runtime_sync:
        concern(f"{cid} (legacy): static drift vs char_meta ({'; '.join(diffs)}) — "
                "neutralized by runtime sync, but should be aligned to avoid confusion")
    else:
        fail(f"{cid}: mismatch vs char_meta with NO runtime sync: {'; '.join(diffs)}")

# ── E. LOGIC REVIEW: check_night_chat() ─────────────────────────
print("\n--- E. LOGIC REVIEW InitiativeManager.check_night_chat() ---")
fn = re.search(r"func check_night_chat\(\)[^\n]*:\n(.*?)(?=\nfunc |\Z)", init_src, re.S)
sorter = re.search(r"func _night_candidate_sorter[^\n]*:\n(.*?)(?=\nfunc |\Z)", init_src, re.S)
body = fn.group(1) if fn else ""
sbody = sorter.group(1) if sorter else ""
check('flags.get("night_chat_day_"' in body and "return" in body,
      "(a) per-day guard: night_chat_day_<day> flag checked with early return",
      "(a) per-day guard missing")
check(re.search(r'set_flag\("night_chat_day_"', body) is not None,
      "(a) per-day flag is set even when candidates empty (skip-slot recursion safe)",
      "(a) per-day flag never set")
check('meta.get("unlockDay"' in body, "(b) unlockDay gate via .get present", "(b) unlockDay gate missing")
check('== "cold"' in body and '!= "friend" and st != "close" and st != "crush"' in body,
      '(b) cold excluded; rel_state restricted to {friend,close,crush}',
      "(b) rel_state gating incomplete")
check(re.search(r'state\.get\("wechat_msg",\s*""\)\s*!=\s*""', body) is not None,
      "(c) skips chars with pending wechat_msg (no overwrite)",
      "(c) pending-message skip missing")
check(re.search(r'night_chat_last_.*?\)\s*<\s*3', body) is not None,
      "(d) 3-day per-char cooldown via night_chat_last_<cid>",
      "(d) cooldown check missing/incorrect")
check("sort_custom(_night_candidate_sorter)" in body
      and "fa > fb" in sbody and "ra > rb" in sbody and "a < b" in sbody,
      "(e) deterministic selection: favor desc -> rel-order desc -> char_id asc (total order)",
      "(e) selection not deterministic")
# crash-risk audit
risky = [l for l in body.splitlines()
         if re.search(r'\bflags\[[^\]]+\]|\bfavorability\[[^\]]+\]', l)]
check(not risky, "no raw dict [] access on flags/favorability inside check_night_chat (all .get)",
      f"raw dict access risk: {risky}")
check("_init_char_initiative()" in body,
      "char_initiative pre-initialized before char_initiative[best_cid] write (no missing-key crash)",
      "char_initiative[best_cid] written without prior init — crash risk")

# ── F. INTEGRATION ──────────────────────────────────────────────
print("\n--- F. INTEGRATION ---")
ev = grep_lines(GM, r'sid == "evening"')
cn = grep_lines(GM, r"InitiativeManager\.check_night_chat\(\)")
if ev and cn and any(abs(cl - el) <= 3 for el, _ in ev for cl, _ in cn):
    ok(f"advance_time(): evening branch (L{ev[0][0]}) calls check_night_chat() (L{cn[0][0]})")
else:
    fail(f"evening->check_night_chat wiring not found (evening={ev}, call={cn})")
fw = grep_lines(ENDING, r"GameManager\.flags\s*=\s*\{\}")
rc = grep_lines(ENDING, r"GameManager\.reset_char_initiative\(\)")
check(bool(fw), f"EndingScreen NG+: flags reset wholesale `GameManager.flags = {{}}` (L{fw[0][0] if fw else '?'})"
      " -> night_chat_*/wechat_*/moment_* flags auto-clear (R-4)",
      "EndingScreen NG+ does not wholesale-reset GameManager.flags")
check(bool(rc), f"EndingScreen NG+: calls GameManager.reset_char_initiative() (L{rc[0][0] if rc else '?'})",
      "EndingScreen NG+ missing reset_char_initiative() call")
facade = grep_lines(GM, r"func reset_char_initiative")
proxy  = grep_lines(GM, r"InitiativeManager\.reset_char_initiative\(\)")
check(bool(facade) and bool(proxy),
      f"GameManager facade reset_char_initiative (L{facade[0][0] if facade else '?'}) "
      f"forwards to InitiativeManager (L{proxy[0][0] if proxy else '?'})",
      "GameManager.reset_char_initiative facade missing or does not forward")
if fw and rc and rc[0][0] > fw[0][0]:
    concern(f"EndingScreen: reset_char_initiative() (L{rc[0][0]}) runs AFTER flags={{}} (L{fw[0][0]})"
            " — order is harmless here (independent state) but verify no future coupling")

# ── VERDICT ─────────────────────────────────────────────────────
print("\n" + "=" * 72)
print(f"passed={_passed}  failures={len(failures)}  concerns={len(concerns)}  notes={len(notes)}")
if failures:
    print("VERDICT: FAIL")
    for f_ in failures:
        print(f"  ✗ {f_}")
    sys.exit(1)
elif concerns:
    print("VERDICT: PASS (with concerns)")
    for c_ in concerns:
        print(f"  ⚠ {c_}")
    sys.exit(0)
else:
    print("VERDICT: PASS")
    sys.exit(0)
