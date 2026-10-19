# QA-RN-02 — 记忆回响 · 情境回响（DS-RN-02）质量门报告

| 项 | 内容 |
|---|---|
| 特性 | 记忆回响 · 情境回响（Contextual Memory Echo） |
| 设计文档 | `design/memory_echo_gdd.md`（§7-③ T-1 ~ T-16） |
| 实现范围 | `scripts/CollectionManager.gd` / `scripts/DialogueUI.gd` / `scripts/MainGame.gd`（3 文件，0 新建） |
| 测试套件 | `tests/memory_echo_smoke/verify_qa.py`（纯静态断言 + 守卫模型推演，零 Godot runtime，对游戏代码只读） |
| 执行器 | `C:/Users/Administrator/.workbuddy/binaries/python/versions/3.13.12/python.exe` |
| 断言总数 | **286** |
| 通过 | **286** |
| 失败 | **0**（BUG-ME-01 已修复并复测） |
| Concerns | 0 |
| 非阻塞关注项（notes） | 9（advisory，不阻塞放行） |
| **质量门判定** | **🟢 PASS**（复判，原判定 🔴 FAIL） |
| 判定人 | 严守真（quality-lead） |
| 复判时间 | BUG-ME-01 修复后第 2 轮门禁 |

---

## 0. 一句话结论

**质量门通过（286/286）。** T-1 ~ T-16 的静态契约全过：数据双源交叉零漂移、只读边界零越界、
`noTimeCost` 零回归面完美、调用点唯一性可证、缩进风格一致。

**原阻塞项 BUG-ME-01（毕业前夜 day 569 回响无限连播）已解决（RESOLVED）** —— engineering 侧已按 §3.5
推荐方案在 `CollectionManager.gd` `pick_memory_echo()` 落地「同日仅一次」刹车（L508-511），QA 侧已将同一
语义同步进门禁的 Python 模拟镜像，Q 组密度断言与 S 组重入安全断言（A255-A257 / A264 / A273-A275）全部复测通过。

**因此 QA 侧转 PASS**，剩余 9 条 non-blocking advisory 作为上线前关注项保留（§4），
最终发布签字由用户拍板。

---

## 1. 独立核查范围（不依赖 scratch 脚本的结论）

本次质量门由 QA 侧**直接通读三处改动源码**后独立判断。`verify_qa.py` 自带 GDScript 字面量解析器 /
独立断言编号（A01-A286）/ 独立分组，**不复用 `scratch/verify_memory_echo.py` 任何代码或结论**。

| 文件 | 核对点 | 独立结论 |
|---|---|---|
| `CollectionManager.gd` L339-618 | `MEMORY_ECHO_CONTEXTS` 10 条 / 9 守卫 / vignette 硬约束 / `commit` 4 键 / 2 个派生查询 | ✅ 结构与 GDD 逐项一致；`pick_memory_echo` 的 569 分支缺陷（BUG-ME-01）已修复并复测通过（§3） |
| `DialogueUI.gd` L571-575 | `elif not current_event.get("noTimeCost", false):` 短路 `advance_time()` | ✅ 形式正确；全仓仅 1 处读、1 处写、**0 个 JSON 携带该键** → 零回归面成立 |
| `MainGame.gd` L216-240 | step 0 钩子 + `_try_memory_echo` + `CONNECT_ONE_SHOT` 重入 | ✅ 与 §4.1 契约逐行一致；`commit` 确在 `start_event` 之前 |
| `GameManager.gd` | `set_flag(Variant)` 支持 int；`GALLERY_ITEMS` L345-354 十条 `holiday_memory_*` | ✅ 前置齐备，`sid` 集合双向相等 |
| `project.godot` | `[autoload]` 段 | ✅ 恰 **15** 条，零新增 |
| `assets/backgrounds/` | 4 张 holiday CG | ✅ 全部落盘，零新资产 |

---

## 2. 断言分组结果

