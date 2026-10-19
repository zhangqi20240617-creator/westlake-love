# 社团系统 · 目标层（专属事件链 / 成就 / 毕业画廊）· 游戏设计文档（GDD）

> 游戏：《西湖边的青春》（Godot 4.5 横屏手游，1280×720，GDScript）
> 任务：**DS-RN-05b · 社团目标层**（DS-RN-05 社团 MVP 已交付并放行，本层为其「目标」分层）
> 作者：design-strategist 文策渊（Vince Coyer）
> 前置 GDD：`design/club_system_gdd.md`（方案α / 红线 R1–R10 / 成功标准 S-1~S-6）
> 约束：只出设计，不写代码，不修改任何源文件。**零新增 Autoload**。不得削弱「时间即代价」支柱。
> 状态：**待主理人裁决**（§10 列 4 项待裁决决策，均已给推荐默认值）

---

## §-1 源码实证事实表

> 本章每一条均来自本次动笔前的真实读盘，标注「文件:行号」。设计的每一处门控、带位、白名单方案都锚定下表；下表之外的内容不作假设。

### -1.1 事实表（F1–F20）

| 编号 | 事实 | 出处 | 对目标层的约束 |
|---|---|---|---|
| **F1** | `events_life.json` 现有 **72** 个事件，**基准缩进 = 2 空格**（元素 2 / 键 4 / scenes 元素 6 / scene 键 8） | `events_life.json` L1548–1726（社团区块）；`grep -c '"id"'` = 72 | 本层新增事件必须**逐字符沿用 2 空格**，否则污染宿主文件风格（DS-RN-05 已踩过「记 4 实际 2」的坑） |
| **F2** | `club_join_hub`：`classroom` / `slotId:"after"` / `triggerDay:30` / **`priority:212`** / `repeatable:false` / `excludeFlags:["flag_club_joined"]`；5 选项各 `setFlag:"flag_club_joined"` + `setFlags:["flag_club_<type>"]` + 主属性 +1 | `events_life.json` L1549–1605 | 入社带位 212 已占；目标层带位须避开。**注意前置 GDD 附录 B.1 写的是 200，实际落地是 212**——以源码为准 |
| **F3** | 5×`club_weekly_<type>` 实际带位**不统一**：`literature`=60、`broadcast`=60、`astronomy`/`basketball`/`art`=**205** | L1611 / L1659 / L1635 / L1683 / L1707 | 链事件带位必须 **> 205**，才能在 5 社团中**一致地**压过周活动（否则天文/篮球/美术三社的链会被自家周活动挡死） |
| **F4** | 5×`club_weekly_<type>` 共有形状：`slotId:"after"`、`repeatable:true`、`charId:null`、`requireFlags:["flag_club_joined","flag_club_<type>"]`、`excludeFlags:["flag_club_week_done"]`、场景 `setFlag:"flag_club_week_done"`、**无 `noTimeCost`**、`statDelta` 主 +2/次 +1/`stress` +1 | L1606–1725 | 链事件复用同一形状（含**无 `noTimeCost`**），保证「时间即代价」语义一致 |
| **F5** | 周活动地点：literature→`library`、astronomy→`playground`、broadcast→`music_room`、basketball→`playground`、art→`art_room` | L1609 / L1633 / L1657 / L1681 / L1705 | 链事件沿用同地点，玩家心智一致；且 5 者全在 `SCHOOL_LOCATIONS` 内 → 长假自动抑制 |
| **F6** | 周一重置：`_check_weekly_allowance()` 内 `if day_of_week == 1:` 分支末尾 `GameManager.flags.erase("flag_club_week_done")`（**2×tab 缩进**） | `DailyCycleManager.gd` L99–102 | 「每周一次」的唯一节流阀。链事件若也 `setFlag: week_done`，即自动继承同一节流（**这是本设计的核心杠杆**） |
| **F7** | `get_available_event` 门控字段**无任何计数/数值比较型 flag 门控**：只有 `requireFlags`/`excludeFlags`（存在性判定）+ `triggerDay`/`minAff`/`minStress`/`minAddict`/`requireMoney`（固定字段数值比较） | `DataManager.gd` L225–263 | **「参与周数计数」在当前引擎下无法作为解锁门槛消费**——即使写入计数也无字段可读。见 §10 决策 1 |
| **F8** | 非 `repeatable` 事件消费机制：`if not ev.get("repeatable") and GameManager.flags.has(ev_id): continue`；`finish_event()` 完成时 `GameManager.set_flag(ev_id, true)` | `DataManager.gd` L206–208；`DialogueUI.gd` L555–557 | **事件 id 本身即 flag**。链步骤 `repeatable:false` 天然一次性，无需额外去重 |
| **F9** | 候选排序：`candidates.sort_custom(func(a,b): return a.priority > b.priority)`，**取 `candidates[0]`，无同分 tie-break 规则** | `DataManager.gd` L327–329 | 同地点同 slot 的同分事件顺序不确定 → 链事件带位须避开既有值，且链内不产生并发候选 |
| **F10** | `excludeRelState` / `requireRelState` **仅在 `charId != ""` 时求值** | `DataManager.gd` L298–306 | 链事件 `charId:null` ⇒ 加 `excludeRelState:"cold"` 是**死配置（no-op）**。见 §7 |
| **F11** | 长假期间抑制 `SCHOOL_LOCATIONS = ["classroom","library","playground","music_room","art_room"]` 的全部事件 | `DataManager.gd` L288–293 | 链事件在寒/春/暑/秋假自动停办，与长假 set-piece 零冲突 |
| **F12** | `BREAK_PERIODS`：winter[90,100] / spring[150,155] / summer[270,300] / autumn[303,309] | `DailyCycleManager.gd` L38–43 | 链 `triggerDay` 锚点须避开这四段（虽 `triggerDay` 语义为「自该天起」只会延迟不会阻断，仍应避免首触点落在假期） |
| **F13** | 场景级 `setFlags`（数组）与 `setFlag`（单值）**均支持且均调 `unlock_gallery(f)`** | `DialogueUI.gd` L202–212 | 一个场景可同时写「本周已参加」+「链步骤标记」+「成就」，且成就 flag 落下即自动解锁画廊，**无需额外解锁调用** |
| **F14** | 选项级 `skipToNextDay` 支持：`_should_skip_to_next_day = true`（L426–427），`finish_event` L577 消费 → `slot_index=0, day+=1` 并重跑日结算链（含 `_check_weekly_allowance`） | `DialogueUI.gd` L426–427、L577–586 | 「通宵赶稿」可作为**选项级**的超额时间代价，是本层强化支柱 A 的核心手牌 |
| **F15** | `finish_event()` 时段消耗：`elif not current_event.get("noTimeCost", false): GameManager.advance_time()` | `DialogueUI.gd` L590–592 | 链事件**不带 `noTimeCost`** ⇒ 确凿消耗一个 `after` 时段 |
| **F16** | `GALLERY_ITEMS` 条目 schema = `{char, pose, label, hint, flag, bg}`（+ 可选 `type:"video"`）——**没有 `id` 字段，`pose` 是事实上的标识符** | `GameManager.gd` L301–375 | 任务书所说的 `grad_club_<type>` 需落到 **`pose`** 字段，不是 `id`。见 §5 |
| **F17** | 现有 `char:"player"` 条目的 `pose` 占用：`grad_photo` / `yearbook` / `pet_orange_cat` / `west_lake_stamps` / `west_lake_fengwu`；bg 路径约定 `res://assets/backgrounds/<name>.jpg` | `GameManager.gd` L366–374 | `grad_club_*` 五个 pose 全部未占用（R5 可断言） |
| **F18** | 结局上传：`_upload_profile_on_ending` 遍历 `GALLERY_ITEMS`，把已置真的 `flag` 收进 `gallery` 数组写入 profile 的 `gallery_flags` | `EndingScreen.gd` L348–352、L381 | 成就 flag 只要**注册进 GALLERY_ITEMS**，快照阶段**自动**被携带，无需改上传侧 |
| **F19** | NG+ 起始：`GameManager.flags = {}`（L484）后**仅**回注 `ng_count`(L515) / `seen_endings`(L516) / `title_*`(L517–518)。**`gallery_flags` 从未被回注** | `EndingScreen.gd` L484、L514–518；`grep gallery_flags` 全工程仅 L381/L409 + mock_server | ⚠️ **关键缺口**：今天所有画廊 CG（含 `holiday_memory_*`/`grad_photo`/`west_lake_*`）在 NG+ 后全部丢失。成就 flag 要跨周目**必须显式回注**。见 §6 与 OQ-3 |
| **F20** | 社团面板 `_show_club_popup`（L510–546）**纯只读**，只 `flags.has()` 判定渲染，不写任何 flag；`CLUB_NAMES` 常量在 L486–492 | `MainGame.gd` L480–546 | 目标层若要在面板展示链进度/成就，**仍必须只读**（红线 R3） |

### -1.2 带位地形勘测（链事件选址的依据）

链事件只会出现在 5 个社团地点。下表是这 4 个地点在 195–300 带的**全部**竞争者（`playground` 被天文/篮球共用）：

