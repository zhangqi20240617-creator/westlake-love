# 《西湖边的青春》· 经营/收集扩展 · 玩法概念对比与 GDD

> 作者：文策渊（design-strategist） · 阶段：概念孵化 + 系统设计
> 方向：用户已在 4 个方向中选定 **「经营/收集扩展」**（复用 `CollectionManager` / `ITEM_DB`，从 `handmade_gift` / 十景集章延伸，偏收集向长线玩法）
> 约束：只产出设计，不写代码；不新增 Autoload；适配 570 天 + 男女双路线；不回归 3 个已放行特性

---

## §-1 读盘结论（源码实证，非臆造）

本 GDD 的每一处「复用」都经过源码核实。下表是设计依据的事实基线：

| 主题 | 事实 | 出处 |
|---|---|---|
| 货币 | `var money = 100`（int，非 stats 成员） | `GameManager.gd` L18 |
| 货币写入 | `add_stat("money", n)` 走**独立分支**，`money += amount` 后 emit toast，**不 clamp 到 0-100** | `GameManager.gd` L624-631 |
| 周零花 | 周一发放 `100 + intellect/5`，即 **100-120/周** | `DailyCycleManager.gd` L93-98 |
| 兼职周薪 | 需 `flag_has_parttime_job`，周末 +80 money / +2 stress | `DailyCycleManager.gd` L101-106 |
| 每日结算钩子 | `advance_time()` 跨日块依次调 `_update_current_holiday` → 天气 → 心情 → `_check_daily_decay` → `_check_special_date` → `_check_weekly_allowance` → `_check_parttime_income` → `_check_char_initiative` | `GameManager.gd` L434-455 |
| 物品库 | `const ITEM_DB`，7 条，字段 `name/icon/desc/price`，`handmade_gift` 额外带 `category:"gift"` 且 `price:0` | `GameManager.gd` L255-263 |
| 背包 | `var inventory: Dictionary`（item_id → count） | `GameManager.gd` L264 |
| 物品 API | `add_item / remove_item / has_item`，`add_item` 开头 `if not ITEM_DB.has(item_id): return`（**未注册即静默丢弃**） | `CollectionManager.gd` L11-27 |
| 商店 | `ShopUI.update_shop_list()` **无条件遍历整个 `ITEM_DB`**，无分类/无过滤；`_on_buy_pressed` 扣 money → `add_item` | `ShopUI.gd` L137-138 / L222-232 |
| 集章（收集 a） | `WEST_LAKE_STAMP_SCENES`(10) + `grant_stamp` + `_check_stamp_completion` + `_retroactive_stamp_check` + `build_stamp_vignette`；状态全落 `flags`；集满授 `title_西湖十景通` + 画廊 CG | `CollectionManager.gd` L114-337 |
| 记忆回响（收集 b） | `MEMORY_ECHO_CONTEXTS`(10) + `pick/build/commit`；**不消耗时段**，插在 `_on_location_selected` step 0 | `CollectionManager.gd` L339-623 / `MainGame.gd` L216-240 |
| 画廊 | `const GALLERY_ITEMS`（数组，`{char,pose,label,hint,flag,bg}`）+ `FAVOR_GALLERY_UNLOCKS` | `GameManager.gd` L293-360 / `CollectionManager.gd` L48-71 |
| 补偿扫描单一入口 | `GameManager._retroactive_gallery_check()` → `CollectionManager._retroactive_gallery_check()` → 内部串调 `_retroactive_stamp_check()` | `CollectionManager.gd` L85-90 |
| 事件门控 | DataManager 支持 `location/slotId/triggerDay/repeatable/charId/minAff/requireFlags/excludeFlags/requireItem+requireItemAmt/requireMoney/minAddict/minStress/conditionType/requireWeather/requireSeason` | `DataManager.gd` L190-278 |
| 事件产出 | 事件级 `addItem`、场景级 `addItem`、`statDelta/statsDelta`（**money 可为负，走 add_stat**） | `DialogueUI.gd` L122 / L214-216 / L650-654 |
| 热点路由 | `HotspotExploreUI.on_hotspot_clicked()` 的 `match event_id` 分发；`_open_sub_ui(路径, pre_cb, close_cb)` 为通用子界面模式 | `HotspotExploreUI.gd` L141-208 / L213-239 |
| 手作产出 | `int_craft_make` **`repeatable: true`**，`location:"home"`，场景级 `addItem:"handmade_gift"` → **`handmade_gift` 可反复产出，不是稀缺资源** | `events_life.json` L1235 + 事件头 |
| 命名空间 | `fengwu` 前缀全工程**零占用**（Grep 实证） | `scripts/**` |
| 存档 | `save_game` 已持久化 `money` / `flags` / `inventory` / `stats` | `SaveSystem.gd` L69/75/76 |
| NG+ 继承白名单 | profile 键 = `ng_count / unlocked_titles / unlocked_recipes / seen_endings / gallery_flags / inherited_money / inherited_favorability / inherited_subjects`；恢复时 `flags = {}`、`inventory = {}`、money = `100 + min(50%, 500)`；`title_*` 前缀自动回写 | `EndingScreen.gd` L337-389 / L462-522 |
| 更多菜单 | 已有 **9** 个按钮（含「📖 集章簿」「🖼️ 珍贵画廊」「🏅 青春赛季」「🎓 往昔结局」） | `MainGame.gd` L411-421 |

### ⚠️ 两条会直接改变设计的关键发现

**发现 1 · 游戏内四季是「线性单次」，不是循环**

```gdscript
# WeatherManager.gd L28-33
func get_season() -> String:
	var day = GameManager.day
	if day <= 150:   return "spring"      # 第 1-150 天
	elif day <= 300: return "summer"      # 第 151-300 天
	elif day <= 450: return "autumn"      # 第 301-450 天
	else:            return "winter"      # 第 451-570 天
```

570 天里**每个季节只出现一次**（各 120-150 天的长块）。这意味着：任何「季节硬门槛」的收集项 = **一旦错过就本周目永久无法补齐** → 集满称号永久锁死。
十景集章 GDD 的 **D-1 决策已经拍板过同一问题**：`season` 字段「仅作展示与弱正反馈，非获取门槛」（`CollectionManager.gd` L108 注释原文）。
👉 **本 GDD 严格沿用该裁决**，季节一律为软正反馈，不做硬门槛。这是跨 GDD 一致性要求，不是可选项。

**发现 2 · NG+ 会上传 `gallery_flags` 但恢复时不写回**

`EndingScreen._upload_profile_on_ending()`（L348-352）扫描 `GALLERY_ITEMS` 收集已解锁 flag 打进 profile，但 `_on_ng_plus_pressed()`（L462-522）的恢复段**只回写** `ng_count / seen_endings / title_* / recipes / 好感 / 分科 / money`——`gallery_flags` 从未被消费。
即：**画廊在 NG+ 会清零，称号会保留**。这是既有行为，十景集章也是如此。
👉 本特性**对齐既有行为，明确不修**。修它会改变已放行特性（十景集章）的跨周目语义 = 回归风险。已在 §7 立为红线。

---

# Part I · 三个玩法概念

## §A 概念 A：《西湖风物志》—— 第三套收集图鉴（拾得 / 购得 / 手作）

**一句话**：一本初中生自己攒的杭州风物小图鉴——24 件「味 / 物 / 草木 / 声景」，从西湖边、校园里、市集上一件件捡回来、买回来、做出来。

### 核心循环
```
日常进出地点（本就要做的事）
   └→ 满足 地点+季节+天气+时段 软条件 → 概率「拾得」一件风物（不打断、只弹 toast）
   └→ 清河坊市集 / 小卖部 → 用 money「购得」风物
   └→ 攒够 handmade_gift + 材料费 → 手作台「做出」风物
        ↓
   风物志图鉴：24 格逐格点亮，点开可读 3 句随笔 + 获得日
        ↓
   单类集满 6 件 → 分类徽章 + toast
   全 24 件集满 → title_西湖风物通 + 画廊 CG「西湖风物·大成」
```

### 为何契合西湖初中题材
- 初中生不会「经营」，但**一定会攒东西**：桂花、枫叶、汽水瓶盖、明信片。这是这个年龄段最真实的行为。
- 杭州风物是现成的、几乎不需要虚构的素材库：龙井、藕粉、王星记扇、天竺筷、满觉陇桂花、南屏晚钟。
- 与十景集章形成**「地点 vs 物件」的干净对位**：十景是「我走过这些地方」，风物是「我攒下这些东西」。三年下来两本册子并排，就是毕业纪念册的一体两面。
- 「声景」子类（雪落断桥 / 晚自习蝉鸣 / 游船桨声）承接项目现有的高文学度旁白调性，且**零美术成本**。

### 复用 vs 新增
| 复用（不改） | 新增 |
|---|---|
| `CollectionManager` 常量表 + grant/progress/retroactive 模式（照抄十景 5 函数骨架） | 1 个常量表 `FENGWU_ITEMS` + ~10 个函数（同文件内） |
| `GameManager.flags`（状态载体）/ `set_flag` | `fengwu_*` 系列 flag |
| `ITEM_DB` / `inventory` / `add_item` | 6 条 `category:"fengwu"` 物品 |
| `ShopUI`（遍历 ITEM_DB，**零改动自动上架**） | — |
| `GALLERY_ITEMS` + `title_` 前缀称号链路 | 1 条画廊条目 |
| `WeatherManager.get_season/current_weather`（软条件） | — |
| `MainGame._on_location_selected` 既有钩子位 | 1 行插入 |
| `handmade_gift` + `int_craft_make` 链路 | 6 条 `fw_craft_*` 事件 |
| `SaveSystem` / NG+（落 flags 即自动持久化 + 自动清零） | 0 |

**工作量：L**（MVP 层可压到 **M**，见 §C 范围分层）

---

## §B 概念 B：《手作摊 · 文化节义卖》—— 轻经营回路

**一句话**：文化节 / 跳蚤市场上摆一次手作摊，进货—定价—应对顾客—收摊结算。

### 核心循环
```
备货（消耗 money 买材料 + 消耗时段做 handmade_gift）
   → 摆摊日（day 240 文化节 / 周末校门口）
   → 定价决策（高价低销 / 低价走量）
   → 3-5 个随机顾客事件（同学 / 老师 / 攻略角色路过 / 砍价大妈）
   → 收摊结算：营收 - 成本 = 利润 → money
   → 利润再投入下一轮备货
```

### 为何契合
- `day 240 文化节` 已在 `SPECIAL_DATES` 里，`effect:"special"`，天然是摆摊日。
- 攻略角色路过摊位 = 高质量的好感互动场景。
- 初中生「摆摊」只在校园义卖语境下成立——一年一两次，不能常驻。

### 复用 vs 新增
| 复用 | 新增 |
|---|---|
| `money` / `add_stat("money", ±n)` | 进销存状态（库存 / 成本 / 定价 / 营收，**至少 4 个新状态**） |
| `ITEM_DB` 材料物品 | 定价 UI + 顾客队列 UI（新脚本 ~2 个） |
| `SPECIAL_DATES[240]` 文化节 | 顾客随机事件池（~12 事件 × 双路线） |
| `events_life.json` 事件引擎 | 结算公式 + 价格波动曲线 |
| `handmade_gift` | — |

