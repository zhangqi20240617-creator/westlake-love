# Phase 2 关系状态机 · 男女路线全覆盖收口

## 本次收口内容
把女主路线 5 个男角色的冷战/挽回事件铺进 `events_male.json`，与男主路线 5 女角色对称。

| 男角色 | 冷战事件 | 挽回事件 | 地点/时段 |
|---|---|---|---|
| 沈逸飞 yifei | yf_cold_war_01 | yf_cold_recover_01 | 音乐室(晚) / 湖边(早) |
| 周子诚 zicheng | zc_cold_war_01 | zc_cold_recover_01 | 操场(晚) / 校外店(早) |
| 顾北辰 beichen | bc_cold_war_01 | bc_cold_recover_01 | 图书馆(晚) / 校门(早) · D300 |
| 叶明轩 jingjing_m | jm_cold_war_01 | jm_cold_recover_01 | 社区(晚) / 校门(早) |
| 林紫君 zijun | zj_cold_war_01 | zj_cold_recover_01 | 画室(晚) / 图书馆(早) |

- 每角色 `cold_war`：`requireRelState:"close"` + 选项内 `relCold`，选错话好感 −15（−5 选项 + −10 冷战扣减）
- 每角色 `recover`：`requireRelState:"cold"` + `relRecover`，不带 `affDelta`（由 `recover_from_cold` 内部 +5 补偿）
- `location`/`slotId` 严格匹配角色真实地点，否则 `get_available_event` 地点过滤让事件永不可触发

## 顺带修复的缺口
原本 `events_male.json` 只有 yifei(7) / zicheng(7) 的事件，**beichen / jingjing_m / zijun 三个男角色一个事件都没有**。本次追加让他们也具备完整的冷战→挽回体验。

## 文件变更
- 修改 `scripts/events_male.json`：14 → 24 事件（仅数据追加，未触碰既有事件）
- 未动 `DataManager`（男角色文件本就在 `EVENT_FILES` 列表里）

## 校验
- 24 事件 JSON 合法；角色分布 yifei=9 / zicheng=9 / beichen=2 / jingjing_m=2 / zijun=2
- 10 个新事件 `requireRelState` / `relCold` / `relRecover` 字段全部就位，无 id 冲突

## Phase 2 收口状态
- 机制层：RelationshipManager + v6 存档 + 状态 chip + 21 天自动冷战 + 冷战增益封锁 ✅
- 内容层：10 角色（5 女 + 5 男）全部具备冷战/挽回事件 ✅
- **Phase 2 关系状态机（机制 + 内容）正式收口**

## 待用户在 Godot 验证
1. 女主路线下，与任意男角色好感≥60 后去其专属地点对应时段 → 触发"争执"
2. 选错话 → 冷战（好感 −10、增益封锁、面板🔴冷战）
3. 冷战期去对应地点对应时段 → 出现挽回事件 → 和好 +5
4. 顾北辰（D300 解锁）/ 叶明轩（青梅）/ 林紫君 同样可走完冷战→挽回
5. 旧 v5 存档读档自动升级 v6

## 可选后续
1. 给各角色**普通日常事件**加 `excludeRelState:"cold"`，防止冷战期还弹日常邀约（需逐条审事件，暂缓）
2. 进入 **Phase 3 内容厚度**：补 570 天事件密度 / 立绘多 pose / 对话润色
