# 节日事件 triggerDay 修复（DS-RN-06）交付记录

- **类型**：Bug 修复（真 bug，非新特性）· 纯数据层改动，零新增代码
- **发现路径**：社团系统 DS-RN-05 实现期间，quality-lead 在跨文件一致性复核中顺带定位
- **门禁结论**：eng 自验 PASS（exit 0）· quality-lead 独立门禁 50/50 concerns=0（exit 0）· 主理人 trust-but-verify 双重重跑均 PASS
- **风险等级**：高（4 个节日 vignette 在玩家视角下**永远不触发**，属静默失效，无报错）

---

## 1. 定位与现象

4 个节日一次性 vignette：

| 事件 id | 标题 | 原期望触发日 | 实际触发 |
|---|---|---|---|
| `fest_teacherday` | 📚 教师节·谢师 | day 10 | 开局 day 1 即被消费 |
| `fest_newyear` | 🎉 元旦·跨年愿望 | day 30 | 开局 day 1 即被消费 |
| `fest_dragonboat` | 🎋 端午·龙舟彩绳 | day 120 | 开局 day 1 即被消费 |
| `fest_midautumn` | 🥮 中秋·湖畔赏月 | day 310 | 开局 day 1 即被消费 |

玩家在对应节日当天**看不到任何节日叙事**，且因 `repeatable:false` + 消费标记，此后永久不可达。

---

## 2. 根因

`events_life.json` 中 4 个事件均为：

```
location: null, slotId: null, charId: null, priority: 300, repeatable: false,   ← 缺 triggerDay
```

落入事件门控引擎 `DataManager.get_available_event()`（L175–329）的两条规则：

1. **`location:null` / `slotId:null` 视为「任意地点 / 任意时段匹配」**（L192–200）；
2. **`triggerDay` 语义 =「从该天起可用」**（L202–204）；读取为 `int(ev.get("triggerDay", 0))`，
   缺省 `0` ⇒ 门控恒 `false` ⇒ **从 day 1 起就可选**；
3. 候选按 `priority` 降序 `sort_custom` 取最高（L327–329），`priority:300` 为全池最高之一；
4. `repeatable:false` 事件经 `GameManager.flags.has(ev_id)` 消费（L208）。

结果：玩家 day 1 第一次探索，4 条 vignette 立即进入候选池（任意地点/任意时段匹配、无日期门槛、最高优先级），被选中后写 `flags[fest_*]=true`，**永久消费**。节日当天反而因已消费而无内容。

---

## 3. 双触发路径（为何必须「精确等于」节日当天）

quality-lead 发现节日 vignette 有**两条**触发路径，工程自验原本只知其一：

- **① 直发·精确当天**：`MainGame._apply_special_date`（L368–379）在节日当天以 `get_event_by_id()` → `start_event()` 直发；
  **不校验 `triggerDay`，也不校验已消费状态**。
- **② 回落·从该天起**：探索时经 `get_available_event()` 按 `triggerDay` 放行。

推论：`triggerDay` **必须精确等于**节日当天。

- 若 `triggerDay < 节日当天`：回落路径提前开门并消费 → 直发路径当天因「不校验消费」**二次重播同一 vignette**。
- 若 `triggerDay > 节日当天`：直发路径当天因 `get_event_by_id()` 裸查仍可播（不校验 triggerDay），但回落路径开门过晚，玩家若节日当天未探索则**顺延补播**，不丢内容（可接受）。

本修复取值 = 节日当天（10/30/120/310），恰好落在「直发精确当天」窗口内，两条路径同日只播一次。

> 注：春节 `eco_lucky_money`（🧧 day 95）**本来不带 `fest_` 前缀且已带 `triggerDay:95`**，不在缺陷范围内，未改动。

---

## 4. 修复方案

**最小、纯 JSON 修改**：为 4 个事件各加 1 个键 `triggerDay`，值精确等于其 `SPECIAL_DATES` 节日当天：

| 事件 | triggerDay | 节日当天（SPECIAL_DATES） |
|---|---|---|
| `fest_teacherday` | 10 | `teacher_day` = 10 |
| `fest_newyear` | 30 | `new_year` = 30 |
| `fest_dragonboat` | 120 | `dragon_boat` = 120 |
| `fest_midautumn` | 310 | `mid_autumn` = 310 |

未改动任何其它字段（`priority` 仍 300 / `repeatable` 仍 false / `location`·`slotId`·`charId` 仍 null / `scenes` 文案与 `statDelta` 零改动）。事件总数仍为 72，全池 245 条 id 唯一。

---

## 5. 落点（零代码改动）

