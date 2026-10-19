# 《西湖边的青春》开发交接计划

> **项目**：Godot 4.5 移动端初中恋爱模拟游戏（杭州西湖中学，570 天初中三年流程）
> **主理人**：游承峰
> **文档日期**：2026-08-03
> **文档目的**：供接手开发的同事快速了解项目现状、工程约定、已完成里程碑与待完成工作

---

## 一、项目概览与技术栈

| 维度 | 说明 |
|---|---|
| 引擎 | Godot 4.5 Mobile renderer, GDScript, 1280×720 横屏 |
| Autoload | **15 个**（严禁新增）：GameManager（核心）+ 基础 6 个（DataManager / SaveSystem / NetworkManager / CookingManager / SeasonManager / WardrobeManager）+ 拆出的 8 个子系统 Manager（InitiativeManager / ExamManager / WeatherManager / CollectionManager / LocationManager / DailyCycleManager / NGPlusManager / RelationshipManager） |
| 事件系统 | JSON 驱动，`DataManager.EVENT_FILES` 注册 10 个事件文件（`events_yutong.json` / `events_male.json` / `events_keke.json` / `events_life.json` / `events_break.json` 等），全局约 245 条事件 |
| 联网 | Mock Server（Python, 127.0.0.1:8000），提供云端 profile / 排行榜等联网功能 |
| 存档 | AES-256 加密, 3 槽位, 版本迁移机制 v1→v6（关系状态机在 v6 加 `relationship_state`） |
| 性别分流 | 男主攻略 5 女角色, 女主攻略 5 男角色, 共享事件引擎 |
| 好感度系统 | 30/60/85 三层剧情锁；边际递减（85+ 系数 0.05）；NPC 好感≥30 后主动微信/邀约 |
| NG+ | 跨周目保留称号/食谱/金币/画廊 CG，触发熟悉感台词 |

### 核心设计支柱
1. **时间即代价**：每个行动消耗真实时段（morning/noon/after/evening），不存在「免费」成长
2. **双向奔赴**：NPC 主动发起关系推进，而非玩家单方面刷数值
3. **机会成本**：同一时段只能做一件事，系统主动提示放弃的选项

---

## 二、工程约定（务必遵守）

### 2.1 缩进铁律（GDScript 解析级失败）
| 文件 | 缩进 | 备注 |
|---|---|---|
| `GameManager.gd` / `MainGame.gd` / `DialogueUI.gd` / `EndingScreen.gd` | **4 空格** | |
| `DailyCycleManager.gd` 等新拆出的 Manager | **tab** | |
| `events_life.json` 等事件 JSON | **2 空格** | ⚠️ 曾记错为 4 空格，实际基准 2 空格 |
| **严禁同文件混用** | | Godot 会报解析错误 |

### 2.2 事件文件加载
- `DataManager.gd` 的 `EVENT_FILES` 列表才是实际加载的文件清单。
- ⚠️ `events.json` 是**未加载的历史单体文件**——改它等于没改。新增/修改角色事件须写入对应已加载文件（如 `events_male.json` / `events_keke.json`）。

### 2.3 事件门控引擎（`DataManager.get_available_event`）
- `location:null` / `slotId:null` 视为「任意地点/任意时段匹配」
- `triggerDay` 语义 = **「从该天起可用」**（非「仅当天」），缺省 0 = 不设限
- `repeatable:false` 事件经 `GameManager.flags.has(ev_id)` 判定已消费
- 候选按 `priority` 降序排序取最高，**无同分 tie-break**
- 节日当天有**第二条直发路径**：`MainGame._apply_special_date` 以 `get_event_by_id()` 直接播放，**不校验 triggerDay 也不校验消费** → 故 fest 事件的 `triggerDay` 必须精确等于节日当天