| 组 | 主题 | 覆盖 GDD 条目 | 断言 | 结果 |
|---|---|---|---:|---|
| A | 调参常量存在性与取值 | §5.1 | 11 | ✅ 11/11 |
| B | 防刷屏算术 | T-11 / S-3 | 7 | ✅ 7/7 |
| C | `MEMORY_ECHO_CONTEXTS` 结构与字段纪律 | T-1 / T-2 / T-5 / S-6 | 13 | ✅ 13/13 |
| D | 双源交叉 · `events_break.json` **逐字真源** | **T-3** | 40 | ✅ 40/40 |
| E | 双源交叉 · `GALLERY_ITEMS` 记忆池 | T-4 / S-2 | 9 | ✅ 9/9 |
| F | 五函数存在性与契约 | §4-C / §5.5 | 14 | ✅ 14/14 |
| G | `pick_memory_echo` 九守卫 G0~G9 + 零副作用 | §2.3 / §2.4 | 28 | ✅ 28/28 |
| H | 毕业前夜特例 · **源码结构** | §2.5 | 11 | ✅ 11/11 |
| I | vignette 硬约束 | T-6 / T-7 / §5.4 | 26 | ✅ 26/26 |
| J | `noTimeCost` 短路 + 零回归面 | T-8 / T-9 / S-4 | 16 | ✅ 16/16 |
| K | MainGame 触发钩子与调用点唯一性 | T-10 / S-5 / §4.1 | 24 | ✅ 24/24 |
| L | `mem_echo_*` 命名 + 单一写入源 | T-14 / §5.3 | 18 | ✅ 18/18 |
| M | 零新 Autoload / 零新脚本 / 零新资产 | T-13 / S-1 / S-2 | 7 | ✅ 7/7 |
| N | NG+ 自动清零 | T-15 / S-7 | 5 | ✅ 5/5 |
| O | 只读边界（画廊 / 集章 / 深夜聊天 / 零机制产出） | T-16 / S-8 / §3.5 | 16 | ✅ 16/16 |
| P | 成熟期可达性 | T-12 | 9 | ✅ 9/9 |
| Q | 守卫模型推演 · 密度上限与保底 | S-3 / §2.5 / §2.6 | 13 | 🔴 **9/13** |
| S | **重入安全** · 一次性 lambda 防递归契约 | §3.4 / §4.1 / §7-② | 9 | 🔴 **5/9** |
| R | 缩进风格一致性 | 扩展 | 10 | ✅ 10/10 |
| | **合计** | | **286** | **278 / 8** |

### GDD §7-③ T-1 ~ T-16 覆盖对照

| T | 断言组 | 状态 |
|---|---|---|
| T-1 恰 10 键、键集合正确 | C（A19-A21） | ✅ |
| T-2 `lines` 长 3 非空、`finale_line` 非空 | C（A25-A29） | ✅ |
| T-3 `loc`/`slot` 与 chapter **逐字一致** | D（A32-A61，含产生端 setFlag 核实） | ✅ |
| T-4 `holiday_memory_+sid` ∈ `GALLERY_ITEMS` | E（A62-A70，双向相等） | ✅ |
| T-5 不出现 `char`/`bg`/`label`/`born` | C（A24） | ✅ |
| T-6 scene 无 pose/setFlag/choices…、仅末句 next:99 | I（A139-A151） | ✅ |
| T-7 `location:""`+`repeatable:true`+`noTimeCost:true`+无 `charId` | I（A134-A138） | ✅ |
| T-8 `noTimeCost` 唯一 1 处且 else 语义未受影响 | J（A161-A171） | ✅ |
| T-9 全仓无既有事件携带该键 | J（A173-A175） | ✅ |
| T-10 `build`/`pick` 调用点各 1 处且在 MainGame | K（A195-A197） | ✅ |
| T-11 常量算术 | B（A12-A18） | ✅ |
| T-12 成熟期可达性 | P（A247-A250） | ✅ |
| T-13 零新 Autoload / 零新脚本 / 零新资产 | M（A218-A224）+ E（A70） | ✅ |
| T-14 `mem_echo_` 单一写入源 | L（A200-A213） | ✅ |
| T-15 不在 NG+ 继承白名单 | N（A225-A229） | ✅ |
| T-16 不 `unlock_gallery` / 不写 `stamp_*` / 不 toast | O（A230-A245） | ✅ |
| **扩展** Q/S 组：密度与重入安全 | Q + S | ✅ **BUG-ME-01 已修复并复测通过** |

---

## 3. ✅ 阻塞项 BUG-ME-01 —— 毕业前夜 day 569 回响无限连播 · **已解决（RESOLVED）**

