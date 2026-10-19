# 西湖十景集章系统 GDD（Phase 4 · 拟真叙事 · 收官子特性）

- 任务：DS-RN-03 ｜ 设计：文策渊 ｜ 评审强度：lean（逻辑级验证，无 Godot runtime）
- 交付对象：engineering-lead（程基岩）+ art-director（林绘澄，仅 §8 一张 CG）
- 项目：《西湖边的青春》· Godot 4.5 mobile · 1280×720 横屏 · 570 天流程
- 状态：**按推荐全定**，仅 §9 留 1 项可选收紧供用户拍板（D-1），不拍板也可直接实现

---

## §0 概览与目标

### 0.1 特性定位

「西湖十景集章」是**拟真叙事**阶段的第三块，也是最后一块：

| 子特性 | 状态 | 承载的玩家动机 |
|---|---|---|
| 拟真手机UI闭环（DS-RN-01） | 已设计 | **社交拟真** —— 昼夜节律下的关系维系 |
| 记忆回响（DS-RN-02） | 延期 | 回顾 |
| **西湖十景集章（DS-RN-03）** | **本文档** | **地域拟真 + 收集完成欲** —— 把"杭州"从背景板变成可被玩家亲手走完的地图 |

设计支柱对齐：
1. **地方感（Sense of Place）** —— 十景是杭州的文化骨架。当前 `WeatherManager.WEST_LAKE_SCENES` 只有 4 景、且仅作季节氛围文字，西湖是"看得见摸不着"的。集章把它变成**玩家的行动对象**。
2. **路线解耦的长线目标** —— 570 天里，恋爱线是分叉的、互斥的；集章是**唯一一条所有玩家都能走完的收集线**，为非攻略向玩家（Bartle Explorer / Achiever）提供贯穿全程的目标锚。
3. **低摩擦、高氛围** —— 这不是挑战系统。它的产出是"文字明信片 + 一枚印"，成本是 1 个时段，不设失败态。

### 0.2 与其余两块的关系

- **与手机UI**：互补而非重叠。手机是"室内 / 关系向"，集章是"户外 / 地点向"。两者共用 `GameManager.flags` 与 toast 通道，不共享逻辑。
- **与记忆回响（延期）**：集章簿在体感上部分承担了"回顾"职能（每景记录获得日 + 文案），但**不侵占**记忆回响的设计空间——集章簿只回顾"我去过哪"，记忆回响回顾"我和谁发生过什么"。
- **与画廊**：集满 10 章 → 解锁一张画廊 CG，把集章的终点接回既有收集系统，复用 `GALLERY_ITEMS` 展示层，零新 UI。

### 0.3 成功标准

| # | 标准 | 可验证方式（静态断言） |
|---|---|---|
| S-1 | 任意恋爱路线（含单身/全冷战）均可集满 10 章 | 断言：10 个 stamp flag 的授予条件中**不包含**任何 `charId` / `minAff` / `relState` 依赖 |
| S-2 | 不存在不可逆错过（no soft-lock） | 断言：10 景在打卡面板的可选条件不含"仅某季节"硬门槛（见 §2.4 / §8-② / §9 D-1） |
| S-3 | 已体验浪漫事件的玩家自动获得对应章，不需重复劳动 | 断言：4 个 `west_lake_*` 事件终局场景的 `setFlags` 均含对应 `stamp_*` |
| S-4 | 零新 Autoload、零存档迁移 | 断言：`project.godot` `[autoload]` 段不变；新增键全部落在 `GameManager.flags` |
| S-5 | 数据单一真源 | 断言：全工程仅 `CollectionManager.WEST_LAKE_STAMP_SCENES` 一处定义十景注册表 |

---

## §1 十景注册表

### 1.1 源码核实结论（本 GDD 数据以实际源码为准）

| 核实项 | 结论 |
|---|---|
| 既有四景 | `scripts/WeatherManager.gd` L21-26 `WEST_LAKE_SCENES`，键为 `spring/summer/autumn/winter`，字段 `name/emoji/season_label/desc`。**仅供 `CenterDashboardUI.gd:303` 显示季节氛围，与收集无关。本 GDD 不修改该常量。** |
| 既有四事件 | `scripts/events_special.json` L1288/1354/1421/1484，`isSpecial:true`，priority 80/90/90/95 |
| ⚠️ **事件级 `setFlag` 是死数据** | 全工程仅 `DialogueUI.gd:203`（场景级 `setFlag`）与 `:474-477`（选项级 `setFlags`/`setFlag`）会写 flag。**没有任何代码读取事件根节点的 `setFlag`。** 因此 `west_lake_winter_jingjing`（events_special.json **L1574**，位于事件根）**当前永远不会被置位**——这是一处既有 bug，本 GDD 顺带修复（见 §5 改动 C-4） |
| ⚠️ 场景级不支持 `setFlags` 数组 | `DialogueUI.gd:203` 只判 `scene.has("setFlag")`（单字符串）。要让一个场景同时写"浪漫 flag + stamp flag"，需补 2 行数组支持（见 §5 改动 A） |
| lakeside 地点 | `GameManager.gd` L164-173，`slots:["after","evening"]`，4 个基础热点（3 个 `random_event` + 1 个 `lakeside_wishes`） |
| lakeside 周末放宽 | `LocationManager.gd:83-84`，周末 slots 覆写为 `["morning","noon","after","evening"]` |
| 热点合并 | `LocationManager.get_location_hotspots()` = 基础 + `_get_temp_hotspots()`；长假会给 lakeside 追加临时热点（L41/47/51） |
| 热点路由 | `HotspotExploreUI.on_hotspot_clicked()` L141，`match event_id` 分支表 L143-184，默认 fallback 走 `DataManager.get_event_by_id` |
| 称号 | `title_*` 前缀 flag。`EndingScreen.gd:337-338` 结局时扫描 `flags` 中 `title_` 开头的键上传全局档案；`:466` NG+ 时用 `GameManager.flags["title_"+t]=true` 回写继承。**没有 TitlePopup / 主界面称号展示 UI**——称号目前只在结局页与跨周目继承中生效 |
| 画廊 | `GameManager.GALLERY_ITEMS`（L292-357，常量数组）；`CollectionManager.is_gallery_unlocked()` 按 `flag` 字段判定；`GalleryPopupUI.gd:59` 遍历渲染 |
| NG+ | `EndingScreen.gd:440` `GameManager.flags = {}`，随后仅回写 `ng_count` / `seen_endings` / `title_*`。→ **stamp_* 与 west_lake_stamps_complete 在 NG+ 清空（符合预期：新周目重新集章），称号 `title_west_lake_master` 保留（符合预期：荣誉跨周目）** |
| flags 支持非 bool 值 | `GameManager.set_flag()` L675-682：bool 走 set/erase，其余类型直接赋值 → **可存 int 获得日** |
| 存档 | `SaveSystem` 整体序列化 `GameManager.flags` 字典，新增任意键**无需**版本迁移 |
| Autoload | `CollectionManager` 已注册（`project.godot` `[autoload]`），可直接承载集章逻辑，**不新增 Autoload** |

### 1.2 十景总表

`sid` = stamp id（snake_case，拼音）。stamp flag 一律为 `stamp_<sid>`。