### 2.4 工作流
- 每条需求走：**design-strategist GDD → 主理人决策拍板 → engineering-lead 实现 → quality-lead 独立门禁 → 主理人 trust-but-verify 独立重跑签字**
- 验证用 Python 逻辑级校验脚本（正则/JSON 解析），无 Godot runtime
- Managed Python 路径：`C:\Users\Administrator\.workbuddy\binaries\python\versions\3.13.12\python.exe`

---

## 三、已完成里程碑（基线）

### Phase 1 工程地基 ✅
- GameManager 从 1412 行拆出 8 个子系统 Manager，降至 ~658 行，外部 27 脚本零改动
- 存档 v6 + 关系状态机序列化
- 对外 API 零破窗

### Phase 2 核心张力 ✅
- 机会成本提示 / 顶栏中考倒计时
- 关系状态机（RelationshipManager + 冷战机制 + 男女路线 10 角色冷战/挽回事件全覆盖）

### Phase 3 内容厚度（部分完成）
- 第一批 4 空角色弧光补齐（keke/beichen/jingjing_m/zijun 各 7 新事件，全局 119→147 事件）
- 570 天密度蓝图（`design/content_density_blueprint.md`）
- 存量 `excludeRelState:"cold"` 清理（全 11 文件 209 角色事件 gap=0）
- 立绘多 pose 补全 ✅
- **后续可选**：对话润色 / 全角色加厚至 11-12 事件

### Phase 4 拟真叙事 ✅
- 拟真手机 UI 闭环（朋友圈全 10 + 深夜聊天模式）
- 西湖十景集章（打卡 + 称号「西湖十景通」+ 画廊 CG + 集章簿）
- 记忆回响（地点触发情境回响，复用 holiday_memory_* 画廊 10 条，修复 BUG-ME-01 day569 无限连播）

### 经营/收集扩展
- **西湖风物志**（DS-RN-04 / 04b）：24 件构成（拾得 12 + 购得 6 + 手作 6），称号「西湖风物通」，质量门 51/51 PASS ✅

### 模式创新
- **社团系统 MVP**（DS-RN-05）：5 社团（文学/天文/广播/篮球/美术），初一 day30 后加入，每周一次周活动，强化「时间即代价」。质量门 100/100 PASS ✅
- **节日事件 triggerDay 修复**（DS-RN-06）：4 个 fest 一次性全局事件加 `triggerDay`（10/30/120/310），根治开局即消费/节日当天无内容 bug。质量门 50/50 PASS ✅

### 生活支柱补强 ✅
- P0（身心健康/同学冲突/家庭深度 24 事件）
- P1（节日补全 fest_×4 / 社交圈 bond_×6 / 考试节奏 mock_×6 / 毕业仪式 grad_×4）
- P2（兴趣/经济：春节叙事 + 兼职周薪 + 手作礼物）
- `events_life.json` 扩至 60+ 事件（现为 92，含社团目标层 20 事件）

### Phase 5 打磨平衡（首 sprint 已落地）
- ENG 审计完成（`docs/balance/eng_balance_audit.md`）
- 首 sprint 10 项已落地（`docs/balance/eng_sprint1_changelog.md`）：R1（export internet=true）/ ENG-08/09 / M1/M2/M4 / S1/S2/S3/S4
- **遗留**：DES-01/02/03 数值方案未回传 / 性能重构未做 / S4 持久化白名单未做

---

## 四、当前进行中（半成品，接手须先收尾）

### A 线 · 社团目标层（DS-RN-05b）

