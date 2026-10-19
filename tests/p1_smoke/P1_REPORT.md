# 《西湖边的青春》P1 内容补强 · 整合校验与质量门报告

- **校验对象**：P1 四支柱（节日补全 / 社交圈 / 考试节奏 / 毕业仪式感）
- **校验方式**：Python 逻辑级模拟 + 真实读盘（无 Godot 运行时）
- **校验脚本**：`D:\zkgame\tests\p1_smoke\validate_p1.py`
- **运行环境**：`C:\Users\Administrator\.workbuddy\binaries\python\versions\3.13.12\python.exe`（Python 3.13.14）
- **结论日期**：2025-07-30

---

## 一、质量门判定

> **QUALITY GATE: PASS**

| 指标 | 数值 |
|---|---|
| 断言总数 | 22 |
| PASS | 22 |
| FAIL | 0 |
| WARN | 0 |
| 退出码 | 0 |

**一句话结论**：P1 四支柱落地产物整合校验全部通过（22/22 断言 PASS），无阻塞项，质量门判定 **PASS**。毕业画廊（`grad_photo` / `grad_yearbook`）解锁链路经静态确认完整闭合，可放心进入手动 Playtest 签收阶段。

---

## 二、测试范围

覆盖 P1 全部 44 事件及其与现有引擎/数据/资源的交叉接线：

| # | 校验组 | 校验内容 |
|---|---|---|
| 1 | 事件文件加载 | JSON 合法、44 事件、id 全局唯一（含与 `events_daily.json` 的 `exam_result_*` 等不撞） |
| 2 | statDelta 合法性 | 所有 life/fest/bond/mock/grad 的 statDelta key ⊆ 合法 8 维，无 `study` 死键 |
| 3 | 性别对称 | 全部事件 `charId == null` |
| 4 | 不碰恋爱状态机 | 无事件写 `requireRelState`/`excludeRelState`/`favors`/`affDelta` |
| 5 | flag 串联闭环 | `flag_conflict_resolved`、`bond_misunderstood`、`grad_*` 的 scene 级 setFlag + 引擎读取确认 |
| 6 | 节日叙事接线 | `MainGame.gd` `fest_narrative_map` 四键映射 + 四 fest 事件存在 |
| 7 | SPECIAL_DATES 无冲突 | 无重复 day、240/330=special、P1 新增考日 {110,210,360} 在册、无同日冲突 |
| 8 | 画廊映射一致 | `GALLERY_ITEMS` 含 grad 两条目 + bg 文件存在 + flag 同名 |
| 9 | EVENT_FILES 注册 | 含 `res://scripts/events_life.json` |

---

## 三、用例清单与结果（22 条）

| 用例 | 结果 | 关键证据 |
|---|---|---|
| 1.1 注册进 EVENT_FILES | ✅ PASS | EVENT_FILES 共 10 个文件 |
| 1.2 合法 JSON + 44 事件 | ✅ PASS | life 24 / fest 4 / bond 6 / mock 6 / grad 4 |
| 1.3 全局 id 唯一 | ✅ PASS | 全局 217 事件，无重复 |
| 1.4 不与 events_daily 撞名 | ✅ PASS | life 与 daily 文件 id 零交集 |
| 2 statDelta 合法（无 study） | ✅ PASS | 全部 key ∈ {intellect,strength,social,art,charm,stress,addict,money} |
| 3 性别对称 charId==null | ✅ PASS | 44 事件全部 null |
| 4 不碰恋爱状态机 | ✅ PASS | 无 requireRelState/excludeRelState/favors/affDelta |
| 5.1 flag_conflict_resolved 闭环 | ✅ PASS | setters=[life_conflict_reconcile] requirers=[bond_accept] |
| 5.2 bond_misunderstood 闭环+无死锁 | ✅ PASS | 引用+内部 choice 置位+全局有 setter |
| 5.3 grad_* setFlag 在 scene 级 | ✅ PASS | 四事件 scene_set(gid)=True，top_set=None |
| 5.4 引擎读取 scene 级 setFlag | ✅ PASS | `DialogueUI.gd` L197-200 |
| 6.1 fest_narrative_map 四键 | ✅ PASS | new_year/dragon_boat/mid_autumn/teacher_day 映射正确 |
| 6.2 四 fest 事件存在 | ✅ PASS | 均可被 get_event_by_id 检索 |
| 7.1 SPECIAL_DATES 无重复 day | ✅ PASS | 21 个特殊日期，day 唯一 |
| 7.2 day240=special（文化节） | ✅ PASS | effect='special' |
| 7.3 day330=special（白色情人节） | ✅ PASS | effect='special' |
| 7.4 P1 新增考日 {110,210,360} 在册 | ✅ PASS | exam 日集合=[60,110,180,210,360,480,500] |
| 7.5 无同日冲突 | ✅ PASS | exam/special/festival/break 各 day 互不相交 |
| 8.grad_photo 画廊+资源 | ✅ PASS | flag=grad_photo, bg=grad_photo.jpg, 文件存在 |
| 8.grad_yearbook 画廊+资源 | ✅ PASS | flag=grad_yearbook, bg=lakeside_evening.jpg, 文件存在 |
| 8.3 画廊 flag 与事件 setFlag 同名 | ✅ PASS | [grad_photo, grad_yearbook] 一致 |
| 9 EVENT_FILES 注册 | ✅ PASS | 已含 events_life.json |