| 地点 | 竞争者 | priority | repeatable | 门控 |
|---|---|---|---|---|
| `library` | `life_health_counseling` | 300 | false | minStress 55 |
| | `mock_stress_relief` | 230 | false | — |
| | `club_weekly_literature` | 60 | **true** | joined+type, ¬week_done |
| `playground` | `life_conflict_bystander` | 255 | false | — |
| | `grad_photo` | 240 | false | triggerDay 558 |
| | `bond_bros` | 235 | false | slotId `after` |
| | `club_weekly_astronomy` / `_basketball` | 205 | **true** | joined+type, ¬week_done |
| | `life_health_exercise_relief` | 200 | **true** | **零门控** |
| `music_room` | `club_weekly_broadcast` | 60 | **true** | joined+type, ¬week_done |
| | （195–300 带无其他竞争者） | — | — | — |
| `art_room` | `club_weekly_art` | 205 | **true** | joined+type, ¬week_done |
| | `life_health_art_relief` | 200 | **true** | **零门控** |

**读表结论**：这 4 个地点的**可重复**竞争者最高只有 **205**；≥206 即可保证链事件**永不被永久饿死**。其余竞争者全是一次性事件（230/235/240/255/300），最多造成**有界延迟**（被消费后自动让路），不构成功能死亡。

---

## §0 概览

### 0.1 特性定位

社团 MVP 交付的是**节律**（每周一次的例行活动）。目标层交付的是**弧光**——把「我每周去社团」升维成「我们做成了一件事」。

每个社团一条 4 步事件链，横跨初一下到初三，讲一个「立项 → 受挫 → 冲刺 → 成事」的完整故事；终点授予社团成就 flag，并在珍贵画廊留下一张专属毕业 CG。这是玩家三年投入的**兑现凭证**，也是社团系统从「周常」变成「记忆」的那一步。

**本层的核心机制创新**：链步骤**不额外增加**每周负担，而是**顶替**当周的例行活动（同 slot / 同地点 / 同 `week_done` 节流阀 / 更高带位）。语义即「这周社团在忙大事」。它带来三个白拿的好处：

1. 复用 F6 的周一重置阀 ⇒ 链进度天然限速 **≤1 步/周**，零新调度、零新代码；
2. 不制造第二条周常 ⇒ 不触发认知过载（前置 GDD 红线 R8）；
3. 链步骤消耗的仍是那个 `after` 时段 ⇒ 「时间即代价」原样继承，且 s3「通宵」把代价**加倍**。

### 0.2 设计支柱（2 条，与前置 GDD 同源不漂移）

- **支柱 A · 时间即代价（承接全局）**：链的每一步都真实吃掉一个 `after` 时段；s3 冲刺步提供「通宵」选项，用 `skipToNextDay`（F14）一次性吃掉**当天剩余全部时段**——这是全系统对支柱 A 最重的一次落锤。
- **支柱 B · 选择定义青春（本层深化为「兑现」）**：MVP 阶段「选哪个社团」是承诺；目标层「有没有走完那条链」是**兑现**。走完的人拿到成就与 CG，中途放弃的人什么都没有——不惩罚，但也不施舍。

> **反漂移声明**：本层**不给 money**、**不给道具**、**不进 ITEM_DB**、**属性收益总量刻意做低**（§3.7 有量化），避免变成「刷成就换数值」的主导策略。链的回报是**叙事 + 收藏 + 荣誉**，不是战力。

### 0.3 范围分层表

| 层级 | 条目 | 内容 | 交付物 |
|---|---|---|---|
| **MVP** | 5 条事件链全量 | 5 社团 × 4 步 = **20** 个 `club_chain_*` 事件，`events_life.json` 72 → **92** | 纯 JSON，零代码 |
| | 链步骤 flag 体系 | `flag_club_chain_<type>_s1..s4`（20 个） | 纯 flag 态 |
| **目标** | 社团成就 | 5 个 `flag_club_achievement_<type>`，链终点（s4）授予 | 纯 flag 态 |
| | 毕业画廊条目 | 5 条 `pose:"grad_club_<type>"` 追加进 `GALLERY_ITEMS` | `GameManager.gd` +5 行 |
| | 成就 CG 美术 | 5 张 `grad_club_<type>.jpg`（1280×720） | art-director 出图 |
| | NG+ 携带白名单 | `EndingScreen.gd` 回注 5 个成就 flag | +1 常量 +3 行 |
| **愿景** | 跨社团联动 | 「五社通」大成 CG：集齐 5 个成就 flag 解锁（承诺制下**单周目不可能**，需跨 ≥5 周目 —— 与 NG+ 携带白名单形成闭环，见 OQ-4） | CollectionManager `_check_club_completion`（比照 `_check_fengwu_completion`），愿景层再评估 |
| | 面板链进度展示 | `_show_club_popup` 只读渲染链进度条 + 成就徽章（**仍不写 flag**） | `MainGame.gd`，本层不做 |
| | 社团同伴 NPC | 链事件引入独立 NPC（需扩 `characters.json`） | 本层**明确不做**（见 §7.4） |

---

## §1 核心循环

### 1.1 微观：一次链步骤（顶替当周例行活动）

```
[after 时段，玩家进入本社团地点]
        │
        ▼
DataManager.get_available_event(loc)
  候选池同时含：club_weekly_<type> (60 或 205)
              club_chain_<type>_sN (218)   ← 两者 excludeFlags 都是 week_done
        │
        ▼  sort by priority desc → 218 胜出
命中 club_chain_<type>_sN
        │
        ▼
DialogueUI 播放链剧情（statDelta / 部分步含选项分支）
        │
        ▼
终场景 setFlag: "flag_club_week_done"          ← 继承周节流阀（F6）
        setFlags: ["flag_club_chain_<type>_sN"] ← 解锁下一步（s4 另加成就 flag）
        │
        ▼
finish_event()：
  · 无 noTimeCost → advance_time() 消耗 after 时段（F15）
  · s3 若选「通宵」→ skipToNextDay 吃掉当天剩余全部时段（F14）
  · repeatable:false → set_flag(ev_id) 永久消费（F8）
        │
        ▼
次周一 _check_weekly_allowance 擦除 week_done（F6）
  → 下一步链事件（或恢复例行活动）重新可选
```

### 1.2 宏观：三年一条链

```
Day 30   club_join_hub → 承诺一个社团
   │
   ├─ Day 30–119   每周例行活动（MVP 层），建立节律与归属
   │
   ├─ Day 120+  ┌ s1 立项：社团接下一件大事，你举了手
   │            │      ↓（≥1 周间隔，由 week_done 强制）
   ├─ Day 220+  ├ s2 受挫：事情不顺，有人退出
   │            │      ↓
   ├─ Day 340+  ├ s3 冲刺：【抉择】通宵拼一把 / 按时收工
   │            │      ↓
   └─ Day 470+  └ s4 成事：作品/比赛/播报/流星/画展落地
                        ↓
                 flag_club_achievement_<type> = true
                        ↓（F13 setFlags 自动 unlock_gallery）
                 珍贵画廊解锁「grad_club_<type>」CG
                        ↓（F18 结局上传自动纳入 gallery_flags）
                 NG+ 回注白名单携带 → 跨周目荣誉印记（§6）
```

> **锚点为何拉这么开**（120/220/340/470，间隔 100–130 天）：链是三年的**骨架**不是周常，四个节拍分别落在初一下 / 初二上 / 初二下 / 初三，与学业压力曲线共振。s3 冲刺刻意压在 340（初二下～初三初，`PRESSURE_START_DAY` 附近），让「通宵赶社刊」和「备考」正面对撞——这是支柱 A 全游戏最锋利的一刀。

---

## §2 MDA 分析

### Mechanics
- **顶替式链步骤**：与 `club_weekly` 争夺同一候选池，靠带位 218 > 205 稳定胜出；共享 `week_done` 节流阀。
- **顺序门控**：`requireFlags:[..., "flag_club_chain_<type>_s{N-1}"]` 串链，不可跳步、不可乱序。
- **时间锚点**：`triggerDay` 120/220/340/470 提供最低时间投入下限。
- **超额代价选项**：s3 提供 `skipToNextDay` 分支，用「一整天」换更高属性与更好的 s4 文本铺垫。
- **一次性消费**：全部 `repeatable:false`，走 F8 的 event-id-as-flag 消费。
- **终点授予**：s4 场景 `setFlags` 同时落链尾 flag + 成就 flag，成就 flag 即画廊 flag（F13 一步到位）。

### Dynamics
- **节律 → 弧光的相位切换**：玩家在连续数十周同质的周活动后，突然遇到 s1，产生「这个系统还有下文」的惊喜；后续每次进社团地点都带着「这周会不会是链步骤」的期待——用**间歇性强化**把周常从疲劳区拉回心流区。
- **投入沉没 → 承诺升级**：s2 受挫步刻意给**低于周活动**的属性（主 +1），制造「这周亏了」的真实感；但它推进了链。玩家在此处第一次意识到：链的价值不在数值。
- **s3 的真实两难**：通宵 = 当天剩余时段全灭 + `stress` +8（把玩家推向 `minStress` 30/35/40/45 的健康事件带，F 表 §-1.2 外的 home 侧事件）；按时收工 = 无损但拿不到最好的结果。这不是「显然选 A」的假选择。
- **跨周目收集涌现（愿景）**：承诺制 ⇒ 单周目只能拿 1 个成就；成就跨 NG+ 携带 ⇒ 集齐 5 个需 ≥5 周目。为 Achiever 型玩家提供了一条**超长期**的目标线，且完全不需要新系统。