| 子项 | 状态 | 说明 |
|---|---|---|
| GDD | ✅ 已交付 | `design/club_target_layer_gdd.md`（822 行），含 5 链设计/成就/画廊/NG+方案/红线 R1-R11/成功标准 S-1~S-7 |
| 主理人裁决 | ✅ 已拍板 | OQ-1 批准（追加 `flag_club_active_<type>` 硬参与门）；OQ-3 批准（根治 NG+ gallery_flags 不回注的全游戏 bug）；推荐默认值全采纳 |
| 实现 | ✅ 已交付 | events_life.json 72→92（+20 个 `club_chain_*`）；GameManager GALLERY_ITEMS +5 条；EndingScreen NG+ 回注（CLUB_ACHIEVEMENT_FLAGS + gallery_flags 全集）；5 个 club_weekly 追加 setFlags；自验 54/54 PASS |
| **门禁** | ⚠️ **半成品** | `tests/club_target_smoke/verify_qa.py` 已写盘（43KB）但**运行 60 秒超时，疑似死循环**，需调试。旧门禁 rebaseline **未完成** |
| **毕业 CG** | ❌ 未出图 | 5 张 `grad_club_<type>.jpg` 未生成。已有美术圣经 `design/club_gallery_art_spec.md`（含构图/色调/生成提示词） |
| **交付记录** | ❌ 未写 | 需写 `docs/balance/club_target_layer_changelog.md` |

**A 线接手第一步——修门禁超时 bug**：
1. 读 `tests/club_target_smoke/verify_qa.py`，找到模拟推演部分（可能 S-1③ 的可达性模拟有无限循环）
2. 修复后重跑确认 PASS（失败=0, concerns=0）
3. Rebaseline 旧门禁（详见下方「待完成 A」）
4. 主理人独立重跑全部门禁签字放行

---

## 五、待完成工作（按 A→B→C→D 顺序）

### A 线 · 社团目标层收尾

#### A1. 修复并跑通社团目标层门禁
- **文件**：`tests/club_target_smoke/verify_qa.py`（已存在但有超时 bug）
- **动作**：调试超时问题（重点检查 S-1 的模拟推演逻辑是否有死循环），修复后运行至全绿
- **验收**：assertions 全通过, concerns=0, 变异测试抓取率 100%

#### A2. Rebaseline 两条既有门禁
- **`tests/club_smoke/verify_qa.py`**：
  - Q0.4 / Q12.3：club 事件数断言 `== 6` → `== 26`（club_join_hub + 5 weekly + 20 chain）
  - Q11.2（原「EndingScreen 零 club 引用」）→ 改为「EndingScreen 对 club 的引用仅限于 `CLUB_ACHIEVEMENT_FLAGS` 常量 + `gallery_flags` 回注，不含 `club_join_hub`/`club_weekly`/`flag_club_joined`/`flag_club_active` 等业务词」
  - 其余断言原样保留
- **`tests/fest_smoke/verify_qa.py`**：
  - Q2.9：事件总数断言 `== 72` → `== 92`
- **验收**：club 100/100, fest 50/50

#### A3. 生成 5 张毕业画廊 CG
- **文件**：`assets/backgrounds/grad_club_literature.jpg` / `grad_club_astronomy.jpg` / `grad_club_broadcast.jpg` / `grad_club_basketball.jpg` / `grad_club_art.jpg`
- **规格**：1280×720, jpg, 风格参考 `design/club_gallery_art_spec.md`
- **⚠️ 关键**：出图后**必须在 Godot 4.5 编辑器打开工程一次**自动生成 `.import` 文件，否则导出包不含该资源（`west_lake_fengwu_complete.jpg` 已踩过此坑）

#### A4. 写交付记录
- **文件**：`docs/balance/club_target_layer_changelog.md`
- **内容**：定位/决策/落点/质量门/已裁决偏差/后续

#### A5. 更新记忆
- `MEMORY.md` 追加「社团目标层 DS-RN-05b」章节
- 当日日志补记

---

### B 线 · Phase 5 打磨平衡

#### B1. DES-01/02/03 数值平衡方案（design-strategist）
- **来源**：`docs/balance/eng_balance_audit.md` 第④块「数值平衡曲线」
- **问题**：好感度早期推进偏快、后期边际递减过陡；ExamManager 预估与结算存在感知偏差
- **输出**：`design/balance_design.md`，含：
  - DES-01：好感度曲线调整方案（早期放缓、边际递减曲线参数化）
  - DES-02：属性成长曲线（主属性/次属性/stress 的三年成长预期）
  - DES-03：经济基底平衡（周零花 100+intellect/5、兼职 +80/周、社团 statDelta 的经济影响）