**工作量：L（偏重）**

### ⛔ 设计红线预警
- **经济失衡**：现有唯一收入是 100-120/周 + 兼职 80/周末。一个可重复的利润回路会瞬间成为**主导策略**——只要摆摊比学习「划算」，玩家的最优解就是刷摊，而这**直接对撞项目的「时间即代价」支柱**（`GameManager.gd` L476-478 的机会成本提示系统）。
- 要把利润压到「不划算」才安全，但那样经营就没有正反馈 → **设计自相矛盾**。
- 一年一次的低频形态可以规避，但低频 = 长线价值弱（570 天里只触发 2-3 次）。

---

## §C 概念 C：《青春纪念册》—— 跨收集成就树

**一句话**：把 `GALLERY_ITEMS`(47) + 十景(10) + 记忆回响(10) + `title_*` 称号统一成一棵成就树，配一根「三年收集总进度条」和里程碑奖励。

### 核心循环
```
玩家在任意已放行系统里推进（画廊 / 集章 / 回响 / 称号 / 结局）
   → 纪念册聚合层只读扫描，实时算出「三年收藏度 X%」
   → 跨系统里程碑（25% / 50% / 75% / 100%）→ 称号 + 画廊跨页
   → 毕业典礼结算时，纪念册作为「你的三年」摊开展示
```

### 为何契合
- `GALLERY_ITEMS` 里**已经有 `grad_yearbook`「毕业纪念册」条目**（`GameManager.gd` L356）——这个隐喻是项目自己埋好的锚点。
- 解决一个**真实存在的问题**：更多菜单已 9 个按钮，画廊/集章/赛季/结局四个收集入口彼此割裂，玩家没有「我总共完成了多少」的单一答案。

### 复用 vs 新增
| 复用 | 新增 |
|---|---|
| 全部三套收集的现有 flag（**纯只读，一行不写**） | 1 个聚合表 `MEMENTO_TREE` + ~6 个只读查询函数 |
| `title_` 前缀链路 | 4 条里程碑称号 flag |
| `GALLERY_ITEMS` | 1-2 条跨页画廊条目 |
| `EndingScreen` 结算 | 纪念册 UI（新脚本 1 个） |

**工作量：M**

### 局限
纯 meta 层——它让已有内容**更有连贯感**，但**不产生新的逐时段玩法**。用户诉求是「增加玩法」，C 严格来说是「整理玩法」。

---

## §D 三概念一句话对比 + 推荐

| | A《西湖风物志》 | B《手作摊义卖》 | C《青春纪念册》 |
|---|---|---|---|
| 类型 | 收集主导 + 轻经济 | 经营主导 | 元收集 / 聚合 |
| 题材契合 | ★★★★★ 攒东西是初中生本能，杭州风物零虚构 | ★★★☆☆ 初中生开店需强行包装，只能低频 | ★★★★☆ `grad_yearbook` 是项目自埋锚点 |
| 复用度 | ★★★★☆ 照抄十景骨架 + ShopUI 零改动上架 | ★★★☆☆ 进销存是全新状态机 | ★★★★★ 纯只读聚合 |
| 风险 | ★★★☆☆ 收集疲劳 / 入口过载 / lakeside 抢道 | ★★★★★ **经济失衡 + 主导策略 + 撞「时间即代价」支柱** | ★☆☆☆☆ 只读，几乎无风险 |
| 长线价值 | ★★★★★ 24 条 × 3 渠道横跨 570 天四季 | ★★☆☆☆ 一年 2-3 次，回路易腻 | ★★★★☆ 完美主义者锚点，但天花板由他人内容决定 |
| 新玩法感 | 强 | 强 | 弱 |
| 双路线成本 | **零**（物是物，与性别无关，24 条全共享） | 中（顾客事件需双路线文案） | 零 |
| 工作量 | L（MVP 可压 M） | L（偏重） | M |

### 🏆 推荐：**概念 A 《西湖风物志》**

**理由（按用户给的四维）**

1. **题材契合**——这是唯一一个「不需要为了玩法而扭曲人设」的方案。B 要让初中生做小老板，C 不产生新行为；A 只是把「初中生本来就在攒东西」这件事系统化。24 件风物全部是真实杭州物产/景象，文案密度可以直接对齐已放行的十景 vignette 调性。

2. **复用度**——十景集章已经跑通了一条完整的「常量表 → grant → 集满 → 称号 → 画廊」流水线并通过质量门。风物志是**同一条流水线的第二次实例化**，工程侧几乎是模式复制而非新架构。更关键的三个零改动：
   - `ShopUI` 遍历整个 `ITEM_DB`（L137-138）→ 新增物品**自动上架，零改动**
   - `SaveSystem` 已存 `flags`/`inventory`/`money` → **零存档迁移**
   - NG+ 的 `title_` 前缀白名单 → 称号**自动继承，零改动**

3. **风险**——A 的三个风险（收集疲劳 / 入口过载 / lakeside 抢道）**全部有明确、廉价的缓解**（§7 逐条给方案），且都不触碰已放行代码路径。而 B 的经济失衡风险是**结构性的**：它与项目的核心支柱直接对撞，只能靠「把奖励压到没意思」来规避，这不是缓解，是阉割。

4. **长线价值**——570 天 × 4 时段 = 2280 个决策槽。A 提供 24 个跨越四季、分布在 8+ 个地点的收集目标，且**不消耗时段**（拾得是进地点的副产物）→ 它给长流程注入密度，却不与恋爱主线抢时间预算。这是收集向玩法在长流程里最理想的形态。

**同时吸收 C 的核心价值**：A 的 §5 集成方案把「更多菜单」的「📖 集章簿」升级为「📖 青春收藏」二级选单（内含 集章簿 / 风物志），按钮总数保持 9 不变。这解决了 C 想解决的入口割裂问题的一半，成本近乎为零，且 **StampBookUI 一行不动**。

**不推荐 B 的明确理由**：经济失衡与「时间即代价」支柱冲突（支柱漂移红线）。若用户仍想要经营手感，建议以 A 的「购得」渠道 + §附录 的价格季节浮动作为轻量替代。

---

# Part II · 《西湖风物志》完整 GDD

---

## §0 概览与目标

### 0.1 特性定位

`CollectionManager` 的**第三套收集系统**，与已放行两套的关系：

| | 西湖十景集章（已放行） | 记忆回响（已放行） | **西湖风物志（本 GDD）** |
|---|---|---|---|
| 收集对象 | 10 个地点 | 10 段长假记忆（**派生**，不新增） | 24 件物 |
| 获取动作 | 主动打卡（lakeside 单入口） | 被动触发（不可主动） | **三渠道**：拾得 / 购得 / 手作 |
| 是否打断 | 是（播 vignette，消耗时段） | 是（播 vignette，**不**消耗时段） | **否**（仅 toast，不消耗时段） |
| 与经济 | 无 | 无 | **有**（购得 / 手作消耗 money） |
| 情感落点 | 「我走过这些地方」 | 「我还记得那时候」 | 「我攒下这些东西」 |
| 集满奖励 | `title_西湖十景通` + CG | 无（软演出） | `title_西湖风物通` + CG |

### 0.2 设计支柱（2 条，本特性内不得漂移）

- **P1 · 收集是日常的副产物，不是日常的替代品**
  拾得不消耗时段、不打断流程、不给属性收益。玩家永远不需要「为了收集而专门跑一趟」，也永远不会因为收集而放弃学习或约会。
  → 这条直接守护项目的「时间即代价」支柱。

- **P2 · 三年攒下的东西，是给未来的自己看的**
  风物无功能性收益（不加属性、不加好感、不可消耗）。它的唯一回报是图鉴里那一格亮起来，和点开后的三句随笔。
  → 与十景集章的情感回报模型完全一致（十景也只给 stress -2 的弱反馈）。

### 0.3 范围分层

| 层 | 内容 | 条目数 | 工作量 | 依赖 |
|---|---|---|---|---|
| **MVP** | 仅**拾得**渠道（草木 6 + 声景 6）+ 图鉴 UI + 集满称号 | 12 | **M** | 零 `ITEM_DB` 改动、零事件改动、零 `ShopUI` 改动 |
| **目标** | + 购得 6（`ITEM_DB` + 市集事件）+ 手作 6（消耗 `handmade_gift`）+ 分类徽章 | 24 | **L** | 需内容 pass 补 18 条文案 |
| **愿景** | 风物赠礼偏好（不同角色偏好不同风物）/ 风物进入毕业结算文案 | 24 | — | 需双路线文案，**本 GDD 不展开** |

⚠️ MVP 是**可独立发布的完整体验**：12 条、单渠道、集满即得称号。目标层新增的 12 条以「图鉴扩容」形式追加，不改 MVP 已有逻辑。

### 0.4 成功标准

| # | 标准 | 可验证方式 |
|---|---|---|
| S-1 | 零新 Autoload | `project.godot` autoload 段 diff 为空 |
| S-2 | 零存档迁移 | 所有新状态落 `flags` / `inventory`，`SaveSystem` diff 为空 |
| S-3 | 三个已放行特性零回归 | `StampBookUI.gd` / 记忆回响区 / 手机 UI 相关文件 diff 为空 |
| S-4 | 拾得不消耗时段 | 逻辑断言：拾得路径不调用 `advance_time()` |
| S-5 | 收集密度合理 | 推演：570 天预期拾得 12/12，且 P(集满) ≥ 0.95（§3.1 数值） |
| S-6 | 双路线零分流 | `FENGWU_ITEMS` 无 `charId` / 无性别字段 |
| S-7 | 更多菜单按钮数不增 | `MainGame.gd` L411-421 items 数组长度保持 9 |

---

## §1 核心循环

### 1.1 逐时段循环（微观）

```
玩家在看板选一个地点
   ↓
[MainGame._on_location_selected(loc_id)]
   ├─ step 0：记忆回响判定（已存在）── 命中 → 播回响 → return → 播完重入
   ├─ step 1：风物拾得判定（★新增）── 命中 → 弹 toast + 写 flag → 继续往下（不 return）
   └─ step 2：进入热点探索层（已存在）
   ↓
玩家正常做他本来要做的事（学习 / 找人 / 触发事件）
```

**关键设计**：step 1 **不 return**。拾得是「顺手捡到」，不是一次独立的交互。它插在记忆回响之后——回响命中时会 `return` 并在播完后重入，重入时 `pick_memory_echo` 必返回 `{}`（冷却已写），才轮到拾得判定。
👉 **同一次进入地点，回响与拾得天然互斥，零额外互斥代码**。

### 1.2 长周期循环（宏观 · 570 天）

```
初一上（day 1-90，spring）    → 柳枝 / 桃核 / 莺啼陆续到手，图鉴开张
初一下（day 91-180，spring→summer）→ 荷叶 / 蝉鸣 / 桨声；小卖部开始出现风物商品
初二（day 181-360，summer→autumn）→ 桂花 / 香樟籽 / 晚钟；handmade_gift 攒够，手作台开张
初三上（day 361-450，autumn）  → 红枫 / 剩余购得项收尾
初三下（day 451-570，winter）  → 蜡梅 / 雪落断桥（限 snowy，最紧张的一格）
day 569 毕业前夜               → 图鉴翻到最后一页，与记忆回响、集章簿并列
```