- **`scripts/events_life.json`**：4 处（`fest_teacherday` L616 / `fest_newyear` L638 / `fest_dragonboat` L660 / `fest_midautumn` L682）各加 `triggerDay` 键。
- **`scripts/DailyCycleManager.gd`** `SPECIAL_DATES`（L12–35）：22 条特殊日期未改动，`effect:"festival"` 5 条（10/30/95/120/310）未改动。
- **`scripts/MainGame.gd`** `fest_narrative_map`（L360–379）：直发分支未改动。
- **`project.godot`**：autoload 仍为 15，未新增。
- **`EndingScreen.gd`**：零改动，NG+ `flags={}` 自然重置 4 个 fest 消费标记 → 新周目节日完整复现。

---

## 6. 质量门（主理人 trust-but-verify 双重确认）

### 6.1 工程自验（eng，已移至 `scratch/_verify_fest_triggerday.py`）
- 校验 `events_life.json` 合法 JSON、总数 72 不变；
- 4 个 `triggerDay` 精确等于 10/30/120/310；
- `priority=300` / `repeatable=false` / `location`·`slotId`·`charId` 仍 null（纯加键、无夹带）。
- 结果：PASS（exit 0）。

### 6.2 quality-lead 独立门禁（`tests/fest_smoke/verify_qa.py`）
- **断言 50 项，通过 50，失败 0，concerns=0**（exit 0）。
- 分组覆盖：
  - **Q0 门禁自检**：6 受检源可达、EVENT_FILES 注册 10 文件、事件池 245 条可解析（防空扫描假 PASS）；
  - **Q1 修复核心**：`triggerDay` 精确落位 + 语义复演（day1 × 5 地点 × 5 时段 = 25 组合下 4 事件全不可选 → 原 Bug 反向验证；各自当天转可选；前一天仍不可选）；
  - **Q2 零回归**：键集恰 9 键（原 8 + triggerDay）、priority/repeatable/location/slotId/charId/scenes 指纹/总数全部未变；
  - **Q3 JSON 合法性**；
  - **Q4 零代码改动**：autoload 仍 15、无 fest 命名 Autoload、SPECIAL_DATES 未动、DataManager 门控语义未变；
  - **Q5 NG+ 重置**：`flags={}` 自然复活 4 fest；
  - **Q6 三文件一致性三角**（工程自验完全未覆盖）：`fest_narrative_map` × `SPECIAL_DATES` × `events_life.json` 三方 banner/day/id/triggerDay 精确对齐，含 `eco_lucky_money=95`；
  - **Q7 根因同类清零**：全池 245 条扫描「全局+零门控+一次性+无 triggerDay」的 day1 可消费事件 → **零漏网**（缺陷形状彻底清零）；
  - **Q8 双触发路径语义 + 回落可达性**：直发分支仍在、不校验消费、`triggerDay` 均不早于节日当天（无重播窗口）、优先级 300 高于常驻竞争者（不饿死）；
  - **Q9 可选增强**（note 级，不阻断）：约定固化建议（见 §7）。

---

## 7. 非阻塞关注与后续

1. **约定固化（Q9 建议）**：当前「fest 事件必须带 triggerDay」仅靠本门禁把守，源码/文档侧无强制。建议：
   - 在 `DataManager.get_available_event` 的 `triggerDay` 分支上方补一行注释，或
   - 在 `docs` 登记「节日一次性全局事件必须带 `triggerDay`」约定；
   - 将本门禁 Q6/Q7 两组（跨文件不变量）接入 CI / 提交前检查，避免日后新增节日事件重蹈覆辙。
   → 状态：**待办**（不阻断本次放行）。
2. **`MainGame.gd` L376–381 if/elif 链脆弱性（既有代码，非本轮引入）**：`elif effect == "break" or effect == "free_day":` 实际因中间隔 `var` 语句被截断，未链到上方 `elif effect == "festival"`。因节日 banner 与长假日期不相交侥幸正确。quality-lead 建议排期给 engineering-lead 单修。**不阻断本次放行**。
3. **发布硬阻塞（前序遗留，与本次无关）**：
   - ⚠️ `assets/backgrounds/west_lake_fengwu_complete.jpg` 缺 `.import` → Godot 导出包不含该资源（见 DS-RN-04b 发布清单）；
   - 项目至今非 git 仓库，DS-RN-04/04b + DS-RN-05 + DS-RN-06 多文件待提交。

---

## 8. 交付物清单

- 修复：`scripts/events_life.json`（4 处 `triggerDay`）
- 门禁：`tests/fest_smoke/verify_qa.py`（50/50，concerns=0）
- 工程自验：`scratch/_verify_fest_triggerday.py`（由 `scripts/` 移入，避免污染事件脚本目录）
- 本文档：`docs/balance/fest_triggerday_changelog.md`
