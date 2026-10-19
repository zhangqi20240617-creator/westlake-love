# DS-RN-04b · 西湖风物志「手作渠道」补完 — 工程变更记录

> Owner: 程基岩 (engineering-lead) · 依据主理人（游承峰）诊断 spec 实现
> 前序：DS-RN-04（风物志 24 槽落地，18/24 可达）见 `docs/balance/eng_fengwu_changelog.md`
> 本次结论：**24/24 全可达，称号「西湖风物通」+ 大成 CG 解锁通路打通**

---

## 0. 一句话摘要

补上风物志三渠道中缺失的第三条 —— 手作。新增 6 条 `fw_craft_*` 家中事件，
以「1 个 `handmade_gift` + 材料费」换 1 件手作风物；产物走**纯 flag**、不进 `ITEM_DB`。
改动 3 个源文件（**新增 153 行，删除 0 行既有逻辑**）、2 个验证脚本，新增 1 个变异测试脚本。
零新 Autoload、零新 `.tscn`、零新美术、零存档迁移。

---

## 1. 源码改动清单

| # | 文件 | 缩进 | 位置 | 改动 |
|---|------|------|------|------|
| 1 | `scripts/DialogueUI.gd` | 4 空格 | L218–232（**+15 行**，插在既有 addItem 分支 L214–216 之后） | 场景级 `removeItem` / `grantFengwu` 两个新分支 |
| 2 | `scripts/events_life.json` | 4 空格 | L1406–1543（**+138 行**，追加在末尾 `]` 之前） | 6 条 `fw_craft_*` 事件；事件总数 60 → **66** |
| 3 | `scripts/CollectionManager.gd` | tab | L486/491/496/501/506/511（hint）、L543–545（函数体）、L354–360 / L478–480 / L570 / L586（注释） | 原地修改：6 条 hint 改可达成文案 + `get_fengwu_reachable_total()` 修遗留 bug + 4 处注释同步 |

**未触碰**：`GameManager.gd`、`FengwuBookUI.gd`、`DataManager.gd`、`MainGame.gd`、
`SaveSystem.gd`、`project.godot`、任何 `.tscn` / 美术资产。

三个文件缩进纯净度实测：`DialogueUI.gd` tab=0 / space=659；`events_life.json` tab=0；
`CollectionManager.gd` tab=665 / space=0；无行内混用（verify_qa Q39 守着）。

### 1.1 `DialogueUI.gd` — 两个对称的场景级字段

在既有 `addItem` 分支（L214–216）之后**对称**追加，不动事件级 L122–125：

```gdscript
    # 场景级别 removeItem → 直接扣背包（DS-RN-04b：fw_craft_* 消耗 handmade_gift）
    if scene.has("removeItem") and scene["removeItem"] != null and scene["removeItem"] != "":
        CollectionManager.remove_item(scene["removeItem"], 1)

    # 场景级别 grantFengwu → 风物志入册（DS-RN-04b：手作产物的**唯一**授予通道）
    if scene.has("grantFengwu") and scene["grantFengwu"] != null and scene["grantFengwu"] != "":
        CollectionManager.grant_fengwu(scene["grantFengwu"])
```

**为什么必须是 `grant_fengwu()` 而不是 `set_flag()`：**
`_check_fengwu_completion()` 只在 `grant_fengwu()` 内部被调用（CollectionManager L570–582）。
若旁路成 `set_flag("fengwu_" + fid, true)`，24 个 flag 会全部落账、图鉴显示 24/24，
但集满判定永不触发 → 称号与大成 CG **永久不可达**，且是静默失败。
这条已用变异体 M6 复现并被 Q45 抓住。

**为什么必须是 `remove_item()` 而不是靠 `requireItem`：**
`DataManager.get_available_event()` 的 `requireItem` 只做 `has_item()` 校验、**不消耗**
（DataManager.gd L245–250，全函数无 `remove_item` 调用）。若不显式扣，
1 个 `handmade_gift` 可以做出全部 6 件。变异体 M1 复现，Q43 抓住。