- **验收**：可断言的成功标准与边界

#### B2. 性能重构（engineering-lead）
- **来源**：`docs/balance/eng_balance_audit.md` 第①块「性能剖析」
- **P1 快进×N**：`advance_time()` 每日推进链改为批量推进（一次算出 N 天净 delta，而非 N 次单日链），避免 `_check_*` 重复全量扫描
  - 位置：`GameManager.gd` L434-481
  - ⚠️ 涉及跨模块结算逻辑，需先确认数值副作用
- **P4a dirty 存档**：`update_ui` / `girls_ui` 加 dirty 检测，避免每帧无条件重绘
  - 位置：`MainGame.gd` `update_ui()`
- **P4b ogv 瘦身**：jingjing/anim.ogv（19.7MB）转为轻量序列帧或降分辨率，目标 <5MB；清理 `anim11111.ogv` 疑似废弃资源
  - 需美术配合
- **P6 girls_ui**：对 `girls_ui` 加 dirty 标志（仅在好感/状态变化时重绘）

#### B3. 打磨门禁（quality-lead）
- 数值边界断言 + 性能前后对比 + 零回归
- concerns=0 方可放行

---

### C 线 · 发布/工程卫生

#### C1. git 初始化
- 项目至今**非 git 仓库**，DS-RN-04/05/05b/06 多文件待提交
- **动作**：
  1. `git init`
  2. 编写 `.gitignore`（忽略 `.import` 生成物 / 临时沙箱 `.*qa_sandbox*` / `__pycache__` / `.godot/`）
  3. 提交全部已交付改动，message 锚定各 DS-RN 编号

#### C2. 修 jpg .import 硬阻塞
- **`assets/backgrounds/west_lake_fengwu_complete.jpg`**：缺 `.import` 文件 → Godot 导出包不含该资源，实机读不到
- **5 张 `grad_club_*.jpg`**（A3 出图后同样需处理）
- **动作**：在 Godot 4.5 编辑器打开工程一次自动生成 `.import`（或手工补）
- **⚠️ 本机无 Godot 二进制**，需在有 Godot 环境的机器上操作

#### C3. fest triggerDay 约定固化（非阻塞）
- 在 `DataManager.gd` 的 `triggerDay` 分支上方补注释，或 docs 登记「fest 事件必须带 triggerDay」约定
- 建议把 `tests/fest_smoke/verify_qa.py` 的 Q6/Q7 接入 CI

#### C4. MainGame if/elif 链脆弱性修复（非阻塞，既有代码）
- `MainGame.gd` L376-381：`elif effect == "break" or effect == "free_day"` 实际链到 `if fest_narrative_map.has(banner)` 而非上方 `elif effect == "festival"`（中间隔 `var` 语句，if/elif 链被截断）
- 因节日 banner 与长假日期不相交侥幸正确，但建议排期单修

---

### D 线 · 新模式创新

#### D1. 新模式创新 GDD（design-strategist）
- 继续「模式创新」线，开启下一种玩法
- **输出**：`design/<new_mode>_gdd.md`
- **要求**：支柱 / MDA / 范围分层（MVP/目标/愿景）/ 跨 GDD 一致性 / 红线 / 成功标准
- **优先**：零新 Autoload 的事件驱动方案
- **候选方向**（供参考，由 design-strategist 评估）：
  - 社团目标层 OQ-4「五社通」大成 CG（集齐 5 成就，需 ≥5 周目，DS-RN-05c）
  - 学科竞赛/课外深度系统
  - 宿舍/走读生活系统
  - 跨角色社交网络图谱
  - 校园传说/都市怪谈探索

