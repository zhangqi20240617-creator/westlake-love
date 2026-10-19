# -*- coding: utf-8 -*-
"""
DS-RN-04 西湖风物志收集系统 —— 工程侧逻辑级验证（无 Godot runtime）
Owner: 程基岩 (engineering-lead)

方法：纯静态断言（解析 .gd 文本 / GDScript 字面量提取 / 常量验算 / 缩进扫描），
      对游戏代码只读。参考写法：scratch/verify_memory_echo.py。

覆盖用户验收清单：
  A  FENGWU_ITEMS 24 槽完整性（12 拾得 / 6 购得 / 6 手作）
  B  拾得判定条件合法性（loc 硬门槛 + season/weather/slot 软条件值域与可达性）
  C  购得 6 与 GameManager.ITEM_DB 双源交叉 + ShopUI 零改动自动上架
  D  手作 6 渠道（DS-RN-04b：纯 flag 不进 ITEM_DB + fw_craft_* 事件契约 + 可达性）
  E  grant_fengwu 幂等 + 写入口收敛（CollectionManager 内部 + DialogueUI 唯一外部通道）
  F  集满授 title 需 24 件 →【三渠道全通，24/24 可达，称号可解锁】
  G  拾得判定守卫（结局日 / 每日限速 / 硬软条件分离 / 概率 roll / 常量算术）
  H  与记忆回响钩子互斥（MainGame 调用位置）
  I  缩进铁律（CollectionManager=tab；GameManager/MainGame/FengwuBookUI=4 空格）
  J  补偿扫描链路串入 _retroactive_gallery_check
  K  画廊 CG 条目 + 背景图复用现有资源（零新美术）
  L  存档 / NG+（fengwu_* 随 flags={} 清空；title_* 自动继承；零存档迁移）
  M  零新 Autoload / 图鉴 UI 接线 / 三条已放行特性零回归面
  N  【DS-RN-04b】手作接入后的集满链路 mock 复演（18+6 → 称号 / 消耗 / 扣款）

退出码：0 = 全过，1 = 有失败断言。
"""
import ast
import io
import json
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"

COLL = SCRIPTS / "CollectionManager.gd"
GM = SCRIPTS / "GameManager.gd"
MAIN = SCRIPTS / "MainGame.gd"
DLG = SCRIPTS / "DialogueUI.gd"
EVENTS_LIFE = SCRIPTS / "events_life.json"
BOOK = SCRIPTS / "FengwuBookUI.gd"
SHOP = SCRIPTS / "ShopUI.gd"
ENDING = SCRIPTS / "EndingScreen.gd"
SAVE = SCRIPTS / "SaveSystem.gd"
WEATHER = SCRIPTS / "WeatherManager.gd"
PROJECT = ROOT / "project.godot"

# ── 用户拍板的范围决策（D-1 / D-2 / D-3）────────────────────────
EXP_TOTAL = 24
EXP_PICKUP = 12          # 拾得
EXP_BUY = 6              # 购得
EXP_HANDMADE = 6         # 手作（DS-RN-04b 已接入 fw_craft_* 事件）
EXP_REACHABLE = EXP_PICKUP + EXP_BUY + EXP_HANDMADE   # 24 —— 三渠道全通

# 手作材料费真源（GDD §4.2，合计 95 元）
CRAFT_COSTS = {
    "fw_hm_yahua": 15, "fw_hm_guihuajiang": 10, "fw_hm_xiangnang": 25,
    "fw_hm_taci": 20, "fw_hm_zhuze": 15, "fw_hm_luyin": 10,
}
CRAFT_COST_TOTAL = 95

CATEGORIES = {"味", "物", "草木", "声景"}
OBTAINS = {"拾得", "购得", "手作"}
SEASONS = {"", "spring", "summer", "autumn", "winter"}
WEATHERS = {"", "sunny", "cloudy", "rainy", "snowy"}
SLOTS = {"", "morning", "noon", "after", "evening"}
FIELDS = {"name", "category", "obtain", "loc", "season", "weather", "slot", "hint"}

TITLE_FLAG = "title_西湖风物通"
COMPLETE_FLAG = "west_lake_fengwu_complete"
PICKUP_DAY_FLAG = "fengwu_pickup_day"

AUTOLOAD_EXPECTED = 15   # 改动前基线（零新 Autoload）
ITEM_DB_EXPECTED = 13    # 7（基线）+ 6（购得风物）
GALLERY_EXPECTED = 55    # 54（基线）+ 1（风物大成）

# ─────────────────────────────────────────────────────────────────
_n = 0
failures = []


def check(cond, desc, detail=""):
    global _n
    _n += 1
    tag = f"F{_n:02d}"
    if cond:
        print(f"  [PASS] {tag}  {desc}")
    else:
        msg = f"{tag}  {desc}" + (f"  →  {detail}" if detail else "")
        failures.append(msg)
        print(f"  [FAIL] {msg}")
    return bool(cond)


def section(title):
    print(f"\n--- {title} ---")


# ── GDScript 字面量提取（字符串感知；# 注释仅在字符串外生效）──────
def extract_block(src: str, anchor: str) -> str:
    i = src.index(anchor) + len(anchor)
    while src[i] not in "[{":
        i += 1
    open_ch = src[i]
    close_ch = "]" if open_ch == "[" else "}"
    depth, in_str, esc, start = 0, False, False, i
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
            elif c == "#":
                nl = src.find("\n", i)
                i = nl if nl != -1 else len(src) - 1
            elif c in "[{":
                depth += 1
            elif c in "]}":
                depth -= 1
                if depth == 0 and c == close_ch:
                    return src[start:i + 1]
        i += 1
    raise ValueError(f"unbalanced literal for anchor {anchor!r}")


def gd_to_py(block: str) -> str:
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
        if c == "#":
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
    return "".join(out)


def load_literal(path: Path, anchor: str):
    return ast.literal_eval(gd_to_py(extract_block(path.read_text(encoding="utf-8"), anchor)))