### Aesthetics
- **胜任感（SDT · Competence）**：s4 是全系统唯一一次「你做成了一件被别人看见的事」——社刊发到每个班、播报全校听见、画挂在墙上。
- **自主感（SDT · Autonomy）**：s3 的通宵抉择是玩家自己定的价码。
- **关联感（SDT · Relatedness）**：链的叙事主语刻意用「我们」而非「我」，社团同伴以无名群像出现（不占 `charId`，见 §7.4）。
- **青春的重量**：链的成本落在初二下—初三，正是最不该分心的时候。**它本来就该很难。**

### 心流平衡（Csikszentmihalyi）
周活动是低挑战低技巧的**安全区**（防倦怠靠低频而非高刺激）；链步骤是四个间隔极远的**挑战尖峰**。尖峰间距 100+ 天，保证每次出现都是新鲜的，而不是又一个待办。

### Bartle 覆盖
| 类型 | 本层给什么 |
|---|---|
| Achiever | 5 个成就 flag + 5 张 CG + 愿景层「五社通」跨周目大成 |
| Explorer | 链只有走进社团地点才会撞见；四个锚点不公示，靠玩家自己发现 |
| Socializer | 链叙事的群像同伴、s2 的「有人退出」、s4 的集体成事 |
| Killer | 本层刻意**不提供**竞争性数值优势（防主导策略），Killer 需求由既有「全服学霸」榜承接 |

---

## §3 五条事件链逐链设计

### 3.0 全链共有规格（5×4=20 事件的公共形状）

| 字段 | 值 | 依据 |
|---|---|---|
| `id` | `club_chain_<type>_s<N>`，N∈{1,2,3,4} | 任务书命名规范；`club_chain_` 前缀全工程零占用 |
| `charId` | `null` | F10 + 性别对称（前置 S-5） |
| `location` | 同该社团 `club_weekly` 的地点（F5） | 玩家心智一致 + 长假自动抑制（F11） |
| `slotId` | `"after"` | F4，真实竞争位点 |
| `priority` | **218** | §3.1 专章论证 |
| `repeatable` | `false` | F8，一次性消费 |
| `requireFlags` | `["flag_club_joined","flag_club_<type>","flag_club_chain_<type>_s{N-1}"]`（s1 无第三项） | 顺序串链 |
| `excludeFlags` | `["flag_club_week_done"]` | **继承周节流阀**（F6），链限速 ≤1 步/周 |
| `triggerDay` | s1=120 / s2=220 / s3=340 / s4=470 | F12 全部避开 BREAK_PERIODS |
| `noTimeCost` | **不写该键** | F15，确凿消耗时段（支柱 A 红线） |
| 终场景 `setFlag` | `"flag_club_week_done"` | 与 `club_weekly` 同构 |
| 终场景 `setFlags` | `["flag_club_chain_<type>_s<N>"]`（s4 追加成就 flag） | F13 |
| `statDelta` money | **恒为 0（不写）** | 防经济失衡（前置 R6） |

> **不可跳步的双保险**：`requireFlags` 串链（正向）+ `repeatable:false` 事件消费（反向）。即使 flag 被外部误置，已消费的步骤也不会重播。

### 3.1 带位裁定：**priority = 218**（含论证）

这是本 GDD 最需要被审计的一个数字，逐条给理由：

| 判据 | 结论 |
|---|---|
| **必须 > 205** | 天文/篮球/美术三社的 `club_weekly` 是 205（F3）。链要顶替周活动，带位必须高于**全部 5 社**的周活动 ⇒ 下界 206 |
| **必须 > 200** | `life_health_exercise_relief`(playground, 200, **repeatable, 零门控**) 与 `life_health_art_relief`(art_room, 200, **repeatable, 零门控**) 是永不消失的竞争者。DS-RN-05 正是为它们才把三社抬到 205 ⇒ 链 ≥206 即安全 |
| **必须 < 260** | 健康危机带 **260–290**（insomnia 260 / body_anxiety 270 / anxiety_attack 280 / panic_prelude 290）绝对优先，**任何情况下不得被社团压制**（红线 R4）。218 与 260 之间留 42 点缓冲 |
| **必须 < 240** | `grad_photo`(playground, **240**, triggerDay 558) 是毕业 CG 事件，且**与天文/篮球链同处 playground**。若链带位 ≥240，初三末尾未走完链的玩家会被链事件顶掉毕业合影 ⇒ **这是一条硬约束**，218 完全规避 |
| **宜 < 230** | `mock_*` 考试节奏带 230、`bond_*` 社交弧 235、家庭/冲突带 240–265 均为叙事主干，社团不应插队 ⇒ 218 全部让行 |
| **须避开既有值** | F9 无 tie-break 规则。195–300 带已占用：195,200,205,210,212,215,220,225,230,235,240,245,250,251–257,260,265,270,280,290,300。**218 全工程零占用**（已 grep 验证），左右邻 215/220 均已占 |
| **留扩展余量** | 216/217/219 三个空位保留，供未来「按社团差异化带位」或插入第 5 步时使用 |

> **一个带位服务 20 个事件是否有并发风险？** 无。① 玩家只能加入 1 个社团（承诺制）⇒ 只有 1 条链的 `requireFlags` 可满足；② 链内相邻步骤靠 `flag_club_chain_*_s{N-1}` 互斥 ⇒ 任一时刻**至多 1 个** `club_chain_*` 进入候选池。故 218 上永不产生同分并发，F9 的 tie-break 缺失不构成风险。**这一点建议 quality-lead 写成正向断言。**

### 3.2 文学社 · 社刊《湖畔》 → `flag_club_achievement_literature`

地点 `library` ｜ 主属性 `intellect` / 次 `art`（对齐 F4 周活动映射）

| 步 | id | triggerDay | 标题 | 叙事梗概 | statDelta |
|---|---|---|---|---|---|
| s1 | `club_chain_literature_s1` | 120 | 📖 停刊三年的《湖畔》 | 社长从器材柜底翻出一摞旧刊，最后一期停在三年前。「要不要，我们把它办回来？」你举了手。 | intellect +2, art +1, stress +2 |
| s2 | `club_chain_literature_s2` | 220 | 📖 三篇稿子 | 征稿箱开了两周，只收到三篇，其中一篇是社长自己写的。有人开始说算了。 | intellect +1, art +2, social +1, stress +3 |
| s3 | `club_chain_literature_s3` | 340 | 📖 截稿前夜 | 排版差最后八页。窗外天黑了，明天还有一模。**【抉择】** | 见下 |
| s4 | `club_chain_literature_s4` | 470 | 📖 复刊号 | 《湖畔》复刊号发到每个班。你在走廊听见有人念出你排的那一页。 | intellect +3, art +2, charm +1, **stress −4** |

**s3 抉择**（本社 skipToNextDay 分支）
- 「熬到把它做完」：intellect +4, art +2, **stress +8**，`skipToNextDay:true` — 吃掉当天剩余全部时段
- 「按时收工，缺的版留白」：intellect +2, art +1, stress +3 — 仅正常消耗 `after`

### 3.3 天文社 · 流星观测 → `flag_club_achievement_astronomy`

地点 `playground` ｜ 主 `intellect` / 次 `social`

| 步 | id | triggerDay | 标题 | 叙事梗概 | statDelta |
|---|---|---|---|---|---|
| s1 | `club_chain_astronomy_s1` | 120 | 🔭 观测计划书 | 社长在黑板上写下极大期的日期，说今年要做一次真正的记录，不只是看看。 | intellect +2, social +1, stress +2 |
| s2 | `club_chain_astronomy_s2` | 220 | 🔭 连着七天的云 | 预演观测连着七天都是阴天。折射镜盖着防尘布，没人说话。 | intellect +1, social +2, stress +3 |
| s3 | `club_chain_astronomy_s3` | 340 | 🔭 极大夜 | 云缝开了。峰值在凌晨两点。**【抉择】** | 见下 |
| s4 | `club_chain_astronomy_s4` | 470 | 🔭 那一页记录 | 观测记录钉在社团墙上，最后一行是你写的时间与方位。 | intellect +3, social +2, charm +1, **stress −4** |

**s3 抉择**
- 「守到凌晨两点」：intellect +4, social +2, **stress +8**, `skipToNextDay:true`
- 「十点前回家」：intellect +2, social +1, stress +3

### 3.4 广播站 · 晨间播报 → `flag_club_achievement_broadcast`

地点 `music_room` ｜ 主 `charm` / 次 `social`

| 步 | id | triggerDay | 标题 | 叙事梗概 | statDelta |
|---|---|---|---|---|---|
| s1 | `club_chain_broadcast_s1` | 120 | 🎙️ 接下晨间档 | 师姐把早班的钥匙给了你：「明天七点二十，别迟到。」 | charm +2, social +1, stress +2 |
| s2 | `club_chain_broadcast_s2` | 220 | 🎙️ 三十秒空白 | 稿子翻页时卡了一下，全校听了三十秒的空白。整个上午你都不太敢抬头。 | charm +1, social +2, intellect +1, stress +3 |
| s3 | `club_chain_broadcast_s3` | 340 | 🎙️ 特别节目 | 毕业季特辑要重写一版全新的稿。旧稿也能用，但你知道那不一样。**【抉择】** | 见下 |
| s4 | `club_chain_broadcast_s4` | 470 | 🎙️ 校园之声 | 最后一次早班。你念完，把话筒推回原位，广播室的红灯灭了。 | charm +3, social +2, art +1, **stress −4** |