#### D2. 新模式创新 实现（engineering-lead）
- 按 GDD 落地；优先零新 Autoload，必要时最小侵入接线
- 零回归既有特性

#### D3. 新模式创新 门禁（quality-lead）
- 独立门禁 + 变异测试 + 零回归
- concerns=0 放行

---

## 六、关键文件索引

### 核心脚本
| 文件 | 说明 | 缩进 |
|---|---|---|
| `scripts/GameManager.gd` | 核心状态引擎（~658 行），含 ITEM_DB / GALLERY_ITEMS / advance_time | 4 空格 |
| `scripts/DataManager.gd` | 事件/角色数据管理，`get_available_event` 门控引擎 | 4 空格 |
| `scripts/MainGame.gd` | 主界面控制器，更多菜单/社团面板/风物志面板 | 4 空格 |
| `scripts/DialogueUI.gd` | 对话 UI，finish_event/setFlags/skipToNextDay | 4 空格 |
| `scripts/EndingScreen.gd` | 结局画面 + NG+ 周目重置 + 继承数据合并 | 4 空格 |
| `scripts/DailyCycleManager.gd` | 日结算链：衰减/特殊日期/周零花/周一重置 | tab |
| `scripts/RelationshipManager.gd` | 关系状态机（好感度纯函数 + 冷战覆盖态） | tab |
| `scripts/CollectionManager.gd` | 风物志 + 记忆回响 + 十景集章 | tab |
| `scripts/InitiativeManager.gd` | 双向奔赴/主动邀请/深夜聊天 | tab |
| `scripts/ExamManager.gd` | 中考预估/结算/机会成本 | tab |

### 事件数据
| 文件 | 说明 |
|---|---|
| `scripts/events_life.json` | 生活事件（当前 92 条，含 fest_×4 / club_join_hub / club_weekly_×5 / club_chain_×20 / life_* / bond_* / mock_* / grad_* / fw_craft_*） |
| `scripts/events_yutong.json` | 陈雨桐线 |
| `scripts/events_male.json` | 5 男角色线（yifei/zicheng/beichen/jingjing_m/zijun） |
| `scripts/events_keke.json` | 柯可线 |
| `scripts/events_break.json` | 长假特殊事件（26 事件） |
| `scripts/characters.json` | 10 角色定义 |

### 设计文档
| 文件 | 说明 |
|---|---|
| `design/club_system_gdd.md` | 社团系统 MVP GDD（DS-RN-05） |
| `design/club_target_layer_gdd.md` | 社团目标层 GDD（DS-RN-05b，822 行） |
| `design/club_gallery_art_spec.md` | 5 张毕业画廊 CG 美术圣经 |
| `design/content_density_blueprint.md` | 570 天密度蓝图 |
| `design/relationship_state_machine.md` | 关系状态机设计 |
| `design/holiday_events_design.md` | 长假特殊事件设计 |
| `design/realistic_phone_gdd.md` | 拟真手机 UI GDD |
| `design/memory_echo_gdd.md` | 记忆回响 GDD |
| `design/gameplay_economy_expansion_gdd.md` | 西湖风物志 GDD |

### 审计与交付记录
| 文件 | 说明 |
|---|---|
| `docs/balance/eng_balance_audit.md` | Phase 5 ENG 审计（性能/存档/Mock Server/数值） |
| `docs/balance/eng_sprint1_changelog.md` | 首 sprint 落地记录 |
| `docs/balance/club_system_changelog.md` | 社团 MVP 交付记录 |
| `docs/balance/fest_triggerday_changelog.md` | fest 修复交付记录 |
| `docs/balance/eng_fengwu_changelog.md` | 风物志交付记录 |
| `docs/balance/eng_fengwu_handmade_changelog.md` | 风物志手作补完记录 |

---

## 七、验证脚本一览

### 运行方式
```bash
PY="C:/Users/Administrator/.workbuddy/binaries/python/versions/3.13.12/python.exe"
"$PY" <脚本路径>
```