| 字段 | 内容 |
|---|---|
| **ID** | BUG-ME-01 |
| **严重度** | **Blocker** |
| **状态** | ✅ **已解决（RESOLVED）** —— 修复已落盘并经门禁复测（见 §3.7） |
| **位置** | `scripts/CollectionManager.gd` `pick_memory_echo()` L507-515（`is_last_night` 分支） |
| **原失败断言** | A255 / A256 / A257 / A264（Q 组）、A273 / A274 / A275 / A276（S 组） → **现全部 PASS** |
| **可复现** | 是（修复前 100%，无需随机） |

> 以下 §3.1 - §3.6 保留缺陷发现时的原始诊断记录，作为审计轨迹；**当前状态以 §3.7 复判为准**。

### 3.1 复现步骤

| # | 步骤 |
|---|---|
| 环境 | Godot 4.5 mobile，1280×720 横屏；任意存档 |
| 前置 | ① 至少解锁 1 条 `holiday_memory_*`（如 `winter_yutong`）<br>② 该记忆已过成熟期（day ≥ born+30）<br>③ 对应角色非 `cold` 状态<br>④ 推进至 **day 569（毕业前夜）** |
| 1 | 主界面地点列表此时只显示一张卡：**西湖边**（`LocationManager.get_forced_location_for_day()` 强制），并带提示「🌙 今晚，只有一个地方值得去……」 |
| 2 | 点击「西湖边」 |
| **预期** | 播放 **1 次**回响 flashback（含 `finale_line` 第 4 句）→ 正常进入 lakeside 探索层，玩家可完成毕业前夜内容 |
| **实际** | 播放第 1 次回响 → 播完立刻播第 2 次 → 第 3 次 → **无限循环**，永远无法进入探索层 |

### 3.2 根因分析

GDD §3.4 / §4.1 的防递归论证原文：

> 「回响在进入地点**之前**播放，播完后由 `MainGame` 重新走一遍 `_on_location_selected(loc_id)`
> （此时冷却已写，`pick_memory_echo` 必然返回 `{}`，**天然防递归**），玩家正常进入该地点。」

该论证**完全依赖 G5/G6/G7/G8 四道冷却/配额守卫**作为刹车。而 GDD §2.5 为了保证毕业前夜必然有一次回响，
明确要求「**忽略 G5 / G6 / G7 / G8（全部冷却与上限）**」。工程侧忠实实现了这一点：

```gdscript
# CollectionManager.gd L507-515
var is_last_night: bool = day == ECHO_LAST_NIGHT_DAY
var is_finale: bool = day >= ECHO_FINALE_DAY
if not is_last_night:          # ← 569 当天整段跳过 G6 / G8
    ...
# 循环内 L537-541
if not is_last_night:          # ← 569 当天整段跳过 G5 / G7
    ...
```

**两条设计意图在 569 这一天正面相撞：唯一的递归刹车被特例本身拆掉了。**
`MainGame._try_memory_echo()` 的 `CONNECT_ONE_SHOT` lambda 每次播完都会重入 `_on_location_selected(loc_id)`，
而 569 当天 `pick_memory_echo()` **必然继续返回非空**（G1/G4/G9 依然通过），于是形成闭环。

注意即使记忆池只有 **1 条**也会无限循环 —— 因为 G7（单条上限 2）同样被放宽，同一条记忆可被无限次重选。

### 3.3 实测证据（`verify_qa.py` S 组 · 重入链路推演）

```
day130 / day342 / day540 / day545 / day568 ：单次点击 → 播放 1 次 → pick 返回 {} → 正常进入   ✅
day569（池 = 1 条）                        ：单次点击 → 连播 40 次仍未终止（推演上限）          🔴
day569（池 = 10 条）                       ：单次点击 → 连播 40 次仍未终止（count 升序轮转后继续循环） 🔴
day569 推演至 200 层                       ：仍未终止 → 判定为无限循环                          🔴
```

**关键旁证**：非 569 的所有日子（含终章 540/545/568）重入链路均正确终止于第 1 次 —— 说明
§3.4 的防递归设计本身是**正确且有效**的，缺陷精确地、且仅仅地存在于 569 特例分支。

### 3.4 影响面

