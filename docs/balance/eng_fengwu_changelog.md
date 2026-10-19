# 《西湖风物志》收集系统 — 工程实现交付记录（eng_fengwu_changelog）

> **实施人**：程基岩（engineering-lead / 技术+引擎）
> **交付日期**：2026-08-02（续跑收尾）
> **任务性质**：**实现**（严格依据 `design/gameplay_economy_expansion_gdd.md` §-1 源码实证 / §A 概念 / §3 系统拆解 / §5 集成点 / §7 风险 / §9 决策 落地，非设计）
> **主理人**：游承峰（下派与验收）
> **范围边界**：经营/收集扩展方向《西湖风物志》。本 sprint 落地 **18 件可达**（拾得 12 + 购得 6），**6 件手作槽位预留**（D-3）。称号「西湖风物通」需集满全 24 件才授 → 当前最大进度 18/24，**暂锁**，不降到 18。
> **未执行 git commit**（按铁律，高影响动作须人工审批）。

---

## 0. 铁律合规自检（上线前硬约束）

| 约束 | 状态 | 说明 |
|---|---|---|
| 缩进铁律：CollectionManager 用 tab；GameManager/MainGame/FengwuBookUI 用 4 空格；同文件禁混用 | ✅ 合规 | CollectionManager.gd 首缩进行 L12 `if not GameManager.ITEM_DB.has...` 为 `\t` 起始；GameManager.gd L9、MainGame.gd L36、FengwuBookUI.gd L34 均为 4 空格起始。全程无同文件混用。 |
| 不新增 Autoload | ✅ 合规 | `project.godot` [autoload] 仍为 15 条；FengwuBookUI 走运行时 `load("res://scripts/FengwuBookUI.gd").new()` 子界面模式，**未注册**、**未建 .tscn**。 |
| 不破坏已放行 3 特性（手机UI闭环 / 西湖十景集章 165/165 / 记忆回响 286/286） | ✅ 合规 | 见 §6 回归结果，4+1 脚本全绿；风物志区在 CollectionManager 内位移至记忆回响区**之前**，保证两个已放行回响 QA 的「marker→EOF」切片假设成立。 |
| 不写隐私/策划/美术文本资源 | ✅ 合规 | 所有风物条目文案为玩法内 flavor hint（属程序可写范畴）；CG 复用现有 `res://assets/backgrounds/lakeside_evening.jpg`，**零新建美术**。 |
| 存档/NG+ 零迁移 | ✅ 合规 | `fengwu_*` 随 `flags={}` 清空；`title_*` 前缀经 EndingScreen 白名单自动继承（L515-518）。SaveSystem / EndingScreen **零改动**（见 §3.5）。 |

---

## 1. 范围决策落地映射（用户已拍板）

| 决策 | 内容 | 本实现的落地 |
|---|---|---|
| **D-1** | 全量 24 件框架（拾得12 / 购得6 / 手作6） | `FENGWU_ITEMS` 24 槽全登记，顺序=拾得12→购得6→手作6（`CollectionManager.gd` L385-511） |
| **D-3** | 先不做手作；本 sprint 实现拾得12+购得6=18 件，6 手作槽位预留 | 手作 6 条 `obtain:"手作"`、`loc/season/weather/slot` 全空、**无任何 grant 路径**（全局搜 `fw_hm_` 仅出现在 `CollectionManager.gd` 注册表内） |
| **D-2**（锁定） | 手作产物走纯 flag 不进 ITEM_DB | 6 手作 fid（`fw_hm_*`）未写入 `ITEM_DB`；后续由手作系统直调 `grant_fengwu(fid)`，不进购物/背包链路 |
| **D-4**（锁定） | 拾得只弹 toast，不播 vignette/演出，不与记忆回响叠加 | `pick_fengwu_pickup` 仅 `show_toast("🍃 风物入册")`；插入点在 `_try_memory_echo` 的 `return` **之后**，命中回响时早已 return，天然互斥 |
| 称号门槛 | `title_西湖风物通` 需集满 24 件 | `_check_fengwu_completion()` 遍历全 24 件，缺一则 return false → 本 sprint 恒 false，称号**暂锁**（刻意设计，不降到 18） |