**s3 抉择**
- 「重写一版」：charm +4, social +2, **stress +8**, `skipToNextDay:true`
- 「沿用旧稿」：charm +2, social +1, stress +3

### 3.5 篮球队 · 年级联赛 → `flag_club_achievement_basketball`

地点 `playground` ｜ 主 `strength` / 次 `social`

| 步 | id | triggerDay | 标题 | 叙事梗概 | statDelta |
|---|---|---|---|---|---|
| s1 | `club_chain_basketball_s1` | 120 | 🏀 报名表 | 年级联赛的报名表贴在公告栏。教练念首发名单时念到了你。 | strength +2, social +1, stress +2 |
| s2 | `club_chain_basketball_s2` | 220 | 🏀 小组赛第二场 | 输了十七分。更衣室里没人说话，队长把球衣叠了三遍。 | strength +1, social +2, charm +1, stress +3 |
| s3 | `club_chain_basketball_s3` | 340 | 🏀 半决赛前 | 战术板上还有两套没跑熟。灯要关了。**【抉择】** | 见下 |
| s4 | `club_chain_basketball_s4` | 470 | 🏀 最后一场 | 哨响。比分不重要了——这支队站到了最后一场。 | strength +3, social +2, charm +1, **stress −4** |

**s3 抉择**
- 「留下来把它跑熟」：strength +4, social +2, **stress +8**, `skipToNextDay:true`
- 「明天再练」：strength +2, social +1, stress +3

### 3.6 美术社 · 画展 → `flag_club_achievement_art`

地点 `art_room` ｜ 主 `art` / 次 `charm`

| 步 | id | triggerDay | 标题 | 叙事梗概 | statDelta |
|---|---|---|---|---|---|
| s1 | `club_chain_art_s1` | 120 | 🎨 主题：我的西湖 | 校庆画展征稿。老师说尺寸随意，但要是你自己真的看见过的。 | art +2, charm +1, stress +2 |
| s2 | `club_chain_art_s2` | 220 | 🎨 第三稿被否 | 「技术没问题，但这张画里没有你。」老师把画放回架子上。 | art +1, charm +2, intellect +1, stress +3 |
| s3 | `club_chain_art_s3` | 340 | 🎨 布展前夜 | 天还没干透，明天九点开展。**【抉择】** | 见下 |
| s4 | `club_chain_art_s4` | 470 | 🎨 开幕 | 画挂在进门第二幅。有个低年级的学生在你的画前站了很久。 | art +3, charm +2, social +1, **stress −4** |

**s3 抉择**
- 「重画一张」：art +4, charm +2, **stress +8**, `skipToNextDay:true`
- 「交现在这张」：art +2, charm +1, stress +3

### 3.7 数值总量核验（防主导策略，前置红线 R1）

| 口径 | 主属性总收益 |
|---|---|
| 单条链全部 4 步（s3 走通宵） | **+12**（2+1+4+3+2 含次属性溢出，主属性口径 2+1+4+3 = **+10**） |
| 单条链全部 4 步（s3 走按时） | 主属性 **+8** |
| 对照：`club_weekly` 三年累计（day30→570，约 **77** 周） | 主属性 **+154** |
| **链占比** | **约 5%–6.5%** |

**结论**：链的属性收益相对周活动累计**可忽略**，相对学习收益更是零头。链**不构成任何数值上的主导策略**，其价值 100% 落在叙事 / 收藏 / 成就。此表建议直接转成 quality-lead 的数值上界断言（S-6）。

**stress 侧**：全链净 stress = 2+3+8−4 = **+9**（通宵路线）或 2+3+3−4 = **+4**（按时路线）。通宵路线会把玩家推近 `minStress` 30/35/40/45 的家庭/健康事件门槛——**这是刻意的系统耦合**：深度投入社团 → 压力累积 → 健康事件在 `home` 触发。因链事件在校内地点、健康事件在 `home`/`community`，**地点天然隔离 + 带位 218 < 260 双重保险**，健康带绝不会被压制。

### 3.8 边缘情况（EC-1 ~ EC-8）

| 编号 | 情况 | 判定与处置 |
|---|---|---|
| **EC-1** | `triggerDay` 到点但玩家整周不去社团地点 | 链无限期等待（`triggerDay` 是「自该天起」F7）。**接受**——不去就没有，符合支柱 B |
| **EC-2** | 链步骤可用时正处长假 | `SCHOOL_LOCATIONS` 抑制（F11）→ 假期结束自动恢复。**接受**，仅延迟 |
| **EC-3** | 文学社链在 library 被 `life_health_counseling`(300) / `mock_stress_relief`(230) 顶掉 | 二者均 `repeatable:false`，消费后自动让路。最坏延迟 2 周。**接受**（若不接受则须把链抬到 ≥301，将连带压死 grad/健康带，代价远大于收益） |
| **EC-4** | 天文/篮球链在 playground 被 `bond_bros`(235,after) / `life_conflict_bystander`(255) / `grad_photo`(240) 顶掉 | 同 EC-3，均一次性。**特别注意 `grad_photo` 在 day 558**：s4 锚点 470 距其 88 天，正常玩家早已完成，不构成冲突 |
| **EC-5** | s3 选「通宵」且当天是**周日** | `skipToNextDay` → day+1 → `day_of_week==1` → `_check_weekly_allowance` 立即擦除 `week_done`（F14 调用链）⇒ 玩家当次会话内可再做一次周活动。**净收益 ≈ 主属性 +2**。判定：**接受**（代价是 3 个时段 + stress +8，远超收益；且全周目至多 1 次）。已知、可控、不修 |
| **EC-6** | s3 选「通宵」发生在 day 569（毕业前夜） | s3 锚点 470，且需先走完 s1/s2，实际不可能落到 569。但为杜绝 BUG-ME-01 类事故，**建议 quality-lead 断言：`club_chain_*` 全部 `triggerDay ≤ 470`，且带 `skipToNextDay` 的分支不与 day 569 共存** |
| **EC-7** | NG+ 后成就 flag 已携带，玩家重走同一条链到 s4 | s4 的 `setFlags` 重复置真同一 flag —— `set_flag` 幂等，`unlock_gallery` 有 `not has()` 守卫（`CollectionManager.gd` L34）。**无副作用**。⚠️ 严禁给链事件加 `excludeFlags:["flag_club_achievement_*"]`（否则 NG+ 链直接死亡）→ 立为红线 R6 |
| **EC-8** | 玩家未入社（无 `flag_club_joined`） | `requireFlags` 第一项即拦截，20 个链事件全部不可见。**天然安全** |

---

## §4 成就系统设计

### 4.1 授予模型：**链终点一次性**（推荐）

`club_chain_<type>_s4` 的终场景一次性落三个 flag：

```
setFlag : "flag_club_week_done"
setFlags: ["flag_club_chain_<type>_s4", "flag_club_achievement_<type>"]
```

**为什么不用「累计阈值」**：F7 已证明引擎**没有任何计数型 flag 门控**——即使在周一钩子里累加一个 `club_weeks` 整数，`get_available_event` 也**没有字段可以读它**。要支持阈值必须给 `DataManager` 新增门控字段（如 `requireFlagGte`），那是引擎级改动，超出本层范围且会波及全部 245 个事件的门控语义。**终点授予是当前引擎下唯一零代码、可断言、可审计的方案。**

叙事上它也更对：成就应该奖励「做成了」，而不是「来够了次数」。后者会诱导 Achiever 无脑刷周常（前置红线 R1 明令禁止的主导策略形态）。

### 4.2 flag 命名（5 个，最终）

```
flag_club_achievement_literature    社刊主编      —— 《湖畔》复刊
flag_club_achievement_astronomy     星轨记录者    —— 流星雨观测记录
flag_club_achievement_broadcast     校园之声      —— 晨间播报毕业特辑
flag_club_achievement_basketball    联赛首发      —— 年级联赛站到最后
flag_club_achievement_art           画展参展者    —— 校庆画展开幕
```

**命名空间安全**：`club_` 前缀在 DS-RN-05 已确认独占；`flag_club_achievement_` 子空间当前零占用。它**不以 `title_` 开头**，故不会被 `_upload_profile_on_ending` 的 titles 收集器（`EndingScreen.gd` L340–342）误捞进「称号」——这是刻意的：社团成就是**画廊态**不是**称号态**，走 `gallery_flags` 通道（F18）。

### 4.3 与 `club_weekly` / `week_done` 的协同（零冲突论证）

| 潜在冲突 | 为何不发生 |
|---|---|
| 链事件与周活动**同时**触发 | 不可能。`get_available_event` 只返回 `candidates[0]`（F9），带位 218 > 205/60 ⇒ 链步骤可用时必然独占 |
| 链吃掉 `week_done` 后玩家本周**无法再做周活动** | **这是设计意图**，非缺陷。链步骤 = 当周的社团活动。玩家不会「少一次」，只会「这次不一样」 |
| 链事件**不设** `week_done` 会怎样 | 会破坏 ≤1步/周 限速，且允许同周连吃两次社团时段。**明确禁止**（红线 R7） |
| 周一重置擦除 `week_done` 会**误伤**链进度 | 不会。F6 只 `erase("flag_club_week_done")` 单键，`flag_club_chain_*` / `flag_club_achievement_*` 均不在其射程内。`DailyCycleManager.gd` **零改动** |
| 成就 flag 被 `excludeFlags` 误用导致 NG+ 链死锁 | 由红线 R6 明令禁止 + S-5 断言拦截 |