| # | sid | 名称 | emoji | 推荐季节 | 一句话文案摘要 | 浪漫事件 |
|---|---|---|---|---|---|---|
| 1 | `sudichunxiao` | 苏堤春晓 | 🌸 | 春（1-150） | 桃柳夹堤，花瓣铺水，春天从这条堤上开始。 | ✅ `west_lake_spring_jingjing`（叶菁菁） |
| 2 | `quyuanfenghe` | 曲院风荷 | 🌿 | 夏（151-300） | 接天莲叶，荷香入院，夏天最凉的一口气。 | ✅ `west_lake_summer_yutong`（陈雨桐） |
| 3 | `pinghuqiuyue` | 平湖秋月 | 🍂 | 秋（301-450） | 湖面如镜，桂香十里，月亮是被水捧出来的。 | ✅ `west_lake_autumn_wanqing`（苏晚晴） |
| 4 | `duanqiaocanxue` | 断桥残雪 | ❄️ | 冬（451-570） | 雪半融，桥似断，白堤安静得像一句没说完的话。 | ✅ `west_lake_winter_jingjing`（叶菁菁） |
| 5 | `huagangguanyu` | 花港观鱼 | 🐟 | 春 | 红鱼成群，牡丹将开，喂鱼的人比鱼还慢一拍。 | ✖ |
| 6 | `liulangwenying` | 柳浪闻莺 | 🐦 | 春 | 柳条垂到肩上，黄莺在头顶换了三个调子。 | ✖ |
| 7 | `leifengxizhao` | 雷峰夕照 | 🌇 | 夏 | 塔影被夕阳拉长，整座湖被染成橘子汽水的颜色。 | ✖ |
| 8 | `santanyinyue` | 三潭印月 | 🌕 | 秋 | 三座石塔点起烛火，水里多了好几个月亮。 | ✖ |
| 9 | `nanpingwanzhong` | 南屏晚钟 | 🔔 | 冬 | 净慈寺的钟声撞过湖面，把一天的杂音全压下去。 | ✖ |
| 10 | `shuangfengchayun` | 双峰插云 | ⛰️ | 无季节（全年） | 南北高峰探进云里，晴天才看得见两个尖。 | ✖ |

**季节配平**：春 3 / 夏 2 / 秋 2 / 冬 2 / 无季节 1。四个有浪漫事件的景各占一季，保证任何路线的玩家在任何季节都至少有 1 个"当季推荐"可打。

> ⚠️ **"推荐季节"是氛围标签，不是获取门槛。** 详见 §2.4 与 §8-②。这是为守住成功标准 S-2（no soft-lock）的关键设计决定：春季只有 day 1-150 且不复现，若做成硬门槛，任何在前 150 天没去过西湖 3 次的玩家将**永久无法**集满十景，直接违背决策 1「任何路线都能集满 10 章」。

### 1.3 与 `WeatherManager.WEST_LAKE_SCENES` 的关系（数据边界）

| | `WeatherManager.WEST_LAKE_SCENES` | `CollectionManager.WEST_LAKE_STAMP_SCENES`（新增） |
|---|---|---|
| 条目数 | 4（按季节键） | 10（按 sid 键） |
| 用途 | 中央手账季节氛围文字（`CenterDashboardUI:303`） | 集章系统唯一真源（打卡面板 + 集章簿 + vignette 文案） |
| 本 GDD 是否修改 | **否**（保持不动，零回归风险） | 新建 |
| 一致性约束 | 前 4 景的 `name` / `emoji` 必须与 stamp 表 #1-#4 完全一致 | 由静态断言测试守护（见 §8-④ T-2） |

---

## §2 获取机制（核心）

### 2.1 双路径收敛模型

```
路径 A（主路径 · 路线解耦）
  玩家去 lakeside → 点击常驻热点「🏞️ 西湖十景·集章打卡」
    → 打卡面板（列出未得景）→ 选一景
    → 播放该景 vignette（2-4 句 + emoji，走 DialogueUI）
    → CollectionManager.grant_stamp(sid)
    → flags["stamp_<sid>"]=true + flags["stamp_<sid>_day"]=day + toast
    → advance_time()（DialogueUI:565 自然消耗 1 时段）

路径 B（副路径 · 浪漫演出）
  满足角色/季节/好感/天气条件 → step1 高优自动播放 west_lake_* special 事件
    → 终局场景 setFlags: ["west_lake_xxx", "stamp_<sid>"]
    → 下一次 _on_event_finished 时 CollectionManager._retroactive_stamp_check() 补齐 day + 集满判定

           ↓ 两条路径写同一个 flag ↓
                flags["stamp_<sid>"]
```

**关键设计点**：`stamp_<sid>` 是**幂等**的。走过浪漫事件的玩家，该景在打卡面板中直接显示为"已得"，不会重复劳动；反之只打卡不谈恋爱的玩家，一样集满。这就是决策 1「路线解耦」的技术落点。

### 2.2 热点定义

在 `GameManager.gd` L164-173 的 `lakeside.hotspots` 数组**末尾追加**一项（基础热点，非临时热点 —— 常驻，不受长假/文化节影响）：

```gdscript
{"label": "🏞️ 西湖十景·集章打卡", "pos": Vector2(0.72, 0.28), "event_id": "west_lake_stamp"}
```

坐标选取说明：现有 4 点占据 `(0.45,0.35) / (0.2,0.65) / (0.75,0.6) / (0.5,0.75)`，`(0.72,0.28)` 落在右上天际线区域，与全部既有点欧氏距离 ≥ 0.24，且长假临时热点（`(0.40,0.50)` / `(0.40,0.45)` / `(0.38,0.48)`）也不冲突。**最坏情况**（秋假 + lakeside）屏上共 6 个按钮，仍在 `HFlowContainer` 承载范围内。

### 2.3 热点路由

在 `HotspotExploreUI.on_hotspot_clicked()` 的 `match event_id`（L143-184）中，紧邻 `"lakeside_wishes"` 分支（L150-152）后插入：

```
"west_lake_stamp":
    → _open_sub_ui("res://scripts/StampBookUI.gd",
          pre_add_cb: inst.set_meta("mode", "checkin"),
          on_close_cb: 见下)
    return
```

`on_close_cb` 契约（**必须自定义，不能用默认**）：面板关闭时读取 `inst` 的返回值 `picked_sid`：

| `picked_sid` | 行为 |
|---|---|
| `""`（玩家点了关闭 / 无未得景） | `_location_explore_ui.show()` + `_on_update_ui_cb.call()` + `_on_board_refresh_cb.call()`（照抄 `cooking_*` 分支 L156-160），**不消耗时段** |
| 非空（玩家选了某景） | `_location_explore_ui.hide()` → `_dialogue_ui.show()` → `_dialogue_ui.start_event(CollectionManager.build_stamp_vignette(picked_sid))`，随后由 DialogueUI 正常走完并 `advance_time()` |

> 设计意图：**打开面板本身免费**（玩家可以进去看看还差哪几景就退出），**真正盖章才收 1 时段**。避免"点错一下白白浪费半天"的挫败感。

### 2.4 可选条件（打卡面板列出哪些景）

一个景出现在打卡面板的**可选列表**中，当且仅当：

| 条件 | 判定 | 理由 |
|---|---|---|
| C1 未获得 | `not GameManager.flags.has("stamp_<sid>")` | 幂等 |
| C2 当日未打卡 | `GameManager.flags.get("stamp_checkin_day", -1) != GameManager.day` | 限速，见 §2.5 |
| C3 —— | **无季节门槛、无天气门槛、无角色门槛、无好感门槛** | 守住 S-1 / S-2 |

**推荐季节的作用（纯正反馈，无惩罚）**：

