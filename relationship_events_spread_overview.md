# 关系状态机 · 冷战/挽回事件铺开总览

## 目标
关系状态机基础设施（RelationshipManager + v6 存档 + 状态 chip）已落地，但冷战/挽回事件只有雨桐有。
本次把这套"吵架→冷战→和好"的内容铺到**男主路线的全部 5 个女角色**，让机制真正可体验。

## 改动清单

### 新增/修改的事件文件（均经 JSON 校验）
| 角色 | 冷战事件 | 挽回事件 | 触发地点/时段 |
|---|---|---|---|
| 陈雨桐 yutong | yt_cold_war_01（已有） | yt_cold_recover_01（已有） | 断桥/课桌 |
| 叶菁菁 jingjing | jj_cold_war_01 | jj_cold_recover_01 | 校门(晚) / 社区(早) |
| 苏晚晴 wanqing | wq_cold_war_01 | wq_cold_recover_01 | 图书馆(晚) / 湖边(早) |
| 林小夏 xiaoxia | xx_cold_war_01 | xx_cold_recover_01 | 操场(晚) / 操场(早) |
| 方可可 keke | **kk_cold_war_01（新建文件）** | **kk_cold_recover_01（新建文件）** | 校外小店(晚) / 湖边(早) |

- 每个冷战事件：`requireRelState: "close"` + 选项内 `relCold: true`，选错话 → 好感 −15（−5 选项 + −10 冷战扣减）
- 每个挽回事件：`requireRelState: "cold"` + `relRecover: true`，不带 `affDelta`（由 `recover_from_cold` 内部 +5 补偿，避免被冷战增益封锁吞掉）
- `location` / `slotId` 严格匹配角色真实出现地点，否则 `get_available_event` 地点过滤会让事件永不可触发

### 新建文件
- `scripts/events_keke.json`：方可可原本**一个事件都没有**（角色表有、事件列表无），本次补齐冷战+挽回并注册

### 修改文件
- `scripts/DataManager.gd`：`EVENT_FILES` 显式数组追加 `"res://scripts/events_keke.json"`（事件加载是显式列表，不是 glob，漏注册则文件不生效）

## 验证
- 5 个事件文件 JSON 全部合法，字段就位
- 事件总数：yutong=17 / jingjing=12 / wanqing=11 / xiaoxia=10 / keke=2
- 27 个外部脚本零改动（纯数据 + 数据加载列表新增一行）

## 待你在 Godot 验证
1. 与任意女角色好感≥60（进入"暧昧"）后，去其专属地点对应时段，有机会触发"争执"事件
2. 选错话 → 冷战（好感 −10，之后送礼/刷好感被拒，角色面板显示🔴冷战）
3. 冷战期间去对应地点对应时段，出现"道歉/纸条/奶茶"挽回事件 → 和好（+5）
4. 方可可（day300 解锁）路线同样可走完冷战→挽回
5. 旧 v5 存档读档自动升级 v6（relationship_state 字段）

## 可选后续（未做）
- 给各角色**普通日常事件**加 `excludeRelState: "cold"`，防止冷战期仍弹日常邀约（需逐条审事件，暂缓）
- 女主路线 5 男角色（沈逸飞/周子诚/顾北辰/叶明轩/林紫君）的冷战/挽回事件尚未铺，模式可完全复用