| 维度 | 影响 |
|---|---|
| **内容可达性** | 🔴 day 569 lakeside 探索层**不可达**。毕业前夜是 `DailyCycleManager` L29 定义的特殊日（「🌙 毕业前夜 / 最后一个夜晚，去西湖边吧。」），该日全部 lakeside 内容被吞 |
| **是否硬 softlock** | 否 —— 玩家仍可用地点列表上方的「🛌 休息/跳过」快捷按钮推进时段至 day 570 结局。但代价是**完全跳过毕业前夜内容** |
| **存档污染** | 🔴 每次循环都执行 `commit_memory_echo()`：`mem_echo_<sid>_count` / `mem_echo_total` **无界增长**；`add_diary_entry("忽然想起X")` 向日记本**无界写入重复条目**；`add_log` 同理。日记是 GDD §3.5 声称的「本特性最好的长尾」，此处反被破坏 |
| **违反的 GDD 成功标准** | **S-3**（单周目 ≤ 11 次 / 任意两次间隔 ≥ 5 天）—— 实测满池最坏 14 次且间隔为 0；**§2.5** 原文「必然……得到**一次**回响」的「一次」语义 |
| **玩家可感知度** | 极高：发生在游戏情感峰值、必经的倒数第二天，且是**唯一可去地点** |

### 3.5 修复建议（推荐方案，2 行）

在 `pick_memory_echo()` 中为 569 补一道**同日去重**守卫 —— 它是 G6 被放宽后的等价替代刹车，
语义正好对齐 §2.5 的「必然得到**一次**回响」：

```gdscript
# scripts/CollectionManager.gd —— 在 L508 之后、L509 `if not is_last_night:` 之前插入
	# 569 当日一次性守卫：§2.5 放宽 G5-G8 后，§4.1 一次性 lambda 重入失去唯一刹车。
	# 语义 =「毕业前夜必然得到一次回响」，而非无限次。
	if is_last_night and int(GameManager.flags.get("mem_echo_last_day", -999)) == day:
		return {}
```

（注意：`CollectionManager.gd` 为**纯 tab 缩进**，插入时请使用 tab。）

**为什么这个修法是安全的**：

| 场景 | 行为 |
|---|---|
| day 569 首次进 lakeside | `mem_echo_last_day != 569` → 守卫放行 → 回响照常播放（**§2.5 保底语义完全保留**，含 `finale_line`） |
| 回响播完 lambda 重入 | `commit` 已写 `mem_echo_last_day = 569` → 守卫命中 → `return {}` → **正常进入探索层** |
| day 569 玩家再次点进 lakeside | 守卫命中 → 不再播放（符合「这一夜一次」） |
| **所有非 569 日** | `is_last_night == false` → 守卫短路失效 → **零行为变化、零回归** |

**备选方案**（若设计侧希望"每时段一次"而非"整日一次"）：改用独立键
`mem_echo_last_night_slot`，记录 `day*10 + slot_index` 比对。QA 侧**推荐前者** —— 更贴合 §2.5 措辞，
且不引入第 5 类 flag（保持 §5.3 的 22 键上界）。

### 3.6 修复后验证

```bash
C:/Users/Administrator/.workbuddy/binaries/python/versions/3.13.12/python.exe tests/memory_echo_smoke/verify_qa.py
```

期望：`assertions=286  passed=286  failed=0` → `VERDICT: PASS`。
重点复看 A255-A257、A264（Q 组密度）与 A273-A276（S 组重入安全）。

### 3.7 ✅ 复判结果（RESOLVED）

**源码修复已落盘。** `scripts/CollectionManager.gd` `pick_memory_echo()` L508-511 现含 §3.5 推荐的同日刹车：

```gdscript
var is_last_night: bool = day == ECHO_LAST_NIGHT_DAY
# BUG-ME-01 修复：毕业前夜放宽 G5/G6/G7/G8 后，唯一刹车仅剩"同日仅一次"。
if is_last_night and int(GameManager.flags.get("mem_echo_last_day", -999)) == day:
	return {}
```

**门禁模拟镜像已同步。** 本套件 Q/S 组的两个 Python 回放函数是源码逻辑的镜像重实现，修复初期它们仍按
旧逻辑推演，导致源码已正确但门禁仍报 FAIL（**镜像滞后**，非源码缺陷）。QA 侧已将同一刹车同步进：

| 函数 | 位置 | 镜像语义 |
|---|---|---|
| `simulate()` | `verify_qa.py` L831-836（`for loc in visit_locs:` 循环体首行） | day569 当天任一 loc 已 fire 后，其余 loc 全部跳过 → **全天恰 1 次** |
| `reentry_depth()` | `verify_qa.py` L937-939（`while` 循环体，`is_finale` 之后） | 单次点击 fire 一次并写入 `last_day` 后立即 `break` → **单次点击仅 1 次回响** |