> **本层对 `DailyCycleManager.gd` / `MainGame.gd` / `DataManager.gd` / `DialogueUI.gd` 的改动量 = 0。** 唯二触碰源码的是 `GameManager.gd`（+5 行画廊）与 `EndingScreen.gd`（+1 常量 +3 行回注）。

---

## §5 毕业画廊条目

### 5.1 schema 澄清（重要）

任务书写的「id 如 `grad_club_<type>`」需要落地校正：**`GALLERY_ITEMS` 条目没有 `id` 字段**（F16）。其 schema 是 `{char, pose, label, hint, flag, bg}`，其中 **`pose` 是事实上的标识符**（现有 player 条目用 `grad_photo`/`yearbook`/`pet_orange_cat`/`west_lake_stamps`/`west_lake_fengwu`）。

故：`grad_club_<type>` → 落到 **`pose`** 字段；`char` 统一为 `"player"`（与 `grad_photo`/`yearbook` 一致，性别对称）。

### 5.2 五条待追加条目（追加到 `GameManager.gd` L374 之后、L375 `]` 之前）

| pose | label | flag | bg |
|---|---|---|---|
| `grad_club_literature` | 社刊《湖畔》·复刊号 | `flag_club_achievement_literature` | `res://assets/backgrounds/grad_club_literature.jpg` |
| `grad_club_astronomy` | 流星观测·那一夜的记录 | `flag_club_achievement_astronomy` | `res://assets/backgrounds/grad_club_astronomy.jpg` |
| `grad_club_broadcast` | 校园之声·最后一次早班 | `flag_club_achievement_broadcast` | `res://assets/backgrounds/grad_club_broadcast.jpg` |
| `grad_club_basketball` | 年级联赛·站到最后一场 | `flag_club_achievement_basketball` | `res://assets/backgrounds/grad_club_basketball.jpg` |
| `grad_club_art` | 校庆画展·进门第二幅 | `flag_club_achievement_art` | `res://assets/backgrounds/grad_club_art.jpg` |

完整可拷贝片段见 **附录 B**。

### 5.3 解锁通道（零额外代码）

F13 已证：场景级 `setFlags` 逐项调用 `GameManager.set_flag(f,true)` **且** `GameManager.unlock_gallery(f)`。因此 s4 落下 `flag_club_achievement_<type>` 的**同一瞬间**画廊即解锁，**不需要任何额外的解锁调用、不需要碰 `CollectionManager`**。这与 `holiday_memory_*` 的解锁路径完全同构。

### 5.4 美术需求（→ art-director）

- **数量**：5 张，1280×720，JPG，路径 `assets/backgrounds/grad_club_<type>.jpg`
- **调性**：与 `grad_photo.jpg` / `holiday_*` 同一画风；画面主体是**成果物**而非人物（社刊摊在桌上 / 观测记录本与夜空 / 熄灭的广播红灯 / 空球场与地上的球 / 展墙上的那幅画），**不出现玩家立绘**——保证性别对称（前置 S-5）
- ⚠️ **交付硬阻塞（沿用 DS-RN-04 教训）**：新图必须在 Godot 4.5 编辑器中打开工程一次以生成 `.import` 文件，否则**导出包不含该资源，实机读不到**。`west_lake_fengwu_complete.jpg` 已因此进入发布清单，本次 5 张图请一次性避免。
- ⚠️ AI 生成图请检查右下角水印（同 DS-RN-04 遗留）。

---

## §6 NG+ 携带白名单方案

### 6.1 现状与缺口（F19，必读）

```
EndingScreen.gd L484   GameManager.flags = {}          ← 全清
             L515      flags["ng_count"]     = ...      ┐
             L516      flags["seen_endings"] = ...      ├ 仅此三类被回注
             L517-518  flags["title_" + t]   = true     ┘
```

`gallery_flags` 在 L381 被**写入** profile、在 L409 被**并集合并**，但**从未被回注 `GameManager.flags`**。经全工程 grep 确认（`gallery_flags` 仅出现在 EndingScreen L381/L394/L409 与 mock_server），**今天所有画廊 CG 在 NG+ 后一律丢失**。

> 这是一个**既有的、超出本层范围的缺口**（影响 `holiday_memory_*` ×10、`grad_photo`、`yearbook`、`pet_orange_cat`、`west_lake_stamps_complete`、`west_lake_fengwu_complete`）。本 GDD **不擅自扩大范围去修它**，但必须登记为 **OQ-3** 上报主理人。

### 6.2 本层要求的改动（最小范围，精确到 5 个 flag）

**须加入回注白名单的 flag（共 5 个）**：

```
flag_club_achievement_literature
flag_club_achievement_astronomy
flag_club_achievement_broadcast
flag_club_achievement_basketball
flag_club_achievement_art
```

**建议实现**（`EndingScreen.gd`，4 空格缩进匹配宿主）：

```gdscript
# —— 文件头部常量区 —— #
## DS-RN-05b · 社团目标层：跨周目携带的社团荣誉 flag（显式白名单，勿用前缀通配）
## 这 5 个同时也是 GALLERY_ITEMS 的 flag，故已由 _upload_profile_on_ending
## 的 gallery 收集器（L348-352）自动写入 profile.gallery_flags，此处只做「回注」。
const CLUB_ACHIEVEMENT_FLAGS := [
    "flag_club_achievement_literature",
    "flag_club_achievement_astronomy",
    "flag_club_achievement_broadcast",
    "flag_club_achievement_basketball",
    "flag_club_achievement_art",
]

# —— 回注点：L518「for t in inherited_titles」循环之后 —— #
var inherited_gallery: Array = src.get("gallery_flags", [])
for g in CLUB_ACHIEVEMENT_FLAGS:
    if g in inherited_gallery:
        GameManager.flags[g] = true
```

**为什么用显式常量数组而不是 `begins_with("flag_club_achievement_")` 前缀过滤**：显式列表可被 quality-lead 断言「恰好 5 项、逐字符匹配 GALLERY_ITEMS 的 flag」，前缀过滤则无法断言完整性且会静默吞掉拼写错误。可审计性优先。

**上传侧改动 = 0**：F18 已证成就 flag 一旦注册进 `GALLERY_ITEMS`，L348–352 的收集器自动把它捞进 `gallery_flags`。

### 6.3 为什么要携带（设计论证）

1. **呼应既有 NG+ 继承支柱**：项目已携带称号 / 食谱 / 金币 / 好感 20% / 分科 30%（MEMORY「NG+继承」）。社团荣誉与「称号」同属**身份印记**类，不携带则语义不一致。
2. **承诺制的必然推论**：一周目只能加入 1 个社团 ⇒ 一周目只能拿 1 个成就。若不携带，玩家**永远**只能同时拥有 1 张社团 CG，画廊里另外 4 格永远是灰的——这是对收集欲的纯粹挫败。携带之后，5 张 CG 变成一条跨 ≥5 周目的长线目标（愿景层「五社通」的地基）。
3. **它不破坏平衡**：成就 flag **不给任何属性、金钱、道具**，只解锁画廊图。携带的是**记忆**，不是**优势**——与「金币携带」相比，它对新周目难度的影响严格为 0。

### 6.4 链事件在 NG+ 下如何自然重置（零额外处理）

`flags = {}`（L484）之后：

| flag | NG+ 后状态 | 后果 |
|---|---|---|
| `flag_club_joined` / `flag_club_<type>` | **清空** | `club_join_hub`（`excludeFlags:["flag_club_joined"]`）复活 → day30 重新选社团 ✓ |
| `flag_club_week_done` | **清空** | 周活动立即可用 ✓ |
| `flag_club_chain_<type>_s1..s4` | **清空** | 链回到起点 ✓ |
| `club_chain_<type>_s1..s4`（event-id 消费 flag，F8） | **清空** | 20 个链事件全部重新可触发 ✓ |
| `flag_club_achievement_<type>` | **由 §6.2 回注** | 画廊保留；且**不被任何 `excludeFlags` 引用**（红线 R6）⇒ 不阻断重走 ✓ |

**结论**：链的「一次性消费」语义完全依赖 `flags`，而 NG+ 整体清 `flags`（这也是 DS-RN-05 已验证的机制），因此**链在 NG+ 下自动、完整地重置，无需任何额外代码**。唯一需要人工干预的就是 §6.2 那 5 个成就 flag 的**反向**保留。

---

## §7 跨 GDD 一致性

### 7.1 与 DS-RN-05 社团 MVP

| 接口 | 一致性保证 |
|---|---|
| `club_weekly_*` 行为 | **零改动**（红线 R2）。链靠带位 218 顶替，不修改周活动任何字段 |
| `week_done` 节流阀 | 链继承而非另起。`DailyCycleManager.gd` L99–102 零改动 |
| 承诺制（不可转社） | 链完全建立在「单社团」前提上（§3.1 并发论证依赖此前提）。**若未来开放转社，本层设计需重新评审**——转社会导致玩家持有两个 `flag_club_<type>`，届时 218 单带位会产生同分并发（F9 无 tie-break）。**登记为 OQ-5** |
| 面板只读 | 本层不改 `_show_club_popup`（红线 R3）。链进度展示列入愿景层 |
| 带位 205 偏差 | 本层带位 218 是在**已裁决的 205 偏差之上**做的选择，未推翻该裁决，反而依赖它（§3.1） |