---

## 2. 逐文件 Diff 摘要

### 2.1 `scripts/CollectionManager.gd`（tab 缩进 · 现 944 行）

**核心新增 — 西湖风物志区（L345-661），位于「西湖十景集章(L98)」与「记忆回响(L662)」之间。**

- **`const FENGWU_ITEMS`（L385-511）**：24 槽字典，每槽字段 `{fid, name, category(味/物/草木/声景), obtain(拾得/购得/手作), loc, season, weather, slot, hint}`。
  - 拾得 12（`liuxu`/`taohuaban`/`hefeng`/`xuehen`/`guihua_jin`/`wapian`/`yinxing_shu`/`yansheng`/`chanming`/`chaohuo`/`longjing_qi`/`xiaozhong`）：`loc` 为硬门槛；`season`/`weather`/`slot` 仅加权正反馈（软条件）。季节仅作软正反馈（四季线性单次，硬门槛会永锁称号）。
  - 购得 6（`fw_longjing`/`fw_oufen`/`fw_guihuatang`/`fw_chousan`/`fw_wangxingji`/`fw_tianzhukuai`）：`loc/season/weather/slot` 全空，`fid == ITEM_DB key`，价格真源在 `ITEM_DB`。
  - 手作 6（`fw_hm_yahua`/`fw_hm_guihuajiang`/`fw_hm_xiangnang`/`fw_hm_taci`/`fw_hm_zhuze`/`fw_hm_luyin`）：`obtain:"手作"`，全条件空，hint 含「【手作 · 尚未开放】」，**无 grant 路径**。
- **常量（L513-521）**：`FENGWU_TOTAL:=24` / `TITLE_FLAG:="title_西湖风物通"` / `COMPLETE_FLAG:="west_lake_fengwu_complete"` / `PICKUP_DAY_FLAG:="fengwu_pickup_day"` / `PICK_BASE:=0.18` / `PICK_BONUS:=0.12` / `PICK_CAP:=0.60` / `END_DAY:=570`。
- **查询 API（只读，供 UI 消费）**：`is_fengwu_owned` / `get_fengwu_day` / `get_fengwu_progress` / `get_fengwu_reachable_total`（由 `obtain!="手作"` 派生，**不硬编码 18**）/ `is_fengwu_pickup_used_today` / `is_fengwu_bonus_active` / `format_fengwu_day`（复用 `format_stamp_day`）。
- **`grant_fengwu(fid)`（L570）**：幂等（`if GameManager.flags.has(flag): return false`）→ 写 `fengwu_<fid>` + `fengwu_<fid>_day` → 调 `_check_fengwu_completion()`；否则 `show_toast("🍃 风物入册")`。
- **`_check_fengwu_completion()`（L586）**：遍历全 24 件，缺一则 return false（本 sprint 恒 false，称号暂锁）；集满置 `COMPLETE_FLAG` + `TITLE_FLAG` + `unlock_gallery` + toast。
- **`_retroactive_fengwu_check()`（L601）**：① 购得旁路（inventory 有 fid 且未入册→grant）② 补 `_day` ③ 集满判定。串入 `_retroactive_gallery_check()`（L95，在既有 `_retroactive_stamp_check()` 之后）。
- **`pick_fengwu_pickup(loc_id)`（L620）**：`day>=END_DAY` guard / `is_fengwu_pickup_used_today()` guard / 过滤 `obtain!="拾得"` / `loc` 硬门槛 / 已入册跳过 / 软条件满足则 `chance += BONUS`（封顶 `minf(chance+BONUS, CAP)`）/ `randf() >= best_chance` return / 命中写 `fengwu_pickup_day` + `grant_fengwu` + `add_log`。
- **`_try_grant_fengwu_item(item_id)`（L656）**：`ITEM_DB.get(item_id).category=="fengwu"` 则 `grant_fengwu(item_id)`。挂接于 `add_item()` 尾部（L20），使 `ShopUI` **零改动**自动上架+入册。
- **区段位移修复**：风物志区由文件末尾移至记忆回响区**之前**（Python 纯位移，零字节差）。修复后顺序 `十景(L98) → 风物志(L345) → 记忆回响(L662，文件尾)`。目的：恢复两个已放行回响 QA 脚本的「marker→EOF」切片假设 → 记忆回响回归由各 3 FAIL 恢复全绿（见 §6）。

