# 冷战（cold）冒烟测试 — 质量门规格与结论

- **测试类型**：逻辑级冒烟测试（Logic-level Smoke Test）
- **测试对象**：事件关系状态过滤 predicate（Cold-War relation-state gating）
- **测试脚本**：`scratch/cold_war_smoke_test.py`（纯 Python + 标准库，不依赖 Godot）
- **数据来源**：`scripts/` 下 8 个真实事件 JSON（全量 147 条事件）
- **运行环境约束**：本机无 Godot 可执行文件，无法做引擎内 playtest；故采用「predicate 复刻 + 真实数据」的可证伪逻辑冒烟方案。

---

## 1. 测试目标

Phase 3 存量债清理已给 79 个角色事件补了 `excludeRelState:"cold"`。本测试验证两件事：

1. **压制生效**：在 `cold` 关系状态下，普通日常弹窗（带 `excludeRelState:"cold"` 的事件，以及无锁普通事件）确实被过滤 predicate 压住，**不再漏出**。
2. **专属保活**：冷战专属的 `requireRelState:"cold"` recover 事件在 `cold` 下**仍正常触发**；且 `exclude` 只在 `cold` 触发，不误伤正常关系状态（familiar 等）。

---

## 2. 被测逻辑（predicate 来源 — `scripts/DataManager.gd` L273-284，已逐字确认）

```gdscript
# 检查 requireRelState / excludeRelState（关系状态机）
var rel_char = ev.get("charId", "")
if rel_char == null: rel_char = ""
if rel_char != "":
    var req_rel = ev.get("requireRelState", "")
    if req_rel == null: req_rel = ""
    if req_rel != "" and RelationshipManager.get_rel_state(rel_char) != req_rel: continue
    var ex_rel = ev.get("excludeRelState", "")
    if ex_rel == null: ex_rel = ""
    if ex_rel != "" and RelationshipManager.get_rel_state(rel_char) == ex_rel: continue
```

### 复刻语义（Python `is_eligible(ev, rel_state)`）
- `charId` 为空 / `null` / 不存在 → **通用/系统事件**，不受关系状态影响，始终 `eligible`。
- 有 `charId` 时：
  - `requireRelState` 非空且 `rel_state != requireRelState` → 跳过（不 eligible）。
  - `excludeRelState` 非空且 `rel_state == excludeRelState` → 跳过（不 eligible）。
- `get_rel_state(char)` 是 Phase 2 已独立验证的关系状态机输出；本测试**不重算状态机**，将其当作输入参数 `rel_state` 注入，只测过滤 predicate 本身。
- JSON `null` 在 Python 中为 `None`，复刻时统一规约为空串 `""`（对应 GDScript 的 `if x == null: x = ""`），与引擎语义逐字一致。

---

## 3. 场景设定

| 项 | 设定 |
|----|------|
| 事件文件 | `events_daily` / `events_special` / `events_wanqing` / `events_yutong` / `events_xiaoxia` / `events_jingjing` / `events_keke` / `events_male`（顶层均为数组） |
| 注入关系状态 `rel_state` | `cold`, `familiar`, `friend`, `close`, `crush`（5 种） |
| 覆盖事件 | 全量 147 条（角色事件 127 / 通用事件 20） |
| 断言 B 样本 | keke→`kk_cold_recover_01`、beichen→`bc_cold_recover_01`、jingjing_m→`jm_cold_recover_01`、zijun→`zj_cold_recover_01` |
| 断言 C 样本 | `keke_meet_01` |

---

## 4. 断言与预期结果

### A. COLD 场景 — 无普通事件漏出（回归核心）
**断言**：在 `rel_state="cold"` 下，每一个 `eligible` 的**角色事件**，其 `requireRelState` 必须 `== "cold"`。
**预期**：不存在任何带 `excludeRelState:"cold"` 的事件、或任何无锁普通事件在 `cold` 下 `eligible`。若补丁完整，COLD eligible 角色事件应仅为各角色的 `*_cold_recover_01` 等 `requireRelState:"cold"` 事件。
**通过条件**：违规列表为空。

### B. COLD 场景 — 冷战专属 recover 事件保活
**断言**：所有 `requireRelState=="cold"` 的事件在 `cold` 下必须 `eligible`；至少验证 keke / beichen / jingjing_m / zijun 各自的 `*_cold_recover_01` 在 `cold` 下 `eligible`。
**预期**：`kk_cold_recover_01`、`bc_cold_recover_01`、`jm_cold_recover_01`、`zj_cold_recover_01` 均出现。
**通过条件**：全量 `requireRelState:"cold"` 事件全部 eligible，且 4 个样本齐全。