### 7.2 与 DS-RN-04 西湖风物志

- 链事件**不使用** `grantFengwu`（该字段是 `CollectionManager.grant_fengwu` 的唯一授予通道，24 槽已锁死）——零交叉。
- 链事件**不新增 ITEM_DB 条目**。⚠️ `ShopUI.update_shop_list()` **无条件遍历 ITEM_DB**（`GameManager.gd` L267 注释），任何新增 item 都会自动上架商店。本层零 item ⇒ 商店零污染。
- 手作带位 251–257 与本层 218 无重叠；手作在 `home`，链在校内 ⇒ 地点亦隔离。

### 7.3 与关系状态机（Phase 2 / `excludeRelState`）

**结论：链事件不需要、也不应该加 `excludeRelState:"cold"`。** 两条理由：

1. **技术上是死配置**：F10 已证 `excludeRelState` 仅在 `charId != ""` 时求值（`DataManager.gd` L298–306）。链事件 `charId:null` ⇒ 该字段**永不被读取**。写了等于没写，反而误导后续审计者以为有防护。
2. **语义上不需要**：Phase 3 加 `excludeRelState:"cold"` 的目的是「冷战期不弹与该角色的日常互动」。链事件是**社团集体叙事**，不指向任何攻略角色，冷战与否与它无关。玩家和陈雨桐冷战，不影响社刊要出版。

> **推论（须写入实现规范）**：链事件必须保持 `charId: null`。一旦给某个链事件设了 `charId`，会连带触发 `finish_event` L558–566 的 `last_interact_<char>` 写入与日记条目、并进入 `_get_target_char_ids()` 的性别过滤（破坏 S-5 双路线对称）。**这是本层最容易被"顺手优化"破坏的地方**，建议 quality-lead 写成断言。

### 7.4 关于社团同伴 NPC（前置 OQ-5 的回答）

**本层明确不引入独立社团同伴 NPC。** 理由：新增 `charId` 需扩 `characters.json` + 立绘资产 + 性别对称双份（男女主各一套同伴）+ 关系状态机接入，成本量级远超本层；且会立即引爆 §7.3 的 `charId` 连锁问题。链叙事中的同伴一律以**无名群像**出现（「社长」「师姐」「队长」「老师」），用括号叙述体承载——与 `club_weekly` 现有文风（L1619/L1643/L1667/L1691/L1715 全部是无 speaker 的括号叙述）完全一致。

### 7.5 与长假 set-piece / 记忆回响

- 长假：链地点全在 `SCHOOL_LOCATIONS`（F11）⇒ 自动停办，零冲突。
- 记忆回响：链事件**不带** `noTimeCost`（F15），与回响的免时段语义明确区分，不污染 `DialogueUI` L590 的短路分支。
- 链的 s4 CG 走 `GALLERY_ITEMS`，与 `holiday_memory_*` 同一通道、同一 schema，画廊 UI 零改动。

### 7.6 与毕业事件（`grad_*`）

`grad_yearbook`(555) / `grad_photo`(558) / `grad_dinner`(562) / `grad_lastclass`(565) 全部 priority **240**。链带位 218 < 240 ⇒ **链永远不会顶掉毕业 set-piece**。特别是 `grad_photo` 与天文/篮球链同处 `playground`——这是选择 218 而非 245 的**决定性理由**之一（§3.1）。

---

## §8 设计红线

| 编号 | 红线 | 违反后果 | 断言方式 |
|---|---|---|---|
| **R1** | **零新增 Autoload** | 破坏架构约定 | `project.godot` `[autoload]` 段恒为 **15** 项 |
| **R2** | **不改 `club_weekly_*` 既有行为** | DS-RN-05 质量门回归 | 5 个 `club_weekly_*` 的全部字段与 `events_life.json` L1606–1725 逐字符一致 |
| **R3** | **社团面板只读，不写任何 flag** | 绕过「时间即代价」（支柱 A） | `MainGame.gd` `_show_club_popup` 内零 `set_flag`/`flags[...]=` 写操作 |
| **R4** | **链带位不得压制健康事件带 260–290，亦不得压制毕业带 240** | 健康危机 / 毕业 set-piece 静默失效 | 全部 `club_chain_*` 的 `priority` **恒为 218**；`218 < 240 < 260` |
| **R5** | **画廊条目不得占用既有 id** | 画廊条目冲突 / 覆盖 | 5 个新 `pose` ∉ {grad_photo, yearbook, pet_orange_cat, west_lake_stamps, west_lake_fengwu, …}；5 个新 `flag` 在 `GALLERY_ITEMS` 内唯一 |
| **R6** | **严禁在任何链事件的 `excludeFlags` 中引用 `flag_club_achievement_*`** | NG+ 携带成就后链**永久死锁**，玩家无法重走（EC-7） | 全部 `club_chain_*` 的 `excludeFlags` **恒等于** `["flag_club_week_done"]` |
| **R7** | **每个链事件终场景必须 `setFlag: "flag_club_week_done"`** | 失去 ≤1步/周 限速，同周可连吃多个社团时段，支柱 A 漂移 | 20 个链事件逐个校验终场景含该键 |
| **R8** | **链事件不得带 `noTimeCost`** | 社团零时段成本，支柱 A 崩塌 | 20 个链事件 JSON 中 `noTimeCost` 键出现次数 = **0** |
| **R9** | **链事件不得给 `money`、不得新增 ITEM_DB 条目** | 经济失衡（兼职 +80/周基线）+ 商店自动上架污染（§7.2） | 20 个链事件 `statDelta` 中无 `money` 键；`ITEM_DB` 条目数不变 |
| **R10** | **链事件 `charId` 恒为 `null`** | 破坏双路线对称（S-5）+ 误触 `last_interact_*` / 关系机（§7.3） | 20 个链事件 `charId` 全为 `null` |
| **R11** | **`events_life.json` 缩进恒为 2 空格** | 污染宿主文件风格（DS-RN-05 已踩坑） | 新增区块缩进与 L1548 起的社团区块逐字符一致 |

---

## §9 成功标准

| 编号 | 标准 | 可断言的验证方式 |
|---|---|---|
| **S-1** | **5 条链各 4 个事件，全部可从入社后顺序触发** | ① `events_life.json` 含且仅含 20 个 `^club_chain_` 事件，`72 → 92`；② 每条链 s1..s4 的 `requireFlags` 严格串成 `joined+type → s1 → s2 → s3`；③ 模拟推演：`flag_club_joined+flag_club_<type>` 置真、day 逐步推进、每周去一次本社地点 ⇒ 4 步全部可达，**无死锁、无跳步** |
| **S-2** | **成就 flag 在链终点授予，且仅在链终点** | ① 5 个 `club_chain_*_s4` 的终场景 `setFlags` 含对应 `flag_club_achievement_<type>`；② 全工程 `flag_club_achievement_` 的**写入点恰好 5 处**（均在 s4），零其他授予路径 |
| **S-3** | **5 个 `grad_club_*` 已注册进 `GALLERY_ITEMS` 且可解锁** | ① `GameManager.GALLERY_ITEMS` 新增恰好 5 条，`char=="player"`，`pose` ∈ 5 个 `grad_club_*` 且全工程唯一；② 每条 `flag` 与对应成就 flag **逐字符相等**；③ 5 个 `bg` 文件存在**且各自有 `.import` 同名文件**（DS-RN-04 教训）；④ 置真成就 flag ⇒ `is_gallery_unlocked` 返回 true |
| **S-4** | **NG+ 清档后成就 flag 保留、链可从头重走** | ① `EndingScreen.CLUB_ACHIEVEMENT_FLAGS` 恰好 5 项且与 GALLERY_ITEMS 的 flag 逐字符一致；② 模拟 NG+：`flags={}` → 回注后，`flag_club_achievement_*` 存活、`flag_club_joined`/`flag_club_chain_*`/`club_chain_*` 全部消失；③ 回注后 `club_join_hub` 与 `club_chain_*_s1` 重新可触发（**R6 反向验证**） |
| **S-5** | **带位与红线全绿（零回归）** | ① 20 个链事件 `priority` **恒为 218**，且 218 在全 11 个事件文件中**仅**被这 20 个占用；② `noTimeCost` 出现 0 次；③ `charId` 全 `null`；④ `excludeFlags` 全为 `["flag_club_week_done"]`；⑤ 终场景 `setFlag` 全为 `flag_club_week_done`；⑥ `statDelta` 无 `money` 键 |
| **S-6** | **数值不构成主导策略** | ① 单链主属性总收益（通宵路线）≤ **+10**，≤ `club_weekly` 三年累计（+154）的 **7%**；② 全链净 `stress` ≥ **+4**（即链**净增压**，不得成为解压手段）；③ `ITEM_DB` 条目数与本层前一致 |
| **S-7** | **既有质量门零回归** | 重跑 `tests/club_smoke/verify_qa.py`(100/100)、`tests/fengwu_smoke/verify_qa.py`(51/51)、`tests/memory_echo_smoke/verify_qa.py`(286/286)、`tests/fest_smoke/verify_qa.py`(50/50) 全部 PASS；`project.godot` autoload 恒 15 |

---

## §10 待裁决决策（推荐默认值已标注，请主理人拍板）

### 决策 1 · 解锁门槛：参与周数计数 vs 显式里程碑 flag