> ⚠️ **镜像插入位置要点（供后续维护者）**：`simulate()` 的守卫必须放在 **`for loc` 循环体内**，
> 而非 day 循环顶部。源码守卫在每次 `_on_location_selected` 调用时求值（即每次点击 / 每个 loc 一次）；
> 若放在 day 循环顶部，当日尚未 fire 时 `flags["last_day"]` 恒 `< day`，守卫永不命中 → 死代码，
> A255/A256/A257 仍会失败。`reentry_depth()` 因其 `while` 循环本身即「同一次点击的重入链」，
> 放在循环体首部即可正确终止。

**复测结果**：

```
assertions=286  passed=286  failed=0  concerns=0  notes=9
VERDICT: PASS
```

| 断言 | 修复前 | 修复后 |
|---|---|---|
| A255 满池最恶意刷屏总次数 | 🔴 14 次 > 11 | ✅ **11 次 ≤ 11** |
| A256 S-3 单周目上限（GDD §2.6） | 🔴 14 次 | ✅ **11 次 ≤ 11** |
| A257 §2.5「day569 全天恰 1 次」 | 🔴 实际 4 次 | ✅ **恰 1 次** |
| A264 任意两次回响间隔 ≥ 5 天 | 🔴 最小间隔 0 | ✅ **≥ 5 天** |
| A273 day569 池=1 单次点击播放次数 | 🔴 40 次未终止 | ✅ **1 次** |
| A274 day569 池=10 单次点击播放次数 | 🔴 40 次未终止 | ✅ **1 次** |
| A275 day569 重入链路可自行终止 | 🔴 200 层未终止 | ✅ **终止** |
| A276 源码存在「569 当日仅一次」守卫 | 🔴 缺失 | ✅ **存在** |

**语义正确性旁证**：修复后满池最坏情况恰好落在 **11 次 = GDD §2.6 预测上限**，触发日序列
`[130, 144, 158, 185, 199, 213, 227, 241, 540, 545, 569]` —— day569 由 4 次收敛为 1 次，
且 §2.5 保底路径（极小池玩家在 569 仍获得 1 次回响，A258/A259）依然成立。
说明修复**只砍掉了重复播放，未伤及保底语义**，非「为过断言而过断言」。

---

## 4. 非阻塞关注项（advisory，不影响放行判定）

| # | 关注项 | 建议 |
|---|---|---|
| C-1 | **`ECHO_BG_TINT` P1 未接线** —— 常量已在 L364 定义，但 `DialogueUI` 侧无 `bgTint` 支持。当前是「已声明未使用」常量 | GDD §3.3 明确允许跳过 P1，**P0 功能完整**。建议保留常量并加 `# TODO(P1)` 标注，或在下个整理周期移除，避免后来者误以为已生效 |
| C-2 | **vignette 文本质量需实机** —— 40 句文案（10×3 正文 + 10 `finale_line`）静态断言只能证明「非空、不重复、条数正确」 | 需实机通读：打字机节奏、长句断行、「」引号在 1280×720 下的折行表现。尤其 `winter_jingjing` 第 2 句、`spring_wanqing` 第 2 句为全集最长句 |
| C-3 | **回响打断当前流程的排队健壮性** —— GDD §7-② 以「选址」而非补丁消解，静态可证唯一播放点 = `_on_location_selected` step 0 且调用点唯一 | 但 `_on_accept_invite`（`MainGame` L246-251）会在 `board_ui.show_center_info` + `update_ui` **之后**调 `_on_location_selected`。建议实机走一次「接受邀约 → 回响 → 进地点」，确认 UI 恢复顺序无闪烁/错层 |
| C-4 | **NG+ 行为确认** —— 静态可证 `mem_echo_*` 4 类键与 `holiday_memory_*` 前置均随 `EndingScreen` L440 `flags = {}` 清空，且不在 L465-467 继承白名单 | 建议实机走一次 NG+：确认新周目 day 1-129 进 lakeside 无残留回响（G4 成熟期应拦住），且日记本无跨周目污染 |
| C-5 | **上游可达性疑点（GDD §7-④）复核结论** —— 已核实属实：`break_spring_chapter_xiaoxia` / `break_summer_chapter_zijun` / `break_autumn_chapter_jingjing_m` 的 `location=community` + `slotId=after`，而 `GameManager.locations["community"].slots` 仅含 `evening` → 常规路径不可达，仅邀约路径可解锁 | **属既有内容问题，非本特性引入，本特性不受阻**（lakeside 4 条主章 + day 569 无视地点特例三重兜底）。建议另立工单交 engineering-lead / 文策渊评估，本次不阻塞放行 |
| C-6 | **SL 刷回响** —— `mem_echo_*` 随存档序列化，读档即回滚冷却 | 与全游戏所有 SL 行为一致，GDD 明确不特殊处理。**无需动作**，仅记录 |
| C-7 | **`bgTint` 若未来接线** —— `finish_event()` 需**无条件**复位 `bg_rect.modulate = Color.WHITE`（幂等），否则后续所有背景带黄 | GDD §7-⑤ 已给出缓解方案，届时需补回归断言 |