### 1.3 三渠道的取舍结构（为什么是三条而不是一条）

| 渠道 | 玩家付出的是 | 门槛类型 | 条目数 | 设计意图 |
|---|---|---|---|---|
| **拾得** | 注意力 / 运气 | 软条件（地点+季节+天气+时段）+ 概率 | 12 | 奖励「到处走走」的探索型玩家（Bartle Explorer） |
| **购得** | money | 经济 | 6 | 给周零花钱一个**非功利的花法**，与 exam_guide 形成取舍 |
| **手作** | 时段 + `handmade_gift` + 少量 money | 时间 + 材料 | 6 | 承接 P2 已落地的 `int_craft_make`，让手作有第二个去处（原本只能送人） |

三条渠道分别对应**运气 / 财力 / 时间**三种资源，任一渠道被卡死都不会锁死全局进度感——但集满 24 需要三者兼备。这是防「单一主导策略」的结构性设计。

---

## §2 MDA 分析

### 2.1 Mechanics（机制）

| 机制 | 定义 |
|---|---|
| M1 拾得掷骰 | 进入地点时，对满足软条件的候选风物按概率判定，每日至多 1 次成功 |
| M2 保底递增（pity） | 连续未拾得天数越多，概率越高（35% → 80% 封顶） |
| M3 季节/天气软加权 | 当季/对味天气时该条目权重与概率提升，**但非门槛** |
| M4 商品上架 | 6 条 `category:"fengwu"` 物品常驻 `ITEM_DB`，`ShopUI` 自动展示 |
| M5 手作合成 | 消耗 1×`handmade_gift` + money，产出 1 件风物物品 |
| M6 物品→图鉴登记 | `add_item` 时若 `item_id` 在 `FENGWU_ITEMS` 中，自动点亮图鉴格 |
| M7 分类小成 | 单类 6 件集满 → 徽章 + toast（**不发称号**，防称号通胀） |
| M8 大成 | 24 件集满 → `title_西湖风物通` + 画廊 CG |

### 2.2 Dynamics（动态 · 玩家实际会做什么）

- **D1「反正要去，顺便看看」**——因为拾得不要钱不要时间，玩家在选地点时会产生**极轻微的偏好扰动**：同样是自习，今天下雨那去图书馆还是湖边？这个扰动足够小（不影响最优解），但足够真实（给了地点选择一点额外滋味）。
  ✅ 这正是我们要的：**丰富决策的口感，不改变决策的结构**。

- **D2「这一季的东西这一季捡」**——季节是软加权而非硬门槛，所以玩家不会焦虑，但会自然地在秋天想起「桂花该有了」。

- **D3「零花钱有了第三个去处」**——现有 money 出口是约会道具（movie_ticket 40 / amusement_ticket 80）和 exam_guide 50。风物 15-60 元插入其间，构成**「功利消费 vs 情感消费」的真实取舍**。周零花 100-120 意味着买一件风物 ≈ 放弃半张电影票。

- **D4 终局冲刺**——初三下（winter, day 451-570）如果还差「雪落断桥」（需 snowy 天气），会形成一段真实的、有情绪的等待。这是四季线性带来的**意外礼物**：最后一格天然最难。

- ⚠️ **反面动态 D5（已识别）**：如果拾得概率过高，玩家会感到「系统在往我兜里塞东西」，收集失去分量；过低则产生「刷地点」行为——那会直接违反支柱 P1。§3.1 的数值就是在这两者之间取平衡，pity 机制是防「刷」的关键（保底让刷没有收益）。

### 2.3 Aesthetics（美学 · 目标体验）

主美学：**Discovery（发现）** + **Expression（表达 / 我的三年长这样）**
次美学：**Sensation（感官——文案的味觉/听觉密度）**

明确**不追求**：Challenge（不做难度）、Competition（不做排行）、Fellowship（不做社交分享）。

情绪曲线锚点：
- 第一次拾得（初一上，柳枝）：「诶？还有这个？」——轻微惊喜，无负担
- 中段（初二，桂花/蝉鸣）：「哦对，该有这个了」——季节感的确认
- 终局（初三下，雪落断桥）：「就差这一个了」——三年跨度带来的重量
- 毕业前夜翻图鉴：24 格全亮，每格一个日期——**这才是这个系统真正的产出**

---

## §3 系统拆解（逐系统八节）

### 系统 1 · 拾得判定（Found Roll）

| 节 | 内容 |
|---|---|
| **① 目标** | 让玩家在正常游玩过程中，以「顺手」的姿态获得风物；不制造额外行程，不消耗任何资源 |
| **② 输入** | `loc_id: String`（玩家正进入的地点）；隐式读 `GameManager.day` / `slot_index` / `current_weather` / `WeatherManager.get_season()` / `flags` |
| **③ 规则** | 详见下方规则表 |
| **④ 反馈** | 成功：`show_toast.emit("🍃 拾得风物：<emoji> <名>（n/24）")` + `add_log` + `add_diary_entry("在<地点>捡到了<名>")`。失败：**完全静默**（无任何提示，玩家不应感知到掷骰存在） |
| **⑤ 状态** | 写 `fengwu_<fid>` / `fengwu_<fid>_day` / `fengwu_found_day` / `fengwu_dry_streak`。全部落 `GameManager.flags` |
| **⑥ 边界** | 见下方边缘情况表（≥3 类） |
| **⑦ 数值** | 见 §3.1 |
| **⑧ 风险** | 概率调参错误 → 密度失控。缓解：§8 验收标准 A-5 用蒙特卡洛推演验证 570 天集满率 |

**③ 规则（守卫链，任一不过即 `return ""`）**

| 守卫 | 条件 | 理由 |
|---|---|---|
| F0 | `day < 570` | 结局日不插入任何软演出（对齐记忆回响 G0） |
| F1 | `int(flags.get("fengwu_found_day", -1)) != day` | 每日至多拾得 1 件，防单日刷 |
| F2 | `current_holiday == ""` | 长假期间不触发（对齐记忆回响 G3，长假有独立叙事线） |
| F3 | 候选池非空 | 候选 = `source=="found"` 且 `loc==loc_id` 且未拥有 且（`weather` 为空或匹配）且（`slot` 为空或匹配） |
| F4 | `randf() < p` | `p` 见 §3.1 |

**命中后选择**（多条同时通过 F3 时）：按权重降序取第一，平局按 `fid` 字典序升序（对齐 `pick_memory_echo` 的确定性平局规则，`CollectionManager.gd` L557）。
权重 = `100`（当季 `season` 匹配）+ `50`（`weather` 非空且匹配，即"限定天气"条目优先消费稀有机会）+ `min(dry_streak, 30)`。

**⑥ 边缘情况（≥3 类）**

| # | 情况 | 期望行为 |
|---|---|---|
| E1-1 | 记忆回响同一次进入地点也命中 | 回响先 `return`，播完重入；重入时回响冷却已写 → `pick` 返回 `{}` → 才轮到拾得。**同一次进入不会同时触发两个软演出** |
| E1-2 | 玩家在同一时段反复进出同一地点（若 UI 允许） | F1 拦截（`fengwu_found_day == day`）→ 当日已拾得则静默失败；未拾得则每次进入都掷骰 → **需与 F1 配合确认「进地点」是否消耗时段**。若不消耗，`dry_streak` 保底会让反复进出必然成功 → ⚠️ 见 §7 风险 R-4，缓解为增设时段级限速 `fengwu_roll_slot` |
| E1-3 | `FENGWU_ITEMS` 中某条 `loc` 写了不存在的地点 id | 该条永不进候选池 → 永远无法集满 → **死分支**。§8 验收 A-2 静态断言拦截 |
| E1-4 | 天气限定条目（雪落断桥需 snowy）整个 winter 都没下雪 | 保底不覆盖天气门槛 → 本周目无法集满。⚠️ §7 风险 R-2，缓解：天气**降级为软加权**，非门槛 |
| E1-5 | NG+ 后 `flags` 清空但 `inventory` 也清空 | 图鉴归零，购得/手作物品一并清空 → 语义自洽，符合「新周目重新收集」 |
| E1-6 | 玩家从不去 lakeside 以外的地点 | 只能集齐 lakeside 条目 → 设计上**这是可接受的取舍**（收集本就奖励探索），但 §3.2 的地点分布必须保证「常去地点」覆盖 ≥ 60% |

---

### 系统 2 · 购得渠道（Bought）

| 节 | 内容 |
|---|---|
| **① 目标** | 给零花钱一个非功利出口；让「攒钱买一件不实用的东西」成为一次有情绪的决策 |
| **② 输入** | 玩家在 `off_campus_shop` / `market` 点击购买；读 `GameManager.money` |
| **③ 规则** | 6 条风物注册进 `ITEM_DB`（`category:"fengwu"`，`price` 15-60）。`ShopUI` 无条件遍历 `ITEM_DB` → **零改动自动上架**。购买 → `_on_buy_pressed` 扣 money → `add_item` → `add_item` 末尾新增的 `_check_fengwu_by_item()` 自动点亮图鉴 |
| **④ 反馈** | 复用 `add_item` 现有 toast「获得物品: X x1」+ 新增图鉴点亮 toast |
| **⑤ 状态** | `inventory[fid] += 1`（复用）+ `fengwu_<fid>` / `fengwu_<fid>_day`（新增） |
| **⑥ 边界** | 见下表 |
| **⑦ 数值** | 见 §3.2 定价表 |
| **⑧ 风险** | `ShopUI` 列表从 7 条涨到 13 条，滚动区变长 → §7 风险 R-3 |

**⑥ 边缘情况**

| # | 情况 | 期望行为 |
|---|---|---|
| E2-1 | 玩家重复购买同一风物 | `inventory` 计数递增（复用现有语义），但 `grant_fengwu` **幂等**——图鉴只点亮一次，不重复发 toast（对齐 `grant_stamp` L273 的 `if flags.has(flag): return false`） |
| E2-2 | 玩家把风物送人 / `remove_item` 掉 | 图鉴**保持点亮**（`fengwu_<fid>` 不因失去物品而清除）。语义：「我曾经拥有过」，与画廊 `seen_*` 一致 |
| E2-3 | 事件通过 `addItem` 发放风物（非商店路径） | 同样经 `CollectionManager.add_item` → 自动登记。**单一登记入口，无遗漏** |
| E2-4 | money 不足 | `ShopUI` 现有逻辑已 disable 按钮 + 提示（L213-217 / L232），零改动 |

---

### 系统 3 · 手作渠道（Made）