### 2.2 `scripts/GameManager.gd`（4 空格缩进 · 现 779 行）

- **`ITEM_DB` 末尾新增 6 条 `category:"fengwu"`**（L268-273）：`fw_longjing`(60) / `fw_oufen`(30) / `fw_guihuatang`(20) / `fw_chousan`(90) / `fw_wangxingji`(70) / `fw_tianzhukuai`(45)。注释强调 **key 必须与 `FENGWU_ITEMS` fid 逐字相同**，否则 `_try_grant_fengwu_item` 不触发；`ShopUI` 无条件遍历 `ITEM_DB.keys()` 自动上架，本文件改动即唯一接入点。
- **`GALLERY_ITEMS` 新增 1 条 CG（L374）**：`{ "char":"player", "pose":"west_lake_fengwu", "label":"西湖风物·大成", "hint":"集齐廿四件西湖风物后解锁...", "flag":"west_lake_fengwu_complete", "bg":"res://assets/backgrounds/lakeside_evening.jpg" }`。**零新建美术**，`char:"player"` 经 `GalleryPopupUI` 的 `ResourceLoader.exists` 守卫，无立绘目录也不崩。

### 2.3 `scripts/MainGame.gd`（4 空格缩进 · 现 499 行）

- **`_on_location_selected` 插入（L242）**：在 L220 `if _try_memory_echo(loc_id): return` **之后**、L221 `hotspot_ui.on_location_selected(loc_id)` **之前**插入 `CollectionManager.pick_fengwu_pickup(loc_id)`。被动授予+toast，**不 return 不抢屏**，天然与记忆回响互斥（回响命中时已在 L220 return）。
- **更多菜单新增按钮（L441）**：第 10 项 `{"text":"🍃 风物志", "color":Color(0.34,0.46,0.28), "fn":_show_fengwubook_popup}`（既有 9 按钮之后）。
- **新增 `_show_fengwubook_popup()`（L193）**：仿 `_show_stampbook_popup`，`load("res://scripts/FengwuBookUI.gd").new()` + `add_child` + `closed` 信号回收 + `was_explore_visible` 还原。

### 2.4 `scripts/FengwuBookUI.gd`（新建 · 4 空格缩进 · 350 行）

- **模式**：`extends CanvasLayer`，`signal closed`，运行时 `load().new()` 子界面（仿 `StampBookUI`）。**不注册 Autoload、不建 .tscn**。
- **纯只读**：不写任何 flag、不 grant（验证脚本 F 段断言 `not flags.has/set`）。
- **布局**：6 列 × 4 行 `GridContainer`，24 格点亮状态 + 分类 emoji（味🍶 / 物🏺 / 草木🌿 / 声景🔔）+ ⭐软条件正反馈 + 手作槽暗金虚位（`C_TODO_BORDER`）+「本章可达 18 件」提示。
- **详情区**：点击格子填充 `_obtain_tip`——拾得显示地点名+软条件+每日限速；购得显示价格；手作显示「尚未开放」。入场/退场动画同 `StampBookUI`。

### 2.5 零改动但已读确认的依赖文件