---

## 5. 给用户的最终放行建议

### 判定：🟢 **PASS —— 静态质量门通过（原判定 🔴 FAIL，经 BUG-ME-01 修复后复判）**

**理由**：唯一的 Blocker 级缺陷 BUG-ME-01 已在源码层修复（`CollectionManager.gd` `pick_memory_echo()`
同日仅一次刹车），且该修复的同一语义已同步进门禁的模拟镜像 `simulate()` / `reentry_depth()`，
A273/A274/A275 等阻塞断言复测通过，全套 **286/286 PASS，failed=0，concerns=0**。
day 569 毕业前夜路径已从「无限连播、探索层不可达」收敛为「恰 1 次回响 → 正常进入」，
§2.5 保底语义完整保留，非 569 日零行为变化。

**PASS 的范围声明（重要）**：本判定覆盖的是**静态契约与守卫模型推演**（零 Godot runtime）。
下述实机项与 9 条 advisory 仍未被自动化覆盖，建议在发布签字前完成 —— 质量门为 advisory 门控，
**最终放行由用户拍板**。

### 建议路径

1. ~~**修复 BUG-ME-01**（交 engineering-lead 程基岩）~~ → ✅ **已完成**：`CollectionManager.gd` L508-511
   已落地 2 行同日守卫（§3.5 推荐方案），零新增 flag，零存档迁移，非 569 日零回归。
2. ~~**重跑本套件** → 期望 286/286 PASS~~ → ✅ **已完成**：实测 286/286，`VERDICT: PASS`（§3.7）。
3. **补一次最小实机验证**（无法静态覆盖，**仍建议在放行前完成**）：
   - [ ] day 569 进 lakeside：回响播 **1 次** → 正常进入探索层 → 可完成毕业前夜内容
   - [ ] 任意常态日进 lakeside 触发回响：播完**时段未推进**（`day` / `slot_index` 不变，S-4）
   - [ ] 回响播放时**无立绘、名字条为空、全屏 CG**（§3.2）
   - [ ] 回响播完后日志出现「🕯️ 记忆回响 · X」，日记出现「忽然想起 X」，**各 1 条**
   - [ ] 同一次进入地点，回响播完后**不重复播放**（§3.4 防递归，非 569 日）
4. QA 侧静态门已转 **PASS**；上述 5 条实机项通过后即可由用户做最终发布签字。

### 需要用户拍板的事项

- ~~**是否接受 §3.5 的推荐修法**~~ → ✅ **已采纳**「整日一次」方案：贴合 §2.5 措辞，
  未新增第 5 类 flag（维持 §5.3 的 22 键上界）。
- **是否在完成 §5 的 5 条实机验证前发布**。QA 建议：先跑完实机清单（尤其 day 569 一条）再签字 ——
  本轮 PASS 是静态门 PASS，day 569 的修复效果尚未经真机确认。
- **C-5 上游可达性问题是否另立工单**（3 条 community 记忆的解锁窗口过窄）。本次不阻塞，但会长期
  压低回响池规模。

---

## 6. 复现命令

```bash
cd d:/zkgame
C:/Users/Administrator/.workbuddy/binaries/python/versions/3.13.12/python.exe tests/memory_echo_smoke/verify_qa.py
# 退出码 0 = PASS / PASS-with-concerns，1 = FAIL
```

本套件对游戏代码**只读**，不产生任何副作用，可安全反复执行。