| 节 | 内容 |
|---|---|
| **① 目标** | 让 P2 已落地的 `handmade_gift` 有第二个用途（原本只能送人），把「做东西」从一次性事件变成长线产出 |
| **② 输入** | `handmade_gift` × 1 + money × 材料费；玩家在 `home` / `art_room` 触发 `fw_craft_*` 事件 |
| **③ 规则** | 6 条 `fw_craft_<fid>` 事件写入 `events_life.json`，门控用**既有字段**：`requireItem:"handmade_gift"` + `requireItemAmt:1` + `requireMoney:<材料费>` + `triggerDay` + `location`。场景末尾 `statDelta:{"money": -<材料费>}` + `addItem:"<fid>"` |
| **④ 反馈** | 复用对话演出（2-3 句手作过程旁白）+ `add_item` toast + 图鉴点亮 toast |
| **⑤ 状态** | 消耗 `inventory["handmade_gift"]`、扣 money、`inventory[fid] += 1`、`fengwu_<fid>` |
| **⑥ 边界** | 见下表 |
| **⑦ 数值** | 材料费 10-25 元；`handmade_gift` 由 `int_craft_make` 产出（P2 已落地） |
| **⑧ 风险** | `handmade_gift` 产量若不足 6 件，手作类永远无法集满 → §7 风险 R-5 |

**⑥ 边缘情况**

| # | 情况 | 期望行为 |
|---|---|---|
| E3-1 | `requireItem` 通过但事件内 money 被其他途径花掉 | `DialogueUI` L413-429 已有「扣钱前校验」逻辑；`add_stat("money", -n)` **不 clamp**，money 可为负 → ⚠️ 必须用 `requireMoney` 前置门控（DataManager L252-255 已支持），不依赖场景内校验 |
| E3-2 | 事件不消耗 `handmade_gift`（只 require 不 remove） | `requireItem` **只校验不消耗**（DataManager L245-250 只做 `has_item` 判断）。若要真消耗，需在场景内显式处理 → **必须在事件设计时明确**，否则一个 `handmade_gift` 可解锁全部 6 条 = 主导策略。§8 验收 A-7 拦截 |
| E3-3 | `repeatable` 误设为 true | 玩家可无限刷同一风物物品（图鉴幂等所以不影响进度，但会刷 `inventory`）→ 事件应设 `repeatable:false`，靠 `flags[ev_id]` 天然去重（DataManager L208） |

---

### 系统 4 · 图鉴 UI（FengwuBookUI）

| 节 | 内容 |
|---|---|
| **① 目标** | 让 24 格的点亮过程可视、可翻阅；提供拾得时被刻意省略的文案阅读场 |
| **② 输入** | 只读 `CollectionManager.FENGWU_ITEMS` + `GameManager.flags` |
| **③ 规则** | 只读面板，**无任何写操作**。4 个分类页签（味/物/草木/声景），每页 6 格。已得格显示 emoji + 名 + 获得日；未得格显示 `?` + 灰化 + 提示（渠道 + 大致方位，不剧透精确条件） |
| **④ 反馈** | 顶部总进度条 `n/24`；4 个分类徽章（集满亮起）；点格 → 右侧详情区显示 summary + 3 句随笔 + `format_fengwu_day()` |
| **⑤ 状态** | 无（纯只读，`closed` 信号关闭） |
| **⑥ 边界** | 打开面板**不消耗时段**（对齐集章簿 book 模式，`MainGame.gd` L174-187）；从主界面打开时须记录并恢复 `location_explore_ui.visible`（L177-186 已有该模式，照抄） |
| **⑦ 数值** | 1280×720，格子 4 列 × 2 行 / 页 |
| **⑧ 风险** | 未得格提示写太细 → 变成任务清单，破坏「发现」美学。缓解：提示只写渠道 + 季节意象（例：「秋天，某处树下」），不写地点 id |

**明确复用**：`ThemeUtils` / `PopupManager.make_overlay_popup` / `StampBookUI` 的布局范式（**照抄范式，不修改 StampBookUI 本体**）。

---

### 系统 5 · 集满与称号（Completion）

| 节 | 内容 |
|---|---|
| **① 目标** | 给 570 天的长线收集一个有分量的终点 |
| **② 输入** | 每次 `grant_fengwu()` 成功后自动检查 |
| **③ 规则** | 分类集满（6/6）→ `fengwu_cat_<cat>` = true + 徽章 toast（**不发称号**）。全 24 集满 → `fengwu_complete` + `title_西湖风物通` + `unlock_gallery("fengwu_complete")` + 隆重 toast。**若本次授予即触发大成，跳过普通 toast**（照抄 `grant_stamp` L279 的处理） |
| **④ 反馈** | 分类：`"🌿 风物志·<类名>集齐！"`；大成：`"🏆 西湖风物通！二十四件风物大成——称号已入账，画廊解锁「西湖风物·大成」"` |
| **⑤ 状态** | `fengwu_cat_<cat>` bool × 4、`fengwu_complete` bool、`title_西湖风物通` bool |
| **⑥ 边界** | 幂等（`if flags.has(FENGWU_COMPLETE_FLAG): return false`）；存量存档已满但未置 flag → `_retroactive_fengwu_check()` 补触发 |
| **⑦ 数值** | 4 个分类徽章 + 1 个称号 + 1 个画廊 CG |
| **⑧ 风险** | 称号通胀（项目已有 `title_西湖十景通`）→ 缓解：分类只给徽章不给称号，全局仅 +1 个称号 |

---

## §3.1 数值 · 拾得概率

```
p = clampf(FIND_BASE_P + FIND_PITY_STEP * dry_streak, 0.0, FIND_P_CAP)

FIND_BASE_P    = 0.35   # 基础命中率（单位：概率）
FIND_PITY_STEP = 0.10   # 每「空手日」递增（单位：概率/日）
FIND_P_CAP     = 0.80   # 概率上限（单位：概率）

dry_streak = flags.get("fengwu_dry_streak", 0)   # 单位：日
  命中时       → 置 0
  当日掷骰未中 → +1（每日至多 +1，由 fengwu_found_day 之外的 fengwu_roll_day 保证）
```

**密度推演（MVP 12 条，拾得渠道）**

| 假设 | 值 |
|---|---|
| 有效游玩日（570 - 长假约 60 - 结局 1） | ≈ 509 日 |
| 玩家每日进入 ≥1 个「有候选风物」的地点的概率 | 保守 0.45 |
| → 有效掷骰日 | ≈ 229 日 |
| 期望命中间隔（含 pity，base 0.35） | ≈ 2.4 日 |
| → 570 天期望命中数 | ≈ 95 次 |
| 需要命中数（12 条，每条只需 1 次） | 12 |

**结论**：拾得渠道在 MVP 规模下**极大概率满足**（余量 ~8×）。真正的瓶颈不是概率，而是**地点/季节覆盖**——玩家必须去过那 6-8 个地点、且在对应季节去过。
👉 因此 §3.2 的地点分布必须偏向**高频地点**，这是比概率调参重要得多的设计变量。

> 🔧 **调参留白**：若实测过于容易，优先下调 `FIND_BASE_P` 至 0.20；**不要**上调季节/天气为硬门槛（违反 §-1 发现 1 的既有裁决）。

---

## §3.2 数值 · 24 件风物注册表

**列说明**：`渠道` = found/bought/made；`loc` 仅 found 有效；`season`/`weather`/`slot` 为**软加权**（非门槛，见 §-1 发现 1）；`price` 单位=元（游戏内 money）

### 🌿 草木类（cat = `caomu`）· 6 条 · 全拾得

| fid | 名 | emoji | 渠道 | loc | season | slot | summary（图鉴首行） |
|---|---|---|---|---|---|---|---|
| `liuzhi` | 白堤柳枝 | 🌿 | found | `lakeside` | spring | — | 风一吹就扫到肩膀，折一小段夹进作业本。 |
| `taohe` | 苏堤桃核 | 🌸 | found | `lakeside` | spring | — | 吃剩的核，洗干净了倒有点像颗小石头。 |
| `heye` | 曲院荷叶 | 🍃 | found | `lakeside` | summer | — | 巴掌大的一片，翻过来叶背是浅浅的白。 |
| `guihua` | 满觉陇桂花 | 🌼 | found | `community` | autumn | — | 小区楼下也有一棵，落了一地碎金。 |
| `xiangzi` | 香樟籽 | 🌰 | found | `playground` | autumn | — | 杭州的市树，操场边一地黑紫色的小圆球。 |
| `lamei` | 墙头蜡梅 | 🌺 | found | `community` | winter | — | 从谁家院墙探出来的，香得整条巷子都是。 |

### 🔔 声景类（cat = `shengjing`）· 6 条 · 全拾得（「记下来」而非「拿到手」）

| fid | 名 | emoji | 渠道 | loc | season | weather | slot | summary |
|---|---|---|---|---|---|---|---|---|
| `yingti` | 柳浪莺啼 | 🐦 | found | `lakeside` | spring | — | morning | 叫一声换一个调，抬头找了半天一只没看见。 |
| `chanming` | 晚自习蝉鸣 | 🦗 | found | `library` | summer | — | evening | 一整面窗外都在响，反而让人静下来。 |
| `jiangsheng` | 游船桨声 | 🚣 | found | `lakeside` | summer | — | after | 咿呀，咿呀，慢得像不打算靠岸。 |
| `yuheye` | 雨打荷叶 | 🌧️ | found | `lakeside` | summer | rainy | — | 噼里啪啦，每一滴都能听出落在第几片上。 |
| `wanzhong` | 南屏晚钟 | 🔔 | found | `lakeside` | autumn | — | evening | 余音贴着水面铺过去，铺了好久才散。 |
| `xueluo` | 雪落断桥 | ❄️ | found | `lakeside` | winter | snowy | — | 几乎没有声音——那种"没有声音"本身就是声音。 |

### 🍵 味类（cat = `wei`）· 6 条 · 购得 4 / 手作 2

| fid | 名 | emoji | 渠道 | price | 备注 |
|---|---|---|---|---|---|
| `longjing` | 明前龙井 | 🍵 | bought | 60 | 最贵的一件，半周零花钱 |
| `oufen` | 西湖藕粉 | 🥣 | bought | 20 | — |
| `dingsheng` | 定胜糕 | 🍡 | bought | 15 | 最便宜，入门件 |
| `pianerchuan` | 片儿川 | 🍜 | bought | 25 | — |
| `tangou` | 桂花糖藕 | 🍯 | made | 15（材料费） | 需 `guihua` 已拾得（软提示，非硬门槛） |
| `congbaogui` | 葱包桧 | 🫓 | made | 10（材料费） | — |

### 🧵 物类（cat = `wu`）· 6 条 · 购得 2 / 手作 4

| fid | 名 | emoji | 渠道 | price | 备注 |
|---|---|---|---|---|---|
| `wangxingji` | 王星记扇 | 🪭 | bought | 55 | — |
| `tianzhukuai` | 天竺筷 | 🥢 | bought | 30 | — |
| `youzhisan` | 彩绘油纸伞 | ☂️ | made | 25 | 材料费最高 |
| `sipa` | 绣花丝帕 | 🧣 | made | 20 | — |
| `guolong` | 竹编蝈蝈笼 | 🧺 | made | 15 | — |
| `hushi` | 画过的西湖石 | 🪨 | made | 10 | 石头是湖边捡的，只花颜料钱 |