- 当季景在列表中**置顶** + 标注 `⭐ 当季`，并使用 **season 变体文案**（见 §7 每景的「当季加句」）。
- 当季打卡额外收益：`stress -2`（非当季为 0）。这是一个**弱到不会产生主导策略**的引导——2 点压力在 570 天尺度上可忽略，只够形成"啊，春天来打苏堤更好"的心理暗示，不足以让玩家为它改变行程规划。
- 双峰插云（无季节）恒不带 `⭐`，改用天气正反馈：`current_weather == "sunny"` 时文案追加「今天两个尖都露出来了」，收益同样 `stress -2`。

### 2.5 限速设计

| 层 | 机制 | 效果 |
|---|---|---|
| L1 · 地点可达 | lakeside 工作日仅 `after`/`evening`，周末全时段（`LocationManager:83`） | 天然限制"什么时候能去" |
| L2 · 时段成本 | vignette 走 DialogueUI → `advance_time()`（`DialogueUI:565`） | 每章 = 1 个时段的机会成本 |
| L3 · **每日 1 章** | `flags["stamp_checkin_day"] = GameManager.day`，同日再点热点时面板显示"今天已经盖过一枚了" | 集满 10 章 **≥ 10 个不同日子**，把收集摊平到全程而非一天刷完 |

> **注意 L3 与路径 B 的关系**：浪漫事件授予的章**不写** `stamp_checkin_day`（浪漫事件是被动触发的，不是玩家主动打卡，不应挤占当日打卡额度）。即：同一天可以"看了一场浪漫事件（得 1 章）+ 主动打卡（得 1 章）"，上限 2 章/天。这是刻意留的甜点，不算破坏节奏。

**为什么不做更硬的限速**（如每周 1 章）：10 章 × 每周 1 章 = 10 周 ≈ 70 天，看似合理，但会和"玩家想在毕业前补齐最后一景"的强动机打架，且 570 天里玩家很难记住"这周去过没"。每日 1 章 + 时段成本已经把收集自然摊到 10+ 天，够了。这是**收集系统**不是**日常任务系统**，不需要制造焦虑。

### 2.6 stamp flag 命名规范

| 键 | 类型 | 写入方 | 说明 |
|---|---|---|---|
| `stamp_<sid>` | `bool`（true） | `CollectionManager.grant_stamp()` / 浪漫事件 `setFlags` | 该景已得。sid 见 §1.2 |
| `stamp_<sid>_day` | `int` | `CollectionManager.grant_stamp()` / `_retroactive_stamp_check()` 补齐 | 获得日（`GameManager.day`，1-570）。集章簿展示"第 N 天 · 初X上/下学期" |
| `stamp_checkin_day` | `int` | `CollectionManager.grant_stamp()`（仅打卡路径） | 最近一次**主动打卡**的天数，L3 限速守卫 |
| `west_lake_stamps_complete` | `bool` | `CollectionManager._check_stamp_completion()` | 集满 10 章 → 画廊 CG 解锁 flag |
| `title_west_lake_master` | `bool` | 同上 | 称号「西湖十景通」，`title_` 前缀 → 结局页展示 + NG+ 继承 |

**完整 10 个 stamp flag 清单**（供工程直接复制）：
```
stamp_sudichunxiao        stamp_huagangguanyu
stamp_quyuanfenghe        stamp_liulangwenying
stamp_pinghuqiuyue        stamp_leifengxizhao
stamp_duanqiaocanxue      stamp_santanyinyue
                          stamp_nanpingwanzhong
                          stamp_shuangfengchayun
```

---

## §3 集章簿 UI 规格

### 3.1 形态选型

新建 `scripts/StampBookUI.gd`，`extends CanvasLayer`，**照抄 `LakesideWishesUI.gd` 的骨架**（全屏 0.6 黑遮罩 + 居中 `PanelContainer` 820×530 + 18 圆角 + 深色玻璃 `StyleBoxFlat` + `signal closed`）。

选 `CanvasLayer` 而非 `GalleryPopupUI` 那种 `PopupManager` 代理类的理由：本面板需要被**两处**打开（board 按钮 + lakeside 热点），而 `HotspotExploreUI._open_sub_ui()`（L211）只接受"脚本路径 + `new()` 出来的节点"，`GalleryPopupUI` 的 `make_overlay_popup_cb` 形态无法接入热点路由。用 `CanvasLayer` 一套代码吃两个入口。

### 3.2 双模式

面板通过 `set_meta("mode", ...)` 区分（`_ready()` 里读 `get_meta("mode", "book")`）：

| mode | 入口 | 标题 | 未得格行为 | 已得格行为 |
|---|---|---|---|---|
| `"book"` | MainGame board 按钮 | `📖 西湖十景集章簿` | 灰显，点击→提示"去西湖边打卡吧" | 亮显，点击→展开详情（文案 + 获得日） |
| `"checkin"` | lakeside 热点 `west_lake_stamp` | `🏞️ 西湖十景·集章打卡` | 亮显 + `⭐当季` 徽标，**可点击 → 设 `picked_sid` 并 `queue_free()`** | 灰显（已得，不可选） |

`"checkin"` 模式下若 C2 未通过（当日已打卡），全部格子灰显，底部提示条：`今天已经在湖边盖过一枚印了，明天再来。`

### 3.3 布局

```
┌──────────────────────────────────────────────── 820×530 ──┐
│ 📖 西湖十景集章簿                              [ × ]      │  标题栏（照抄 LakesideWishesUI:50-68）
├───────────────────────────────────────────────────────────┤
│ 收集进度  ▓▓▓▓▓▓░░░░░░░░  6 / 10                          │  ProgressBar（照抄 GalleryPopupUI:23-45）
├───────────────────────────────────────────────────────────┤
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐            │
│  │  🌸  │ │  🌿  │ │  🍂  │ │  ❄️  │ │  🐟  │            │  GridContainer columns=5
│  │苏堤春晓│ │曲院风荷│ │平湖秋月│ │断桥残雪│ │花港观鱼│            │  格子 148×108
│  │第32天 │ │第168天│ │第??天 │ │第??天 │ │第55天 │            │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘            │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐            │
│  │  🐦  │ │  🌇  │ │  🌕  │ │  🔔  │ │  ⛰️  │            │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘            │
├───────────────────────────────────────────────────────────┤
│ 🌸 苏堤春晓  ·  第 32 天（初一上学期）                     │  详情区（点格后填充，
│ 春天的苏堤，桃花开成一条粉色的路……                        │   ScrollContainer，默认空态
│                                                           │   提示"点一枚印看看"）
└───────────────────────────────────────────────────────────┘
```

**格子视觉规范**：

| 状态 | 底色 | 边框 | emoji | 文字 |
|---|---|---|---|---|
| 已得 | `Color(0.10,0.13,0.20,1)` | 1px `Color(0.95,0.78,0.35)`（印泥金） | 原色，40px | 名称 `Color(0.94,0.90,0.82)` + 获得日 12px `Color(1,1,1,0.45)` |
| 未得 | `Color(0.05,0.06,0.10,1)` | 1px `Color(1,1,1,0.10)` | `modulate = Color(0.35,0.35,0.35)` | 名称 `Color(1,1,1,0.25)`，日期位显示 `——` |
| 可打卡（checkin 模式） | 同"已得"底色 | 1px `Color(0.45,0.75,0.95)`（可点蓝） | 原色 | 名称正常 + 右上角 `⭐` 若当季 |

（与既有 UI 配色一致：`LakesideWishesUI` 面板底 `Color(0.06,0.08,0.15,0.95)`、`GalleryPopupUI` 卡片底 `Color(0.05,0.06,0.10,1)`。）

