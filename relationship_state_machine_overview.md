# 关系状态机（Phase 2 收口）实现总览

> 把「0–100 好感数字 + 30/60/85 瓶颈锁」升级为**可感知、可倒退**的关系状态。

## 做了什么
新增第 8 个子系统 Manager `RelationshipManager.gd`，并把关系状态机接入现有 6 个系统。**27 个外部调用方零改动**（纯新增缓存字典 + 门面委托）。

## 状态定义
状态 = 好感度的**纯函数** + 冷战覆盖态：
- 陌生(0–14) → 熟悉(15–29) → 朋友(30–59) → 暧昧(60–84) → 心动(≥85)
- 冷战：由 flag `rel_cold_<id>` 覆盖（叠加在任何态之上），好感 −10，期间正向增益封锁

## 集成点（7 处）
| 文件 | 改动 |
|---|---|
| `RelationshipManager.gd` **(NEW)** | 状态推导 / 重算 / 冷战进入与挽回 / 查询门面 / 信号 |
| `GameManager.gd` | `relationship_state` 字典 + `add_favor` 重算&冷战封锁 + 门面 + `_ready` 静默重算 |
| `DailyCycleManager.gd` | 衰减后重算 + close/crush 连续 21 天无互动→冷战 |
| `DataManager.gd` | 事件过滤新增 `requireRelState` / `excludeRelState` |
| `SaveSystem.gd` | `SAVE_VER` 5→6，序列化 `relationship_state`，读档静默重算 |
| `CharacterStatsPopup.gd` | 好感网格每角色追加状态 chip（中文+颜色） |
| `DialogueUI.gd` | 选项级/事件级 `relCold`/`relRecover` 接线 + 冷战拒收礼物 |
| `events_yutong.json` | PoC 事件：`yt_cold_war_01`(close+relCold) / `yt_cold_recover_01`(cold+relRecover) |

## 关键决策
- 真相仍在 `favorability`，`relationship_state` 仅为派生缓存（与 `char_mood` 同款处理）。
- 升级弹正反馈 toast、降级静默，控制情感噪音。
- 挽回事件的原 `affDelta:5` 因冷战封锁会被吞且误弹提示 → 改为 `recover_from_cold` 内部 +5 补偿。
- 缩进：GameManager 4 空格、新 Manager tab（生成脚本显式保证，已 grep 校验无混用）。

## 待你在 Godot 验证
1. 角色面板出现 `[状态]` chip，进度条颜色随状态变化
2. 好感跨 60 / 85 弹「进入了『暧昧/心动』阶段」
3. 选错话 → 冷战（好感 −10，此后送礼物/刷好感被拒）
4. close/crush 后连续 21 天不互动 → 自动冷战
5. 触发「课桌道歉信」事件 → 和好（+5），状态恢复
6. 旧 v5 存档读档自动升级 v6（relationship_state 由 favorability 重算）

⚠️ 本环境无 Godot 实机，无法跑 `--check`。以上需你在编辑器确认无解析错误。