**经济总量校验**

| 项 | 金额 |
|---|---|
| 购得 6 件合计 | 60+20+15+25+55+30 = **205 元** |
| 手作 6 件材料费合计 | 15+10+25+20+15+10 = **95 元** |
| 风物总支出 | **300 元** |
| 570 天零花钱总收入（约 81 周 × 110） | ≈ **8910 元** |
| 占比 | **≈ 3.4%** |

✅ **结论：不构成经济压力，也不构成经济失衡**。风物是「零花钱的小数点后一位」，符合支柱 P2（无功能收益 → 也不该有经济痛感）。真正的取舍发生在**单次决策**层面：今天这 60 块买龙井还是买电影票？——这才是设计想要的那一下犹豫。

---

## §4 数据模型

### 4.1 复用的既有字段（一个不改）

| 字段 | 类型 | 位置 | 本特性如何使用 |
|---|---|---|---|
| `GameManager.money` | `int` | GameManager.gd L18 | 购得/手作扣款，经 `add_stat("money", -n)` |
| `GameManager.flags` | `Dictionary` | GameManager.gd L221 | **全部新状态的唯一载体** |
| `GameManager.inventory` | `Dictionary` | GameManager.gd L264 | 购得/手作产出的物品实体 |
| `GameManager.ITEM_DB` | `const Dictionary` | GameManager.gd L255 | 追加 6 条（见 4.3） |
| `GameManager.GALLERY_ITEMS` | `const Array` | GameManager.gd L293 | 追加 1 条（见 4.4） |
| `GameManager.set_flag(name, value)` | func | L678-685 | 唯一写 flag 通道（支持 bool / int） |
| `GameManager.day` / `slot_index` / `current_weather` / `current_holiday` | int/String | L19/20/29/30 | 拾得守卫与加权 |
| `CollectionManager.add_item / has_item` | func | L11-27 | 物品发放 + 图鉴登记挂钩点 |
| `CollectionManager.unlock_gallery(flag)` | func | L30-32 | 大成时解锁画廊 |
| `WeatherManager.get_season()` | func | L28-33 | 季节软加权 |
| `GameManager.show_toast` / `add_log` / `add_diary_entry` | signal/func | L389/L410/L417 | 反馈三件套 |

### 4.2 新增 flag（全部落 `GameManager.flags`，零存档迁移）

| flag 键 | 类型 | 默认 | 语义 |
|---|---|---|---|
| `fengwu_<fid>` | `bool` | 不存在 | 该风物已收集（24 个键） |
| `fengwu_<fid>_day` | `int` | -1 | 获得日（`GameManager.day`） |
| `fengwu_found_day` | `int` | -1 | 最近一次**成功拾得**的日（每日 1 件限速） |
| `fengwu_roll_day` | `int` | -1 | 最近一次**掷骰**的日（保证 `dry_streak` 每日至多 +1） |
| `fengwu_roll_slot` | `int` | -1 | 最近一次掷骰的 `day * 4 + slot_index`（时段级限速，防同时段反复进出，见 R-4） |
| `fengwu_dry_streak` | `int` | 0 | 连续空手日数（pity 基准） |
| `fengwu_cat_<cat>` | `bool` | 不存在 | 分类集满（4 个键：`wei`/`wu`/`caomu`/`shengjing`） |
| `fengwu_complete` | `bool` | 不存在 | 24 件大成（**同时是画廊 flag**） |
| `title_西湖风物通` | `bool` | 不存在 | 称号（`title_` 前缀 → EndingScreen L341 自动消费 + NG+ 自动继承） |

> 命名规范对齐十景（`stamp_<sid>` / `stamp_<sid>_day` / `stamp_checkin_day` / `west_lake_stamps_complete`）。
> ⚠️ 前缀 `fengwu_` 全工程未被占用（已 Grep 核实）。

### 4.3 新增常量（`CollectionManager.gd`，**tab 缩进**）

```gdscript
# ═══════════════════════════════════════════════════════════════
# ── 西湖风物志（第三套收集）─────────────────────────────────
# 设计依据：design/gameplay_economy_expansion_gdd.md
# 零新 Autoload / 零存档迁移：所有状态落 GameManager.flags
# ═══════════════════════════════════════════════════════════════

# ── 调参常量 ──────────────────────────────────────────────────
const FENGWU_TOTAL          := 24     # 风物总数（单位：件）
const FENGWU_FIND_BASE_P    := 0.35   # 拾得基础概率
const FENGWU_FIND_PITY_STEP := 0.10   # 每空手日概率递增
const FENGWU_FIND_P_CAP     := 0.80   # 概率上限
const FENGWU_END_DAY        := 570    # 结局日不触发拾得
const FENGWU_COMPLETE_FLAG  := "fengwu_complete"
const FENGWU_TITLE_FLAG     := "title_西湖风物通"

# ── 分类表（顺序 = 图鉴页签顺序）──────────────────────────────
const FENGWU_CATS := {
	"wei":       {"label": "味",   "emoji": "🍵", "count": 6},
	"wu":        {"label": "物",   "emoji": "🧵", "count": 6},
	"caomu":     {"label": "草木", "emoji": "🌿", "count": 6},
	"shengjing": {"label": "声景", "emoji": "🔔", "count": 6},
}

# ── 风物注册表：全工程唯一数据真源 ────────────────────────────
# 字段：
#   name        String        风物名
#   emoji       String        单 emoji，图鉴格主视觉
#   cat         String        分类键，必须 ∈ FENGWU_CATS
#   source      String        "found" | "bought" | "made"
#   loc         String        仅 source=="found" 有效；必须 ∈ GameManager.locations
#   season      String        软加权，"" 表示无季节倾向（⚠️ 非门槛，见 GDD §-1 发现 1）
#   weather     String        软加权，"" 表示无天气倾向（⚠️ 非门槛）
#   slot        String        软加权，"" 表示无时段倾向（"morning"/"noon"/"after"/"evening"）
#   price       int           仅 bought/made 有效；bought=售价，made=材料费（单位：元）
#   summary     String        图鉴详情区首行
#   lines       Array[String] 图鉴详情区随笔 3 句（⚠️ 不播 vignette，仅图鉴内阅读）
#   hint        String        未获得时图鉴显示的模糊提示（不剧透精确条件）
# ⚠️ 字典保持插入顺序 = 图鉴格顺序，不要对 keys() 排序。
# ⚠️ bought/made 的 fid 必须与 GameManager.ITEM_DB 的 item_id 完全一致（登记挂钩依赖此约定）。
const FENGWU_ITEMS := {
	"liuzhi": {
		"name": "白堤柳枝", "emoji": "🌿", "cat": "caomu", "source": "found",
		"loc": "lakeside", "season": "spring", "weather": "", "slot": "", "price": 0,
		"summary": "风一吹就扫到肩膀，折一小段夹进作业本。",
		"lines": [
			"白堤这一段的柳条垂得特别低，走过去得用手拨。",
			"你顺手折了一小段——很细，还带着点湿气。",
			"回家夹进作业本第 37 页。后来那页纸一直有点皱。",
		],
		"hint": "春天，某条堤上，垂到肩膀那么低的东西。",
	},
	# ... 其余 23 条同构（完整文案见内容 pass，本 GDD §3.2 已给全 24 条 summary）
}
```

### 4.4 新增 `ITEM_DB` 条目（`GameManager.gd` L255，**4 空格缩进**）

```gdscript
# ── 西湖风物（category:"fengwu"，ShopUI 自动上架，无功能性效果）──
"longjing":    {"name": "明前龙井", "icon": "🍵", "desc": "清明前采的头茬，杭州人送礼的体面。", "price": 60, "category": "fengwu"},
"oufen":       {"name": "西湖藕粉", "icon": "🥣", "desc": "冲开是半透明的，桂花撒一点更好。", "price": 20, "category": "fengwu"},
"dingsheng":   {"name": "定胜糕",   "icon": "🍡", "desc": "粉红色的小方糕，据说考前吃了讨彩头。", "price": 15, "category": "fengwu"},
"pianerchuan": {"name": "片儿川",   "icon": "🍜", "desc": "雪菜笋片瘦肉面，杭州小孩的胃都记得。", "price": 25, "category": "fengwu"},
"wangxingji":  {"name": "王星记扇", "icon": "🪭", "desc": "黑纸扇，摊开有一股淡淡的柿漆味。", "price": 55, "category": "fengwu"},
"tianzhukuai": {"name": "天竺筷",   "icon": "🥢", "desc": "天竺山的细竹做的，筷头烙着西湖景。", "price": 30, "category": "fengwu"},
```

> 手作类 6 条（`tangou`/`congbaogui`/`youzhisan`/`sipa`/`guolong`/`hushi`）**同样需要注册进 `ITEM_DB`**（`price: 0`，对齐 `handmade_gift` 的 `price:0` 写法），否则 `add_item` 的 `ITEM_DB.has()` 守卫（L12）会**静默丢弃**。
> ⚠️ 但 `price:0` 的物品会以「💰 0 / 购买」形式出现在 `ShopUI` → **必须处理**，见 §7 风险 R-3。

### 4.5 新增 `GALLERY_ITEMS` 条目（`GameManager.gd` L359 后追加）

```gdscript
# ── 西湖风物·大成（集齐 24 件后由 CollectionManager._check_fengwu_completion 解锁）──
{ "char": "player", "pose": "fengwu_complete", "label": "西湖风物·大成", "hint": "集齐二十四件西湖风物后解锁。三年，一座城，二十四件你亲手攒下的东西。", "flag": "fengwu_complete", "bg": "res://assets/backgrounds/fengwu_complete.jpg" },
```
> 美术需求：1 张 CG `fengwu_complete.jpg`（1280×720）→ 移交林绘澄（art-director）。构图建议：书桌俯视，24 件风物散落摆开，中间是翻开的图鉴本。

### 4.6 新增函数清单（全部在 `CollectionManager.gd` 内，tab 缩进）

| 函数 | 签名 | 副作用 | 对标既有 |
|---|---|---|---|
| `is_fengwu_owned` | `(fid: String) -> bool` | 无 | `is_stamp_owned` L226 |
| `get_fengwu_day` | `(fid: String) -> int` | 无 | `get_stamp_day` L230 |
| `get_fengwu_progress` | `() -> Dictionary` | 无 | `get_stamp_progress` L234 |
| `get_fengwu_cat_progress` | `(cat: String) -> Dictionary` | 无 | — |
| `format_fengwu_day` | `(d: int) -> String` | 无 | `format_stamp_day` L256（**可直接复用该函数，不必新写**） |
| `roll_fengwu_find` | `(loc_id: String) -> String` | **无**（纯判定，返回 fid 或 ""） | `pick_memory_echo` L499 |
| `grant_fengwu` | `(fid: String, source: String) -> bool` | 写 flag（**唯一写入口**，幂等） | `grant_stamp` L270 |
| `_check_fengwu_cat_completion` | `(cat: String) -> bool` | 写 `fengwu_cat_<cat>` | — |
| `_check_fengwu_completion` | `() -> bool` | 写 complete/title/gallery | `_check_stamp_completion` L287 |
| `_check_fengwu_by_item` | `(item_id: String) -> void` | 经 `grant_fengwu` 写 flag | — |
| `_retroactive_fengwu_check` | `() -> void` | 补 day + 补大成判定（幂等） | `_retroactive_stamp_check` L302 |