**获得日文案格式**：`第 %d 天` + 学期换算括注，换算规则复用 `GameManager.get_grade_info()` 的既有 **90 天/学期**分段（真源对齐，非 §1.1 季节分段）：1-90 初一上 / 91-180 初一下 / 181-270 初二上 / 271-360 初二下 / 361-450 初三上 / 451-570 初三下。若 `stamp_<sid>_day` 缺失（补偿扫描前的极端时序），显示 `第 ? 天`，**不报错**。

### 3.4 MainGame board 集成点

`scripts/MainGame.gd` L370-378 的 `items` 数组（8 个按钮的 `HFlowContainer`），在 `🖼️ 珍贵画廊` 之后、`🎓 往昔结局` 之前插入第 9 项：

```gdscript
{"text": "📖 集章簿",   "color": Color(0.30, 0.50, 0.45), "fn": _show_stampbook_popup},
```

- 颜色 `Color(0.30,0.50,0.45)`（湖水青）与既有 8 色（蓝/紫/靛/绿/金/靛蓝/酒红/亮蓝）均不撞；按钮样式由既有 L381-400 循环统一生成，无需额外样式代码。
- `HFlowContainer` 自动换行，230×70 的按钮从 8 个变 9 个不会溢出（2 行 → 仍 2 行，第 2 行 4→5 个）。
- 新增私有方法（放在 `_show_gallery_popup`（L169）附近，保持"弹窗方法聚区"）：
  ```
  func _show_stampbook_popup():
      → 实例化 StampBookUI，set_meta("mode","book")，add_child(self)
      → 连接 closed 信号 → update_ui()
  ```
- MainGame 顶部**不需要**新增 `@onready` 或成员变量（与 `score_reveal_ui` 一样按需实例化即可，避免常驻内存）。

---

## §4 集满奖励与称号/画廊接入

### 4.1 判定时机与位置

判定逻辑放 **`CollectionManager.gd`**（已是 Autoload，已owns 画廊/收集职能，零新 Autoload）。新增三个函数，紧跟现有画廊区（L29-44）之后：

| 函数 | 职责 |
|---|---|
| `grant_stamp(sid: String, from_checkin: bool = true)` | 幂等授予：已有则 return；否则写 `stamp_<sid>`=true、`stamp_<sid>_day`=day；`from_checkin` 时写 `stamp_checkin_day`；emit toast `🏞️ 集得「<emoji> <name>」印一枚（<n>/10）`；末尾调 `_check_stamp_completion()` |
| `get_stamp_progress() -> Dictionary` | 返回 `{unlocked:int, total:10}`，供集章簿进度条与 board 角标复用（对齐既有 `get_gallery_progress()` L39 的签名风格） |
| `_check_stamp_completion()` | 若 10 个 `stamp_*` 全部存在且 `west_lake_stamps_complete` 未置位 → 见 §4.2 |
| `_retroactive_stamp_check()` | 补偿扫描（对齐既有 `_retroactive_gallery_check()` L85）：遍历 10 景，凡 `stamp_<sid>` 存在但 `stamp_<sid>_day` 缺失 → 补写为当前 day；末尾调 `_check_stamp_completion()` |

**`_retroactive_stamp_check()` 的三个调用点**：
1. `MainGame.gd` L100 / L120 —— 紧跟既有 `GameManager._retroactive_gallery_check()` 调用（开局 / 读档补偿）
2. `MainGame.gd:226` `_on_event_finished()` —— **关键**：浪漫事件（路径 B）刚播完，在这里补齐 day + 触发集满判定

（成本：O(10) 字典查询，可忽略。）

### 4.2 集满时的原子动作

```
_check_stamp_completion():
  if 已有 west_lake_stamps_complete: return
  if 10 个 stamp_* 未集齐: return
  GameManager.set_flag("west_lake_stamps_complete", true)   # 画廊 CG
  GameManager.set_flag("title_west_lake_master", true)      # 称号
  unlock_gallery("west_lake_stamps_complete")               # 复用 L30，语义对齐
  GameManager.show_toast.emit("🏆 西湖十景集齐！获得称号「西湖十景通」，画廊解锁「西湖十景·集章大成」")
  GameManager.add_log(...)  # 由 MainGame._on_show_toast(L230) 自动落日志，无需额外调用
```

### 4.3 称号系统接入（源码核实）

**现状**：`title_*` 没有独立的授予 API，也**没有主界面展示 UI**。它是一个"约定式"机制：

| 消费点 | 位置 | 行为 |
|---|---|---|
| 结局页上传 | `EndingScreen.gd:337-338` | 遍历 `GameManager.flags`，取 `title_` 开头的键，`substr(6)` 去前缀后作为称号列表上传全局档案 |
| NG+ 继承 | `EndingScreen.gd:466` | `GameManager.flags["title_" + t] = true`，在 L440 `flags = {}` 之后回写 |

**接入方式**：**只需 `GameManager.set_flag("title_west_lake_master", true)`，无需任何额外代码。** 该称号会自动出现在结局页称号列表、自动跨周目继承。

⚠️ **副作用提示（给 engineering-lead）**：`substr(6)` 得到的原始串是 `west_lake_master`（英文 snake），而非中文「西湖十景通」。既有 `title_*` flag 的命名与显示映射关系需确认——若结局页直接显示 `west_lake_master` 会出戏。三种处理，**推荐 (a)**：

- **(a) 推荐**：flag 直接命名为中文——`title_西湖十景通`。GDScript 字典键支持 UTF-8，`substr(6)` 后得到「西湖十景通」，与既有机制零改动对齐。**前提**：engineering-lead 需先 grep 确认既有 `title_*` 的实际命名惯例（**QA 复核勘误**：`SeasonManager.gd:206` 早已授予赛季称号 `title_西湖游客` / `title_清河坊熟客` / `title_烟雨客`，**全部中文名**；本特性并非首个称号授予方。结论方向不变——D-2(a) 选中文 `title_西湖十景通` 是**对齐既有 `title_`+中文 惯例**，而非新立）。
- (b) 保持 `title_west_lake_master`，在 EndingScreen 加一张 `TITLE_LABELS` 映射表。改动更大，但更规范。
- (c) 保持英文 flag，接受结局页显示英文。不推荐。

→ 这一项列入 §9 **D-2**（工程侧确认项，非用户拍板项）。GDD 正文其余部分统一写作 `title_west_lake_master`，若采纳 (a) 则全局替换为 `title_西湖十景通`。

### 4.4 GALLERY_ITEMS 追加条目

在 `GameManager.gd` GALLERY_ITEMS 末尾（L356 `pet_orange_cat` 之后、L357 `]` 之前）追加 1 条。字段严格对齐既有格式（`char` / `pose` / `label` / `hint` / `flag` / `bg`）：

```gdscript
{ "char": "player", "pose": "west_lake_stamps", "label": "西湖十景·集章大成",
  "hint": "集齐西湖十景全部印章后解锁。三年，一座湖，十个你亲自走过的地方。",
  "flag": "west_lake_stamps_complete",
  "bg": "res://assets/backgrounds/west_lake_stamps_complete.jpg" },
```

- `char: "player"` —— 对齐既有 3 条非角色 CG（`grad_photo` / `grad_yearbook` / `pet_orange_cat`）的写法。
- `GalleryPopupUI.gd:63-64` 会 `GameManager.char_meta.get("player", {})` 取 `color`，`player` 若不在 char_meta 中则 fallback `#888888` —— 与既有 3 条行为一致，无回归。
- 画廊总数 `GALLERY_ITEMS.size()` +1，`get_gallery_progress()` 自动跟随，无需改动。