> **推荐：显式里程碑 flag + `triggerDay` 时间锚点（120/220/340/470）。这不是偏好，是引擎硬约束下的唯一可行解。**

- **计数方案在当前引擎下不可实现**：F7 已证 `get_available_event` **没有任何计数型 / 数值比较型 flag 门控**。即使在周一钩子里累加 `club_weeks`，门控层也**没有字段能读它**。要支持必须给 `DataManager` 新增 `requireFlagGte` 之类的门控字段——引擎级改动，波及全部 245 个事件的门控语义，远超本层范围。
- **`triggerDay` 是天然的时间投入代理**：s1=120 意味着入社（day30）后至少 **13 周**；s4=470 意味着至少 **63 周**的社团生涯。配合「≤1步/周」的 `week_done` 限速，链**不可能被速通**。
- **阈值取值理由**：120 / 220 / 340 / 470，间隔 100–130 天，分别落在初一下 / 初二上 / 初二下—初三初 / 初三，四个节拍与学业压力曲线共振；全部避开 `BREAK_PERIODS`（F12）。

> **可选加强（需主理人额外批准，因为它触碰 `club_weekly` 的 JSON）**：给 5 个 `club_weekly_<type>` 的终场景追加 `"setFlags": ["flag_club_active_<type>"]`（幂等、纯追加、不改任何既有键），再让 s1 的 `requireFlags` 加上它。这样门槛就从「时间够了」升级为**「确实参加过至少一次」**，堵住「入社后从不参加也能撞见链」的口子。
> 代价：形式上触碰了 `club_weekly`（红线 R2）。判定：**建议采纳**——改动是纯追加、幂等、零行为变更，收益是把软时间门变成硬参与门。**但必须由主理人明示放行 R2 的这一处豁免。**

### 决策 2 · 每条链事件数与 repeatable

> **推荐：4 步 / 链（共 20 事件），全部 `repeatable: false`。**

- **为什么是 4 不是 3**：3 步只够「开始—做—完成」，装不下**受挫**。s2 的挫折是整条链唯一让玩家意识到「链的价值不在数值」的地方（它刻意给低于周活动的收益），删掉它，链就退化成三次领奖。
- **为什么是 4 不是 5**：5×5=25 事件，锚点间距被压到 ~85 天，链的「稀有事件」质感会被稀释成半个周常；且 20 已是 `events_life.json` 单次最大增量（72→92，+28%）。
- **为什么全部 `repeatable:false`**：链是一次性叙事；F8 的 event-id-as-flag 天然提供消费保证，零额外成本。**若任一步误设 `repeatable:true`，该步会在每周 `week_done` 重置后无限重播、链永远走不到下一步**——建议 quality-lead 对这一项做变异测试。

### 决策 3 · 成就授予：链终点一次性 vs 累计阈值

> **推荐：链终点一次性（s4 授予）。**

技术理由同决策 1（无计数门控可读）。设计理由：终点授予奖励**「做成了」**，阈值授予奖励**「来够了」**——后者会诱导 Achiever 无脑刷周常，正是前置 GDD 红线 R1 点名禁止的主导策略形态。详见 §4.1。

### 决策 4 · 画廊 CG：每社 1 张 vs 更有层次

> **推荐：MVP 每社 1 张（5 张），层次留给愿景层的「五社通」大成 CG。**

- **每社 1 张**：与 5 个成就一一对应，解锁语义最干净（S-3 可逐条断言）；美术成本 5 张可控。
- **不做「每链多张」**：例如每链 2 张（立项照 + 成果照）会把美术成本翻倍到 10 张，但**中间张没有成就语义**，只能挂在 `flag_club_chain_*_s2` 这类过程 flag 上——而过程 flag **不在 NG+ 携带白名单内**，玩家 NG+ 后会看到「成果 CG 还在、过程 CG 没了」的**不一致画廊**。设计上不干净，明确不推荐。
- **层次感的正确去处**：愿景层的**「五社通」大成 CG**（第 6 张）——集齐 5 个成就 flag 解锁。承诺制下单周目不可能，需跨 ≥5 周目，**与 §6 的 NG+ 携带白名单天然闭环**，是本层设计里性价比最高的长线钩子。它需要一个 `CollectionManager._check_club_completion()`（可完全比照既有的 `_check_fengwu_completion` / `_check_stamp_completion`，零新 Autoload）。**建议单独立项为 DS-RN-05c**，不塞进本层。

---

## 附录 A · 事件 JSON 范本（完整可拷贝，**2 空格缩进**）

> 追加位置：`events_life.json` **L1725 `}` 之后、L1726 `]` 之前**（即 `club_weekly_art` 之后、数组闭合之前）。
> 下面给出**文学社完整 4 步**作为范本；其余 4 社按 §3.3–3.6 的表格替换 `location` / 属性键 / flag 名 / 文案即可，**结构字段逐字符相同**。

### A.1 s1 · 立项

```json
  {
    "id": "club_chain_literature_s1",
    "charId": null,
    "location": "library",
    "slotId": "after",
    "triggerDay": 120,
    "priority": 218,
    "repeatable": false,
    "requireFlags": ["flag_club_joined", "flag_club_literature"],
    "excludeFlags": ["flag_club_week_done"],
    "title": "📖 社刊 · 停刊三年的《湖畔》",
    "scenes": [
      {
        "speaker": null,
        "text": "（社长从器材柜最底下拖出一摞旧刊，封面积了灰。《湖畔》——校文学社社刊，最后一期停在三年前的春天。）"
      },
      {
        "speaker": null,
        "text": "「要不要，」社长把最上面那本推到桌子中间，「我们把它办回来？」\n（长桌那头安静了几秒。你先举了手。）",
        "statDelta": { "intellect": 2, "art": 1, "stress": 2 },
        "setFlag": "flag_club_week_done",
        "setFlags": ["flag_club_chain_literature_s1"],
        "next": 99
      }
    ]
  },
```

### A.2 s2 · 受挫

```json
  {
    "id": "club_chain_literature_s2",
    "charId": null,
    "location": "library",
    "slotId": "after",
    "triggerDay": 220,
    "priority": 218,
    "repeatable": false,
    "requireFlags": ["flag_club_joined", "flag_club_literature", "flag_club_chain_literature_s1"],
    "excludeFlags": ["flag_club_week_done"],
    "title": "📖 社刊 · 三篇稿子",
    "scenes": [
      {
        "speaker": null,
        "text": "（征稿箱在走廊立了两周。今天开箱，里面躺着三篇——其中一篇是社长自己写的。）"
      },
      {
        "speaker": null,
        "text": "「一本刊物要三十页。」有人小声说。「算了吧。」\n（你把那三篇摊在桌上，一篇一篇读完。读到第三篇的最后一行时，你决定去每个班要一次。）",
        "statDelta": { "intellect": 1, "art": 2, "social": 1, "stress": 3 },
        "setFlag": "flag_club_week_done",
        "setFlags": ["flag_club_chain_literature_s2"],
        "next": 99
      }
    ]
  },
```

### A.3 s3 · 冲刺（含 `skipToNextDay` 抉择 + 汇合场景）

> **要点**：两个选项各带自己的 `statDelta` 与（可选）`skipToNextDay`，`next` 同时指向 **scene index 2**；由汇合场景统一落 flag。避免在两个分支重复写 flag（DRY，且防止改一处漏一处）。
> `skipToNextDay` 的选项级支持见 `DialogueUI.gd` L426–427；消费见 L577–586。

```json
  {
    "id": "club_chain_literature_s3",
    "charId": null,
    "location": "library",
    "slotId": "after",
    "triggerDay": 340,
    "priority": 218,
    "repeatable": false,
    "requireFlags": ["flag_club_joined", "flag_club_literature", "flag_club_chain_literature_s2"],
    "excludeFlags": ["flag_club_week_done"],
    "title": "📖 社刊 · 截稿前夜",
    "scenes": [
      {
        "speaker": null,
        "text": "（排版差最后八页。窗外天已经全黑了，图书馆的管理员来问过两次要不要关灯。）\n（明天上午有一模。桌角是你还没动过的复习卷。）",
        "choices": [
          {
            "text": "熬到把它做完",
            "statDelta": { "intellect": 4, "art": 2, "stress": 8 },
            "skipToNextDay": true,
            "next": 1
          },
          {
            "text": "按时收工，缺的版留白",
            "statDelta": { "intellect": 2, "art": 1, "stress": 3 },
            "next": 2
          }
        ]
      },
      {
        "speaker": null,
        "text": "（最后一页拼完时，窗户外面已经泛白了。你趴在桌上眯了四十分钟，被第一节课的铃声叫醒。）\n（一模考砸了几分。但《湖畔》是完整的。）",
        "next": 3
      },
      {
        "speaker": null,
        "text": "（你合上电脑，把没排完的八页折了个角。）\n（回家路上你想，留白也是一种版式——虽然你知道那是安慰自己。）",
        "next": 3
      },
      {
        "speaker": null,
        "text": "（社刊送进了印刷店。剩下的，只能等。）",
        "setFlag": "flag_club_week_done",
        "setFlags": ["flag_club_chain_literature_s3"],
        "next": 99
      }
    ]
  },
```

### A.4 s4 · 成事（授予成就 + 解锁画廊）

> **要点**：`setFlags` 第二项 `flag_club_achievement_literature` 落下的**同一瞬间**，`DialogueUI` L204–207 会调 `unlock_gallery` 解锁 `grad_club_literature`（F13）。**无需任何额外解锁调用。**