### 1.2 `events_life.json` — 6 条手作事件

仿 `int_craft_make` 结构，`location: "home"`、`repeatable: false`、无 `triggerDay`。

| 事件 id | priority | 授予 fid | 材料费 | 消耗 |
|---------|----------|----------|--------|------|
| `fw_craft_yahua` | 196 | `fw_hm_yahua` 押花书签 | 15 | handmade_gift ×1 |
| `fw_craft_guihuajiang` | 195 | `fw_hm_guihuajiang` 桂花酱 | 10 | handmade_gift ×1 |
| `fw_craft_xiangnang` | 194 | `fw_hm_xiangnang` 荷叶香囊 | 25 | handmade_gift ×1 |
| `fw_craft_taci` | 193 | `fw_hm_taci` 碑拓 | 20 | handmade_gift ×1 |
| `fw_craft_zhuze` | 192 | `fw_hm_zhuze` 竹制小物 | 15 | handmade_gift ×1 |
| `fw_craft_luyin` | 191 | `fw_hm_luyin` 湖畔录音 | 10 | handmade_gift ×1 |
| **合计** | — | 6 件 | **95 元** | 6 个礼物 |

每条 final scene 固定三件套：`statDelta{money: -N}` + `grantFengwu` + `removeItem`，
外加 `setFlag == 事件 id`（与 `finish_event()` 写的去重键同键，双保险）。

**priority 191–196 是算出来的，不是拍的。** 详见 §3.1。

### 1.3 `CollectionManager.gd` — 修遗留 bug + 文案

```gdscript
func get_fengwu_reachable_total() -> int:
	return FENGWU_TOTAL          # 原实现：遍历 obtain 排除「手作」→ 恒回 18
```

`FengwuBookUI.gd` L108/L145–148 用这个值决定是否显示
「本章可达 N 件；余下 N 件为手作，将在后续章节开放」。不修则图鉴永远向玩家谎报。
变异体 M8 复现（回改 18 → Q12 转红）。

6 条手作 hint 统一去掉 `【手作 · 尚未开放】`，改追加
「在家备一份手作礼物，加一点材料费，就能做出来。」。全文件「尚未开放」残留 = 0。

---

## 2. 验证结果（4 套回归 + 1 套变异，全绿）

| 套件 | 断言数 | 结果 | 与上轮对比 |
|------|--------|------|-----------|
| `scratch/verify_fengwu.py`（engineering） | **160 / 160** | PASS | 140 → 160（+20，新增 D 区手作契约 + N 区 6 个 mock 复演） |
| `tests/fengwu_smoke/verify_qa.py`（quality gate） | **46 / 46** | PASS (with 4 concerns) | 41 → 46（+5：B 区一一映射 +1，M 区手作专项 +4） |
| `tests/west_lake_stamps_smoke/verify_qa.py` | **165 / 165** | PASS | 165 → 165，**零回归** |
| `tests/memory_echo_smoke/verify_qa.py` | **286 / 286** | PASS | 286 → 286，**零回归** |
| `tests/fengwu_smoke/mutation_check_04b.py`（新增） | 8 变异体 | **抓 8 / 逃逸 0** | 新建 |

### 2.1 新增的 6 个 mock 复演（verify_fengwu section N，F154–F160）

- 18 件（拾得 12 + 购得 6）→ 不授称号；再加 6 件手作 → 称号 + complete + 画廊三者原子点亮
- 6 条事件共扣款 95 元（500 → 405），6 个 `handmade_gift` 全部归零
- 1 个礼物只能做 1 件（第 2 条事件因 `has_item` 失败被门控挡下）
- 同一事件重复触发 → `grant_fengwu` 幂等返回 false，不重复扣款
- money 不足 → `requireMoney` 门控挡下，事件不进候选池

### 2.2 新增的 4 条 QA 手作专项（verify_qa M 区 Q43–Q46）