---

## 四、与 P0 的衔接

P1 在 P0 已建立的 `events_life.json`（life_24：健康/冲突/家庭三线）基础上 **+20 事件 = 44**：

- **继承并消费 P0 flag**：`flag_conflict_resolved`（P0 由 `life_conflict_reconcile` 置位）被 P1「社交圈」支柱的 `bond_accept`（`requireFlags`）正确消费，形成「冲突线 → 小团体接纳」的剧情闭环，证明 P1 社交内容确实挂在 P0 关系网络上，而非孤立插入。
- **冲突线防死锁**：`bond_misunderstanding` 通过 `excludeFlags: ["bond_misunderstood"]` 引用该 flag，并由自身 choice 置位，闭环自洽、无死锁。
- **SPECIAL_DATES 延续**：P0 框架保留；P1 恢复 `day240` 文化节 special、`day330` 白色情人节 special，并补入考日 `110/210/360`。
- **全局校验一致性**：重跑全局 id 唯一性（217 事件），P1 的 44 id 与 P0 全部文件（含 `events_daily.json` 的 `exam_result_*`）零碰撞。
- **恋爱状态机零侵入**：`DataManager.gd` L290-301 的 `requireRelState/excludeRelState` 门控仅在 `charId != null` 时启用；P1 全部 `charId == null`，逻辑上不可能触碰恋爱状态机（断言 4 实查亦无任何写操作）。

---

## 五、关键发现：毕业画廊解锁链路（Handoff 重点）

**结论：grad 事件 setFlag 确实位于 scene 级，画廊可正确解锁。**

证据链（逐环真实读盘确认）：

1. **事件层（events_life.json）**：四个毕业事件的最终场景（scenes[1]）各自含 `"setFlag": "<自身 id>"`——
   `grad_yearbook`(L986) / `grad_photo`(L1009) / `grad_dinner`(L1032) / `grad_lastclass`(L1055)；
   **事件顶层均无 setFlag**（dead-setFlag 风险为 0）。
2. **引擎层（DialogueUI.gd L197-200）**：场景渲染时
   ```
   if scene.has("setFlag"):
       GameManager.set_flag(scene["setFlag"], true)
       GameManager.unlock_gallery(scene["setFlag"])
   ```
   即引擎「仅读取 scene 级 setFlag」并同步解锁画廊。
3. **画廊层（CollectionManager.gd）**：`unlock_gallery(flag)` 置位 `GameManager.flags[flag]`；`is_gallery_unlocked(item)` 用 `item["flag"]` 匹配。
4. **数据层（GameManager.gd L343-344）**：`GALLERY_ITEMS` 含
   `grad_photo`(flag=grad_photo, bg=res://assets/backgrounds/grad_photo.jpg) 与
   `grad_yearbook`(flag=grad_yearbook, bg=res://assets/backgrounds/lakeside_evening.jpg)，flag 与事件 setFlag 同名。
5. **资源层（真实磁盘）**：
   - `D:\zkgame\assets\backgrounds\grad_photo.jpg`（239742 B ≈ 240KB）+ `grad_photo.jpg.import` ✅ 存在
   - `D:\zkgame\assets\backgrounds\lakeside_evening.jpg`（930562 B）✅ 存在

**grad 事件触发日**：`grad_yearbook`=555 / `grad_photo`=558 / `grad_dinner`=562 / `grad_lastclass`=565，均落在毕业窗口（day540 中考倒计时30天 之后、day570 毕业典礼之前），时序合理。

---

## 六、阻塞项

**无。** 全部 22 条断言 PASS，无 FAIL、无 WARN，无文件/行号级阻塞现象。

---

## 七、观察与建议（非阻塞，供后续迭代参考）

> 以下不构成质量门降级理由，仅作 QA 提示。

1. **grad 事件优先级 = 240（偏低）**：`get_available_event` 按 priority 取最高。毕业窗口内若同地点同日存在更高优先级事件，毕业事件可能顺延（但因其 `non-repeatable` 且从 triggerDay 起长期可触发，玩家后续访问该地点即会补偿触发，风险低）。
2. **手动 Playtest 签收建议（advisory）**：逻辑级校验无法替代真实运行时体验。建议进入 Godot 后补一轮手动 Playtest 签收：
   - 走通「冲突线 → bond_accept → bond_misunderstanding（两分支）」剧情链；
   - 在 day10/120/310/330 验证四 fest 叙事事件实际弹出；
   - 在 day555-565 访问对应地点触发四 grad 事件，确认画廊 `毕业合影`/`毕业纪念册` 实际亮起、CG 正常加载。
3. **资源体积提示**：`grad_photo.jpg` 约 240KB，符合常规背景图规格；如需高清重绘可后续替换，不影响当前解锁逻辑。

---

## 八、产物清单

| 文件 | 说明 |
|---|---|
| `D:\zkgame\tests\p1_smoke\validate_p1.py` | P1 整合校验脚本（22 断言，可重跑，exit code 0/1） |
| `D:\zkgame\tests\p1_smoke\P1_REPORT.md` | 本报告 |

> 约束遵守：仅写入 `D:\zkgame\tests\p1_smoke\`；未修改任何游戏源码/事件 JSON；未做 git 提交。