---

## §5 集成与接线清单

按依赖顺序排列。**共 7 个文件，1 个新建。**

| # | 文件 | 位置 | 改动 | 类型 |
|---|---|---|---|---|
| **A** | `scripts/DialogueUI.gd` | L202-205（场景级 setFlag 块） | 在 `if scene.has("setFlag")` **之前**插入数组分支：`if scene.has("setFlags"): for f in scene["setFlags"]: GameManager.set_flag(f, true); GameManager.unlock_gallery(f)`。与选项级 L474-477 的写法对称 | 引擎能力补齐（2-4 行） |
| **B** | `scripts/CollectionManager.gd` | 文件末尾（L88 之后）新增「西湖十景集章」区 | ① `const WEST_LAKE_STAMP_SCENES`（§6.1）② `grant_stamp()` ③ `get_stamp_progress()` ④ `_check_stamp_completion()` ⑤ `_retroactive_stamp_check()` ⑥ `build_stamp_vignette(sid) -> Dictionary`（§6.3） | 新增逻辑（核心） |
| **C** | `scripts/events_special.json` | 4 处 | 见下方 C-1~C-4 | 数据 |
| C-1 | 同上 | **L1346-1351**（spring 终局 scene） | `"setFlag": "west_lake_spring_jingjing"` → `"setFlags": ["west_lake_spring_jingjing", "stamp_sudichunxiao"]` | |
| C-2 | 同上 | **L1413-1417**（summer 终局 scene） | `"setFlag": "west_lake_summer_yutong"` → `"setFlags": ["west_lake_summer_yutong", "stamp_quyuanfenghe"]` | |
| C-3 | 同上 | **L1475-1481**（autumn 终局 scene，wanqing 台词那条） | `"setFlag": "west_lake_autumn_wanqing"` → `"setFlags": ["west_lake_autumn_wanqing", "stamp_pinghuqiuyue"]` | |
| C-4 | 同上 | **L1560-1571 两条终局 scene（`next:99` 的 idx 8 / idx 9）各加一个字段；并删除 L1574 事件根的 `"setFlag"`** | 各加 `"setFlags": ["west_lake_winter_jingjing", "stamp_duanqiaocanxue"]`。⚠️ **顺带修复既有 bug**：根级 `setFlag` 无代码读取（§1.1），`west_lake_winter_jingjing` 此前从未被置位 | **含 bug fix** |
| **D** | `scripts/GameManager.gd` | L167-172（`lakeside.hotspots` 数组末尾） | 追加 `{"label": "🏞️ 西湖十景·集章打卡", "pos": Vector2(0.72, 0.28), "event_id": "west_lake_stamp"}` | 数据 |
| **E** | `scripts/GameManager.gd` | L356 之后（GALLERY_ITEMS 末尾） | 追加 §4.4 的 1 条画廊条目 | 数据 |
| **F** | `scripts/StampBookUI.gd` | **新建** | `extends CanvasLayer`，双模式面板，骨架照抄 `LakesideWishesUI.gd`。对外契约：`set_meta("mode", "book"\|"checkin")` 输入；`signal closed`；`var picked_sid: String = ""` 输出 | 新建 UI |
| **G** | `scripts/HotspotExploreUI.gd` | L152 之后（`lakeside_wishes` 分支后） | 新增 `"west_lake_stamp"` 分支，`_open_sub_ui` + 自定义 `on_close_cb`（§2.3） | 路由 |
| **H** | `scripts/MainGame.gd` | ① L376 之后 items 数组插入按钮项 ② `_show_gallery_popup`（L169）附近新增 `_show_stampbook_popup()` ③ L100 / L120 / L226 三处加 `CollectionManager._retroactive_stamp_check()` | 见 §3.4 / §4.1 | 集成 |

### 5.1 明确**不需要**改动的项

| 项 | 理由 |
|---|---|
| `project.godot` | 不新增 Autoload（逻辑寄居已注册的 `CollectionManager`） |
| `SaveSystem.gd` | `flags` 字典整体序列化，新增键零迁移 |
| `WeatherManager.gd` | `WEST_LAKE_SCENES` 保持不动（§1.3），避免 `CenterDashboardUI:303` 回归 |
| `LocationManager.gd` | 集章热点是**基础**热点（写在 `GameManager.locations`），`get_location_hotspots()` L12-13 自动合并，`_get_temp_hotspots()` 无需改 |
| `EndingScreen.gd` | `title_*` 走既有约定式扫描（§4.3），若采纳 D-2(b) 才需改 |
| `GalleryPopupUI.gd` | 遍历 `GALLERY_ITEMS`，新条目自动渲染 |
| 存档版本号 | 同上 |

### 5.2 NG+ 行为确认

`EndingScreen.gd:440` `GameManager.flags = {}` → 随后仅回写 `ng_count` / `seen_endings` / `title_*`。因此：

| 键 | NG+ 后 | 是否符合预期 |
|---|---|---|
| `stamp_*` / `stamp_*_day` / `stamp_checkin_day` | 清空 | ✅ 新周目重新走一遍十景，这正是收集乐趣 |
| `west_lake_stamps_complete` | 清空 | ✅ 画廊 CG 在本周目重新解锁（与 `holiday_memory_*` / `grad_photo` 等既有 CG 行为完全一致） |
| `title_west_lake_master` | **保留** | ✅ 荣誉跨周目，符合称号语义 |

---

## §6 数据格式

### 6.1 `CollectionManager.WEST_LAKE_STAMP_SCENES`（唯一真源）

```gdscript
# ── 西湖十景集章：唯一数据源 ──────────────────────────────────
# 字段：
#   name         String  景名（中文 4 字）
#   emoji        String  单 emoji，集章簿格子主视觉
#   season       String  推荐季节 "spring"/"summer"/"autumn"/"winter"/""（无季节）
#                        ⚠️ 仅作展示与弱正反馈，非获取门槛（见 GDD §2.4）
#   summary      String  一句话摘要，集章簿详情区首行
#   lines        Array[String]  vignette 正文 2-4 句，按序播放（见 GDD §7）
#   season_line  String  当季/晴天时追加的第 5 句；"" 表示无
#   romance_ev   String  关联浪漫事件 id；"" 表示无
const WEST_LAKE_STAMP_SCENES = {
    "sudichunxiao":     { "name": "苏堤春晓", "emoji": "🌸", "season": "spring", "romance_ev": "west_lake_spring_jingjing",  "summary": "...", "lines": [...], "season_line": "..." },
    "quyuanfenghe":     { "name": "曲院风荷", "emoji": "🌿", "season": "summer", "romance_ev": "west_lake_summer_yutong",   ... },
    "pinghuqiuyue":     { "name": "平湖秋月", "emoji": "🍂", "season": "autumn", "romance_ev": "west_lake_autumn_wanqing",  ... },
    "duanqiaocanxue":   { "name": "断桥残雪", "emoji": "❄️", "season": "winter", "romance_ev": "west_lake_winter_jingjing", ... },
    "huagangguanyu":    { "name": "花港观鱼", "emoji": "🐟", "season": "spring", "romance_ev": "", ... },
    "liulangwenying":   { "name": "柳浪闻莺", "emoji": "🐦", "season": "spring", "romance_ev": "", ... },
    "leifengxizhao":    { "name": "雷峰夕照", "emoji": "🌇", "season": "summer", "romance_ev": "", ... },
    "santanyinyue":     { "name": "三潭印月", "emoji": "🌕", "season": "autumn", "romance_ev": "", ... },
    "nanpingwanzhong":  { "name": "南屏晚钟", "emoji": "🔔", "season": "winter", "romance_ev": "", ... },
    "shuangfengchayun": { "name": "双峰插云", "emoji": "⛰️", "season": "",       "romance_ev": "", ... },
}
```

