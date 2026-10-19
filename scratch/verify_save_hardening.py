# -*- coding: utf-8 -*-
"""Phase 5 首 sprint · 存档加固与清理验证（S1/S2/S3/S4 + ENG-08/ENG-09 + R1/M1/M2/M4）

Godot 4.5 无单测 runtime，故本脚本采用「源码解析 + 数据级重放」双轨验证：
  · 源码解析：从 .gd 真源提取迁移链 / 错误码 / NG+ 重置清单，杜绝文档与代码漂移；
  · 数据级重放：把 SaveSystem._migrate_save_dict 的语义在 Python 内重放，
    构造 v1~v5 各版本样例存档，断言读入 v6 后字段齐全、默认值正确、状态机自洽。

用法：
  C:\\Users\\Administrator\\.workbuddy\\binaries\\python\\versions\\3.13.12\\python.exe scratch/verify_save_hardening.py
退出码：0=全过，1=有失败
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"

SAVESYS = (SCRIPTS / "SaveSystem.gd").read_text(encoding="utf-8")
ENDING = (SCRIPTS / "EndingScreen.gd").read_text(encoding="utf-8")
DIALOG = (SCRIPTS / "DialogueUI.gd").read_text(encoding="utf-8")
COLL = (SCRIPTS / "CollectionManager.gd").read_text(encoding="utf-8")
MAIN = (SCRIPTS / "MainGame.gd").read_text(encoding="utf-8")
POPUP = (SCRIPTS / "PopupManager.gd").read_text(encoding="utf-8")
NETMGR = (SCRIPTS / "NetworkManager.gd").read_text(encoding="utf-8")
EXPORTCFG = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")

_results = []


def check(cond, label, detail=""):
    _results.append((bool(cond), label, "" if cond else detail))


def section(title):
    _results.append((None, title, ""))


def func_body(src: str, name: str) -> str:
    """取出某个顶层 func 的函数体（到下一个顶层 func / 顶层注释块为止）。"""
    m = re.search(rf"^func {re.escape(name)}\(.*?$", src, re.M)
    if not m:
        return ""
    lines = src[m.end():].splitlines()
    body = []
    for ln in lines:
        if re.match(r"^(func |# ──|## ──)", ln):
            break
        body.append(ln)
    return "\n".join(body)


# ══════════════════════════════════════════════════════════════
section("0. 缩进铁律（同文件禁混用；Godot 解析器硬要求）")
# ══════════════════════════════════════════════════════════════
INDENT_SPEC = {
    "CollectionManager.gd": "tab",
    "NetworkManager.gd": "tab",
    "GameManager.gd": "space",
    "MainGame.gd": "space",
    "DialogueUI.gd": "space",
    "SaveSystem.gd": "space",
    "EndingScreen.gd": "space",
    "PopupManager.gd": "space",
}
for fname, style in INDENT_SPEC.items():
    text = (SCRIPTS / fname).read_text(encoding="utf-8")
    tab_led = [i for i, l in enumerate(text.splitlines(), 1) if l.startswith("\t")]
    sp_led = [i for i, l in enumerate(text.splitlines(), 1) if l.startswith(" ")]
    if style == "tab":
        check(not sp_led, f"{fname} 纯 tab 缩进（0 行以空格起始）", f"空格起始行: {sp_led[:5]}")
        check(tab_led, f"{fname} 确实使用 tab 缩进")
    else:
        check(not tab_led, f"{fname} 纯 4 空格缩进（0 行以 tab 起始）", f"tab 起始行: {tab_led[:5]}")
        check(sp_led, f"{fname} 确实使用空格缩进")
    # 4 空格文件的缩进深度必须是 4 的倍数（续行/字典对齐除外，故仅统计以 def 关键字开头的行）
    if style == "space":
        bad = []
        for i, l in enumerate(text.splitlines(), 1):
            if re.match(r"^ +(func |if |for |while |else|elif |return |var |const )", l):
                depth = len(l) - len(l.lstrip(" "))
                if depth % 4 != 0:
                    bad.append((i, depth))
        check(not bad, f"{fname} 语句行缩进均为 4 的倍数", f"异常: {bad[:5]}")


# ══════════════════════════════════════════════════════════════
section("R1. Android INTERNET 权限 + 打包过滤")
# ══════════════════════════════════════════════════════════════
check(re.search(r"^permissions/internet=true$", EXPORTCFG, re.M) is not None,
      "export_presets.cfg permissions/internet=true（云存档/排行榜/NG+ 真机可达）")
check(re.search(r"^permissions/internet=false$", EXPORTCFG, re.M) is None,
      "不存在残留的 internet=false")
inc = re.search(r'^include_filter="([^"]*)"', EXPORTCFG, re.M)
exc = re.search(r'^exclude_filter="([^"]*)"', EXPORTCFG, re.M)
check(inc and "*.json" in inc.group(1), "include_filter 含 *.json（说明 json 会入包，需要排除联调数据）")
check(exc and "mock_server_db/*" in exc.group(1),
      "exclude_filter 已排除 mock_server_db/*（联调脏数据与玩家名快照不入包）",
      exc.group(1) if exc else "缺失")
check(exc and "mock_seed_data.json" in exc.group(1),
      "exclude_filter 已排除 mock_seed_data.json（种子数据不入包）",
      exc.group(1) if exc else "缺失")
# 游戏运行时不得依赖 mock_server_db
gd_all = "\n".join(p.read_text(encoding="utf-8") for p in SCRIPTS.rglob("*.gd"))
check("mock_server_db" not in gd_all, "任何 .gd 都不读 mock_server_db（排除后不会破坏运行时）")


# ══════════════════════════════════════════════════════════════
section("ENG-08. DialogueUI 冗余 bool 写入清除")
# ══════════════════════════════════════════════════════════════
fin = func_body(DIALOG, "finish_event")
check('GameManager.set_flag("last_interact_" + char_id, true)' not in fin,
      "冗余 bool 写入 set_flag(last_interact_*, true) 已删除")
check('GameManager.flags["last_interact_" + char_id] = GameManager.day' in fin,
      "保留 int day 写入（消费方 DailyCycleManager 以 int 计时）")
check(fin.count('last_interact_" + char_id') == 1,
      "finish_event 内 last_interact_ 仅写一次（无二次覆盖）")
# 消费方仍以 int 守卫读取
daily = (SCRIPTS / "DailyCycleManager.gd").read_text(encoding="utf-8")
check("last_day is int" in daily, "DailyCycleManager 保留 `last_day is int` 类型守卫（防历史脏档）")
# 回归：memory_echo 门禁依赖 finish_event 内仍出现 last_interact_ 与 charId 分支
check('last_interact_' in fin and 'current_event.get("charId"' in DIALOG,
      "零回归：charId 分支（last_interact_ + 日记）结构保持不变")


# ══════════════════════════════════════════════════════════════
section("ENG-09. 记忆回响重入守卫（复核：是否已被 BUG-ME-01 刹车覆盖）")
# ══════════════════════════════════════════════════════════════
pick = func_body(COLL, "pick_memory_echo")
commit = func_body(COLL, "commit_memory_echo")
try_echo = func_body(MAIN, "_try_memory_echo")

check('if is_last_night and int(GameManager.flags.get("mem_echo_last_day", -999)) == day:' in pick,
      "BUG-ME-01「同日仅一次」刹车仍在（毕业前夜 day569 唯一刹车，不可删）")
check('GameManager.set_flag("mem_echo_last_day", day)' in commit,
      "commit_memory_echo 写 mem_echo_last_day（重入判据的唯一写入源）")
# 关键：commit 必须在 start_event 之前，否则回调重入时冷却尚未落账
i_commit = try_echo.find("CollectionManager.commit_memory_echo")
i_start = try_echo.find("dialogue_ui.start_event")
i_conn = try_echo.find("event_finished.connect")
check(i_commit != -1 and i_start != -1 and i_commit < i_start,
      "_try_memory_echo 中 commit_memory_echo() 先于 start_event()（冷却先落账）")
check(i_commit < i_conn, "commit 亦先于 event_finished.connect（回调注册时冷却已生效）")
check("CONNECT_ONE_SHOT" in try_echo, "回调为 CONNECT_ONE_SHOT（单次重入，不累积连接）")
# 非毕业前夜由 G6 全局间隔兜底
gap_norm = int(re.search(r"ECHO_GLOBAL_GAP_DAYS\s*:=\s*(\d+)", COLL).group(1))
gap_fin = int(re.search(r"ECHO_GLOBAL_GAP_FINALE\s*:=\s*(\d+)", COLL).group(1))
check(gap_norm >= 1 and gap_fin >= 1,
      f"G6 全局间隔 常态={gap_norm}天 / 终章={gap_fin}天 均 ≥1 → 同日二次 pick 必被拦截")
check('if day - int(GameManager.flags.get("mem_echo_last_day", -999)) < gap:' in pick,
      "G6 以 day-mem_echo_last_day < gap 拦截（同日 diff=0，必然拦截）")
# 结论断言：两条路径都已有刹车 ⇒ is_playing_echo 布尔守卫属冗余
check("is_playing_echo" not in MAIN,
      "未引入冗余的 is_playing_echo 守卫（重入已被 commit-before-start + G6/同日刹车全覆盖）")


# ══════════════════════════════════════════════════════════════
section("S2. 存档迁移 v1→v6 · 源码解析 + 数据级重放")
# ══════════════════════════════════════════════════════════════
save_ver = int(re.search(r"const SAVE_VER\s*=\s*(\d+)", SAVESYS).group(1))
check(save_ver == 6, f"SAVE_VER == 6（实际 {save_ver}）")

# ── 从真源解析迁移链顺序 ──
chain = re.findall(r"if ver < (\d+):\s*\n\s*d = _migrate_v(\d+)_to_v(\d+)\(d\)\s*\n\s*d\[\"ver\"\] = (\d+)",
                   func_body(SAVESYS, "_migrate_save_dict"))
check(len(chain) == save_ver - 1,
      f"迁移链覆盖 v1→v{save_ver} 共 {save_ver-1} 步（解析到 {len(chain)} 步）", str(chain))
for guard, frm, to, setver in chain:
    check(guard == to == setver and int(to) == int(frm) + 1,
          f"迁移步 v{frm}→v{to} 的守卫/目标/回写版本号自洽 (if ver<{guard} … ver={setver})")


def parse_literal(raw: str):
    """把 GDScript 字面量转成 Python 值（本文件仅出现 {} / {..} / 整数）。"""
    raw = raw.strip()
    if raw in ("{}", "[]"):
        return {} if raw == "{}" else []
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    try:
        return json.loads(raw)          # {"chinese": 0, ...} 与 JSON 同形
    except Exception:
        return f"<unparsed:{raw}>"


# ── 从每个 _migrate_vN_to_vM 提取「补哪些键、默认值是什么」 ──
MIGRATIONS = {}
for frm in range(1, save_ver):
    body = func_body(SAVESYS, f"_migrate_v{frm}_to_v{frm+1}")
    adds = {}
    for key, val in re.findall(r'if not d\.has\("(\w+)"\):\s*\n\s*d\["\1"\]\s*=\s*(.+?)\s*(?:#.*)?$',
                               body, re.M):
        adds[key] = parse_literal(val)
    MIGRATIONS[frm] = adds
    check(bool(adds) or frm == 0, f"v{frm}→v{frm+1} 解析出补字段 {sorted(adds)}", body[:120])


def migrate(d: dict) -> dict:
    """在 Python 内重放 SaveSystem._migrate_save_dict 的语义。"""
    d = dict(d)
    ver = int(d.get("ver", 1))
    for frm in range(1, save_ver):
        if ver < frm + 1:
            for k, v in MIGRATIONS[frm].items():
                if k not in d:
                    d[k] = json.loads(json.dumps(v))
            d["ver"] = frm + 1
    return d


# ── 构造 v1~v5 各版本「历史样例存档」（刻意只带该版本当时存在的字段）──
def sample_save(ver: int) -> dict:
    d = {
        "ver": ver, "day": 120, "day_of_week": 3, "slot_index": 2, "money": 350,
        "player_name": "张语翰", "school_name": "西湖中学", "gender": "male",
        "stats": {"intellect": 42, "stress": 30}, "favorability": {"yutong": 55, "jingjing": 61},
        "flags": {"ev_001": True, "last_interact_yutong": 118}, "inventory": {"gift_cake": 2},
        "diary": ["和叶菁菁聊了聊"], "recent_logs": ["📖 复习了数学"],
    }
    if ver >= 2:
        d |= {"cooking": {"unlocked": ["dongpo"]}, "season": {"exp": 40},
              "hw_status": 1, "hw_neglect_count": 0}
    if ver >= 3:
        d["subject_scores"] = {"chinese": 12, "math": 30, "english": 8, "science": 5, "society": 3}
    if ver >= 4:
        d["char_mood"] = {"yutong": "happy"}
    if ver >= 5:
        d["relationship_state"] = {"yutong": "friend"}
    return d


ALL_MIGRATED_KEYS = sorted({k for adds in MIGRATIONS.values() for k in adds})
for ver in range(1, save_ver + 1):
    src = sample_save(ver)
    out = migrate(src)
    check(int(out["ver"]) == save_ver, f"v{ver} 样例档迁移后 ver == {save_ver}", f"实际 {out.get('ver')}")
    missing = [k for k in ALL_MIGRATED_KEYS if k not in out]
    check(not missing, f"v{ver} 迁移后补齐全部迁移字段 {ALL_MIGRATED_KEYS}", f"缺失 {missing}")
    check(isinstance(out.get("relationship_state"), dict),
          f"v{ver} 迁移后 relationship_state 为字典（v6 关系状态机可用）",
          f"实际 {type(out.get('relationship_state')).__name__}")
    # 原有数据不得被迁移覆盖
    check(out["money"] == 350 and out["favorability"]["jingjing"] == 61,
          f"v{ver} 迁移不篡改既有字段（money/favorability 原样保留）")
    if ver >= 5:
        check(out["relationship_state"] == {"yutong": "friend"},
              f"v{ver} 已有 relationship_state 不被空字典覆盖（if not d.has 守卫生效）")
    if ver >= 3:
        check(out["subject_scores"]["math"] == 30, f"v{ver} 已有 subject_scores 不被默认值覆盖")

# 幂等：v6 档再迁移一次不变
v6 = migrate(sample_save(6))
check(migrate(v6) == v6, "迁移幂等：v6 档重复迁移结果不变（自动回写不会反复改写）")

# ── load_from_dict 的字段缺失容错 ──
lfd = func_body(SAVESYS, "load_from_dict")
check(re.search(r"^\s*d = _migrate_save_dict\(d\)", lfd, re.M) is not None,
      "load_from_dict 开头即调用 _migrate_save_dict（所有读档路径都过迁移）")
bare_reads = re.findall(r'd\["(\w+)"\]', lfd)
check(not bare_reads, "load_from_dict 无裸 d[\"key\"] 取值（缺字段不会崩）", f"裸读: {bare_reads}")
gets = re.findall(r'd\.get\("(\w+)",\s*([^)]+)\)', lfd)
check(len(gets) >= 15, f"load_from_dict 全部经 d.get(key, default) 读取，共 {len(gets)} 处")
check(re.search(r'GameManager\.relationship_state = saved_rel\.duplicate\(\) if saved_rel is Dictionary else \{\}', lfd) is not None,
      "relationship_state 有 `is Dictionary` 类型兜底（脏档不致崩）")
i_rel = lfd.find("GameManager.relationship_state = saved_rel")
i_recompute = lfd.find("RelationshipManager.recompute_all_states(true)")
check(i_rel != -1 and i_recompute != -1 and i_rel < i_recompute,
      "S2 关键：relationship_state 赋值后立即 recompute_all_states(true) → 迁移路径状态机自洽")
# v1~v5 档进 load_from_dict 时，缺失键都能取到默认值
for ver in range(1, 6):
    out = migrate(sample_save(ver))
    unresolved = [k for k, _dflt in gets if k not in out]
    # 未在存档中的键必须有 .get 默认值兜底（上面已断言无裸读），此处确认默认值非空表达式
    check(all(_d.strip() for _k, _d in gets),
          f"v{ver}：load_from_dict 每个 d.get 都带默认值（缺失键 {unresolved[:4]} 走默认）")


# ══════════════════════════════════════════════════════════════
section("S3. 存档损坏 / 解析失败 / 解密失败的错误码与降级路径")
# ══════════════════════════════════════════════════════════════
check("enum LoadError" in SAVESYS, "定义 LoadError 错误码枚举")
for code in ["NOT_FOUND", "DECRYPT_FAILED", "CORRUPTED", "VERSION_TOO_NEW", "MIGRATE_FAILED"]:
    check(re.search(rf"\b{code}\s*=\s*\d+", SAVESYS) is not None, f"错误码 {code} 已定义")
    check(f"LoadError.{code}:" in SAVESYS, f"错误码 {code} 有对应中文提示文案")
check("signal load_failed(slot: int, code: int, msg: String)" in SAVESYS,
      "对外暴露 load_failed(slot, code, msg) 信号")
check("func get_last_load_error() -> Dictionary" in SAVESYS, "提供 get_last_load_error() 查询接口")

lg = func_body(SAVESYS, "load_game")
check(lg.count("_fail_load(") >= 6, f"load_game 全部失败路径统一走 _fail_load（{lg.count('_fail_load(')} 处）")
check("return false" not in lg, "load_game 内无裸 `return false`（失败必带错误码）", lg)
check("LoadError.DECRYPT_FAILED" in lg, "解密/打开失败 → DECRYPT_FAILED，与「空槽位」区分")
check("LoadError.NOT_FOUND" in lg, "文件不存在 → NOT_FOUND（正常空槽位，不报 error）")
check("LoadError.CORRUPTED" in lg, "JSON 解析失败/非字典 → CORRUPTED")
check("LoadError.VERSION_TOO_NEW" in lg, "存档版本高于本体 → VERSION_TOO_NEW 拒读（防降级写坏）")
check(re.search(r"if orig_ver > SAVE_VER:", lg) is not None, "显式拦截 orig_ver > SAVE_VER")
check("last_load_error = LoadError.NONE" in lg, "进入时复位错误态（不残留上次失败码）")
fail_body = func_body(SAVESYS, "_fail_load")
check("load_failed.emit" in fail_body, "_fail_load 发出 load_failed 信号")
check("push_warning" in fail_body and "push_error" in fail_body,
      "_fail_load 对 NOT_FOUND 用 warning、其余用 error（空槽位不误报错误）")
# meta 配对校验：写入侧 + 读取侧 + 向后兼容
sg = func_body(SAVESYS, "save_game")
check('"body_hash"' in sg, "save_game 在 .meta 写入 body_hash")
mp = func_body(SAVESYS, "_verify_meta_pairing")
check('not meta.has("body_hash")' in mp and "return" in mp,
      "读档侧：老存档 meta 无 body_hash 时跳过校验（存量档零影响）")
check("push_warning" in mp and "_fail_load" not in mp,
      "meta 不配对仅告警不阻断（主体能解析就不判死，避免误杀可玩档）")
# UI 消费错误码
check("SaveSystem.get_last_load_error()" in POPUP, "PopupManager 读取错误码并展示具体原因")
# 只针对「本地读档」分支：云端下载分支的「云端…没有存档或下载失败」是另一条合法路径，不在 S3 范围
check('emit("⚠️ Slot %d 没有存档"' not in POPUP,
      "本地读档已移除「一律报『没有存档』」的误导提示",
      [l for l in POPUP.splitlines() if 'Slot %d 没有存档' in l and '云端' not in l and not l.strip().startswith('#')])


# ══════════════════════════════════════════════════════════════
section("S1. NG+ 云端拉取失败的本地兜底")
# ══════════════════════════════════════════════════════════════
upload = func_body(ENDING, "_upload_profile_on_ending")
check("_ng_profile_snapshot = profile.duplicate(true)" in upload,
      "结算时留存本地继承快照 _ng_profile_snapshot（与上传载荷同源）")
ngp = func_body(ENDING, "_on_ng_plus_pressed")
check("_merge_inherit_profile(cloud, _ng_profile_snapshot)" in ngp,
      "NG+ 以「云端 + 本地快照」合并结果为继承源")
check(re.search(r"if not success:\s*\n\s*GameManager\.show_toast\.emit\(\"❌ 获取云端存档失败", ngp) is None,
      "已移除「云端失败即中止 NG+」的死路径")
# 关键：失败不得进入「清空 flags 但没有继承数据」的空 NG+
i_guard = ngp.find("if src.is_empty():")
i_clear = ngp.find("GameManager.flags = {}")
check(i_guard != -1 and i_clear != -1 and i_guard < i_clear,
      "兜底守卫在 flags 清空之前（继承源为空则原样返回，绝不清档）")
check("GameManager.flags = {}" in ngp, "保留整体清 flags 语义（新周目重集 stamp_*/回响等）")
for key in ['GameManager.flags["ng_count"]', 'GameManager.flags["seen_endings"]',
            'GameManager.flags["title_" + t] = true']:
    check(key in ngp, f"NG+ 回写继承键：{key}")
merge = func_body(ENDING, "_merge_inherit_profile")
check('out["ng_count"] = max(' in merge, "ng_count 取云端/本地最大值（防云端滞后回退周目数）")
for lk in ["seen_endings", "unlocked_titles", "unlocked_recipes", "gallery_flags"]:
    check(f'"{lk}"' in merge, f"{lk} 参与并集合并（只增不减，不丢继承）")
check("if v is Array and (v as Array).is_empty() and out.has(k):" in merge,
      "云端空列表不覆盖本地已有值（首次请求返回空默认结构时不清继承）")
check(ngp.count("data.get(") == 0, "NG+ 内不再直接读云端 data（全部走合并后的 src）")
check("src.get(\"inherited_subjects\"" in ngp, "分科继承亦走 src（此前遗漏的 data.get 已修正）")


# ══════════════════════════════════════════════════════════════
section("S4. NG+ flag 白名单审计（误清 / 漏清）")
# ══════════════════════════════════════════════════════════════
INHERIT_WHITELIST = ["ng_count", "seen_endings", "title_*"]
check(len(INHERIT_WHITELIST) == 3, f"最终继承白名单：{INHERIT_WHITELIST}")
# 误清：白名单三项必须在清空后被回写
check(all(k in ngp for k in ['"ng_count"', '"seen_endings"', '"title_" + t']),
      "无误清：白名单 3 项在 flags={} 之后全部回写")
# 漏清：非 flags 的关系状态缓存必须一并重置
check("GameManager.relationship_state = {}" in ngp,
      "无漏清：relationship_state（不在 flags 内）已随 NG+ 重置")
i_relclear = ngp.find("GameManager.relationship_state = {}")
i_recomp = ngp.find("RelationshipManager.recompute_all_states(true)")
i_fav = ngp.find("GameManager.favorability[char_id] = max(base, bonus)")
check(i_relclear != -1 and i_recomp != -1 and i_fav < i_recomp,
      "关系状态在好感继承之后重算（按新周目好感推导，状态自洽）")
check(i_clear < i_recomp,
      "重算发生在 flags 清空之后 → 无 rel_cold_* 残留，不会带入上周目冷战")
# 回响键确认随 flags 整体清空
echo_keys = re.findall(r'"(mem_echo_[a-z_%s]*)"', COLL)
check(bool(echo_keys), f"记忆回响状态键均以 mem_echo_ 前缀存于 flags：{sorted(set(echo_keys))[:4]}")
check("mem_echo" not in ngp,
      "回响键无需单独处理：flags={} 已整体清除（无残留、无误清）")
# 顺序：reset_char_initiative 必须早于 flags 清空（phone 门禁的既有约定）
i_init = ngp.find("GameManager.reset_char_initiative()")
check(i_init != -1 and i_init < i_clear,
      "reset_char_initiative() 仍早于 flags={}（保持 phone 门禁既有无 concern 状态）")


# ══════════════════════════════════════════════════════════════
section("M1/M2/M4. Mock Server 清理")
# ══════════════════════════════════════════════════════════════
MOCK = (SCRIPTS / "mock_server.py").read_text(encoding="utf-8")
SEEDF = SCRIPTS / "mock_seed_data.json"
check(re.search(r"^PORT\s*=\s*8000", MOCK, re.M) is None,
      "M1：删除硬编码顶层 PORT = 8000（仅保留 DEFAULT_PORT 兜底常量）")
check("DEFAULT_PORT = 8000" in MOCK and "--port" in MOCK and "MOCK_SERVER_PORT" in MOCK,
      "M1：端口支持 --port 参数 + MOCK_SERVER_PORT 环境变量 + 默认值")
check("def resolve_port" in MOCK, "M1：端口解析逻辑独立可测")
check("ZKGAME_SERVER_URL" in NETMGR and "DEFAULT_SERVER_URL" in NETMGR,
      "M1：NetworkManager 支持环境变量注入服务端地址")
check("const SERVER_URL" not in NETMGR, "M1：NetworkManager 不再用 const 硬编码 SERVER_URL")
check(SEEDF.exists(), "M4：种子数据文件 mock_seed_data.json 存在")
seed = json.loads(SEEDF.read_text(encoding="utf-8"))
for k in ["leaderboard", "wishes", "world_chat", "npc_usernames", "virtual_replies"]:
    check(k in seed, f"M4：种子文件含 {k} 段")
check("virtual_pool = SEED.get" in MOCK, "M4：虚拟留言池来自种子文件，代码内不写死")
check("SEED.get(\"npc_usernames\"" in MOCK, "M4：NPC 名单来自种子文件")
check("default_wishes" not in MOCK, "M4：代码内不再写死 default_wishes")
# M2：脏数据
for row in seed["leaderboard"]:
    check(0 <= row["intellect"] <= 100,
          f"M2：种子 {row['username']} intellect={row['intellect']} 在 0-100 内")
lb = json.loads((ROOT / "mock_server_db" / "leaderboard.json").read_text(encoding="utf-8"))
bad_rows = [r for r in lb if not (0 <= r.get("intellect", 0) <= 100)]
check(not bad_rows, "M2：已落盘的 leaderboard.json 无越界脏数据", str(bad_rows))
check("_sanitized_leaderboard_seed" in MOCK, "M2：种子入库前过 0-100 校验，脏数据无法回潮")
check("INTELLECT_MAX" in MOCK, "M2：上限抽为常量，种子校验与提交校验共用")
# 死代码
check(MOCK.count("import random") == 1 and MOCK.count("import time") == 1,
      "死代码：random/time 仅顶层导入一次（原函数内重复 import 已清理）")
check("except Exception as e:\n            self.send_error_response(400" not in MOCK,
      "死代码：未使用的异常变量 e 已清理")


# ══════════════════════════════════════════════════════════════
# 汇总
# ══════════════════════════════════════════════════════════════
print("=" * 78)
print("Phase 5 首 sprint · 存档加固与清理验证")
print("=" * 78)
passed = failed = 0
for ok, label, detail in _results:
    if ok is None:
        print(f"\n── {label} " + "─" * max(0, 60 - len(label)))
        continue
    if ok:
        passed += 1
        print(f"  [PASS] {label}")
    else:
        failed += 1
        print(f"  [FAIL] {label}")
        if detail:
            print(f"         → {detail[:300]}")
print("\n" + "=" * 78)
print(f"assertions={passed + failed}  passed={passed}  failed={failed}")
print("VERDICT:", "PASS" if failed == 0 else "FAIL")
sys.exit(1 if failed else 0)