**⚠️ 明确不新增**：不新增 `build_fengwu_vignette()`。风物**不播演出**（设计决策，见 §1.1 / §7 R-1）。

---

## §5 与现有系统集成点

> 图例：🟢 零改动复用 | 🟡 少量插入 | 🔴 需新建

### 5.1 `MainGame.gd`（4 空格缩进）

**🟡 集成点 1 · 拾得钩子**（L216-221 `_on_location_selected`）

```gdscript
# ── 现状 ────────────────────────────────────────────────
func _on_location_selected(loc_id: String):
    GameManager.current_location = loc_id
    center_info.hide()
    hotspot_container.show()
    if _try_memory_echo(loc_id): return    # step 0
    hotspot_ui.on_location_selected(loc_id)

# ── 改后（+2 行）─────────────────────────────────────────
func _on_location_selected(loc_id: String):
    GameManager.current_location = loc_id
    center_info.hide()
    hotspot_container.show()
    if _try_memory_echo(loc_id): return    # step 0：回响命中则接管，播完重入本函数
    _try_fengwu_find(loc_id)               # ← step 1：风物拾得（不 return，仅 toast）
    hotspot_ui.on_location_selected(loc_id)

## 风物拾得 step 1（GDD §1.1 / §3 系统 1）
## 与 step 0 天然互斥：回响命中会先 return，重入时回响已进冷却，才轮到本步。
## 不消耗时段、不打断流程、失败完全静默。
func _try_fengwu_find(loc_id: String) -> void:
    var fid: String = CollectionManager.roll_fengwu_find(loc_id)
    if fid == "": return
    CollectionManager.grant_fengwu(fid, "found")
```

**🟡 集成点 2 · 补偿扫描**（L263-269 `_on_event_finished`）
```gdscript
func _on_event_finished():
    CollectionManager._retroactive_stamp_check()      # 既有
    CollectionManager._retroactive_fengwu_check()     # ← 新增 1 行（手作事件 addItem 后补 day）
    board_ui.show_center_info(self)
    update_ui()
```

**🟡 集成点 3 · 入口（按钮总数保持 9）**（L411-421 `_show_more_popup` items）
```gdscript
# 现状：{"text": "📖 集章簿", ..., "fn": _show_stampbook_popup},
# 改为：{"text": "📖 青春收藏", ..., "fn": _show_collection_popup},
```
新增 `_show_collection_popup()`：一个二级 overlay，两个大按钮「🏞️ 西湖十景集章簿」→ 调既有 `_show_stampbook_popup()`（**函数本体一行不动**）/「🍃 西湖风物志」→ 调新增 `_show_fengwubook_popup()`。
✅ 更多菜单仍是 9 个按钮（S-7）；✅ `StampBookUI.gd` 零改动（S-3）。

### 5.2 `CollectionManager.gd`（**tab 缩进**）

**🟡 集成点 4 · 物品登记挂钩**（L11-17 `add_item` 末尾 +1 行）
```gdscript
func add_item(item_id: String, amount: int = 1):
	if not GameManager.ITEM_DB.has(item_id): return
	if not GameManager.inventory.has(item_id):
		GameManager.inventory[item_id] = amount
	else:
		GameManager.inventory[item_id] += amount
	GameManager.show_toast.emit("获得物品: %s x%d" % [GameManager.ITEM_DB[item_id].name, amount])
	_check_fengwu_by_item(item_id)   # ← 新增：购得/手作/事件 addItem 的统一登记入口
```
✅ **单一登记入口**：无论物品来自 `ShopUI._on_buy_pressed`（L225）、事件级 `addItem`（DialogueUI L122）还是场景级 `addItem`（L215），全部经此函数 → 零遗漏。

**🟡 集成点 5 · 补偿扫描串联**（L85-90 `_retroactive_gallery_check` 末尾 +1 行）
```gdscript
func _retroactive_gallery_check():
	for char_id in GameManager.favorability.keys():
		var cur = GameManager.favorability[char_id]
		_check_favor_gallery_unlocks(char_id, 0, cur)
	_retroactive_stamp_check()      # 既有
	_retroactive_fengwu_check()     # ← 新增（开局 / 读档 / F6 DEBUG 热键统一覆盖）
```

**🔴 新增**：`FENGWU_*` 常量区 + 11 个函数，追加在文件末尾（记忆回响区之后），用 `═══` 分区注释隔开，风格对齐既有两区。

### 5.3 `DailyCycleManager.advance_time` 钩子 —— 🟢 **明确不接**

| 候选钩子 | 是否接入 | 理由 |
|---|---|---|
| `_check_weekly_allowance` | ❌ | 风物不改变零花钱 |
| `_check_parttime_income` | ❌ | 风物不产生收入（支柱 P2：无功能收益） |
| `_check_daily_decay` | ❌ | 风物不衰减、不过期 |
| `_check_special_date` | ❌ | 风物不挂节日 |
| **新增 `_check_fengwu_*`** | ❌ | **拾得由「进地点」驱动，不由「跨日」驱动**——这是有意的：跨日驱动会让玩家「什么都不做也在收集」，违反支柱 P1 |

> `fengwu_dry_streak` 的递增放在 `roll_fengwu_find` 内部（掷骰未中时，按 `fengwu_roll_day != day` 判定当日首次），**不需要每日结算钩子**。
> ✅ **`DailyCycleManager.gd` diff 为空。**

### 5.4 `ShopUI.gd` —— 🟢 **零改动**（但有副作用需处理）

`update_shop_list()`（L137-138）无条件遍历 `ITEM_DB` → 6 条 bought 风物**自动上架**，`_on_buy_pressed`（L222）自动扣款并 `add_item` → 自动登记图鉴。**一行不改**。

⚠️ 副作用：6 条手作类风物（`price:0`）也会出现在商店，显示为「💰 0 / 购买」→ 玩家可白嫖。
**这是必须解决的漏洞**，三个方案见 §7 风险 R-3（推荐方案：手作类不进 `ITEM_DB`，改用纯 flag 授予）。

### 5.5 `events_*.json` —— 🟡 仅目标层

**MVP 层：零事件改动。**

目标层在 `events_life.json` 追加 6 条 `fw_craft_<fid>`（复用现有 `int_craft_*` 命名邻域）：

```jsonc
{
  "id": "fw_craft_youzhisan",
  "location": "art_room",
  "slotId": "after",
  "triggerDay": 120,
  "repeatable": false,
  "requireItem": "handmade_gift",
  "requireItemAmt": 1,
  "requireMoney": 25,
  "title": "☂️ 给伞面上色",
  "scenes": [
    { "speaker": null, "text": "美术教室后排堆着几把没上色的白伞面……" },
    { "speaker": null, "text": "你挑了一把，蘸了颜料，从伞骨那头开始画。" },
    { "speaker": null, "text": "画的是断桥。歪了，但看得出来是断桥。",
      "statDelta": { "money": -25, "art": 2, "stress": -3 },
      "addItem": "youzhisan",
      "next": 99 }
  ]
}
```

**⚠️ 三个事件设计硬约束（§8 验收 A-7 拦截）**
1. `requireItem` **只校验不消耗**（DataManager L245-250 仅做 `has_item`）→ 若设计意图是「消耗一个手作」，必须在最终 scene 显式移除，否则 1 个 `handmade_gift` 可解锁全部 6 条。
   👉 **本 GDD 的裁决：消耗**（源码核实后修订）。`int_craft_make` 是 **`repeatable: true`**（`events_life.json`），`handmade_gift` 可反复产出、非稀缺资源 → 不存在锁死风险，消耗设计安全且能带来真实的「做一个用一个」手感。
   实现方式：最终 scene 追加 `"removeItem": "handmade_gift"` —— ⚠️ **该字段当前 `DialogueUI` 未实现**（仅有 `addItem`），需程基岩确认是新增 1 个场景级字段（~4 行，对称于 L214-216 的 `addItem` 分支）还是改用其它写法。此为 D-3 的工程前置项。
2. `repeatable` 必须为 `false`（靠 `flags[ev_id]` 天然去重，DataManager L208）。
3. `requireMoney` **必须**前置门控——不能只靠场景 `statDelta` 扣钱，因为 `add_stat("money", n)` **不 clamp**（L625-631），money 会变负数。

### 5.6 NG+ 继承白名单 —— 🟢 **零改动**

| 数据 | NG+ 行为 | 是否符合预期 | 需改代码？ |
|---|---|---|---|
| `fengwu_*` 全部 flag | `flags = {}`（EndingScreen L484）→ **全清** | ✅ 新周目重新收集，符合收集类玩法预期 | 否 |
| 风物 `inventory` 条目 | `inventory = {}`（L489）→ **全清** | ✅ 与 flag 清零语义一致 | 否 |
| `title_西湖风物通` | `_upload_profile_on_ending` 扫 `title_` 前缀（L340-342）→ 进 `unlocked_titles` → NG+ 时 L517-518 回写 | ✅ **称号跨周目保留**，与 `title_西湖十景通` 完全一致 | 否 |
| `fengwu_complete` 画廊 flag | 上传进 `gallery_flags`（L348-352），但恢复段**不回写** → 画廊清零 | ⚠️ 既有行为（十景亦然）→ **对齐，不修** | 否（见 §7 R-6） |
| 风物花掉的 money | 计入 `inherited_money = min(money*0.5, 500)` 的基数 | ✅ 买风物 = 少继承一点钱，是合理代价 | 否 |

✅ `EndingScreen.gd` / `StartMenu.gd` **diff 为空**。

### 5.7 `SaveSystem.gd` —— 🟢 **零改动**

`save_game` 已持久化 `money`(L69) / `flags`(L75) / `inventory`(L76)。新状态 100% 落在这三者内 → **零存档迁移、旧档直接兼容**（旧档读入后 `fengwu_*` 全部缺失 = 未收集，语义正确；`_retroactive_fengwu_check` 在读档时经 `_retroactive_gallery_check` 自动跑一遍）。

### 5.8 集成点汇总

| 文件 | 缩进 | 改动 | 行数量级 |
|---|---|---|---|
| `CollectionManager.gd` | **tab** | 🔴 新增常量区 + 11 函数；🟡 `add_item` +1 行；🟡 `_retroactive_gallery_check` +1 行 | ~400 |
| `GameManager.gd` | 4 空格 | 🟡 `ITEM_DB` +6 条；🟡 `GALLERY_ITEMS` +1 条 | ~8 |
| `MainGame.gd` | 4 空格 | 🟡 `_on_location_selected` +2 行；`_on_event_finished` +1 行；`_show_more_popup` 改 1 行；新增 2 个 popup 函数 | ~40 |
| `FengwuBookUI.gd` | 4 空格（对齐 StampBookUI） | 🔴 新建 | ~280 |
| `events_life.json` | 4 空格 | 🟡 +6 事件（**仅目标层**） | ~150 |
| `ShopUI.gd` / `DailyCycleManager.gd` / `StampBookUI.gd` / `SaveSystem.gd` / `EndingScreen.gd` / `DataManager.gd` / `DialogueUI.gd` / `NGPlusManager.gd` / `project.godot` | — | 🟢 **零改动** | 0 |