> **字典有序性**：GDScript 4 的 `Dictionary` 保持插入顺序，`keys()` 迭代顺序 = 上表顺序 = 集章簿格子顺序（第一行前 5、第二行后 5）。**不要**对 keys 排序。

`lines` / `season_line` / `summary` 的正文见 §7，engineering-lead 直接照抄填入。

### 6.2 lakeside 热点数据结构

`GameManager.locations["lakeside"]["hotspots"]` 改动后完整形态（新增项加粗）：

```gdscript
"hotspots": [
    {"label": "🌉 断桥 (观赏风景)",      "pos": Vector2(0.45, 0.35), "event_id": "random_event"},
    {"label": "🪑 长椅 (小憩发呆)",      "pos": Vector2(0.20, 0.65), "event_id": "random_event"},
    {"label": "🌊 码头 (观察游船)",      "pos": Vector2(0.75, 0.60), "event_id": "random_event"},
    {"label": "🏮 许愿花灯与漂流瓶",     "pos": Vector2(0.50, 0.75), "event_id": "lakeside_wishes"},
    {"label": "🏞️ 西湖十景·集章打卡",   "pos": Vector2(0.72, 0.28), "event_id": "west_lake_stamp"},   # ← 新增
]
```

### 6.3 vignette 事件字典（`build_stamp_vignette(sid)` 返回值）

运行时合成，**不写入任何 JSON 事件文件**（避免污染 `DataManager` 的随机事件池 —— 十景 vignette 不应被 `start_event_search()` 随机抽到）。

```gdscript
{
    "id":       "west_lake_stamp_<sid>",
    "location": "lakeside",
    "title":    "<emoji> <name>",
    "isSpecial": false,          # 非 special，不进优先级队列
    "scenes": [
        {"speaker": null, "text": "<lines[0]>"},
        {"speaker": null, "text": "<lines[1]>"},
        ...                                        # lines 有几句排几条
        {"speaker": null, "text": "<season_line>"},   # 仅当季/晴天时插入
        {"speaker": null,
         "text": "「西湖十景·<name>」——集章簿上，又落下一枚印。",
         "stressDelta": -2,                        # 仅当季/晴天；否则省略该字段
         "next": 99}
    ]
}
```

⚠️ **最后一条 scene 刻意不写 `setFlag`**：flag 授予由 `CollectionManager.grant_stamp(sid)` 统一负责（在 `HotspotExploreUI` 拿到 `picked_sid` 时立即调用，早于 vignette 播放）。这样保证"写 flag + 写 day + 集满判定"三件事**原子**发生在一处，而不是散落在 DialogueUI 的 flag 钩子里。

> 工程注意：`stressDelta` 字段名需与 DialogueUI 既有的属性增减字段命名一致（工程侧请以源码为准核对；若既有字段名不同，按既有的来，本 GDD 只定语义 = 当季打卡减 2 点压力）。

### 6.4 GALLERY_ITEMS 条目

见 §4.4，格式已给全。

### 6.5 打卡面板数据流

```
StampBookUI (mode=checkin)
  ← 读 CollectionManager.WEST_LAKE_STAMP_SCENES     （十景静态数据）
  ← 读 GameManager.flags                            （stamp_* / stamp_*_day / stamp_checkin_day）
  ← 读 WeatherManager.get_season()                  （⭐当季标注）
  ← 读 GameManager.current_weather                  （双峰插云晴天标注）
  ← 读 CollectionManager.get_stamp_progress()       （进度条）
  → 写 self.picked_sid                              （唯一输出，由 HotspotExploreUI 消费）
```

**面板自身不写任何 flag。** 单向数据流，便于静态验证。

---

## §7 十景 vignette 文案

基调约束：初中生视角、口语化、不用生僻典故；**不出现任何角色名**（路线解耦，所有玩家共用）；可以有"如果有人在旁边就好了"式的轻恋爱/友情/独处留白，但不指名道姓。每景 3-4 句 + 1 句当季加句。

### 7.1 前四景（打卡路径专用，与浪漫事件文案区分）

> 这 4 景的浪漫事件已有各自的完整演出（§1.1）。打卡 vignette 是**独处版**，刻意写得更安静，避免与浪漫事件撞感觉。

**① 🌸 苏堤春晓**
- `summary`：桃柳夹堤，花瓣铺水，春天从这条堤上开始。
- `lines`：
  1. 苏堤很长，长到你走一半就开始怀疑自己到底想去哪儿。
  2. 桃花和柳树一棵隔一棵地种着，粉的白的绿的，被风一吹全落到水面上，浮成一层薄薄的彩色。
  3. 你在第三座桥上停下来，看一只野鸭把那层彩色划开一道口子，然后它游走了，口子又慢慢合上。
- `season_line`：春天的苏堤是有声音的——不是鸟叫，是花瓣落到水上的那种，几乎听不见的声音。

**② 🌿 曲院风荷**
- `summary`：接天莲叶，荷香入院，夏天最凉的一口气。
- `lines`：
  1. 还没走到，先闻到荷花味。是那种很淡、带着水汽的甜，不像香水，倒像刚洗过的衣服。
  2. 荷叶挤得满满当当，一直铺到看不见岸的地方。有几片翻了个面，露出浅浅的叶背。
  3. 你蹲下来，看叶心那颗水珠滚来滚去，就是不掉下去。看了大概有一分钟。
- `season_line`：夏天最凉快的一口气，是在这里吸到的。

**③ 🍂 平湖秋月**
- `summary`：湖面如镜，桂香十里，月亮是被水捧出来的。
- `lines`：
  1. 天刚擦黑，湖面还留着一点白，像有人忘了收起来的一块布。
  2. 桂花的味道从背后的树丛里一阵一阵地飘过来，闻久了会有点甜得发晕。
  3. 月亮上来的时候你才发现，水里那个比天上那个更清楚一些。
- `season_line`：秋天的月亮是被水捧上来的——难怪古人非要跑到湖边来看。

**④ ❄️ 断桥残雪**
- `summary`：雪半融，桥似断，白堤安静得像一句没说完的话。
- `lines`:
  1. 杭州的雪一年下不了几场，下了也留不住，所以桥上的雪总是化一半留一半。
  2. 从远处看，化掉的那半和石头一个颜色，桥就像是断在中间——名字就是这么来的。
  3. 你踩上去，脚下发出很轻的一声"咯吱"，然后四周就更安静了。
- `season_line`：冬天的白堤安静得像一句说到一半、就没再说下去的话。

### 7.2 新增六景

**⑤ 🐟 花港观鱼**
- `summary`：红鱼成群，牡丹将开，喂鱼的人比鱼还慢一拍。
- `lines`：
  1. 池子里的红鱼多到有点吓人，你把手伸到水面上方，它们就"哗"地全挤过来，把水搅成一团红。
  2. 旁边一位老爷爷在撕面包，撕得非常慢，一小块一小块。鱼急得直跳，他也不急。
  3. 你忽然觉得，能在这儿把一片面包撕上半小时，大概也算是一种本事。