```json
  {
    "id": "club_chain_literature_s4",
    "charId": null,
    "location": "library",
    "slotId": "after",
    "triggerDay": 470,
    "priority": 218,
    "repeatable": false,
    "requireFlags": ["flag_club_joined", "flag_club_literature", "flag_club_chain_literature_s3"],
    "excludeFlags": ["flag_club_week_done"],
    "title": "📖 社刊 · 复刊号",
    "scenes": [
      {
        "speaker": null,
        "text": "（《湖畔》复刊号，三十二页，印了四百本。你们抱着纸箱一个班一个班地发过去。）"
      },
      {
        "speaker": null,
        "text": "（下午路过初一（3）班的窗外，有个女生正把杂志摊在膝盖上，念出声来。念的是你排的那一页。）\n（她不知道那是谁排的。这样也挺好。）",
        "statDelta": { "intellect": 3, "art": 2, "charm": 1, "stress": -4 },
        "setFlag": "flag_club_week_done",
        "setFlags": ["flag_club_chain_literature_s4", "flag_club_achievement_literature"],
        "next": 99
      }
    ]
  },
```

### A.5 其余 4 社的替换对照表

| 占位 | literature | astronomy | broadcast | basketball | art |
|---|---|---|---|---|---|
| `location` | `library` | `playground` | `music_room` | `playground` | `art_room` |
| 主属性 | `intellect` | `intellect` | `charm` | `strength` | `art` |
| 次属性 | `art` | `social` | `social` | `social` | `charm` |
| s2 第三属性 | `social` | — | `intellect` | `charm` | `intellect` |
| s4 第三属性 | `charm` | `charm` | `art` | `charm` | `social` |
| 成就 flag | `flag_club_achievement_literature` | `..._astronomy` | `..._broadcast` | `..._basketball` | `..._art` |
| 标题前缀 | `📖 社刊` | `🔭 流星观测` | `🎙️ 晨间播报` | `🏀 年级联赛` | `🎨 校庆画展` |

> 结构字段（`charId`/`slotId`/`priority`/`repeatable`/`excludeFlags`/`triggerDay`/终场景 `setFlag`）**5 社完全相同**，只换 `location`、属性键、flag 名与文案。

---

## 附录 B · `GALLERY_ITEMS` 追加片段（**4 空格缩进**，匹配 `GameManager.gd`）

> 插入位置：`GameManager.gd` **L374 之后、L375 的 `]` 之前**。

```gdscript
    # ── 社团目标层·成就 CG（DS-RN-05b）──────────────────────────
    # flag 即 flag_club_achievement_<type>，由 club_chain_<type>_s4 终场景 setFlags 落下；
    # DialogueUI L204-207 的 setFlags 分支会同步调 unlock_gallery，无需额外解锁调用。
    # ⚠️ 这 5 个 flag 同时是 NG+ 携带白名单项（EndingScreen.CLUB_ACHIEVEMENT_FLAGS），
    #    二者必须逐字符一致，改名须同步两处。
    # ⚠️ 5 张 bg 图必须在 Godot 编辑器打开工程生成 .import，否则导出包不含该资源。
    { "char": "player", "pose": "grad_club_literature", "label": "社刊《湖畔》·复刊号", "hint": "让停刊三年的社刊重新发到每个班。三十二页，四百本，其中一页是你排的。", "flag": "flag_club_achievement_literature", "bg": "res://assets/backgrounds/grad_club_literature.jpg" },
    { "char": "player", "pose": "grad_club_astronomy",  "label": "流星观测·那一夜的记录", "hint": "守到凌晨的那一场流星雨。记录本最后一行的时间与方位，是你写的。", "flag": "flag_club_achievement_astronomy",  "bg": "res://assets/backgrounds/grad_club_astronomy.jpg" },
    { "char": "player", "pose": "grad_club_broadcast",  "label": "校园之声·最后一次早班", "hint": "三年的晨间播报走到最后一期。念完，把话筒推回原位，红灯灭了。", "flag": "flag_club_achievement_broadcast",  "bg": "res://assets/backgrounds/grad_club_broadcast.jpg" },
    { "char": "player", "pose": "grad_club_basketball", "label": "年级联赛·站到最后一场", "hint": "从报名表上的名字，到决赛终场的哨声。比分不重要了。", "flag": "flag_club_achievement_basketball", "bg": "res://assets/backgrounds/grad_club_basketball.jpg" },
    { "char": "player", "pose": "grad_club_art",        "label": "校庆画展·进门第二幅", "hint": "画挂在进门第二幅。有个低年级的学生在它前面站了很久。", "flag": "flag_club_achievement_art",        "bg": "res://assets/backgrounds/grad_club_art.jpg" },
```

---

## 附录 C · 实现改动清单（交 engineering-lead）

| # | 文件 | 缩进 | 改动 | 量级 |
|---|---|---|---|---|
| 1 | `scripts/events_life.json` | **2 空格** | L1725 后追加 20 个 `club_chain_*` 事件（72 → 92） | 大（纯数据） |
| 2 | `scripts/GameManager.gd` | **4 空格** | L374 后追加 5 条 `GALLERY_ITEMS`（附录 B） | +5 行 |
| 3 | `scripts/EndingScreen.gd` | **4 空格** | ① 头部加 `CLUB_ACHIEVEMENT_FLAGS` 常量；② L518 后加 4 行回注（§6.2） | +12 行 |
| 4 | `assets/backgrounds/` | — | art-director 出 5 张 `grad_club_<type>.jpg`（1280×720）**+ 生成 `.import`** | 美术 |
| — | `DailyCycleManager.gd` / `MainGame.gd` / `DataManager.gd` / `DialogueUI.gd` / `project.godot` | — | **零改动** | 0 |

> **若决策 1 的「可选加强」获批**，追加第 5 项：`events_life.json` 5 处 `club_weekly_*` 终场景追加 `"setFlags": ["flag_club_active_<type>"]`（纯追加、幂等），并给 5 个 s1 的 `requireFlags` 加上该 flag。

---

## 附录 D · 开放问题（待主理人 / 用户拍板）

- **OQ-1**（对应决策 1 加强项）**是否放行 R2 的一处豁免**——给 5 个 `club_weekly_*` 终场景追加幂等的 `flag_club_active_<type>`，把链的解锁门槛从「时间够了」升级为「确实参加过」？**设计侧倾向：批准**（纯追加、零行为变更、显著提升门槛语义质量）。
- **OQ-2** `triggerDay` 锚点 120 / 220 / 340 / 470 是否合适？若希望链更早给到正反馈，可整体前移为 90 / 180 / 300 / 430（注意 90 落在 winter break[90,100] 内，会延迟到 101 才首触，需改为 101）。
- **OQ-3**（**超范围但重要**）F19 发现：`gallery_flags` 被上传与合并却**从未回注**，导致今天**全部**画廊 CG（`holiday_memory_*` ×10 / `grad_photo` / `yearbook` / `pet_orange_cat` / `west_lake_stamps_complete` / `west_lake_fengwu_complete`）在 NG+ 后一律丢失。本层只按 §6.2 修 5 个社团成就 flag。**是否另立任务把 `gallery_flags` 整体回注？**（收益：所有收集内容跨周目保留，与「NG+ 继承」支柱一致；风险：需评估是否有任何 CG flag 被复用为事件门控——若有，回注会误触发事件）。
- **OQ-4** 愿景层「五社通」大成 CG（集齐 5 成就，需 ≥5 周目）是否立项为 **DS-RN-05c**？需 `CollectionManager._check_club_completion()`（比照 `_check_fengwu_completion`，零新 Autoload）+ 第 6 张 CG。
- **OQ-5** 若未来开放**转社**，玩家可能同时持有两个 `flag_club_<type>` ⇒ 两条链同时进入候选池、在 218 上同分并发（F9 无 tie-break，结果不确定）。**当前承诺制下不存在此问题**，但若转社立项，本层带位方案须重新评审（届时改为 216–219 + 221 五社异位即可解决）。
- **OQ-6** 链步骤是否需要在社团面板（`_show_club_popup`）里展示进度？设计侧建议**本层不做**（红线 R3 只读约束下可做纯展示，但会增加 `MainGame.gd` 改动面，且与本层「零 UI 改动」的干净交付相悖）。列入愿景层。

---

## 回传主理人（游承峰）

**一句话方案**：链步骤**顶替**当周例行活动（同 slot / 同地点 / 同 `week_done` 节流阀 / 带位 **218**），从而零代码继承「每周一次」限速、不制造第二条周常、并原样保住「时间即代价」；20 个纯 JSON 事件 + 5 条画廊 + 5 个 NG+ 白名单 flag，`DailyCycleManager`/`MainGame`/`DataManager`/`DialogueUI` 全部零改动。

**最大风险一句话**：`flag_club_achievement_*` 一旦被误写进任何链事件的 `excludeFlags`，NG+ 携带成就后该链将**永久死锁**——已立为红线 R6 并给出 S-4 反向断言，建议 quality-lead 对此做变异测试。

**必须先拍板的一项**：OQ-1（是否放行 R2 的一处豁免，把解锁门槛从「时间够了」升级为「确实参加过至少一次」）。拍板后我可立即补出其余 4 社的完整 JSON 明细。

— 文策渊（Vince Coyer）· design-strategist