| 编号 | 守的是什么风险 |
|------|---------------|
| Q43 | 经济语义：门控只读 → 必须自带 `removeItem` 真消耗；门控金额与实扣金额等额反号；合计 95 |
| Q44 | 不可重刷三重保险：`repeatable:false` + `finish_event` 写 flag + `DataManager` 见 flag 即 continue |
| Q45 | 授予通道唯一：走 `grant_fengwu()`（含集满判定），全工程调用点仅 2 处，无 set_flag/add_item 旁路 |
| Q46 | 抢得到：6 条 priority 全 > `int_craft_make`(190) 且互异；开局期无更高的永久驻留者压制 |

### 2.3 反向注入（变异）测试

新建 `tests/fengwu_smoke/mutation_check_04b.py`。把真源码复制进临时沙箱、注入缺陷、
用 `FENGWU_QA_ROOT` 指向沙箱跑门禁，**全程不触碰 `D:\zkgame` 真源码**。

| 变异体 | 注入的缺陷 | 抓住它的断言 |
|--------|-----------|-------------|
| M1 | 去掉一条事件的 `removeItem` | Q43 |
| M2 | 门控收 15 元但 `statDelta.money = 0` | Q43 |
| M3 | 手作事件改 `repeatable: true` | Q44 |
| M4 | 删掉 1 条手作事件 | Q11 / Q43 / Q46 |
| M5 | priority 降到 180（低于 int_craft_make） | Q46 |
| M6 | `grantFengwu` 旁路成 `set_flag` | Q45 |
| M7 | 手作产物塞进 `ITEM_DB`（price 0 可白嫖） | Q09 / Q28 / Q29 |
| M8 | `reachable` 退回 18（图鉴谎报） | Q12 |

首轮 M8 **逃逸**（旧 QA 脚本没人管 `get_fengwu_reachable_total()` 的实现），已补断言堵住。
这是变异测试当场兑现价值的一次。

---

## 3. 关键技术决策与推导

### 3.1 priority 191–196 的推导过程

`DataManager.get_available_event()` 把候选按 priority 降序排序后**只取 `candidates[0]`**
（DataManager.gd L328–329），顶层严格唯一、无随机、无回退。因此手作事件必须压过所有
「会长期赖在 home 候选池里」的竞争者，否则永远选不中。

扫描全部 `events*.json`，筛出 home/全局 + `repeatable: true` + 无任何会退场的状态门控
（`minStress`/`minAddict`/`requireFlags`/`requireHoliday`/…）的「永久驻留者」，只有 2 个：

- `int_craft_make` — priority **190**，triggerDay 80（手作原料的产出方）
- `life_family_support_study` — priority **250**，triggerDay 361

其余高 priority 的 home 事件要么 `repeatable: false`（触发一次即被 `flags[ev_id]` 消耗退场），
要么带 stress / 节日 / 天数门控（状态不满足即退场）。

→ 取 191–196：稳压 `int_craft_make`(190)，同时低于 `forced_netbar`(200) 与
`life_family_*` 叙事事件（205–290），不抢叙事节奏。

**自洽的产消循环（不是巧合，是这个 priority 关系的产物）：**
背包无礼物 → `fw_craft_*` 被 `requireItem` 门控挡下 → `int_craft_make`(190) 夺魁 → 产 1 个礼物
→ 下次回家 `fw_craft_*`(191–196) 夺魁 → 消耗礼物、做出 1 件风物 → 又无礼物 …
如此交替 12 次集齐 6 件。玩家不需要理解任何机制。

### 3.2 手作产物为什么是纯 flag（D-2 决策的实现侧确认）

`ShopUI` 无条件全量遍历 `ITEM_DB` 上架，无地点/章节过滤。手作产物若入库且 `price` 缺省为 0，
玩家可在商店直接白嫖。且 `CollectionManager.add_item` 尾部的购得钩子会以 `item_id` 当 fid
落账 → 手作与购得两条渠道语义混淆。
故 6 个 `fw_hm_*` 只作为 `FENGWU_ITEMS` 的 key 存在，不进 `ITEM_DB`，
只能由 `grantFengwu` 授予。变异体 M7 反向验证。

### 3.3 去重的三重保险