- `season_line`：春天的花港，牡丹还没全开，鱼倒是先热闹起来了。

**⑥ 🐦 柳浪闻莺**
- `summary`：柳条垂到肩上，黄莺在头顶换了三个调子。
- `lines`：
  1. 这一段的柳树种得特别密，柳条一直垂到人肩膀那么低，走过去得用手拨。
  2. 黄莺就在头顶上叫，叫一声换一个调，你抬头找了半天，一只都没看见。
  3. 拨开柳条继续往前走，鸟叫声就跟着你，像有谁在树上一路送你到路口。
- `season_line`：春天的柳浪最经不起风，风一来，整条路都在晃。

**⑦ 🌇 雷峰夕照**
- `summary`：塔影被夕阳拉长，整座湖被染成橘子汽水的颜色。
- `lines`：
  1. 太阳快落到山后面的时候，雷峰塔的影子被拉得老长，一直伸到湖里去。
  2. 整片水面变成橘子汽水那个颜色，连远处的游船都镀了一层金边。
  3. 湖边站了一排人在拍照，没人说话。你也站着，直到最后那一点橘色沉下去。
- `season_line`：夏天日落得晚，这一幕能撑到快七点，够你把作业忘个干净。

**⑧ 🌕 三潭印月**
- `summary`：三座石塔点起烛火，水里多了好几个月亮。
- `lines`：
  1. 那三座石塔比想象中小，圆圆的，像三个被人插在水里的石头葫芦。
  2. 每座塔身上有五个圆洞，晚上点上蜡烛，加上天上那个真的，据说能数出三十三个月亮。
  3. 你认真数了数，只数出七个，剩下的大概得靠想象力补。
- `season_line`：秋天的湖面最平，塔影一动不动，像是被谁按在水里。

**⑨ 🔔 南屏晚钟**
- `summary`：净慈寺的钟声撞过湖面，把一天的杂音全压下去。
- `lines`：
  1. 净慈寺的钟声响起来的时候，你正好走到湖边。
  2. 那声音很低，先是"咚"的一下，然后余音贴着水面一路铺过去，铺了好久才散。
  3. 钟声没了之后，你才发现刚才那一会儿，脑子里什么都没在想。
- `season_line`：冬天空气冷而干，钟声传得比平时还要远。

**⑩ ⛰️ 双峰插云**
- `summary`：南北高峰探进云里，晴天才看得见两个尖。
- `lines`：
  1. 南高峰和北高峰隔着一大片湖水遥遥相对，山尖常年埋在云里，看不见顶。
  2. 你眯着眼睛找了半天，云动了一下，露出一个尖，隔了几秒又被盖回去。
  3. 有人说要等一个特别晴的日子才能同时看见两个尖。你想，那就下次吧——反正你还有很多个下次。
- `season_line`（晴天触发）：今天天特别透，两个尖都露出来了——这种日子一年也没几天。

> **文案落地说明**：`lines` 数组按上表逐句填入，engineering-lead 无需二次编辑。§7 的 `season_line` 对应 §6.1 的 `season_line` 字段；双峰插云的 `season_line` 触发条件是 `GameManager.current_weather == "sunny"` 而非季节（在 `build_stamp_vignette()` 里按 `season == ""` 分流判断）。

---

## §8 风险与缓解

### ① 浪漫事件（step1 高优自动播放）与打卡热点共存

**风险**：4 个 `west_lake_*` 事件 `isSpecial:true`、priority 80-95，在满足条件时会**抢在玩家操作之前**自动播放。玩家可能刚点了"集章打卡"想盖苏堤春晓，结果被浪漫事件截胡，产生"我的操作被吞了"的挫败感。

**缓解（三重）**：
1. **两条路径写同一个 flag**（§2.1）。浪漫事件终局 `setFlags` 含 `stamp_<sid>`，所以即便被截胡，玩家**照样拿到那一章**——结果一致，只是演出更好看了。这从根本上消解了冲突。
2. **触发时序上不存在真冲突**：special 事件在进入地点/推进时段的 step1 阶段判定，此时 `HotspotExploreUI` 尚未构建热点按钮；玩家点热点时，本时段的 special 判定已经过去。二者在同一时段内不会互相打断。
3. **打卡面板对已得景灰显**（§3.2）。浪漫事件先发生的情况下，玩家打开面板会看到该景已亮，认知连贯，不会"选了一个其实已经有的景"。

**残留风险（可接受）**：玩家可能"本想打卡苏堤，结果被迫看了 3 分钟菁菁的桃花戏"。这在恋爱模拟里是**正收益**，不缓解。

### ② 每游湖 1 章限速 & 季节软锁

**风险 A（限速过松）**：不限速的话，玩家一个周末在 lakeside 反复进出可以一口气刷 4 章（4 个时段），十景两个周末刷完，收集线的长尾感彻底垮掉。
**缓解**：`stamp_checkin_day` 每日 1 章（§2.5 L3）+ 时段成本。集满 ≥ 10 个不同日子，配合 lakeside 的时段可达性，自然摊到 3-6 周以上。

**风险 B（限速过紧）**：若做成"每周 1 章"或"每季只能打当季的景"，会制造 570 天里无法补救的错过。
**缓解**：**季节做成推荐而非门槛**（§2.4）。这是本 GDD 最重要的一处设计红线判断：

> 春季（day 1-150）在整个 570 天流程中**只出现一次**、不复现。若把"苏堤春晓/花港观鱼/柳浪闻莺"锁死在春季，那么一个在初一上学期忙于学习、没去过 3 次西湖的玩家，将在 day 151 那一刻**永久失去**「西湖十景通」称号，且游戏不会给出任何提示。这是典型的**不可逆隐性失败（irreversible hidden failure）**，直接违反决策 1「任何路线都能集满 10 章」，也违反收集系统"可完成"的基本契约。
> 
> 代价是损失一点"应季而游"的仪式感。用 `⭐当季` 徽标 + 置顶 + 专属加句 + `stress -2` 把仪式感以**正反馈**形式补回来——引导而不惩罚。

若用户仍希望收紧，见 §9 **D-1**（给出了带补救机制的折中方案）。

**风险 C（认知过载）**：主界面 board 从 8 个按钮变 9 个。
**缓解**：仍是 `HFlowContainer` 2 行（5+4），未新增层级、未新增 HUD 常驻元素。集章簿的所有信息都在一次点击之后，不占主界面认知带宽。

### ③ CG 美术需求 → 移交 art-director（林绘澄）

**1 张新 CG**，规格严格对齐 `design/holiday_art_spec.md` §0/§4.1 既有横屏 CG 规格：

| 项 | 值 |
|---|---|
| 文件名 | `west_lake_stamps_complete.jpg` |
| 落盘路径 | `res://assets/backgrounds/west_lake_stamps_complete.jpg` |
| 分辨率 | **1280 × 720（16:9 横屏）**，JPEG |
| 风格锚点 | 与 4 张 holiday CG 同族：painterly Chinese landscape illustration / Ghibli · 新海诚 氛围光 / semi-realistic / cinematic color grading |
| 画面内容 | **一本摊开的集章簿**（中式线装本或速写本），跨页上盖着 10 枚朱红印章，每枚印章内是一景的极简线描剪影（苏堤柳桥 / 荷叶 / 湖月 / 断桥雪 / 红鱼 / 柳莺 / 雷峰塔 / 三石塔 / 寺钟 / 双峰）。本子摊在西湖边的石栏上，背景是虚化的湖面与远山，光线是傍晚的暖金色。 |
| 情绪 | 完成感 + 一点告别感（这是三年走完一座湖的证明），**不甜、不燃，要静** |
| 硬约束 | **no characters**（路线解耦，不能出现任何角色）、no watermark、no text/no legible characters on the page（避免中文字形穿帮） |
| `.import` | 参照 `holiday_art_spec.md` §R3 建议，单独写 `.import`，参数照抄 `lakeside_evening` |