**新增 Autoload：0** ✅

---

## §6 依赖排序与里程碑

```
M0 决策关闭（用户拍板 D-1 ~ D-4，见 §9）
     │
     ├─── M1 数据层（无依赖，可立即开工）
     │      ├ FENGWU_ITEMS 24 条注册表（12 条 found 文案先行）
     │      ├ FENGWU_CATS / 调参常量
     │      └ 查询函数：is_owned / get_day / get_progress / get_cat_progress
     │
     ├─── M2 授予层（依赖 M1）
     │      ├ grant_fengwu（唯一写入口，幂等）
     │      ├ _check_fengwu_cat_completion / _check_fengwu_completion
     │      ├ _retroactive_fengwu_check
     │      └ GALLERY_ITEMS +1 条
     │
     ├─── M3 拾得层（依赖 M2）★ MVP 可玩线
     │      ├ roll_fengwu_find（纯判定）
     │      ├ MainGame._try_fengwu_find 接线
     │      └ _retroactive_gallery_check 串联
     │
     ├─── M4 图鉴 UI（依赖 M1，可与 M3 并行）★ MVP 完成线
     │      ├ FengwuBookUI.gd（仿 StampBookUI）
     │      └ MainGame 二级选单「📖 青春收藏」
     │
     │   ══════ MVP 交付门（12 条 found，可独立发布）══════
     │
     ├─── M5 购得层（依赖 M2；⚠️ 阻塞于 D-2 的 ShopUI 方案）
     │      ├ ITEM_DB +6 条 bought
     │      └ add_item 挂钩 _check_fengwu_by_item
     │
     ├─── M6 手作层（依赖 M5 的挂钩；⚠️ 阻塞于 D-3 的消耗语义）
     │      └ events_life.json +6 条 fw_craft_*
     │
     ├─── M7 内容 pass（依赖 M1；可与 M5/M6 并行）
     │      └ 补齐 24 条 × (summary + 3 lines + hint)
     │
     └─── M8 美术（依赖 M2 的 flag 名；交林绘澄）
            └ fengwu_complete.jpg CG 1 张
```

**关键路径**：M0 → M1 → M2 → M3 → M4（MVP）
**可并行**：M4 ∥ M3；M7 ∥ M5 ∥ M6 ∥ M8
**外部阻塞**：M5/M6 阻塞于用户决策 D-2 / D-3；M8 阻塞于美术排期（**不阻塞 MVP 发布**——CG 缺失时画廊条目灰显，`GalleryPopupUI` 已有缺图兜底）

---

## §7 风险与缓解

### R-1 · 🔴 高 · 与已放行「记忆回响」抢同一个钩子位

**风险**：`_on_location_selected` 已被记忆回响占用 step 0（`MainGame.gd` L216-240，已过质量门）。风物拾得插 step 1，若处理不当会出现「进一次地点连播两段软演出」的双重打断，或破坏回响的 `CONNECT_ONE_SHOT` 重入链。

**缓解**（三层）：
1. **拾得不播 vignette**——只发 toast，物理上不可能与回响的对话演出叠加。这是本 GDD 最重要的一条差异化决策。
2. **插在 `if _try_memory_echo(loc_id): return` 之后**——回响命中时直接 return，重入时回响已写冷却（`commit_memory_echo` 在 `start_event` 之前调用，L231），`pick` 必返 `{}`，才轮到拾得。**天然互斥，零额外代码**。
3. `_try_fengwu_find` **不 return**、不改变控制流、不触碰 `dialogue_ui` / `location_explore_ui` 任何可见性状态。

**验收**：§8 A-1 静态断言 + A-8 重入推演。

---

### R-2 · 🔴 高 · 四季线性单次 → 季节/天气硬门槛会永久锁死集满

**风险**：`get_season()` 是线性单次（`WeatherManager.gd` L28-33），`snowy` 天气在 winter 段也只是概率事件。若把 `season`/`weather` 设为硬门槛，「雪落断桥」等条目存在**本周目永久无法获得**的真实可能 → 集满称号锁死 → 完美主义玩家体验灾难。

**缓解**：
- `season` / `weather` / `slot` **全部降级为软加权**（权重 +100 / +50），**不作任何过滤**。严格对齐十景集章 **D-1 已拍板裁决**（`CollectionManager.gd` L108 注释）。
- 唯一硬门槛是 `loc`（地点）——地点是玩家可控的，不存在「运气不好就没了」。
- 保留季节的**表现层价值**：当季拾得时 toast 加一句季节感文案（对齐 `season_line` 机制）。

**残留风险**：软加权后，「雪落断桥」可能在春天被捡到，轻微损失氛围。**接受**——一致性 > 氛围洁癖，且十景已开此先例。

---

### R-3 · 🟠 中高 · `price:0` 手作类风物会在 `ShopUI` 被白嫖

**风险**：`add_item` 的 `ITEM_DB.has()` 守卫（L12）要求所有物品必须注册；但 `ShopUI` 无条件遍历整个 `ITEM_DB`（L137-138），`price:0` 的手作类会显示为「💰 0 / 购买」→ 玩家点一下就白嫖，手作渠道形同虚设。同时商店列表从 7 条涨到 13 条（+86%），移动端 700×520 面板滚动负担加重（**认知过载**红线）。

**缓解三方案**（→ 决策 D-2）：

| 方案 | 做法 | ShopUI 改动 | 优点 | 缺点 |
|---|---|---|---|---|
| **① 纯 flag（推荐）** | 手作类**不进 `ITEM_DB`**，`fw_craft_*` 事件用 `setFlag:"fengwu_<fid>"` 代替 `addItem`，图鉴照常点亮 | 🟢 **零** | 零白嫖、商店只 +4 条（13→11）、零回归 | 手作产物不进背包（无实体） |
| ② ShopUI 过滤 | `update_shop_list` 加 `if item.get("price", 0) <= 0: continue` | 🟡 +1 行 | 手作物品有实体 | 改动已放行外的文件；`handmade_gift`（price 0）也会一并从商店消失（**实际上是好事**） |
| ③ 分类页签 | ShopUI 按 `category` 分区 | 🔴 ~60 行 | 商店体验最好 | 改动最大，超出本特性范围 |

**本 GDD 推荐 ①**：手作产物的价值在图鉴里，不在背包里。且方案 ① 顺带规避了 §5.5 的 `requireItem` 消耗语义难题。

---

### R-4 · 🟠 中 · 同时段反复进出地点可刷拾得

**风险**：若「进入地点」本身不消耗时段（需工程侧确认），玩家可在同一时段反复进出 → pity 累积下必然命中 → 退化为「点击刷奖励」，直接违反支柱 P1。

**缓解**：
- 增设**时段级掷骰限速** `fengwu_roll_slot`（int = `day * 4 + slot_index`）：同一时段只掷骰一次，重复进入静默跳过。
- `fengwu_dry_streak` 按「日」递增（由 `fengwu_roll_day` 保证每日至多 +1），不按「次」——刷次数不加速保底。
- 双层限速：`fengwu_found_day`（每日至多**得**1 件）+ `fengwu_roll_slot`（每时段至多**掷**1 次）。

---

### R-5 · 🟢 低（已降级）· `handmade_gift` 供给 —— 源码核实后风险解除

**原假设风险**：`handmade_gift` 唯一来源 `int_craft_make` 若为 `repeatable:false`，整局只产 1 个 → 手作类 6 条永久锁死。

**核实结论**：`int_craft_make` 的 `repeatable` 实为 **`true`**（`location:"home"`，场景级 `addItem:"handmade_gift"`）。玩家可在卧室反复手作 → **`handmade_gift` 非稀缺资源，锁死风险不存在**。

**因此修订**：
1. 手作事件**可以安全地消耗** `handmade_gift`（§5.5 裁决已相应修订）——这比「只校验不消耗」有更真实的手感。
2. 新增的工程前置项：场景级 `removeItem` 字段当前 **未实现**（`DialogueUI` 仅有 `addItem`，L214-216）→ 需程基岩评估（~4 行对称实现）。列入 D-3。
3. 残留风险：`int_craft_make` 可重复 → 玩家可无限刷 `handmade_gift`。但该物品 `price:0` 且仅用于送礼/手作，**不产生 money**，不构成经济失衡；且刷它要消耗时段，与「时间即代价」自洽。**判定为既有系统的可接受行为，不在本特性内处理。**

---

### R-6 · 🟡 中低 · 收集疲劳与入口过载

**风险**：项目已有 4 个收集向入口（画廊 / 集章簿 / 赛季 / 结局图鉴），更多菜单已 9 个按钮。第 5 个独立入口 = **认知过载**。同时玩家面对第三套收集可能产生「又来」的疲劳。

**缓解**：
- 入口**不新增顶级按钮**：「📖 集章簿」升级为「📖 青春收藏」二级选单（集章簿 / 风物志），按钮数 9 → 9。
- 风物与十景的**动作形态刻意不同**（被动拾得 vs 主动打卡；无演出 vs 有演出），降低「同质重复」感。
- MVP 只上 12 条，观察玩家反馈再决定是否推目标层 24 条——**范围分层本身就是疲劳风险的缓解手段**。

---

### R-7 · 🟢 低 · 三个已放行特性的回归边界（红线清单）

| 已放行特性 | 触碰边界 | 本 GDD 的保证 |
|---|---|---|
| **手机 UI 闭环** | 完全不相关 | `WeChatUI.gd` / `phone_*` **零引用、零改动** |
| **西湖十景集章** | 共用 `CollectionManager` 文件、共用 `flags`、共用 `_retroactive_gallery_check`、共用「更多菜单」入口 | ① `stamp_*` 前缀**零读零写**；② `WEST_LAKE_STAMP_SCENES` / `grant_stamp` / `build_stamp_vignette` **零修改**；③ `StampBookUI.gd` **diff 为空**；④ `_retroactive_gallery_check` 仅**追加**一行，不改既有调用顺序；⑤ `_show_stampbook_popup()` 函数本体不动，只改调用它的入口 |
| **记忆回响** | 共用 `_on_location_selected` 钩子位、共用 `CollectionManager` 文件 | ① `mem_echo_*` 前缀**零读零写**；② 插入位置严格在 `_try_memory_echo` 的 `return` 之后；③ 拾得**不播 vignette、不碰 `dialogue_ui`**，不可能干扰 `CONNECT_ONE_SHOT` 重入链；④ 记忆回响区代码 **diff 为空** |

**通用红线**：
- ❌ 不改 `_retroactive_gallery_check` 中既有两行的**顺序**（只在末尾追加）
- ❌ 不改 `add_item` 的既有 6 行（只在末尾追加第 7 行）
- ❌ 不修 §-1 发现 2 的 `gallery_flags` NG+ 不回写问题（属十景集章的既有语义）
- ❌ 不在 `CollectionManager` 中把三套收集的公共逻辑「重构提取」——重构 = 触碰已放行代码