1. 事件 `repeatable: false` → `DataManager` L208 见 `flags[ev_id]` 即 continue
2. `DialogueUI.finish_event()` 完成时写 `GameManager.set_flag(ev_id, true)`
3. 事件末句 `setFlag == 事件 id`（与 2 同键，选项分支提前结束时兜底）

外加 `grant_fengwu()` 自身幂等（`flags.has(flag)` 即 return false）→ 即便前三层全破，
风物也不会重复入册，只会多扣一次钱。

---

## 4. 遗留与待裁决项

### 4.1 本次**刻意未动**（上一轮已放行的非阻塞关注）

- **拾得可重 roll**：`FENGWU_PICKUP_DAY_FLAG` 只在 roll 成功后才写，失败不消耗当日额度。
  按主理人指令不顺手修。
- **送礼池污染**：6 件购得风物可作礼物送出，`GIFT_PREFERENCES` 无条目走兜底 +3。同上。

### 4.2 本次**新发现**，需主理人裁决（均已写进 verify_qa concerns）

**① 图鉴文案已过期 · 高（建议尽快授权一行修复）**

`FengwuBookUI.gd` L331 未获得的手作格 tooltip 仍硬编码
`"【手作 · 尚未开放】…这一格会在后续章节里补上。"`。
渠道已开通，但玩家读到这句会**直接放弃尝试**，等于把已可达的 6 件在认知上锁死。
（L145–148 的顶部提示因 `reachable == total` 已自动静默，无需改。）

建议改为 CollectionManager 侧已更新的话术「在家备一份手作礼物，加一点材料费，就能做出来。」。
**未擅改原因**：任务书授权范围是 DialogueUI / events_life / CollectionManager / 验证脚本 四处，
`FengwuBookUI.gd` 不在其中，按铁律「不动无关系统」停下上报。

**② 手作窗口有闭合期 · 中（非本次引入的回归）**

`life_family_support_study`（priority 250, `repeatable: true`, triggerDay 361, 零状态门控）
自 day 361 起永久占据 home 候选首位。引擎无事件冷却机制。
→ day 361 之后在家既产不出原料、也做不了手作。

按 `GameManager.get_grade_info()` 真源（90 天/学期，全程 570 天）换算：
手作可用窗口 = **day 81–360**（初一下～初二下，280 天，占全程 49%），**初三全程关闭**。
集齐 6 件仅需 12 次在家事件，窗口充裕，**不构成 soft-lock**；
且该压制对既有 `int_craft_make` 早已成立，非本次引入。

若要根治，二选一（均属设计决策，未擅改）：
① 给 `life_family_support_study` 加 `excludeFlags` 或冷却；
② 把 `fw_craft_*` 抬到 250 以上 —— 但会压过 `life_family_*` 叙事事件，破坏叙事节奏。

**③ 大成 CG 与「毕业纪念册」同图 · 轻（美术侧）**

`lakeside_evening.jpg` 被两条画廊项共用。以前集满不可达所以看不见，
现在两格会在同一周目内同时点亮，画廊出现两格相同背景。建议补一张专属图。

---

## 5. 约束核对

| 约束 | 实测 |
|------|------|
| 零新 Autoload | `project.godot [autoload]` = 15 项，无 `Fengwu*`（Q33） |
| 零新 `.tscn` | `**/*Fengwu*.tscn` = 0 个（Q34） |
| 不注册新脚本 | 无新增 `.gd`；新增的仅 1 个 Python 变异测试脚本，不进引擎 |
| 手作产物纯 flag | 6 个 `fw_hm_*` 均不在 `ITEM_DB`（Q09） |
| 缩进铁律 | 3 个源文件缩进纯净度全部实测通过（Q39） |
| 零存档迁移 | 全部走 `GameManager.flags`，`SaveSystem` 无 fengwu 特判（Q37） |
| NG+ 语义 | 风物进度不在 NG+ 白名单，新周目清零重来（Q36–Q37） |
| 不改设计决策 | 2 项冲突已停下上报（§4.2 ①②），未擅改 |