| 文件 | 确认结论 |
|---|---|
| `scripts/ShopUI.gd` | L137-144 无条件遍历 `GameManager.ITEM_DB.keys()`，无 category 过滤 → 6 条 fengwu 自动上架，**零改动**。 |
| `scripts/SaveSystem.gd` | L75 `"flags": GameManager.flags.duplicate()` / L279 `GameManager.flags = d.get("flags", {})`，整字典序列化 → `fengwu_*` 自动持久化，**零存档迁移、无需版本号 bump**。 |
| `scripts/EndingScreen.gd` | L484 `flags={}` 清空（fengwu_* 随清）、L515-518 `title_*` 白名单回写（称号自动继承）、L160/341 `begins_with("title_")` 收集。本地无 fengwu 硬编码，**零改动**。 |
| `scripts/GalleryPopupUI.gd` | L99-102 / L267-270 `ResourceLoader.exists` 守卫，新 CG 条目只吃 `bg`，`char:"player"` 安全。 |
| `scripts/LocationManager.gd` | lakeside 周末放开四段；现有地点时段已知（用作拾得软条件设计，避免死权重）。 |

---

## 3. 架构与数据流

```
                 ┌───────────────── 授予入口（3 条）─────────────────┐
                 │                                                  │
  拾得12  ──►  MainGame._on_location_selected
                  └─► CollectionManager.pick_fengwu_pickup(loc_id)   [被动/toast/D-4]
                          │ loc硬门槛 + 软条件加权(封顶0.60) + 概率
                          ▼
  购得6   ──►  ShopUI(无条件遍历ITEM_DB) ──► GameManager.add_item
                  └─► CollectionManager._try_grant_fengwu_item       [直连/零改动]
                          ▼
  手作6   ──►  (本 sprint 无入口 · 预留) ────────────────────────── [D-3 槽位]

                          └──────────────┐ 全部汇入
                                         ▼
              CollectionManager.grant_fengwu(fid)   [幂等]
                  ├─ 写 fengwu_<fid> + fengwu_<fid>_day
                  ├─ _check_fengwu_completion()  → 遍历全 24
                  │     缺一则 return（本 sprint 恒 false → 称号暂锁）
                  │     集满 → west_lake_fengwu_complete + title_西湖风物通 + unlock_gallery
                  └─ show_toast("🍃 风物入册")  [D-4：无 vignette/演出/回响叠加]

  补偿链路：_retroactive_gallery_check → _retroactive_fengwu_check
              (① 购得旁路 ② 补 _day ③ 集满判定)

  持久化：SaveSystem 整字典 flags.duplicate()  →  fengwu_* 自动存/读（零迁移）
  NG+    ：EndingScreen flags={} 清空 fengwu_* ；title_* 白名单回写（称号继承）
  图鉴   ：FengwuBookUI（运行时 load/new，只读）→ 消费 is_fengwu_owned / get_fengwu_*
  画廊   ：GALLERY_ITEMS[west_lake_fengwu_complete] → lakeside_evening.jpg（零新美术）
```

**设计要点（与十景集章流水线复用）**：`CollectionManager` 寄居风物志逻辑，`GameManager` 留守 `ITEM_DB` / `GALLERY_ITEMS` / `inventory` 状态；授权幂等、称号/画廊/图鉴三路下游在 D-3 手作落地后**自动接通**，无需二次改线。

---

## 4. 缩进 / Autoload / 存档-NG+ 合规（工具实证）

- **缩进铁律**：CollectionManager.gd 首缩进行 `\t`（L12）；GameManager/MainGame/FengwuBookUI 首缩进行均为 4 空格（L9/L36/L34）。`verify_fengwu.py` G 段（缩进铁律）断言全过。
- **Autoload**：`project.godot` [autoload] 仍为 15 条，FengwuBookUI 未注册。
- **存档-NG+**：`grep fengwu` 在 `SaveSystem.gd` / `EndingScreen.gd` 中**零命中** → 纯继承机制，无手写耦合。

---

## 5. 验证：`scratch/verify_fengwu.py`（新增 · 140/140 PASS）

纯静态断言（解析 .gd 文本 / 字面量提取 / 缩进扫描），无 Godot runtime（本机无 Godot on PATH）。覆盖矩阵：

