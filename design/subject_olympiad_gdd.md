# Game Design Document: 学科奥数竞赛深度系统 (D线)

## 📌 一、项目概况 (Overview)
- **子系统系属**：深度长期挑战 / 数值进阶与「时间即代价」的极限考验系统
- **核心一句话**：一条为超高智商与抗压能力的玩家准备的“独木桥”。只有极其自律的人才能在兼顾全科成绩的同时，撑过漫长的奥数魔鬼集训，获得名校**提前录取权（保送）**及专属纪念画廊。
- **设计基调**：**零新 Autoload 侵入**。将极度复杂的竞赛淘汰机制，完全坍缩转换于原有的 JSON 事件链网与内置 flag 进行驱动。

---

## 🎯 二、核心机制支柱 (Core Mechanics)

### 1. 竞赛的三级跃迁网 (The Competition Chain)
学科竞赛不只是一两次简单的加分项，而是一条长达一年的地狱事件长廊，跨越初一到初三：
* **选拔赛 (Day 150 后)**：需要数学分数 (`math` 进度) >= 20 且 `intellect` (智力) >= 30 方可解锁“班主任的密谈”。选择参赛将获得 `flag_olympiad_joined`。
* **周末魔鬼集训 (Day 150～350 持续循环)**：
  - 玩家需要在周末高频消耗时间参与特殊的【奥数集训】事件。
  - 需要在 `events_life.json` 中配置连续多段相互挂钩的刷题事件链（`olympiad_training_1`, `2`, `3` ... 依链式解锁）。
  - **副作用**：极高的 Stress (压力) 上升，大幅侵占其他日常社交和社团时间。
* **市级初赛与省决 (Day 360 / Day 420 强制结算)**：
  - 由天数硬性驱动的强制遭遇事件。
  - 判定玩家收集了多少 `flag_olympiad_training_done` 层级。若中途摆烂未达标，则在初赛中直接被淘汰（获 `flag_olympiad_dropped`）；若满级突围，则获得全省一等奖金牌（`flag_olympiad_gold`）！

### 2. 回报：提前批降分录取系统 (Early Admission Concept)
在常规游戏流程中，初三最后会经过 `ExamManager.gd` 进行各科综合分的算计。
竞赛线的最强红利是颠覆此规则：
- 只要获得了 `flag_olympiad_gold`（奥赛金牌）。
- **`ExamManager` 的底层结算将被接管**：该名玩家将直接触发「特殊人才选拔保送」，无视中考实际裸分，保底录取全省最顶尖高中（如：**hz2 / xuejun**），并解锁极高特长加成评价。

### 3. 奥数竞赛纪念 CG 与画廊
成功夺金或保送成功，将作为人生极为闪耀的高光时刻。
- 画廊系统追加：【金牌的重量】（`grad_olympiad_gold`）。
- 并在 `EndingScreen.gd` 原定好结局之上，附加专版的保送成功文字提示。

---

## 🏗️ 三、实施方案建议与工程界限 (Engineering Boundaries)

### 1. 零 Autoload 实现法
- 在 `events_life.json` 追加一套 priority 极高 (220左右) 的专用子结构，利用原生的 `requireFlags` 与 `triggerDay` 设计严密的训练链路。
- 淘汰判定：使用两个带 `noTimeCost` 的结算节点（一个要 flag 高，一个兜底淘汰）。

### 2. ExamManager 结算挂入
原有的 `get_admission_result()`（位于 `scripts/GameManager.gd` 的底层由 `ExamManager` 托管处）：
```gdscript
# 在 ExamManager.get_admission_result(score) 开始处拦截：
if GameManager.flags.has("flag_olympiad_gold"):
    return {
        "success": true,
        "school": { ... 顶配 hz2 数据 ... },
        "message": "无需等待中考查分。早在一个月前，你的名字便已赫然刻在了提前批保送的红榜第一位。"
    }
```

### 3. 数据层扩展需求：
无需新开数据接口。依然可被自动编入现有 `tests/olympiad_smoke/verify_qa.py` 断言：确保 Day 150～420 的完整链不会意外阻断（或与冷战态、社团带起大面积拥塞）。

---

## 📏 四、红线与防腐

1. **不能覆盖关键叙事**：竞赛集训（周末）的带位不得打压 P0（主线冲突）、假日事件（Fest）和社团周常活动（club_weekly），竞赛玩家将体会到极致的**分身乏术感**。
2. **纯粹的公平性**：为了不让系统成为纯粹的数值堆砌，集训事件需同时增加对随机抗压事件和社交失联（冷战容易叠加）的暴露几率：因为你总在刷题。