### C. NON-COLD 场景 — exclude 不误伤正常状态
**断言**：以 `rel_state="familiar"` 为例，所有带 `excludeRelState:"cold"` 的事件必须 `eligible`（证明 `exclude` 仅在 `cold` 触发）；验证样本 `keke_meet_01` 在 `familiar` 下 `eligible`。
**预期**：99 个 `excludeRelState:"cold"` 事件在 `familiar` 下全部 eligible，`keke_meet_01` 出现。
**通过条件**：无 exclude 事件在 familiar 下被排除，样本出现。

### D. 不变量 — 无矛盾双锁
**断言**：全量事件中同时含 `requireRelState` 与 `excludeRelState`（二者均非空）的数量为 `0`。
**预期**：`0`。
**通过条件**：双锁事件计数为 0。

### E. 通用事件 — 不受关系状态影响
**断言**：`events_daily.json`（`charId=null`）在所有 `rel_state ∈ {cold, familiar, friend, close, crush}` 下均 `eligible`，且其所有事件 `charId` 均为 `null`。
**预期**：20 条通用事件在 5 种状态下全部 eligible。
**通过条件**：无非通用事件混入，且任意状态下均无被排除项。

---

## 5. 本次运行结论

**整体结论：PASS ✅（5/5 断言全部通过）**
运行命令：`python scratch/cold_war_smoke_test.py`　退出码 `0`

### 各断言结果
| 断言 | 结果 | 说明 |
|------|------|------|
| A | PASS ✅ | COLD eligible 角色事件共 10 个，全部 `requireRelState:"cold"`，无普通/无锁事件漏出 |
| B | PASS ✅ | 10 个 `requireRelState:"cold"` 事件全部 eligible；keke/beichen/jingjing_m/zijun 样本齐全 |
| C | PASS ✅ | 99 个 `excludeRelState:"cold"` 事件在 familiar 下全 eligible；样本 `keke_meet_01` 出现 |
| D | PASS ✅ | 同时含两把锁的事件数 = 0 |
| E | PASS ✅ | 20 条 `events_daily` 通用事件 charId 均为 null，5 种状态下全 eligible |

### 关键计数
| 指标 | 数值 |
|------|------|
| 载入事件总数 | 147（角色 127 / 通用 20） |
| COLD 下 eligible 角色事件数 | 10 |
| `requireRelState:"cold"` 事件数 | 10 |
| `excludeRelState:"cold"` 事件数 | 99 |
| 同时含两把锁的事件数 | 0 |
| `events_daily.json` 通用事件数 | 20 |

### COLD 场景下 eligible 角色事件清单（断言 A 的直接证据）
> 证明「只有 recover 类漏出」，普通日常弹窗已被压住。

```
wq_cold_recover_01   charId=wanqing      requireRelState=cold
yt_cold_recover_01   charId=yutong       requireRelState=cold
xx_cold_recover_01   charId=xiaoxia      requireRelState=cold
jj_cold_recover_01   charId=jingjing     requireRelState=cold
kk_cold_recover_01   charId=keke         requireRelState=cold
yf_cold_recover_01   charId=yifei        requireRelState=cold
zc_cold_recover_01   charId=zicheng      requireRelState=cold
bc_cold_recover_01   charId=beichen      requireRelState=cold
jm_cold_recover_01   charId=jingjing_m   requireRelState=cold
zj_cold_recover_01   charId=zijun        requireRelState=cold
```

---

## 6. 质量门判定（Advisory）

- **判定**：PASS。补丁（Phase 3 的 `excludeRelState:"cold"`）在真实数据上经 predicate 复刻验证，已有效压制普通事件在冷战下的弹出，且冷战专属 recover 事件保活、exclude 不误伤正常状态、通用事件不受影响。
- **放行建议**：本测试为逻辑级冒烟门控，证据充分，建议作为 QA 质量门「通过」。最终发布签字仍由用户/主理人人工审批。
- **复测触发条件**：若后续修改 `DataManager.gd` 过滤逻辑、事件 JSON 的 `requireRelState`/`excludeRelState` 字段，或调整冷战 recover 事件，须重跑本脚本并比对关键计数。

---

## 7. 注意事项与边界
- 本测试**不重算关系状态机**（Phase 2 已独立验证），`rel_state` 为注入参数；因此覆盖的是「predicate 本身」而非状态机输出。
- 测试未修改任何游戏代码或事件 JSON，仅新增 `scratch/cold_war_smoke_test.py` 与本文档。
- 引擎内 playtest 因本环境无 Godot 可执行文件而未执行；若有引擎环境，建议补充一次真实运行时抽检（本逻辑测试已为其提供门控基线）。