---

### R-8 · 🟢 低 · 设计理论红线自检

| 红线 | 自检结论 |
|---|---|
| **主导策略** | ✅ 风物无属性/好感/经济收益 → 不可能成为最优解。三渠道分别消耗运气/财力/时间，无单一渠道可通吃 |
| **经济失衡** | ✅ 总支出 300 元 / 总收入 ≈8910 元 = 3.4%；不产生任何收入 → 单向汇，不可能通胀 |
| **认知过载** | ⚠️ 已识别 → R-6 缓解（入口不增、MVP 减半、动作形态差异化） |
| **支柱漂移** | ✅ 支柱 P1「收集是副产物」由「不消耗时段 + 不打断 + 无收益」三重保证；与项目「时间即代价」支柱同向而非对冲 |

---

## §8 验收标准（逻辑级验证脚本应覆盖的契约）

> 无 Godot 运行时 → 采用与 `tests/west_lake_stamps_smoke/verify_qa.py` / `tests/memory_echo_smoke/verify_qa.py` 相同的**静态解析 + 逻辑推演**范式。
> 建议目录：`tests/fengwu_smoke/verify_qa.py` + `QA_REPORT.md`

### A 组 · 结构与一致性断言（静态解析）

| # | 断言 | 失败即 FAIL |
|---|---|---|
| A-1 | `MainGame._on_location_selected` 中 `_try_fengwu_find` 调用**位于** `if _try_memory_echo(loc_id): return` 之后、`hotspot_ui.on_location_selected` 之前 | 是 |
| A-2 | `FENGWU_ITEMS` 中所有 `source=="found"` 条目的 `loc` ∈ `GameManager.locations` 的键集合 | 是（死分支） |
| A-3 | `FENGWU_ITEMS` 条目数 == `FENGWU_TOTAL`；各 `cat` 计数 == `FENGWU_CATS[cat].count`；`cat` ∈ `FENGWU_CATS` 键集 | 是 |
| A-4 | 所有 `source != "found"` 的 `fid` 均存在于 `GameManager.ITEM_DB`（若采用 R-3 方案 ①，则改为断言 made 类 **不在** `ITEM_DB`） | 是（静默丢弃） |
| A-5 | `FENGWU_ITEMS` 的 `season` 值 ∈ {"", "spring","summer","autumn","winter"}；`weather` ∈ {"", "sunny","cloudy","rainy","snowy"}；`slot` ∈ {"", "morning","noon","after","evening"} | 是 |
| A-6 | 6 条 `fw_craft_*` 全部 `repeatable == false` 且含 `requireMoney`；`int_craft_make` 的 `repeatable` 仍为 `true`（供给前提未被他人改动，回归守卫） | 是 |
| A-7 | 6 条 `fw_craft_*` 事件中 `requireItem:"handmade_gift"` 与最终 scene 的消耗动作**成对出现**（符合 §5.5 修订后裁决：消耗）；若 `removeItem` 字段未实现则本项标 BLOCKED 而非 PASS | 是（主导策略） |
| A-8 | `fengwu_*` 前缀 flag 在全工程中**仅由** `CollectionManager` 的 `grant_fengwu` / `_retroactive_fengwu_check` / `roll_fengwu_find` 写入（Grep 断言写入点唯一性） | 是 |

### B 组 · 隔离断言（已放行特性零回归）

| # | 断言 | 失败即 FAIL |
|---|---|---|
| B-1 | 风物相关代码**不出现** `stamp_` / `WEST_LAKE_STAMP_SCENES` / `grant_stamp` / `build_stamp_vignette` 任何引用 | 是 |
| B-2 | 风物相关代码**不出现** `mem_echo_` / `MEMORY_ECHO_CONTEXTS` / `pick_memory_echo` / `commit_memory_echo` 任何引用 | 是 |
| B-3 | `StampBookUI.gd` / `SaveSystem.gd` / `EndingScreen.gd` / `StartMenu.gd` / `DailyCycleManager.gd` / `DataManager.gd` / `DialogueUI.gd` / `NGPlusManager.gd` / `project.godot` **diff 为空** | 是 |
| B-4 | `CollectionManager._retroactive_gallery_check` 的既有两行（`_check_favor_gallery_unlocks` 循环 + `_retroactive_stamp_check()`）**顺序与内容未变**，新调用仅追加在末尾 | 是 |
| B-5 | `CollectionManager.add_item` 前 6 行未变，新调用仅追加在末尾 | 是 |
| B-6 | `project.godot` 的 `[autoload]` 段 diff 为空（零新 Autoload） | 是 |
| B-7 | `MainGame._show_more_popup` 的 `items` 数组长度仍为 **9** | 是 |

### C 组 · 行为推演断言（逻辑级模拟）

| # | 断言 | 方法 |
|---|---|---|
| C-1 | **幂等性**：对同一 `fid` 连续调用 `grant_fengwu` 10 次 → `flags` 状态与调用 1 次完全一致，toast 只发 1 次 | 模拟 flags 字典 |
| C-2 | **每日限速**：同一 `day` 内 `roll_fengwu_find` 成功 1 次后，后续调用必返 `""` | 模拟 |
| C-3 | **时段限速**：同一 `(day, slot_index)` 内第二次调用 `roll_fengwu_find` 静默跳过，且 `dry_streak` 不重复递增 | 模拟（R-4） |
| C-4 | **回响互斥**：模拟 `_on_location_selected` 全链路，当 `pick_memory_echo` 命中时，该次调用中 `roll_fengwu_find` **不被调用**；重入后才被调用，且此时 `pick` 返 `{}` | 控制流推演（R-1） |
| C-5 | **无递归**：`_try_fengwu_find` 不触发任何会重入 `_on_location_selected` 的路径（推演 200 层） | 控制流推演 |
| C-6 | **集满原子性**：第 24 件授予时，同一次调用内完成 `fengwu_complete` + `title_西湖风物通` + `unlock_gallery`，且**跳过**该件的普通 toast | 模拟（对齐 `grant_stamp` L279） |
| C-7 | **分类不发称号**：任一 `fengwu_cat_<cat>` 置位时，`flags` 中不新增任何 `title_` 前缀键 | 模拟 |
| C-8 | **补偿幂等**：`_retroactive_fengwu_check` 连续调用 5 次，`flags` 无变化（除首次补 day / 补大成） | 模拟 |
| C-9 | **旧档兼容**：输入一个不含任何 `fengwu_*` 键的 flags 字典 → 所有查询函数返回合法值（进度 0/24，`get_fengwu_day` 返 -1），不抛异常 | 模拟 |
| C-10 | **NG+ 语义**：模拟 `flags={}` + `inventory={}` + `title_西湖风物通` 回写 → 图鉴进度归零、称号保留 | 模拟（§5.6） |
| C-11 | **概率收敛**：蒙特卡洛 10000 局 × 570 天，按 §3.1 假设（每日 0.45 概率进入有候选地点）→ MVP 12 条集满率 ≥ 0.95 | 蒙特卡洛 |
| C-12 | **经济无失衡**：模拟全额购买 6 件 bought + 6 件 made 材料费 → 总支出 == 300；`money` 全程 ≥ 0（`requireMoney` 前置门控生效） | 模拟 |
| C-13 | **确定性平局**：候选池中两条权重相同时，恒返 `fid` 字典序较小者（对齐 L557） | 模拟 |

### D 组 · 内容完整性

| # | 断言 |
|---|---|
| D-1 | 24 条全部具备非空 `name` / `emoji` / `summary` / `hint`；`lines` 长度 ∈ [1,4] |
| D-2 | `emoji` 字段均为**单个** emoji 字符（图鉴格布局依赖） |
| D-3 | 24 个 `fid` 无重复；`fengwu_<fid>` 与既有 flag 命名空间（`stamp_*` / `mem_echo_*` / `seen_*` / `holiday_memory_*` / `title_*` / `int_*` / `eco_*`）**无碰撞** |

---

## §9 决策区（待用户拍板）

| # | 决策 | 选项 | 本 GDD 倾向 | 阻塞 |
|---|---|---|---|---|
| **D-1** | 发布范围 | ① MVP 12 条（M）② 目标 24 条（L） | **① 先 MVP** —— 12 条可独立发布，零 `ITEM_DB` / 零事件 / 零 `ShopUI` 改动，风险面最小；观察反馈再推 24 | M5-M7 |
| **D-2** | 手作产物形态（R-3） | ① 纯 flag，不进 `ITEM_DB`（ShopUI 零改动）② 进 `ITEM_DB` + ShopUI 加 `price<=0` 过滤（+1 行）③ ShopUI 分类页签（~60 行） | **①** —— 零白嫖、零回归、顺带规避 `requireItem` 消耗语义难题 | M5/M6 |
| **D-3** | 手作是否消耗 `handmade_gift`（R-5） | ① 不消耗（资格校验）② 消耗 1 个 | **①** —— 消耗有锁死风险，且 `int_craft_make` 的 `repeatable` 未核实 | M6 |
| **D-4** | 拾得是否播 vignette | ① 不播，仅 toast ② 播 2-3 句（同十景） | **①** —— 这是与记忆回响共存的**安全前提**（R-1），也是与十景形成动作差异的关键。改为 ② 会同时引入双打断风险和时段消耗争议 | M3 |
| **D-5** | 是否吸收概念 C 的跨收集总进度条 | ① 不做，仅二级选单聚合入口 ② 在「青春收藏」选单顶部加一根「三年收藏度 n%」总进度条（只读聚合十景+风物+画廊） | **②**（成本约 20 行只读代码，收益是把 4 个割裂入口串成一条叙事） | M4 |

---

## §10 交付摘要

| 项 | 内容 |
|---|---|
| **推荐概念** | 《西湖风物志》—— `CollectionManager` 第三套收集，24 件杭州风物，三渠道（拾得 12 / 购得 6 / 手作 6） |
| **核心差异化** | 不消耗时段、不打断流程、无功能性收益 —— 收集是日常的副产物 |
| **MVP 范围** | 12 条拾得 + 图鉴 UI + 集满称号（**M**），零 `ITEM_DB`/零事件/零 `ShopUI` 改动 |
| **目标范围** | 24 条 + 购得 + 手作 + 分类徽章（**L**） |
| **新增 Autoload** | **0** |
| **新增脚本** | 1（`FengwuBookUI.gd`） |
| **零改动文件** | `ShopUI` / `DailyCycleManager` / `StampBookUI` / `SaveSystem` / `EndingScreen` / `StartMenu` / `DataManager` / `DialogueUI` / `NGPlusManager` / `project.godot` |
| **存档迁移** | **0**（全部落 `flags` / `inventory` / `money`） |
| **双路线成本** | **0**（24 条与性别无关） |
| **美术需求** | 1 张 CG `fengwu_complete.jpg`（1280×720）→ 林绘澄 |
| **最大风险** | R-1（与已放行「记忆回响」抢 `_on_location_selected` 钩子位）—— 已由「拾得不播 vignette」+「插在 return 之后」双重结构化缓解 |
| **待拍板** | D-1 ~ D-5（§9） |