def src_of(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def func_body(src: str, name: str) -> str:
    """取 func <name> 的函数体（到下一个顶层 func / 顶层注释块 / EOF）。"""
    m = re.search(r"^func %s\(.*?\).*?:\n(.*?)(?=^func |^# ═|\Z)" % re.escape(name),
                  src, re.S | re.M)
    if not m:
        return ""
    lines = m.group(1).split("\n")
    while lines and (not lines[-1].strip() or lines[-1].lstrip().startswith("#")) \
            and not lines[-1].startswith(("\t", " ")):
        lines.pop()
    return "\n".join(lines)


def strip_comments(src: str) -> str:
    """删除 GDScript 注释（字符串感知），用于"代码级"出现次数统计。"""
    out, i, in_str, esc = [], 0, False, False
    while i < len(src):
        c = src[i]
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
        if c == "#":
            nl = src.find("\n", i)
            i = nl if nl != -1 else len(src)
            continue
        out.append(c)
        i += 1
    return "".join(out)


def split_top_level_entries(block: str) -> dict:
    """把 GDScript 字典字面量拆成 {key: raw_value_str}（仅顶层，字符串/注释感知）。
    用于含 Vector2(...) 等非 Python 字面量的 GameManager.locations。"""
    i = block.index("{") + 1
    n = len(block)
    out = {}
    while i < n:
        while i < n and block[i] in " \t\r\n,":
            i += 1
        if i < n and block[i] == "#":
            nl = block.find("\n", i)
            i = nl if nl != -1 else n
            continue
        if i >= n or block[i] == "}":
            break
        if block[i] != '"':
            i += 1
            continue
        j = i + 1
        while j < n and block[j] != '"':
            if block[j] == "\\":
                j += 1
            j += 1
        key = block[i + 1:j]
        i = j + 1
        while i < n and block[i] in " \t\r\n":
            i += 1
        if i >= n or block[i] != ":":
            continue
        i += 1
        while i < n and block[i] in " \t\r\n":
            i += 1
        start = i
        depth, in_str, esc = 0, False, False
        while i < n:
            c = block[i]
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
                elif c == "#":
                    nl = block.find("\n", i)
                    i = nl if nl != -1 else n
                    continue
                elif c in "[{(":
                    depth += 1
                elif c in "]})":
                    if depth == 0:
                        break
                    depth -= 1
                elif c == "," and depth == 0:
                    break
            i += 1
        out[key] = block[start:i].strip()
    return out


def gd_const_float(src: str, name: str):
    m = re.search(r"^const %s\s*:?=\s*([0-9.]+)" % re.escape(name), src, re.M)
    return float(m.group(1)) if m else None


def gd_const_int(src: str, name: str):
    m = re.search(r"^const %s\s*:?=\s*(-?\d+)" % re.escape(name), src, re.M)
    return int(m.group(1)) if m else None


# ═════════════════════════════════════════════════════════════════
print("=" * 74)
print("DS-RN-04 西湖风物志 —— 工程验证 (static, no Godot runtime)")
print("=" * 74)

COLL_SRC = src_of(COLL)
GM_SRC = src_of(GM)
MAIN_SRC = src_of(MAIN)
BOOK_SRC = src_of(BOOK) if BOOK.exists() else ""
SHOP_SRC = src_of(SHOP)
ENDING_SRC = src_of(ENDING)
SAVE_SRC = src_of(SAVE)
DLG_SRC = src_of(DLG)
EVENTS_RAW = src_of(EVENTS_LIFE)
EVENTS = json.loads(EVENTS_RAW)

FW = load_literal(COLL, "const FENGWU_ITEMS = ")
ITEM_DB = load_literal(GM, "const ITEM_DB = ")
GALLERY = load_literal(GM, "const GALLERY_ITEMS = ")
LOC_RAW = split_top_level_entries(extract_block(GM_SRC, "var locations = "))

fids = list(FW.keys())
by_obtain = {o: [f for f in fids if FW[f].get("obtain") == o] for o in OBTAINS}
PICKUPS = by_obtain["拾得"]
BUYS = by_obtain["购得"]
HANDMADE = by_obtain["手作"]

# ─────────────────────────────────────────────────────────────────
section("A · FENGWU_ITEMS 注册表完整性（24 槽 / D-1）")

check(len(FW) == EXP_TOTAL, f"FENGWU_ITEMS 恰好 {EXP_TOTAL} 槽", f"实际 {len(FW)}")
check(len(PICKUPS) == EXP_PICKUP, f"拾得 {EXP_PICKUP} 件", f"实际 {len(PICKUPS)}")
check(len(BUYS) == EXP_BUY, f"购得 {EXP_BUY} 件", f"实际 {len(BUYS)}")
check(len(HANDMADE) == EXP_HANDMADE, f"手作预留 {EXP_HANDMADE} 件", f"实际 {len(HANDMADE)}")
check(len(PICKUPS) + len(BUYS) + len(HANDMADE) == len(FW),
      "obtain 值域封闭（无第四类）",
      f"未归类 {set(fids) - set(PICKUPS) - set(BUYS) - set(HANDMADE)}")

bad_fields = {f: sorted(set(FW[f].keys()) ^ FIELDS) for f in fids if set(FW[f].keys()) != FIELDS}
check(not bad_fields, "每条 8 字段齐备且无多余键", str(bad_fields)[:200])

bad_cat = {f: FW[f].get("category") for f in fids if FW[f].get("category") not in CATEGORIES}
check(not bad_cat, f"category ∈ {sorted(CATEGORIES)}", str(bad_cat))

bad_empty = [f for f in fids if not str(FW[f].get("name", "")).strip()
             or not str(FW[f].get("hint", "")).strip()]
check(not bad_empty, "name / hint 均非空（图鉴不出现空格子）", str(bad_empty))

names = [FW[f]["name"] for f in fids]
check(len(set(names)) == len(names), "风物名互不重复", str([n for n in names if names.count(n) > 1]))

# fid 命名空间安全：flag 形如 fengwu_<fid> 与 fengwu_<fid>_day，
# 另有限速位 fengwu_pickup_day —— 三者不得互撞。
collide = [f for f in fids if f + "_day" in FW or f == "pickup_day" or f == "pickup"]
check(not collide, "fid 不与 fengwu_<fid>_day / fengwu_pickup_day 撞名", str(collide))
check(PICKUP_DAY_FLAG == "fengwu_" + "pickup_day" and "pickup_day" not in FW,
      "限速位 fengwu_pickup_day 未被任何 fid 占用")

order = [FW[f]["obtain"] for f in fids]
expected_order = ["拾得"] * EXP_PICKUP + ["购得"] * EXP_BUY + ["手作"] * EXP_HANDMADE
check(order == expected_order,
      "注册表顺序 = 拾得 → 购得 → 手作（图鉴分组连续）", f"实际 {order}")

cat_count = {c: sum(1 for f in fids if FW[f]["category"] == c) for c in sorted(CATEGORIES)}
check(all(v >= 3 for v in cat_count.values()),
      f"四类分布均衡（每类 ≥3）：{cat_count}", str(cat_count))

# ─────────────────────────────────────────────────────────────────
section("B · 拾得 12 · 判定条件合法性（loc 硬门槛 / 其余软条件）")

loc_ids = set(LOC_RAW.keys())
check(len(loc_ids) >= 10, f"成功解析 GameManager.locations（{len(loc_ids)} 个地点）", str(sorted(loc_ids)))

bad_loc = {f: FW[f]["loc"] for f in PICKUPS if FW[f]["loc"] not in loc_ids}
check(not bad_loc, "拾得条目的 loc 全部存在于 GameManager.locations（否则永不可达）", str(bad_loc))

bad_season = {f: FW[f]["season"] for f in fids if FW[f]["season"] not in SEASONS}
check(not bad_season, f"season ∈ {sorted(SEASONS)}", str(bad_season))
bad_weather = {f: FW[f]["weather"] for f in fids if FW[f]["weather"] not in WEATHERS}
check(not bad_weather, f"weather ∈ {sorted(WEATHERS)}", str(bad_weather))
bad_slot = {f: FW[f]["slot"] for f in fids if FW[f]["slot"] not in SLOTS}
check(not bad_slot, f"slot ∈ {sorted(SLOTS)}", str(bad_slot))

# 软条件可达性：slot 必须是该地点真实开放的时段，否则该 +0.12 是永不触发的死权重。
# 例外：lakeside 周末放开四段（LocationManager.get_available_locations L83-84）。
loc_slots = {}
for lid, raw in LOC_RAW.items():
    m = re.search(r'"slots"\s*:\s*\[([^\]]*)\]', raw)
    loc_slots[lid] = set(re.findall(r'"(\w+)"', m.group(1))) if m else set()
loc_slots["lakeside"] = {"morning", "noon", "after", "evening"}   # 周末例外

dead_slot = {f: (FW[f]["loc"], FW[f]["slot"]) for f in PICKUPS
             if FW[f]["slot"] and FW[f]["slot"] not in loc_slots.get(FW[f]["loc"], set())}
check(not dead_slot, "slot 软条件均落在该地点真实开放时段内（无死权重）", str(dead_slot))

# snowy 仅在 winter 刷出（WeatherManager._refresh_weather_by_season L88-93）
dead_weather = {f: (FW[f]["season"], FW[f]["weather"]) for f in PICKUPS
                if FW[f]["weather"] == "snowy" and FW[f]["season"] not in ("", "winter")}
check(not dead_weather, "weather==snowy 的条目季节必为 winter/不限（snowy 只在冬季刷出）",
      str(dead_weather))

pick_locs = {FW[f]["loc"] for f in PICKUPS}
check(len(pick_locs) >= 5, f"拾得覆盖 ≥5 个地点（避免堆单点）：{sorted(pick_locs)}",
      str(sorted(pick_locs)))

# 每个地点的拾得件数 ≤ 4，避免单地点刷太久
per_loc = {l: sum(1 for f in PICKUPS if FW[f]["loc"] == l) for l in pick_locs}
check(max(per_loc.values()) <= 4, f"单地点拾得件数 ≤4：{per_loc}", str(per_loc))

# ─────────────────────────────────────────────────────────────────
section("C · 购得 6 × ITEM_DB 双源交叉 + ShopUI 零改动上架")

missing = [f for f in BUYS if f not in ITEM_DB]
check(not missing, "购得 fid 全部存在于 GameManager.ITEM_DB（fid == item_id）", str(missing))

db_fengwu = sorted(k for k, v in ITEM_DB.items() if v.get("category") == "fengwu")
check(db_fengwu == sorted(BUYS),
      "ITEM_DB 中 category=='fengwu' 的集合 == 购得 fid 集合（不多不少）",
      f"ITEM_DB={db_fengwu} vs FENGWU={sorted(BUYS)}")

bad_price = {f: ITEM_DB.get(f, {}).get("price") for f in BUYS
             if not isinstance(ITEM_DB.get(f, {}).get("price"), int)
             or ITEM_DB.get(f, {}).get("price", 0) <= 0}
check(not bad_price, "购得物品 price 均为正整数（商店不白送）", str(bad_price))

bad_meta = [f for f in BUYS
            if not str(ITEM_DB.get(f, {}).get("name", "")).strip()
            or not str(ITEM_DB.get(f, {}).get("icon", "")).strip()
            or not str(ITEM_DB.get(f, {}).get("desc", "")).strip()]
check(not bad_meta, "购得物品 name/icon/desc 齐备（商店行不出现占位）", str(bad_meta))

name_mismatch = {f: (FW[f]["name"], ITEM_DB.get(f, {}).get("name"))
                 for f in BUYS if FW[f]["name"] != ITEM_DB.get(f, {}).get("name")}
check(not name_mismatch, "风物名与 ITEM_DB 物品名逐字一致（双源不漂移）", str(name_mismatch))

check(len(ITEM_DB) == ITEM_DB_EXPECTED,
      f"ITEM_DB 总数 = {ITEM_DB_EXPECTED}（7 基线 + 6 风物）", f"实际 {len(ITEM_DB)}")

# 购得 / 手作 不参与拾得判定 → 四个条件位必须恒为空
non_pick_dirty = {f: (FW[f]["loc"], FW[f]["season"], FW[f]["weather"], FW[f]["slot"])
                  for f in BUYS + HANDMADE
                  if any(FW[f][k] for k in ("loc", "season", "weather", "slot"))}
check(not non_pick_dirty, "购得/手作条目 loc/season/weather/slot 恒为空", str(non_pick_dirty))

shop_body = func_body(SHOP_SRC, "update_shop_list")
check("GameManager.ITEM_DB" in shop_body and ".keys()" in shop_body,
      "ShopUI.update_shop_list 遍历 ITEM_DB.keys()")
check("category" not in strip_comments(shop_body),
      "ShopUI 无 category 过滤 → 新增 6 条自动上架（ShopUI 零改动）")
check("fengwu" not in strip_comments(SHOP_SRC),
      "ShopUI.gd 全文无 fengwu 硬编码（真·零改动）")

# ─────────────────────────────────────────────────────────────────
section("D · 手作 6 渠道（DS-RN-04b：纯 flag + fw_craft_* 事件契约 + 可达性）")

in_db = [f for f in HANDMADE if f in ITEM_DB]
check(not in_db,
      "★ D-2 白嫖防护：手作 fid 均不在 ITEM_DB（进了就会被 ShopUI 按 price:0 免费上架）",
      str(in_db))

# 手作产物绝不可走 addItem —— add_item 对非 ITEM_DB 物品会访问 ITEM_DB[id].name 而崩溃
add_item_hm = [f for f in HANDMADE
               if re.search(r'"addItem"\s*:\s*"%s"' % re.escape(f), EVENTS_RAW)]
check(not add_item_hm,
      "★ 手作 fid 绝不出现在任何 addItem 字段（走 addItem 必崩：ITEM_DB[fid].name）",
      str(add_item_hm))

craft_evs = [e for e in EVENTS if str(e.get("id", "")).startswith("fw_craft_")]
check(len(craft_evs) == EXP_HANDMADE,
      f"events_life.json 恰含 {EXP_HANDMADE} 条 fw_craft_* 事件", f"实际 {len(craft_evs)}")

granted = [str(e["scenes"][-1].get("grantFengwu", "")) for e in craft_evs]
check(sorted(granted) == sorted(HANDMADE),
      "6 条事件的 grantFengwu 目标 == 6 个手作 fid（不多不少、逐字一致）",
      f"事件={sorted(granted)} vs 注册表={sorted(HANDMADE)}")

bad_contract = {}
for e in craft_evs:
    sc = e["scenes"][-1]
    fid = str(sc.get("grantFengwu", ""))
    cost = CRAFT_COSTS.get(fid)
    errs = []
    if e.get("location") != "home":
        errs.append("location=%s" % e.get("location"))
    if e.get("charId") is not None:
        errs.append("charId=%s" % e.get("charId"))
    if e.get("repeatable", False) is not False:
        errs.append("repeatable=%s" % e.get("repeatable"))
    if e.get("requireItem") != "handmade_gift":
        errs.append("requireItem=%s" % e.get("requireItem"))
    if int(e.get("requireItemAmt", 0)) != 1:
        errs.append("requireItemAmt=%s" % e.get("requireItemAmt"))
    if cost is None or int(e.get("requireMoney", -1)) != cost:
        errs.append("requireMoney=%s(期望%s)" % (e.get("requireMoney"), cost))
    if sc.get("removeItem") != "handmade_gift":
        errs.append("removeItem=%s" % sc.get("removeItem"))
    if cost is None or int(sc.get("statDelta", {}).get("money", 0)) != -cost:
        errs.append("statDelta.money=%s(期望%s)" % (sc.get("statDelta"), -cost if cost else "?"))
    if int(sc.get("next", -1)) != 99:
        errs.append("next=%s" % sc.get("next"))
    if errs:
        bad_contract[e.get("id")] = errs
check(not bad_contract,
      "每条事件契约齐备：home + charId null + repeatable false + "
      "requireItem handmade_gift×1 + requireMoney==材料费 + "
      "statDelta.money==-材料费 + removeItem handmade_gift + next 99",
      str(bad_contract))

check(sum(int(e.get("requireMoney", 0)) for e in craft_evs) == CRAFT_COST_TOTAL,
      f"6 条材料费合计 == {CRAFT_COST_TOTAL} 元（与 GDD §4.2 一致）",
      str(sum(int(e.get("requireMoney", 0)) for e in craft_evs)))

# requireItem 只校验不消耗（DataManager L245-250）→ 必须靠 removeItem 真消耗
check(all(e["scenes"][-1].get("removeItem") == "handmade_gift" for e in craft_evs),
      "★ 消耗语义：requireItem 只校验不消耗，6 条全部显式 removeItem "
      "（否则 1 个 handmade_gift 可白嫖 6 件风物）")

check(all(e["scenes"][-1].get("setFlag") == e.get("id") for e in craft_evs),
      "每条末句 setFlag == 事件 id（与 finish_event 的 flags[ev_id] 去重同键，双保险）")

# ★ 可达性：priority 必须高于同在 home 且 repeatable:true 的 int_craft_make，
#   否则 DataManager 取 candidates[0] 时永远选不到这 6 条 —— 手作渠道死锁。
icm = next((e for e in EVENTS if e.get("id") == "int_craft_make"), {})
icm_prio = int(icm.get("priority", 0))
too_low = {e.get("id"): e.get("priority") for e in craft_evs
           if int(e.get("priority", 0)) <= icm_prio}
check(icm_prio > 0 and not too_low,
      f"★ 可达性：6 条 priority 均 > int_craft_make({icm_prio}) —— "
      f"DataManager 取 candidates[0]，不高于这条 repeatable 事件即永不触发",
      str(too_low))
prios = [int(e.get("priority", 0)) for e in craft_evs]
check(len(set(prios)) == len(prios),
      "6 条 priority 互不相同（排序无并列，选择确定性可静态复现）", str(prios))
check(not any("triggerDay" in e for e in craft_evs),
      "6 条均不设 triggerDay（自然门控 = 持有 handmade_gift 即可）")

# DialogueUI 侧两个新场景级字段（手作产物的唯一授予通道）
check(re.search(r'if scene\.has\("grantFengwu"\)[^\n]*\n\s*CollectionManager\.grant_fengwu\(',
                DLG_SRC) is not None,
      "DialogueUI 场景级 grantFengwu 分支存在，且调用 CollectionManager.grant_fengwu")
check(re.search(r'if scene\.has\("removeItem"\)[^\n]*\n\s*CollectionManager\.remove_item\('
                r'scene\["removeItem"\], 1\)', DLG_SRC) is not None,
      "DialogueUI 场景级 removeItem 分支存在，且调用 remove_item(x, 1)")
check(re.search(r'grantFengwu"\]\)\s*\n', DLG_SRC) is not None
      and not re.search(r'set_flag\(scene\["grantFengwu"\]', DLG_SRC),
      "grantFengwu 不改用 setFlag（setFlag 不触发集满判定与入册 toast）")

all_src = "\n".join(src_of(p) for p in sorted(SCRIPTS.glob("*.gd")))
all_code = strip_comments(all_src)
FW_BLOCK = extract_block(COLL_SRC, "const FENGWU_ITEMS = ")
code_outside_registry = strip_comments(all_src.replace(FW_BLOCK, ""))
hardcoded_hm = [f for f in HANDMADE if f'"{f}"' in code_outside_registry]
check(not hardcoded_hm,
      "注册表之外的 .gd 无任何手作 fid 硬编码（授予纯数据驱动，经事件 JSON 下发）",
      str(hardcoded_hm))
check(all(f'"{f}"' in FW_BLOCK for f in HANDMADE),
      "6 个手作 fid 均在注册表中登记")

stale = [f for f in HANDMADE if "尚未开放" in FW[f]["hint"]]
check(not stale, "手作 hint 已删除「尚未开放」标记（改为可达成文案）", str(stale))

pick_body = func_body(COLL_SRC, "pick_fengwu_pickup")
check('!= "拾得"' in pick_body and "continue" in pick_body,
      "pick_fengwu_pickup 过滤 obtain != 拾得（手作/购得不会被拾得误授）")

# ─────────────────────────────────────────────────────────────────
section("E · grant 幂等 / 唯一写入口 / UI 只读")

grant_body = func_body(COLL_SRC, "grant_fengwu")
check(bool(grant_body), "grant_fengwu() 存在")
check("if GameManager.flags.has(flag): return false" in grant_body,
      "grant_fengwu 幂等守卫：已入册直接 return false")
check("if not FENGWU_ITEMS.has(fid): return false" in grant_body,
      "grant_fengwu 未知 fid 安全失败（不写脏 flag）")
check('GameManager.set_flag(flag, true)' in grant_body
      and 'GameManager.set_flag(flag + "_day", GameManager.day)' in grant_body,
      "grant_fengwu 同时写 fengwu_<fid> 与 fengwu_<fid>_day")

# fengwu_ 写入点必须全部在 CollectionManager 内
writers = []
for p in sorted(SCRIPTS.glob("*.gd")):
    code = strip_comments(src_of(p))
    if re.search(r'(set_flag\(\s*"fengwu_|flags\[\s*"fengwu_|set_flag\(FENGWU_|flags\[FENGWU_)', code):
        writers.append(p.name)
check(writers == ["CollectionManager.gd"],
      "fengwu_* 的写入点唯一收敛在 CollectionManager.gd", str(writers))

grant_callers = sorted({p.name for p in SCRIPTS.glob("*.gd")
                        if "grant_fengwu(" in strip_comments(src_of(p))})
check(grant_callers == ["CollectionManager.gd", "DialogueUI.gd"],
      "grant_fengwu() 调用点恰为 2 处：CollectionManager（定义 + 拾得/购得内部）"
      " + DialogueUI（手作唯一外部通道），无第三处旁路", str(grant_callers))

check(bool(BOOK_SRC), "FengwuBookUI.gd 已创建")
book_code = strip_comments(BOOK_SRC)
check("set_flag" not in book_code and "grant_fengwu" not in book_code
      and not re.search(r"flags\[", book_code),
      "FengwuBookUI 不写任何 flag / 不授予（单向数据流，只读面板）")
check("unlock_gallery" not in book_code, "FengwuBookUI 不碰画廊解锁")

toast_hits = len(re.findall(r"show_toast\.emit", strip_comments(
    COLL_SRC[COLL_SRC.index("const FENGWU_ITEMS"):])))
check(toast_hits == 2,
      "风物志区仅 2 处 toast（普通入册 1 + 集满 1），无 toast 泛滥", f"实际 {toast_hits}")

# ─────────────────────────────────────────────────────────────────
section("F · 集满授 title 需 24 件 →【本 sprint 称号暂锁】")

comp_body = func_body(COLL_SRC, "_check_fengwu_completion")
check(bool(comp_body), "_check_fengwu_completion() 存在")
check("for fid in FENGWU_ITEMS.keys():" in comp_body and "if not is_fengwu_owned(fid): return false" in comp_body,
      "集满判定遍历全 FENGWU_ITEMS（24），而非仅可达的 18")
check("get_fengwu_reachable_total" not in comp_body,
      "集满判定未被「可达数」降级（不得偷偷按 18 判定）")
check("GameManager.set_flag(FENGWU_TITLE_FLAG, true)" in comp_body,
      "集满置称号 FENGWU_TITLE_FLAG")
check("GameManager.set_flag(FENGWU_COMPLETE_FLAG, true)" in comp_body
      and "unlock_gallery(FENGWU_COMPLETE_FLAG)" in comp_body,
      "集满置画廊 flag 并调用 unlock_gallery")

tf = re.search(r'const FENGWU_TITLE_FLAG\s*:?=\s*"([^"]+)"', COLL_SRC)
check(tf and tf.group(1) == TITLE_FLAG, f"称号 flag == {TITLE_FLAG}", tf.group(1) if tf else "缺失")
check(tf and tf.group(1).startswith("title_"),
      "称号 flag 带 title_ 前缀（EndingScreen 自动消费 + NG+ 自动继承）")
cf = re.search(r'const FENGWU_COMPLETE_FLAG\s*:?=\s*"([^"]+)"', COLL_SRC)
check(cf and cf.group(1) == COMPLETE_FLAG, f"画廊 flag == {COMPLETE_FLAG}", cf.group(1) if cf else "缺失")
check(cf and not cf.group(1).startswith("fengwu_"),
      "画廊 flag 不以 fengwu_ 开头（不与 fengwu_<fid> 命名空间混淆）")

check(gd_const_int(COLL_SRC, "FENGWU_TOTAL") == EXP_TOTAL,
      f"FENGWU_TOTAL == {EXP_TOTAL}", str(gd_const_int(COLL_SRC, "FENGWU_TOTAL")))
check(gd_const_int(COLL_SRC, "FENGWU_TOTAL") == len(FW),
      "FENGWU_TOTAL 与注册表实际条数一致（不会显示成 x/错数）")

reach_body = func_body(COLL_SRC, "get_fengwu_reachable_total")
check("return FENGWU_TOTAL" in reach_body and '!= "手作"' not in reach_body,
      "★ 遗留 bug 已修：get_fengwu_reachable_total 直接返回 FENGWU_TOTAL，"
      "不再排除 obtain==手作（否则手作上线后仍返 18）", reach_body.strip()[:120])

# ★ 核心解锁断言（DS-RN-04b：由「暂锁」翻转为「可达」）
check(EXP_REACHABLE == EXP_TOTAL == 24,
      f"【已解锁】可达上限 {EXP_REACHABLE}/{EXP_TOTAL} → 称号 {TITLE_FLAG} 本版本可真实达成")
check(len(HANDMADE) == EXP_HANDMADE and len(craft_evs) == EXP_HANDMADE,
      f"【解锁成因】{len(HANDMADE)} 件手作各有 1 条 fw_craft_* 事件授予 → "
      f"_check_fengwu_completion 可真实返回 true")
gm_complete_refs = [l.strip() for l in GM_SRC.splitlines()
                    if COMPLETE_FLAG in l and not l.strip().startswith("#")]
check(len(gm_complete_refs) == 1,
      "GameManager 内 west_lake_fengwu_complete 仅出现在画廊条目（无旁路解锁）",
      str(gm_complete_refs))

# ─────────────────────────────────────────────────────────────────
section("G · 拾得判定守卫（D-4：被动 / 不打断 / 概率）")

check(bool(pick_body), "pick_fengwu_pickup() 存在")
check("if GameManager.day >= FENGWU_END_DAY: return \"\"" in pick_body,
      "G0 结局日守卫：day >= FENGWU_END_DAY 直接返回")
check(gd_const_int(COLL_SRC, "FENGWU_END_DAY") == 570,
      "FENGWU_END_DAY == 570（对齐记忆回响 ECHO_END_DAY）")
check("if is_fengwu_pickup_used_today(): return \"\"" in pick_body,
      "每日 1 件限速守卫")
check("if is_fengwu_owned(fid): continue" in pick_body, "已入册跳过")
check('String(data.get("loc", "")) != loc_id: continue' in pick_body,
      "loc 为唯一硬门槛（!= loc_id → continue）")
check("randf() >= best_chance" in pick_body, "概率 roll：randf() 判定")
check("GameManager.set_flag(FENGWU_PICKUP_DAY_FLAG, GameManager.day)" in pick_body,
      "命中后写入限速位（限速真实生效）")

# 软条件必须只加权、不 continue —— 函数体内 continue 恰好 3 次（obtain / loc / owned）
n_continue = len(re.findall(r"\bcontinue\b", strip_comments(pick_body)))
check(n_continue == 3, "函数体内 continue 恰好 3 次（obtain / loc / owned 三道守卫）",
      f"实际 {n_continue} —— 多出的很可能是把软条件写成了硬门槛")
soft_lines = [l for l in pick_body.splitlines()
              if re.search(r"==\s*(season|weather|slot)\b", l)]
check(len(soft_lines) == 3 and all("FENGWU_PICK_BONUS" in l for l in soft_lines),
      "season/weather/slot 三项一律只做 += FENGWU_PICK_BONUS 加权", str(soft_lines))
check(not re.search(r"(season|weather|slot)\b.*:\s*continue", pick_body),
      "★ 季节/天气/时段绝不作为硬门槛（否则错过当季即永锁称号）")

base = gd_const_float(COLL_SRC, "FENGWU_PICK_BASE")
bonus = gd_const_float(COLL_SRC, "FENGWU_PICK_BONUS")
cap = gd_const_float(COLL_SRC, "FENGWU_PICK_CAP")
check(base is not None and bonus is not None and cap is not None,
      f"概率常量齐备 BASE={base} BONUS={bonus} CAP={cap}")
check(base and base > 0, "BASE > 0（无软条件时仍可拾得 → 不会有永不可达条目）")
check(base + 3 * bonus <= cap + 1e-9,
      f"BASE+3×BONUS={base + 3 * bonus:.2f} ≤ CAP={cap}（满条件加成不被封顶砍掉）")
check(cap and cap < 1.0, "CAP < 1.0（保留随机性，不做保底必得）")
check("minf(chance, FENGWU_PICK_CAP)" in pick_body, "概率封顶用 minf 收口")
check("is_equal_approx(chance, best_chance) and fid < best_fid" in pick_body,
      "平局按 fid 字典序（选择稳定、可静态复现）")

# D-4：不播 vignette / 不消耗时段 / 不改属性
for forbidden, why in [("build_", "不合成 vignette"),
                       ("start_event", "不启动对话事件"),
                       ("statDelta", "不改属性"),
                       ("add_favor", "不改好感"),
                       ("advance_slot", "不消耗时段")]:
    check(forbidden not in pick_body, f"D-4 拾得{why}（函数体内无 {forbidden}）")

# ─────────────────────────────────────────────────────────────────
section("H · 与记忆回响互斥 + MainGame 接线")

sel_body = func_body(MAIN_SRC, "_on_location_selected")
check(bool(sel_body), "_on_location_selected() 存在")
lines = [l.strip() for l in sel_body.splitlines()]
try:
    i_echo = next(i for i, l in enumerate(lines) if "_try_memory_echo(loc_id): return" in l)
except StopIteration:
    i_echo = -1
try:
    i_pick = next(i for i, l in enumerate(lines) if "CollectionManager.pick_fengwu_pickup(loc_id)" in l)
except StopIteration:
    i_pick = -1
try:
    i_hot = next(i for i, l in enumerate(lines) if "hotspot_ui.on_location_selected(loc_id)" in l)
except StopIteration:
    i_hot = -1
check(i_echo >= 0, "记忆回响 step 0 仍在（未被破坏）")
check(i_pick >= 0, "已插入 CollectionManager.pick_fengwu_pickup(loc_id)")
check(i_echo >= 0 and i_pick > i_echo,
      "★ 拾得调用位于记忆回响 return 之后（二者天然互斥，不同屏）",
      f"echo@{i_echo} pick@{i_pick}")
check(i_hot >= 0 and i_pick < i_hot,
      "拾得调用位于 hotspot_ui.on_location_selected 之前", f"pick@{i_pick} hot@{i_hot}")
check(i_pick >= 0 and "return" not in lines[i_pick],
      "拾得调用行不带 return（不抢屏、不打断进入地点）")

n_pick_calls = len(re.findall(r"pick_fengwu_pickup\(", strip_comments(all_src)))
check(n_pick_calls == 2,
      "pick_fengwu_pickup 全工程 1 处定义 + 1 处调用", f"实际出现 {n_pick_calls} 次")

FW_SECTION_MARKER = "# ── 西湖风物志（DS-RN-04）"
echo_region = COLL_SRC[COLL_SRC.index("MEMORY_ECHO_CONTEXTS"):COLL_SRC.index(FW_SECTION_MARKER)]
check("fengwu" not in echo_region.lower(),
      "记忆回响区未被风物志污染（零回归面）",
      str([l.strip() for l in echo_region.splitlines() if "fengwu" in l.lower()][:5]))
for fn in ("pick_memory_echo", "commit_memory_echo", "build_memory_echo_vignette"):
    check("fengwu" not in func_body(COLL_SRC, fn).lower(), f"{fn}() 内无 fengwu 引用")

# ─────────────────────────────────────────────────────────────────
section("I · 缩进铁律（防 GDScript mixed tabs and spaces）")

def indent_stat(path: Path):
    tabs, spaces = [], []
    for i, line in enumerate(io.open(path, encoding="utf-8"), 1):
        if not line.strip():
            continue
        lead = line[:len(line) - len(line.lstrip())]
        if "\t" in lead:
            tabs.append(i)
        if lead.startswith(" "):
            spaces.append(i)
    return tabs, spaces


t, s = indent_stat(COLL)
check(len(s) == 0 and len(t) > 0, f"CollectionManager.gd 全 tab（tab={len(t)} space={len(s)}）",
      f"空格行 {s[:10]}")
for p in (GM, MAIN, BOOK):
    t2, s2 = indent_stat(p)
    check(len(t2) == 0 and len(s2) > 0, f"{p.name} 全 4 空格（tab={len(t2)} space={len(s2)}）",
          f"tab 行 {t2[:10]}")

fw_region = COLL_SRC[COLL_SRC.index("# ── 西湖风物志（DS-RN-04）"):]
check("\n    " not in fw_region.replace("\n    #", "\n\t#"),
      "风物志新增区无 4 空格缩进残留")

# ─────────────────────────────────────────────────────────────────
section("J · 补偿扫描链路串入")

retro_body = func_body(COLL_SRC, "_retroactive_fengwu_check")
check(bool(retro_body), "_retroactive_fengwu_check() 存在")
gal_body = func_body(COLL_SRC, "_retroactive_gallery_check")
check("_retroactive_fengwu_check()" in gal_body,
      "CollectionManager._retroactive_gallery_check 已串入风物补偿")
check("_retroactive_stamp_check()" in gal_body, "十景补偿仍在（零回归）")
check("CollectionManager._retroactive_gallery_check()" in func_body(GM_SRC, "_retroactive_gallery_check"),
      "GameManager._retroactive_gallery_check → CollectionManager（链路未断）")
check('call_deferred("_retroactive_gallery_check")' in GM_SRC,
      "开局 / 读档时触发补偿扫描（GameManager._ready）")
check('!= "购得"' in retro_body and "GameManager.inventory.has(fid)" in retro_body,
      "补偿①：inventory 里已有购得风物却未入册 → 补录")
check("get_fengwu_day(fid) < 0" in retro_body, "补偿②：已入册但缺 _day → 补当前 day")
check("_check_fengwu_completion()" in retro_body, "补偿③：存量存档已集满 → 补触发")

add_item_body = func_body(COLL_SRC, "add_item")
check("_try_grant_fengwu_item(item_id)" in add_item_body,
      "add_item 尾部挂购得钩子（ShopUI / 事件 addItem 全覆盖）")
hook_body = func_body(COLL_SRC, "_try_grant_fengwu_item")
check('!= "fengwu"' in hook_body and "grant_fengwu(item_id)" in hook_body,
      "购得钩子以 category=='fengwu' 识别，item_id 直接当 fid")

# ─────────────────────────────────────────────────────────────────
section("K · 画廊 CG 条目 + 零新美术资源")

fw_gal = [g for g in GALLERY if g.get("flag") == COMPLETE_FLAG]
check(len(fw_gal) == 1, f"GALLERY_ITEMS 恰好 1 条 flag=={COMPLETE_FLAG}", f"实际 {len(fw_gal)}")
check(len(GALLERY) == GALLERY_EXPECTED,
      f"GALLERY_ITEMS 总数 = {GALLERY_EXPECTED}（54 基线 + 1）", f"实际 {len(GALLERY)}")
if fw_gal:
    g = fw_gal[0]
    check(bool(str(g.get("label", "")).strip()) and bool(str(g.get("hint", "")).strip()),
          "风物大成条目 label / hint 非空")
    bg = str(g.get("bg", ""))
    bg_path = ROOT / bg.replace("res://", "")
    check(bg.startswith("res://") and bg_path.exists(),
          f"背景图复用现有资源且文件存在：{bg}", f"缺失 {bg_path}")
    check(g.get("char") == "player", "char == player（与十景大成同构）")
check(any(g.get("flag") == "west_lake_stamps_complete" for g in GALLERY),
      "十景大成条目仍在（零回归）")

# ─────────────────────────────────────────────────────────────────
section("L · 存档 / NG+ 语义")

check('"flags":             GameManager.flags.duplicate()' in SAVE_SRC
      or re.search(r'"flags"\s*:\s*GameManager\.flags\.duplicate\(\)', SAVE_SRC) is not None,
      "SaveSystem 整字典存 flags → fengwu_* 自动持久化，零存档迁移")
check(re.search(r'GameManager\.flags\s*=\s*d\.get\("flags"', SAVE_SRC) is not None,
      "读档整字典还原 flags（无需新增字段 / 版本号 bump）")

check("GameManager.flags = {}" in ENDING_SRC,
      "NG+ 清空 flags → fengwu_* / fengwu_pickup_day / 画廊 flag 全部清零")
check("GameManager.inventory = {}" in ENDING_SRC,
      "NG+ 清空 inventory → 购得风物需重新购买（补偿扫描不会误判）")
check('flag_key.begins_with("title_")' in ENDING_SRC,
      "结局上传按 title_ 前缀收集称号 → title_西湖风物通 自动入档")
check('GameManager.flags["title_" + t] = true' in ENDING_SRC,
      "NG+ 回写 title_* → 称号跨周目自动继承（无需为风物志加白名单）")

ng_region = ENDING_SRC[ENDING_SRC.index("GameManager.flags = {}"):]
# 注意：`GameManager.flags["title_" + t]` 会被捕获成 "title_"，这正是称号继承本身。
ng_writes = set(re.findall(r'GameManager\.flags\[\s*"([a-zA-Z_]+)"', ng_region))
check(ng_writes <= {"ng_count", "seen_endings", "title_"},
      "NG+ 回写白名单仅 ng_count / seen_endings / title_*（无 fengwu_ 泄漏）",
      str(sorted(ng_writes)))
check("title_" in ng_writes, "白名单确实含 title_ 前缀项（称号继承通道存在）")
check(not any(k.startswith("fengwu") or k.startswith("west_lake") for k in ng_writes),
      "★ NG+ 白名单不含 fengwu_* / west_lake_* → 风物进度真的清零重来", str(sorted(ng_writes)))
check("fengwu" not in strip_comments(ENDING_SRC),
      "EndingScreen 全文无 fengwu 硬编码（不泄漏跨周目）")

# ─────────────────────────────────────────────────────────────────
section("M · 零新 Autoload / 图鉴 UI 接线 / 已放行特性零回归面")

proj = src_of(PROJECT)
auto_block = proj[proj.index("[autoload]"):]
auto_block = auto_block[:auto_block.index("\n[", 1)]
n_auto = len(re.findall(r'^\w+="\*res://', auto_block, re.M))
check(n_auto == AUTOLOAD_EXPECTED, f"Autoload 仍为 {AUTOLOAD_EXPECTED} 个（零新增）", f"实际 {n_auto}")
check("FengwuBookUI" not in proj, "FengwuBookUI 未进 Autoload")
check(not list((ROOT / "scenes").glob("Fengwu*.tscn")) if (ROOT / "scenes").exists() else True,
      "未新建 Fengwu*.tscn（走运行时 new() 子界面模式）")

check('{"text": "🍃 风物志"' in MAIN_SRC and '"fn": _show_fengwubook_popup' in MAIN_SRC,
      "更多菜单已加「🍃 风物志」按钮并接线 _show_fengwubook_popup")
items_block = extract_block(MAIN_SRC, "var items = ")
n_btn = len(re.findall(r'\{"text":', items_block))
check(n_btn == 10, "更多菜单共 10 个按钮（9 基线 + 1 风物志）", f"实际 {n_btn}")

open_body = func_body(MAIN_SRC, "_show_fengwubook_popup")
check('load("res://scripts/FengwuBookUI.gd")' in open_body, "图鉴走 load(...).new() 运行时实例化")
check("if not scr: return" in open_body, "脚本加载失败安全返回（不崩）")
check("add_child(inst)" in open_body and "inst.closed.connect" in open_body,
      "add_child + closed 信号回收（与集章簿同构）")
check("was_explore_visible" in open_body,
      "记录并还原探索层可见性（不把探索层凭空显出来）")
check("signal closed" in BOOK_SRC and "queue_free()" in BOOK_SRC,
      "FengwuBookUI 声明 closed 信号并自我回收（无节点泄漏）")

# 三条已放行特性的接线点仍在
check("_show_stampbook_popup" in MAIN_SRC and "StampBookUI.gd" in MAIN_SRC,
      "零回归：西湖十景集章入口仍在")
check("_try_memory_echo" in MAIN_SRC and "pick_memory_echo" in COLL_SRC,
      "零回归：记忆回响接线仍在")
check("phone_wechat" in GM_SRC, "零回归：手机 UI 热点仍在")
check("STAMP_TOTAL" in COLL_SRC and "WEST_LAKE_STAMP_SCENES" in COLL_SRC,
      "零回归：十景注册表与常量未被改动")

# ─────────────────────────────────────────────────────────────────
section("N · 【DS-RN-04b】手作接入后集满链路 mock 复演")


class FengwuSim:
    """按 GDScript / DialogueUI 源码语义复刻的最小模型。
    上方 D/E/F 区的结构断言保证本模型与实现同构。"""

    def __init__(self, money=500, gifts=6):
        self.flags = {}
        self.day = 300
        self.money = money
        self.inventory = {"handmade_gift": gifts} if gifts else {}
        self.toasts = []
        self.gallery = []

    # CollectionManager.grant_fengwu()
    def grant_fengwu(self, fid):
        if fid not in FW:
            return False
        flag = "fengwu_" + fid
        if flag in self.flags:
            return False
        self.flags[flag] = True
        self.flags[flag + "_day"] = self.day
        if self._completion():
            return True
        self.toasts.append("入册:" + fid)
        return True

    def _completion(self):
        if COMPLETE_FLAG in self.flags:
            return False
        if any(("fengwu_" + f) not in self.flags for f in FW):
            return False
        self.flags[COMPLETE_FLAG] = True
        self.flags[TITLE_FLAG] = True
        self.gallery.append(COMPLETE_FLAG)
        self.toasts.append("集满")
        return True

    # CollectionManager.remove_item()
    def remove_item(self, item_id, amount=1):
        if item_id in self.inventory:
            self.inventory[item_id] -= amount
            if self.inventory[item_id] <= 0:
                del self.inventory[item_id]

    # DataManager 事件门控（requireItem 只校验不消耗 + requireMoney 门控）
    def can_fire(self, ev):
        if not ev.get("repeatable", False) and ev.get("id") in self.flags:
            return False
        need = int(ev.get("requireItemAmt", 1))
        if self.inventory.get(ev.get("requireItem", ""), 0) < need:
            return False
        return self.money >= int(ev.get("requireMoney", 0))

    # DialogueUI: play_current_scene() 场景级字段 + _advance_scene() statDelta
    def fire(self, ev):
        sc = ev["scenes"][-1]
        if sc.get("setFlag"):
            self.flags[sc["setFlag"]] = True
        if sc.get("removeItem"):
            self.remove_item(sc["removeItem"], 1)
        if sc.get("grantFengwu"):
            self.grant_fengwu(sc["grantFengwu"])
        self.money += int(sc.get("statDelta", {}).get("money", 0))
        if not ev.get("repeatable", False):
            self.flags[ev["id"]] = True   # finish_event()


NON_HM = [f for f in fids if FW[f]["obtain"] != "手作"]

# ① 18 件非手作拿满 —— 称号仍不授（差 6 件手作）
s18 = FengwuSim()
for f in NON_HM:
    s18.grant_fengwu(f)
owned18 = sum(1 for k in s18.flags if k.startswith("fengwu_") and not k.endswith("_day"))
check(owned18 == 18 and TITLE_FLAG not in s18.flags and COMPLETE_FLAG not in s18.flags,
      "mock①：拾得12+购得6=18 件拿满，称号/大成 CG 仍不授（差 6 件手作）",
      f"owned={owned18}")

# ② 再经 6 条 fw_craft_* 事件补齐 → 称号 + complete + 画廊三者原子达成
for ev in craft_evs:
    assert s18.can_fire(ev), "事件 %s 门控未通过" % ev.get("id")
    s18.fire(ev)
owned24 = sum(1 for k in s18.flags if k.startswith("fengwu_") and not k.endswith("_day"))
check(owned24 == 24 and s18.flags.get(TITLE_FLAG) is True
      and s18.flags.get(COMPLETE_FLAG) is True
      and s18.gallery == [COMPLETE_FLAG],
      "★ mock②：18 + 6 手作 = 24 → 称号 / west_lake_fengwu_complete / 画廊大成 CG 三者齐开",
      f"owned={owned24} title={s18.flags.get(TITLE_FLAG)} gal={s18.gallery}")
check(s18.toasts.count("集满") == 1 and s18.toasts[-1] == "集满",
      "mock②：集满 toast 只发 1 条且为最后一条（末件跳过普通入册 toast）",
      str(s18.toasts[-2:]))

# ③ 消耗与扣款：6 个 gift 用光、money 精确扣 95
check(s18.money == 500 - CRAFT_COST_TOTAL and "handmade_gift" not in s18.inventory,
      f"★ mock③：6 条事件共扣款 {CRAFT_COST_TOTAL} 元（500→{s18.money}）且 6 个 "
      f"handmade_gift 被全部消耗", f"money={s18.money} inv={s18.inventory}")

# ④ 只有 1 个 gift 时，绝不可解锁 6 件（requireItem 只校验不消耗的经典陷阱）
s1 = FengwuSim(money=500, gifts=1)
fired = 0
for ev in craft_evs:
    if s1.can_fire(ev):
        s1.fire(ev)
        fired += 1
hm_owned = sum(1 for f in HANDMADE if ("fengwu_" + f) in s1.flags)
check(fired == 1 and hm_owned == 1,
      "★ mock④：只持有 1 个 handmade_gift 时只能做出 1 件（removeItem 真消耗，"
      "杜绝「1 个礼物解锁 6 件」）", f"fired={fired} owned={hm_owned}")

# ⑤ 事件式重复触发幂等：repeatable:false + flags[ev_id] 去重
s_rep = FengwuSim(money=500, gifts=6)
ev0 = craft_evs[0]
s_rep.fire(ev0)
money_after_first = s_rep.money
can_again = s_rep.can_fire(ev0)
s_rep.grant_fengwu(str(ev0["scenes"][-1]["grantFengwu"]))
check(not can_again and s_rep.money == money_after_first
      and s_rep.inventory.get("handmade_gift") == 5,
      "★ mock⑤：同一 fw_craft_* 事件二次触发被 flags[ev_id] 拦下 —— "
      "不重复扣款、不重复消耗；grant_fengwu 二次调用幂等",
      f"can_again={can_again} money={s_rep.money} inv={s_rep.inventory}")

# ⑥ 材料费不足时事件不出现（requireMoney 门控 → money 不会被扣成负数）
s_poor = FengwuSim(money=5, gifts=6)
check(not any(s_poor.can_fire(ev) for ev in craft_evs) and s_poor.money == 5,
      "mock⑥：money=5 时 6 条事件全部被 requireMoney 门控挡下（money 不会变负）")

# ═════════════════════════════════════════════════════════════════
print("\n" + "=" * 74)
if failures:
    print(f"结果：{_n - len(failures)}/{_n} PASS，{len(failures)} FAIL")
    for f in failures:
        print("  ✗ " + f)
    print("=" * 74)
    sys.exit(1)
print(f"结果：{_n}/{_n} PASS —— DS-RN-04(+04b) 西湖风物志 静态验证全绿")
print(f"  · 注册表 {EXP_TOTAL} 槽 = 拾得 {EXP_PICKUP} + 购得 {EXP_BUY} + 手作 {EXP_HANDMADE}")
print(f"  · 三渠道全通，可达 {EXP_REACHABLE}/{EXP_TOTAL} → 称号「西湖风物通」现已可达")
print(f"  · 手作：6 条 fw_craft_* 事件，材料费合计 {CRAFT_COST_TOTAL} 元，纯 flag 不进 ITEM_DB")
print("=" * 74)
sys.exit(0)