### 工程自验脚本（scratch/）
| 脚本 | 说明 | 状态 |
|---|---|---|
| `scratch/verify_club_target.py` | 社团目标层工程自验（54 断言） | ✅ 54/54 PASS |
| `scratch/verify_club.py` | 社团 MVP 工程自验（231 断言） | ✅ 231/231 PASS |
| `scratch/verify_fengwu.py` | 风物志工程自验（160 断言） | ✅ 160/160 PASS |
| `scratch/verify_memory_echo.py` | 记忆回响工程自验（111 断言） | ✅ 111/111 PASS |
| `scratch/verify_phone_impl.py` | 手机 UI 工程自验 | ✅ PASS |
| `scratch/verify_save_hardening.py` | 存档健壮性验证 | ✅ PASS |
| `scratch/_verify_fest_triggerday.py` | fest 修复工程自验 | ✅ PASS |
| `scratch/validate_phase3.py` | Phase 3 校验 | ✅ PASS |

### 独立门禁脚本（tests/）
| 脚本 | 说明 | 状态 |
|---|---|---|
| `tests/club_smoke/verify_qa.py` | 社团 MVP 门禁 | ⚠️ 需 rebaseline（事件数 6→26） |
| `tests/club_target_smoke/verify_qa.py` | 社团目标层门禁 | ⚠️ **超时 bug，需修复** |
| `tests/fest_smoke/verify_qa.py` | fest 修复门禁 | ⚠️ 需 rebaseline（事件数 72→92） |
| `tests/fengwu_smoke/verify_qa.py` | 风物志门禁 | ✅ 51/51 PASS |
| `tests/memory_echo_smoke/verify_qa.py` | 记忆回响门禁 | ✅ 286/286 PASS |
| `tests/west_lake_stamps_smoke/verify_qa.py` | 十景集章门禁 | ✅ 165/165 PASS |
| `tests/phone_impl_smoke/verify_qa.py` | 手机 UI 门禁 | ✅ 121/121 PASS |

---

## 八、已知问题与风险

### 硬阻塞（上线前必须修）
1. **`west_lake_fengwu_complete.jpg` 缺 `.import`** → Godot 导出包不含该资源，实机读不到
2. **5 张 `grad_club_*.jpg` 未生成 + 未 `.import`** → 社团目标层画廊 CG 实机不可见
3. **`tests/club_target_smoke/verify_qa.py` 超时 bug** → 社团目标层无有效门禁
4. **两条既有门禁未 rebaseline** → club_smoke / fest_smoke 的事件数断言已过时

### 重要修复（已落地但需知晓）
- **NG+ gallery_flags 全集回注**（OQ-3）：`EndingScreen.gd` 已在本次实现中一并修复——此前 gallery_flags 被上传合并却从未回注，导致 NG+ 后全部画廊 CG 丢失。现为 CLUB_ACHIEVEMENT_FLAGS + gallery_flags 全集回注。**需门禁验证确认。**

### 非阻塞关注
1. `MainGame.gd` L376-381 if/elif 链脆弱性（既有代码，节日 banner 与长假日期不相交侥幸正确）
2. fest 事件「必须带 triggerDay」约定尚未在源码注释固化
3. 项目非 git 仓库，多轮交付未提交
4. `export_presets.cfg` 的 `internet=true` 已翻正（R1 已修），但 exclude_filter 挡 mock 数据的 R3 合规待办未做
5. `scratch/verify_fengwu.py` L657 描述文案与新语义相悖（非阻塞文档漂移）
6. 社团目标层 OQ-4「五社通」大成 CG / OQ-5 转社评估 / OQ-6 面板进度展示 均未做

### Mock Server 注意
- Python Mock Server（127.0.0.1:8000）不在 Godot 导出列表，不影响 release 构建
- 但硬编码端口与超界脏数据应清理（M1/M2 已落地部分）