| 节 | 覆盖内容 | 关键断言 |
|---|---|---|
| A 注册表 | 24 槽 = 拾得12 + 购得6 + 手作6 | `FENGWU_ITEMS` 键数==24；三段计数正确 |
| B 拾得条件合法 | loc 真源 + season/weather/slot 软条件值域 | snowy 仅配 winter、slot 落在地点开放时段内（无死权重） |
| C 购得双源交叉 | fid == ITEM_DB key 且 category=="fengwu" | 6 条交叉一致，否则 `_try_grant` 不触发 |
| D 手作预留 | obtain:"手作" 且全局无 grant 路径 | `FENGWU_ITEMS` 块外搜 `fw_hm_` 零命中 |
| E grant 幂等 | `if flags.has(flag): return false` | 重复授予不覆盖 `_day`、不重复 toast |
| F 集满需 24 件 | `_check_fengwu_completion` 遍历全 24 | 本 sprint 最大 18 不可达 → 称号暂锁（断言不被「可达数」降级） |
| G 拾得守卫 | 结局日 guard + 每日限速 + loc 硬门槛 + 概率封顶 | `randf() >= chance` 早退；`minf(chance+BONUS, CAP)` |
| H 与回响互斥 | 插入点在 `_try_memory_echo` return 之后 | 切片至风物志 marker 后，回响区仍为文件尾 |
| I 缩进铁律 | CollectionManager=tab；其余=4sp | 行级统计无混用 |
| J 补偿链路 | `_retroactive_fengwu_check` 串入 gallery check | L95 调用存在 |
| K 画廊 CG 零新美术 | bg 复用现有图 | `res://assets/backgrounds/lakeside_evening.jpg` 存在引用 |
| L 存档/NG+ | flags 整字典 + title_* 白名单 | EndingScreen/SaveSystem 无 fengwu 硬编码 |
| M 零新 Autoload + 图鉴接线 | 菜单第 10 项 + popup + UI 只读 | `🍃 风物志` 按钮 / `_show_fengwubook_popup` / FengwuBookUI 不写 flag |

> 注：脚本编写期曾因中文引号嵌套（F 段）与 4 条断言逻辑写错（F34/F60/F91/F122）误报，均已在脚本侧修正（**未改已放行 QA 迁就实现**，反模式已规避），复跑 140/140 PASS。

---

## 6. 回归结果（4+1 脚本全绿）

| 脚本 | 结果 | 结论 |
|---|---|---|
| `tests/memory_echo_smoke/verify_qa.py` | **286 / 286 PASS** | 风物志位移修复后恢复全绿（修复前各 3 FAIL） |
| `tests/west_lake_stamps_smoke/verify_qa.py` | **165 / 165 PASS** | 十景集章流水线未受影响 |
| `scratch/verify_memory_echo.py` | **111 / 111 PASS** | 回响脚本复测通过（BUG-ME-01 刹车等） |
| `scratch/verify_phone_impl.py` | **PASS** | 手机 UI 闭环未受影响 |
| `scratch/verify_fengwu.py`（新增） | **140 / 140 PASS** | 本特性静态验证全绿 |

**已放行 3 特性零回退确认**：手机 UI 闭环 / 西湖十景集章 165/165 / 记忆回响 286/286。

---

## 7. 遗留风险

| 风险 | 等级 | 说明 / 缓解 |
|---|---|---|
| 称号暂锁体验 | 中 | 玩家集满 18/24 后无称号，需在图鉴明确「本章可达 18 件」提示（已实现）避免误判 bug。手作落地后自动满 24 授称号，无需改线。 |
| 拾得概率感知 | 低 | 基础 0.18、单软条件 +0.12、封顶 0.60；每日单点限速。若实测体感过稀，仅调 `PICK_BASE/BONUS/CAP` 三常量即可，无逻辑改动。 |
| 手作槽位后续接入 | 低 | 见 §8，接手成本极低（单点调用）。 |
| 无 Godot runtime 验证 | 中 | 本机无 Godot on PATH，全部为静态断言。建议 CI 接入真实 Godot headless 跑 `MainGame` 烟雾测试（拾得触发 toast、购得入册、图鉴渲染）作为下一步。 |
| 存档版本号 | 无 | `fengwu_*` 走整字典持久化，零迁移、无需 bump（已确认 v1→v6 兼容）。 |

