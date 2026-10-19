# excludeRelState 历史债清理 · 质量门报告

## 校验概要
- **脚本**：`tests/excl_relstate_smoke/validate_excl.py`
- **运行**：`"C:\Users\Administrator\.workbuddy\binaries\python\versions\3.13.12\python.exe" "D:\zkgame\tests\excl_relstate_smoke\validate_excl.py"`
- **范围**：全 11 个 `events_*.json`（角色事件 = `charId` 非 null 且非 `"player"`）
- **判定规则**：角色事件须满足以下**至少一条**才算已正确覆盖，否则记 FAIL：
  1. 含 `excludeRelState` 字段（值 `"cold"`）；或
  2. 含 `requireRelState` 字段（状态已精确锁）；或
  3. 属**固定剧情节点集**（id 含 `grad`/`graduation`/`end_pre`，共 7 个：`yt_end_pre`, `jj_end_pre`, `special_graduation_eve`, `special_grad_wq`, `special_grad_xx`, `special_grad_yf`, `special_grad_zc`）——冷战不应阻断，否则断剧情/结局；或
  4. 属**关系状态机事件**（id 含精确关键词 `cold_war`/`cold_recover`/`_cold`/`close_`/`crush_`/`confess`/`breakup`/`rel_state`/`relstate`/`makeup`/`reconcile`/`reunite`/`apolog`/`misunderstand`/`_rel`）。
  - 排除集刻意**不用裸子串** `rel`/`war`/`angry`/`fight`（会误伤 umbrella/warning 等词）。
- **执行者注**：`quality-lead` 因代理 `127.0.0.1:7892` 持续 502（ECONNREFUSED）无法派发，主理人兜底执行本校验（逻辑级，无 Godot 运行时，与质量门判定等价）。

## 逐项结论
| 文件 | 角色事件 | 已覆盖 | 缺口 | 判定 |
|---|---|---|---|---|
| events.json | 69 | 69 | 0 | PASS |
| events_break.json | 13 | 13 | 0 | PASS |
| events_daily.json | 0 | 0 | 0 | PASS |
| events_jingjing.json | 12 | 12 | 0 | PASS |
| events_keke.json | 9 | 9 | 0 | PASS |
| events_life.json | 0 | 0 | 0 | PASS |
| events_male.json | 45 | 45 | 0 | PASS |
| events_special.json | 23 | 23 | 0 | PASS |
| events_wanqing.json | 11 | 11 | 0 | PASS |
| events_xiaoxia.json | 10 | 10 | 0 | PASS |
| events_yutong.json | 17 | 17 | 0 | PASS |
| **合计** | **209** | **209** | **0** | **PASS** |

## 质量门总判定
**PASS** —— 全 11 文件 209 个角色事件均已覆盖，gap=0；`events.json` 的 `excludeRelState:"cold"` 计数断言 == 62 通过；7 个节点事件断言未含 `excludeRelState`（未误屏蔽）。无阻塞项。

## 关键数据
- `events.json`：角色事件 69 = 加 `excludeRelState` 62 + 节点豁免 7 + 关系机 0；`leaked`(既无 excl/req 又非节点) = 0。
- 全 11 文件：209 角色事件全部覆盖。
- `events.json` `excludeRelState:"cold"` 计数 == 62 ✓
- 7 节点事件确认无 `excludeRelState` ✓（未误屏蔽，冷战期仍弹以推进剧情/结局）

## 已知风险与缓解
- **R1 代理故障**：`quality-lead` 无法派发（连续 2 次 `127.0.0.1:7892` 502）。主理人兜底跑校验，逻辑等价；代理恢复后可重派复核，预期结论一致。
- **R2 子串误报防护**：排除集用精确关键词（含 `_cold`/`close_`/`crush_` 等），刻意避开裸 `rel`/`war`。Grep 复核确认 `events.json` 无真实关系机事件（Phase 0 脚本曾因裸 `rel`/`war` 误把 `jj_umbrella`/`friend_warning_*` 算成 rel=2，设计落地时正确加了这 2 个，无 BUG）。
- **R3 节点豁免**：7 个毕业/结局前置事件不加 `excludeRelState`，防冷战期断剧情/结局。属设计判定豁免，非遗漏。
- **R4 无 Godot 实跑**：仅逻辑级 JSON 校验。建议用户在编辑器内进一次冷战态（置 `flag_cold_*`）目视确认：普通角色事件不弹、专门冷战/挽回事件照弹、生活事件（charId:null）照弹。
- **R5 设计偏差已澄清**：design-strategist 报告"预期加 60，实际加 62"的偏差，源于 Phase 0 子串误报（见 R2），实际 62 处正确，无缺口、无错加。