---

## 九、社团目标层（DS-RN-05b）技术细节速查

> 接手 A 线收尾的同事请重点阅读此节。

### 已落地的改动（3 个文件）

**1. `scripts/events_life.json`（2 空格，72→92 事件）**
- 末尾追加 20 个 `club_chain_<type>_s<N>` 事件（5 链 × s1..s4）
- type ∈ {literature, astronomy, broadcast, basketball, art}
- 每事件：`priority:218` / `slotId:"after"` / `repeatable:false` / `charId:null` / `triggerDay: 120/220/340/470` / `excludeFlags:["flag_club_week_done"]` / 无 `noTimeCost` / `statDelta` 无 money
- s1 requireFlags = [flag_club_joined, flag_club_<type>, flag_club_active_<type>]
- s2/s3/s4 严格串链（requireFlags 含前一步 chain flag）
- s4 终场景 setFlags 含 `flag_club_achievement_<type>`（成就授予，全池恰好 5 处）
- 5 个 `club_weekly_*` 终场景追加 `setFlags:["flag_club_active_<type>"]`（OQ-1 纯追加）

**2. `scripts/GameManager.gd`（4 空格）**
- GALLERY_ITEMS 55→60，追加 5 条：`{char:"player", pose:"grad_club_<type>", flag:"flag_club_achievement_<type>", bg:"res://assets/backgrounds/grad_club_<type>.jpg", ...}`

**3. `scripts/EndingScreen.gd`（4 空格）**
- 头部 `const CLUB_ACHIEVEMENT_FLAGS`（5 项）
- NG+ 回注段（L518 之后）：① CLUB_ACHIEVEMENT_FLAGS 回注；② gallery_flags 全集回注（OQ-3 根治）

### priority 带位地形（195-300）
| 带位 | 占用者 | 说明 |
|---|---|---|
| 205 | club_weekly astronomy/basketball/art | 社团周活动（已裁决偏差） |
| 212 | club_join_hub | 入社事件 |
| 215 | life_* 两处 | 生活事件 |
| **218** | **club_chain_*×20** | **社团目标层链事件（本层新增，全池唯一占用）** |
| 230 | mock_stress_relief | |
| 240 | grad_yearbook/photo/dinner/lastclass | 毕业 set-piece |
| 250 | life_family_support_study | |
| 255 | life_conflict_bystander | |
| 260-290 | life_health_* | 健康事件带 |
| 300 | fest_* / life_health_counseling | 节日/健康疏导 |

### 红线（R1-R11）
- R1: 不新增 Autoload
- R2: 不改 club_weekly 既有字段（OQ-1 仅追加 setFlags）
- R3: 社团面板只读不写 flag
- R4: 链带位不得压制健康带 260-290 / 毕业带 240
- R5: 画廊条目不得占用既有 pose
- R6: **严禁在链事件 excludeFlags 引用 flag_club_achievement_***（NG+ 携带后链永久死锁）
- R7: 链事件终场景必须 setFlag flag_club_week_done
- R8: 链事件不得带 noTimeCost
- R9: 链事件不得给 money / 新增 ITEM_DB
- R10: charId 全 null（双路线对称）
- R11: events_life.json 2 空格无 tab

---

## 十、联系方式与协作模式

- **主理人**：游承峰（最终决策、trust-but-verify 签字放行）
- **design-strategist**：文策渊（GDD 设计、数值方案）
- **engineering-lead**：程基岩（代码实现、工程审计）
- **quality-lead**：严守真（独立门禁、变异测试）
- **art-director**：林绘澄（美术资产、CG 出图）

> 子代理模式：通过 Agent 工具 spawn，内联回传。TeamCreate/SendMessage 当前不可用，直接用 Agent + subagent_type。

---

*文档结束。如有疑问，先读 `MEMORY.md`（项目长期记忆）与对应 GDD / changelog。*