参考 prompt 骨架（art-director 可自行重写）：
```
painterly Chinese landscape illustration, an open traditional stamp-collecting booklet
lying on a stone railing by West Lake, ten vermillion seal stamps printed across the
two pages, each seal containing a minimal line-art silhouette of a West Lake scenic
spot, blurred lake and distant mountains in warm golden-hour backlight,
Ghibli/Makoto Shinkai atmospheric lighting, semi-realistic, high detail on paper
texture and seal ink, cinematic color grading, quiet nostalgic mood,
1280x720 landscape, no characters, no watermark, no legible text
```

### ④ 无 Godot 运行时 → 静态断言验证清单

移交 quality-lead（严守真）。建议新建 `tests/west_lake_stamps_smoke/`，全部为**静态断言**（grep / JSON parse / 常量比对），不依赖引擎运行：

| # | 断言 | 方法 |
|---|---|---|
| T-1 | `WEST_LAKE_STAMP_SCENES` 恰含 10 个键，且键集合 == §1.2 sid 全集 | 解析 `CollectionManager.gd` 常量块 |
| T-2 | 前 4 景的 `name` / `emoji` 与 `WeatherManager.WEST_LAKE_SCENES` 对应季节项完全一致 | 双常量比对 |
| T-3 | `events_special.json` 4 个 `west_lake_*` 事件的**所有** `next:99` 终局场景均含 `setFlags` 且包含对应 `stamp_*`（winter 事件有 2 条终局分支，都要有） | JSON 遍历 |
| T-4 | `events_special.json` 中不再存在事件**根级** `setFlag` 字段 | JSON key 扫描（回归守卫，防止死数据复活） |
| T-5 | `DialogueUI.gd` 场景级块同时处理 `setFlags` 与 `setFlag` | grep `scene.has("setFlags")` |
| T-6 | 10 个 `stamp_<sid>` 字面量在 `CollectionManager.gd` 与 `events_special.json` 之间无拼写漂移 | 交叉 grep |
| T-7 | `GALLERY_ITEMS` 含 `flag == "west_lake_stamps_complete"` 的条目，且 `bg` 指向的文件存在 | grep + 文件存在性 |
| T-8 | `lakeside.hotspots` 含 `event_id == "west_lake_stamp"`，且 `HotspotExploreUI` 的 match 表存在同名分支（路由闭合） | 双向 grep |
| T-9 | `lakeside` 5 个热点 `pos` 两两欧氏距离 ≥ 0.20；且与 3 个 lakeside 长假临时热点 `pos` 也 ≥ 0.15 | 坐标计算 |
| T-10 | `project.godot` `[autoload]` 段与改动前逐字节一致（S-4） | diff |
| T-11 | 全工程 `stamp_` 前缀 flag 的写入点仅出现在 `CollectionManager.gd` 与 `events_special.json` 两处（单一写入源） | grep 全仓 |
| T-12 | `StampBookUI.gd` 中不含任何 `set_flag` / `flags[` 写操作（§6.5 单向数据流） | grep |

### ⑤ 其他

| 风险 | 缓解 |
|---|---|
| `setFlags` 数组支持是**引擎能力改动**，可能影响其他已有事件 | 改动为**纯新增分支**（`if scene.has("setFlags")`），既有 `setFlag` 路径完全不动。全仓 grep 确认当前**无任何**场景级 `setFlags` 使用者 → 零回归面 |
| 玩家在 day 569（`get_forced_location_for_day()` 强制 lakeside，`LocationManager:59-62`）想补最后一章 | ✅ 天然支持：那天只能去 lakeside，集章热点常驻可用，是很好的"最后一章"叙事时刻。**这是本设计的一个意外彩蛋，建议保留并在 §7⑩「反正你还有很多个下次」的文案上形成回响** |
| emoji 在部分安卓设备字体缺失（⛰️ / 🌇 变豆腐块） | 集章簿格子 emoji 下方**始终**有中文景名，emoji 缺失不影响可用性。若 QA 实机发现，可降级为纯文字格 |
| toast 刷屏（集满时连发 2 条：第 10 章 + 集满） | `grant_stamp` 内做合并：若本次授予后即集满，则**只发**集满那条（更隆重），跳过普通章 toast |

---

## §9 决策区

**总体：按推荐全定，无阻塞性待决项。** 以下 2 项为可选项，不拍板亦可按推荐直接实现。

### D-1（用户可选拍板）季节是否收紧为硬门槛？

| 选项 | 说明 | 评价 |
|---|---|---|
| **A（推荐 · 已写入正文）** | 季节 = 推荐标签。全 10 景全年可打卡；当季有 `⭐` + 专属加句 + `stress -2` | ✅ 零 soft-lock，守住 S-1/S-2。仪式感靠正反馈补 |
| B | 季节 = 硬门槛，但增加补救：day 540 起（毕业季）在 lakeside 追加"回忆补章"热点，可无视季节补齐 | 仪式感更强，但多一套补救逻辑 + 一个额外热点；且 day 540 之前玩家会处于"我可能已经废了"的焦虑中而不自知 |
| C | 季节 = 硬门槛，无补救 | ❌ 设计红线：不可逆隐性失败，违反决策 1。**不建议** |

> 若用户选 B，需追加：临时热点定义（`LocationManager._get_temp_hotspots()`）+ `day >= 540` 时打卡面板忽略季节过滤 + 补章 vignette 前置一句"这一景你当时错过了，但西湖一直在"。设计侧 1 小时可补，工程侧约 +15 行。

### D-2（工程侧确认，非用户拍板）称号 flag 命名

见 §4.3。推荐 **(a) `title_西湖十景通`**（中文 flag，`EndingScreen:338` 的 `substr(6)` 后直接得到可读称号，零改动）。请 engineering-lead 实现前先 grep 全仓确认是否已有其他 `title_*` 授予点及其命名惯例——**QA 复核勘误**：`SeasonManager.gd:206` 已有 `title_西湖游客` / `title_清河坊熟客` / `title_烟雨客`（全中文），本特性并非首个称号授予方；D-2(a) 选中文 `title_西湖十景通` 对齐既有惯例。

---

## §10 交付摘要

| 项 | 内容 |
|---|---|
| 新建文件 | 1（`scripts/StampBookUI.gd`） |
| 修改文件 | 6（DialogueUI / CollectionManager / GameManager / events_special.json / HotspotExploreUI / MainGame） |
| 新增 Autoload | **0** |
| 存档迁移 | **不需要** |
| 新增美术资产 | 1 张 CG（1280×720，见 §8-③） |
| 新增 flag | 22 个（10 stamp + 10 stamp_day + 1 checkin_day + 1 complete）+ 1 称号 |
| 顺带修复 | 1 个既有 bug（`west_lake_winter_jingjing` 事件根级 setFlag 从未生效，§5 C-4） |
| 阻塞性待决 | **无** |

**下游移交**：
- engineering-lead（程基岩）：§5 接线清单 + §6 数据格式 + §7 文案（可直接照抄）
- art-director（林绘澄）：§8-③ 单张 CG
- quality-lead（严守真）：§8-④ T-1 ~ T-12 静态断言清单