---

## 8. 手作 6 槽位如何预留 · 后续 sprint 接手成本

### 8.1 预留机制（本 sprint 已完成的部分）
- **注册表全登记**：`FENGWU_ITEMS` 已含 6 条 `obtain:"手作"` 槽位（`fw_hm_yahua` 押花书签 / `fw_hm_guihuajiang` 手熬桂花酱 / `fw_hm_xiangnang` 荷叶香囊 / `fw_hm_taci` 瓦当拓片 / `fw_hm_zhuze` 竹编茶则 / `fw_hm_luyin` 湖声一段），`loc/season/weather/slot` 全空。
- **零 grant 路径**：全局搜 `fw_hm_` 仅出现在 `CollectionManager.gd` 注册表内，**任何脚本都未调用 `grant_fengwu("fw_hm_*")`** → 恒为未获得。
- **下游全接通**：`get_fengwu_reachable_total()` 由 `obtain!="手作"` 派生（当前 18，手作可达成自动回 24）；`_check_fengwu_completion()` 已遍历全 24；`FengwuBookUI` 已渲染暗金虚位 +「尚未开放」提示；画廊 CG `west_lake_fengwu_complete`、称号 `title_西湖风物通` 已就位。
- **D-2 严守**：6 手作 fid 未写入 `ITEM_DB`（纯 flag），与购得 6 条（在 ITEM_DB）明确分流。`_try_grant_fengwu_item` 仅对 `ITEM_DB` 内 `category=="fengwu"` 生效 → 手作必须经**直调 `grant_fengwu`**，不会误入购物/背包链路。

### 8.2 后续 sprint 接手成本（极低）
接手方只需：
1. **建手作系统**（独立 design/impl 任务，超出 D-3 范围）—— minigame / 配方 / 产出。
2. **在产出点加一行调用**：`CollectionManager.grant_fengwu("<fid>")`（6 件各一处，或直接循环 `FENGWU_ITEMS` 中 `obtain=="手作"` 的键）。
3. **（可选润色）** 去掉 6 条 hint 末尾的「【手作 · 尚未开放】」字样。

**零增量部分**（已就位，无需再动）：图鉴 UI、画廊 CG、称号判定、NG+ 继承、拾得/购得同款持久化、存档迁移（无）、`_check_fengwu_completion` 的 24 件遍历、`get_fengwu_reachable_total` 的自动回 24。

**唯一注意点**：手作产出为玩家主动行为，不应套用 `pick_fengwu_pickup` 的每日限速/概率；直调 `grant_fengwu` 即为幂等精确授予（已含 `_day` 写入与集满判定），与 D-4 的「拾得只弹 toast」互不干扰。

---

## 9. 待主理人（游承峰）审批项

1. **验收交付**：4 文件改动 + 新建 `FengwuBookUI.gd` + 新增 `scratch/verify_fengwu.py`（140/140）+ 本 changelog。是否需要我补充某文件的完整 diff 贴出？
2. **git commit**：按铁律未自动提交，请人工审批后再 commit（建议 commit message 锚定 DS-RN-04）。
3. **CI 真机验证**：本机无 Godot runtime，建议下一轮在 CI 接入 Godot headless 烟雾测试（见 §7 中风险）。
4. **手作系统排期**：6 槽位已零成本预留，何时立 design/impl 均可无缝接入（见 §8）。

---

**回传主理人**：游承峰 — 《西湖风物志》DS-RN-04 实现已落地，18/24 可达、称号按设计暂锁、3 已放行特性零回退、新增静态验证 140/140 全绿。待您审批 commit 与手作系统排期。
