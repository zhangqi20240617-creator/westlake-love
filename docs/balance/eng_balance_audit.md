# 《西湖边的青春》Phase 5 打磨平衡 — 首冲刺只读审计报告

> **审计人**：程基岩（engineering-lead）
> **审计日期**：2026-08-02
> **审计阶段**：Phase 5「打磨平衡」首冲刺（只读）
> **审计范围**：性能剖析 / 存档健壮性 / Mock Server 脏数据 / 数值平衡曲线初评
> **铁律声明**：本报告为**只读审计**。除明确标注为「trivial 且零风险」的安全改动外，**未修改任何 `scripts/*.gd`、`events_*.json` 业务逻辑文件，未执行 git commit**。所有修改类建议均以 Story 形式列出，待主理人（游承峰）调度后实施。

---

## 执行摘要（一句话结论）

| 审计块 | 整体严重度 | 一句话结论 |
|---|---|---|
| ① 性能剖析 | **Medium（局部 High）** | 无致命热点，但 20MB 视频立绘 + `advance_time` 链在低端移动设备上有帧率/启动风险，优先清理资源与冗余写入。 |
| ② 存档健壮性 | **High** | 迁移链路基本完整，但 NG+ 清空白名单在无网/云端拉取失败场景会丢失继承数据，属上线前必须加固项。 |
| ③ Mock Server 脏数据 | **Low** | 不影响 release 构建（Python 不在导出列表），但硬编码端口与超界脏数据应在仓库清理，避免误导联调。 |
| ④ 数值平衡曲线 | **Medium（需 design 配合）** | 好感度早期推进偏快、后期边际递减过陡，ExamManager 预估与结算存在感知偏差，需 design-strategist 出数值方案后调参。 |

**首 sprint 落地顺序建议（详见文末）**：先修「上线级阻断」（额外风险 internet 权限 + NG+ 存档）+「零风险清理」（Mock Server / DialogueUI 冗余写入），再做「性能资源瘦身」，最后把「数值调参」交给 design 出方案后再动。

---

## ① 性能剖析

### 1.1 分析对象与方法
- 高频路径：`GameManager.advance_time()` 每日推进链、`MainGame._on_location_selected()`、`CollectionManager.pick_memory_echo()`、`DialogueUI.finish_event()` / `update_sprites()`、`MainGame.update_ui()`。
- 移动端目标：Godot 4.5 **renderer=mobile**、1280×720 横屏、vram 压缩 etc2/astc。
- 方法：静态路径走读 + 调用链展开 + 资源体积盘点。**未运行 profile（本冲刺只读）**，热点判定基于代码路径复杂度与资源体积，非实测数据。

### 1.2 高频路径热点清单

#### P1 · `advance_time()` 每日推进链 — 严重度 **Medium**
- **位置**：`GameManager.gd` L434-481。
- **链路**：`_check_daily_decay` → `_check_special_date` → `_check_weekly_allowance` → `_check_parttime_income` → `_check_char_initiative` →（网瘾递归 `advance_time(true)`）→ `SeasonManager._run_conditional_checks()`。
- **问题**：
  1. 每日跨日触发 **5+ 个 `_check_*` 子系统全量扫描**，每个内部又遍历角色数组与 flags 字典（`DailyCycleManager._check_daily_decay` 内含冷战检测、冷落惩罚、hw 后果链）。在 570 天流程内，若玩家连续「快进」多日，递归/循环会放大成本。
  2. `_check_daily_decay` 内 `recompute_all_states(false)` 会对全部关系状态机重算；快进 N 天时该成本 ×N。
- **建议**：
  - 将「快进多日」改为**批量推进**（一次算出 N 天净 delta，而非 N 次单日链），避免 `_check_*` 重复全量扫描。
  - 对 `_check_char_initiative` 的候选排序（`_night_candidate_sorter`）确认是否每日必跑——可改为「有未决主动事件才排序」。
- **本冲刺动作**：仅提方案，**不修改**（涉及跨模块结算逻辑，需先确认数值副作用）。

#### P2 · `_on_location_selected` → `_try_memory_echo` 回调重入 — 严重度 **Low**
- **位置**：`MainGame.gd` L216-221。
- **问题**：命中记忆回响时用 `CONNECT_ONE_SHOT` 回调重入播放，逻辑正确但**没有去重保护**——若同一帧多次触发 `_on_location_selected`（极端 UI 抖动），可能叠加回响播放。
- **建议**：在 `_try_memory_echo` 入口加 `is_playing_echo` 布尔守卫，进行中直接 return。
- **本冲刺动作**：属「trivial 且零风险」安全改动候选，可下 sprint 直接交 engineering-lead 实现（见 Story ENG-09）。

#### P3 · `pick_memory_echo` 遍历成本 — 严重度 **Low**
- **位置**：`CollectionManager.gd` L499-562。
- **现状**：遍历 `MEMORY_ECHO_CONTEXTS`（10 条）逐条守卫 + 打分，复杂度 **O(10) 常数级**，且含毕业前夜特例（L507-511 已有 BUG-ME-01 修复说明）。
- **结论**：**不构成热点**，无需优化。仅提示：若未来记忆条目扩到 50+，建议改为按 `loc_id` 预分组字典，避免全表遍历。
- **本冲刺动作**：不修改。

#### P4 · 资源加载 — 视频立绘 20MB — 严重度 **High（移动端）**
- **位置**：`DialogueUI.update_sprites()` 优先加载 `.ogv` 视频立绘。
- **实测体积**：
  - `assets/sprites/jingjing/anim.ogv` —— **19.7 MB**（解码为 Theora 视频纹理，移动端解码开销大）
  - `assets/sprites/yutong/anim.ogv` —— 6.9 MB
  - `assets/sprites/yutong/anim11111.ogv` —— 4.0 MB
- **问题**：
  1. 20MB ogv 在低端 Android 上**首次进入 jingjing 场景时会触发明显卡顿/内存尖峰**（视频纹理常驻解码缓冲）。
  2. `anim11111.ogv` 命名疑似**重复/废弃资源**（与 `anim.ogv` 并存），属资源冗余。
  3. `_path_exists_cache` 缓存了资源存在性，但未缓存「已解码纹理」——每次 `update_sprites` 若重新 seek ogv 仍有开销。
- **建议**：
  - **优先**：将 jingjing/anim.ogv 转为轻量序列帧（png 雪碧图）或降低分辨率/帧率，目标 < 5MB；或直接回退静态立绘。
  - 清理 `anim11111.ogv` 等疑似废弃资源。
  - 评估 `update_sprites` 是否每帧无差别重算——建议加 dirty 检测（同 P6）。
- **本冲刺动作**：仅提方案（资源替换需美术配合，交林绘澄协同；代码侧加 dirty 检测可交 engineering-lead）。

#### P5 · `DialogueUI.finish_event` 冗余/类型污染写入 — 严重度 **Medium**
- **位置**：`DialogueUI.gd` L546-547。
  ```gdscript
  GameManager.set_flag("last_interact_" + char_id, true)   # L546：写入 bool true
  GameManager.flags["last_interact_" + char_id] = GameManager.day  # L547：立即覆盖为 int day
  ```
- **问题**：
  1. **L546 是冗余写入**——下一行 L547 立即用 `int day` 覆盖，L546 的 `true` 从未被读取。
  2. 虽 `DailyCycleManager` L119/L157 用 `if last_day is int` 守卫（已确认），理论覆盖了类型污染风险，但**L546 的存在会误导后续维护者**，且 `set_flag` 走的是整字典 flags 序列化路径，无谓写入增加存档体积与心智负担。
- **建议**：**删除 L546 整行**，仅保留 L547 的 `int day` 写入。
- **本冲刺动作**：属「trivial 且零风险」安全改动候选，可下 sprint 直接交 engineering-lead（见 Story ENG-08）。**本冲刺不修改**。

#### P6 · `update_ui` / `girls_ui` 每帧数值刷新 — 严重度 **Medium**
- **位置**：`MainGame.gd` `update_ui()`。
- **现状**：`loc_list_ui` 已有 dirty 检测；但 `girls_ui` 仅更新数值，**疑似每帧无条件重绘**（需确认是否在 `_process` 内无节流调用）。
- **问题**：若 `update_ui` 在 `_process` 中每帧调用且 `girls_ui` 重建节点，会在多角色 HUD 上产生持续 CPU 开销。
- **建议**：对 `girls_ui` 也加 dirty 标志（仅在好感/状态变化时重绘），或将 `_process` 调用改为信号驱动（状态变更时触发一次）。
- **本冲刺动作**：仅提方案（需先确认调用频率，建议 quality-lead 配合实测）。

### 1.3 移动端帧率风险点汇总
| 风险点 | 影响 | 严重度 |
|---|---|---|
| 20MB ogv 视频立绘解码 | 进入场景卡顿/内存尖峰 | High |
| `advance_time` 快进 N 天 ×N 全量扫描 | 快进时掉帧 | Medium |
| `girls_ui` 疑似每帧重绘 | 持续 CPU 占用 | Medium |
| `_path_exists_cache` 未缓存解码纹理 | 立绘反复 seek 开销 | Low |

### 1.4 性能预算建议（供后续 sprint 落地基线）
- 目标帧率：移动端 **≥ 30fps 稳定**（Godot mobile 渲染器下限）。
- 单场景资源预算：立绘纹理常驻 < 15MB / 场景；单 ogv < 5MB。
- `advance_time` 单次推进（含全部 `_check_*`）预算 < 8ms（留足渲染余量）。

---

## ② 存档健壮性

### 2.1 现状
- 存档版本 `SAVE_VER = 6`（`SaveSystem.gd` L6），AES-256 加密，3 槽位，整字典 JSON 序列化。
- 迁移：`_migrate_save_dict`（L118-178）支持 v1→v6 逐步升级；v5/v6 均为补 `relationship_state` 空字典。
- 读档：`load_game`（L72-115）加密优先，失败回退明文 json 并自动迁移回写；`JSON.parse_string` 失败返回 false。
- 容错：`load_from_dict` 逐字段 `d.get(key, default)`；读档后 `recompute_all_states(true)` + `_update_current_holiday()` + `_retroactive_gallery_check()`。

### 2.2 风险点清单

#### S1 · NG+ 清空白名单在无网/云端失败场景丢继承数据 — 严重度 **High**
- **位置**：`EndingScreen.gd` L440 `GameManager.flags = {}` 清空 → L463-466 仅回写 `ng_count` / `seen_endings` / `title_*`。
- **问题**：
  1. 继承的 `money` / `favorability` / `subjects` **来自云端 profile 拉取**（非 flags），写入在云端回调内；但 `flags = {}` 已在本地**先行清空**。
  2. 若云端拉取失败（移动端无 INTERNET 权限、或 server 不可达），**NG+ 继承数据（好感/分科/资金）将全部丢失**，玩家进入新周目从零开始，且无明显错误提示。
- **建议**：
  - 将「本地清空 flags」延迟到「云端 profile 拉取成功并写入继承数据之后」；失败则保留旧档并弹提示，不进入 NG+。
  - 增加离线兜底：云端不可达时用**本地上一周目存档的继承字段**作为 fallback。
- **本冲刺动作**：仅提方案（涉及 NG+ 流程与网络降级，需先确认设计意图，建议 design + quality 双签）。

#### S2 · 旧档 v1~v5 跨版本读取的字段错配 — 严重度 **Medium**
- **现状**：`_migrate_save_dict` 对 v1-v4 做了逐步补字段，v5/v6 补 `relationship_state`。
- **风险**：若某中间版本存档**缺失 `relationship_state` 且 `_migrate_save_dict` 未覆盖该版本号分支**，读档后 `GameManager.relationship_state` 可能为 null → `load_from_dict` L231-232 已用 `if saved_rel is Dictionary else {}` 兜底，但**兜底后未触发 recompute**，关系状态机可能短暂不一致。
- **建议**：迁移完成后统一调一次 `recompute_all_states(true)`（当前在 `load_from_dict` 末尾已有，确认迁移路径也走到该末尾）。补一条单测：构造 v1~v5 各版本样例存档，断言读入 v6 后 `relationship_state` 非空且状态机自洽。
- **本冲刺动作**：仅提方案（补测试交 quality-lead，代码侧加断言可交 engineering-lead）。

#### S3 · 加密失败 / JSON 解析失败的降级路径 — 严重度 **Medium**
- **现状**：`load_game` 加密失败回退明文；`JSON.parse_string` 失败返回 false 并打 error。
- **风险**：
  1. 加密存档**部分损坏**（密钥未变但密文截断）时，`JSON.parse_string` 在解密后的字节上失败 → 返回 false，但**未尝试从 `.meta` 修复或提示用户「存档损坏」**，仅静默失败。
  2. `.meta` 文件本身未校验完整性，可能被单独删除导致「有存档无 meta」或反之。
- **建议**：
  - `load_game` 失败时区分「无存档 / 存档损坏 / 版本不兼容」三种状态，向 UI 返回可识别错误码，弹对应提示。
  - 写档时对 `.meta` 与主体做**配对校验**（如 meta 存主体 hash），读档时校验一致性。
- **本冲刺动作**：仅提方案（需先确认 UX 错误处理规范，design + quality 配合）。

#### S4 · 整字典 flags 序列化下的「幽灵键」累积 — 严重度 **Low**
- **现状**：`SaveSystem.save_game` 整字典 `GameManager.flags` 序列化。任何 `set_flag` 写入的键都会永久入档。
- **风险**：L546（见 P5）这类冗余写入、以及调试期临时 flag 若未清理，会随档累积，增加存档体积且难排查。**当前无周期性「键白名单裁剪」机制**（NG+ 除外）。
- **建议**：定义一个 `PERSISTENT_FLAG_WHITELIST`（或按前缀命名空间管理），`save_game` 时仅序列化白名单内键，杜绝幽灵键。
- **本冲刺动作**：仅提方案。

#### S5 · 字段缺失容错现状评估 — 严重度 **Low（已较好）**
- `load_from_dict` 已逐字段 `d.get(key, default)`，且 `relationship_state` 有 Dictionary 兜底。**此部分健壮性已达上线基线**，无需紧急改动，仅 S2/S3 需补强。

### 2.3 加固建议优先级
1. **S1（High）**：NG+ 云端失败兜底 —— 上线前必做。
2. **S3（Medium）**：损坏/解析失败的错误码区分 —— 上线前建议做。
3. **S2（Medium）**：旧档迁移单测 —— 本 sprint 可并行补。
4. **S4（Low）**：flag 白名单裁剪 —— 打磨期优化。

---

## ③ Mock Server 脏数据清理

### 3.1 现状
- 文件：`scripts/mock_server.py`（524 行，Python，非 Godot 代码）。
- 端口：**`PORT = 8000` 硬编码**（L8）。
- 端点（`do_GET`/`do_POST`）：
  - `GET /leaderboard`、`GET /cloud_save/download`、`GET /wishes/random`、`GET /wishes/my`、`GET /chat/history`、`GET /player/profile`
  - `POST /cloud_save/upload`、`POST /leaderboard/submit`、`POST /wishes/submit`、`POST /wishes/reply`、`POST /chat/send`、`POST /player/profile`
- 数据落地：`mock_server_db/`（leaderboard.json / wishes.json / world_chat.json / profiles/ / saves/）。
- `NetworkManager.gd`（L 内 `SERVER_URL = "http://127.0.0.1:8000"`）硬编码指向本机。

### 3.2 清理清单

| 项 | 位置 | 问题 | 严重度 | 建议 |
|---|---|---|---|---|
| M1 硬编码端口 | `mock_server.py` L8 / `NetworkManager.gd` SERVER_URL | 端口写死，联调冲突时无配置入口 | Low | 改为读环境变量 / 启动参数（`--port`），`NetworkManager` 经 `project.godot` 或 `OS.get_environment` 注入。 |
| M2 超界脏数据 | `mock_server.py` L514 `{"username":"卷王本王","intellect":110}` | `intellect:110` 超出游戏内 0-100 上限（仅本地 mock，不影响游戏校验，但误导联调） | Low | 改为 `intellect: 99` 或标注为「测试桩 NPC」；或抽成 `seed_data/` 独立文件便于清理。 |
| M3 死代码 / 重复 | `anim11111.ogv`（资源侧，见 P4） | 疑似废弃重复资源 | Low | 删除或归档。 |
| M4 测试态数据混入 | `init_wishes_db` 预设 NPC 心愿/回复 | 测试用心愿写死在代码，非数据驱动 | Low | 抽到 `mock_server_db/wishes.json` 初始化文件，与代码分离。 |

### 3.3 对 release 构建的影响说明（重要）
- **Mock Server 不影响 release 构建**：Godot 导出（export_presets）仅含 `.gd` / `.tscn` / `.png` 等资源，**Python 脚本不在 `export_filter` 内**，不会打入 APK/AAB。故 M1-M4 属**仓库卫生**问题，不影响打包体积与运行。
- **但 `NetworkManager` 硬编码 `127.0.0.1:8000` 在移动端本机无 server** → 云存档 / 排行榜 / 世界聊天 / NG+ profile 拉取**在真机上全部静默失败**（见额外风险 R1）。上线前必须配套真实后端，或在无网时彻底降级（不弹出「成功」假提示）。

### 3.4 本冲刺动作
- 仅提方案。**M2（脏数据 intellect:110）与 M4（心愿数据外置）属 trivial 清理，可下 sprint 交 engineering-lead**，且不触碰游戏业务代码，零风险。

---

## ④ 数值平衡曲线初评

> 本节为**初评**，结论性调参需 design-strategist 出正式数值方案后由 engineering-lead 落地。本节仅指出「曲线是否合理」的初步判断与待澄清问题。

### 4.1 好感度曲线
- **瓶颈锁**：`FAVOR_MILESTONES`（L513）三层锁 30 / 60 / 85，**仅覆盖 4 角色**（yutong/jingjing/xiaoxia/wanqing）。
- **边际递减**（`add_favor`）：基础 0.35 → ≥30 系数 0.22 → ≥60 系数 0.12 → ≥85 系数 0.05。
- **增益来源**：好感基础 + 心情/运势/穿搭地点加成 + 每日 `InitiativeManager._check_char_initiative`（≥85 触发概率 0.6，每晚最多 1 位主动邀请 +3）。
- **初步问题**：
  1. **早期推进偏快**：基础 multiplier 0.35 且无「每日/每周好感增益上限」，配合每日主动邀请（+3）与 5 星运势（×1.2），理论上前期可在数十天内逼近 30/60 锁，导致前中期「好感已拉满、后续无事可做」。
  2. **后期边际过陡**：≥85 仅 0.05，且 85→真结局需 ≥90，最后 5 点需极大量互动，形成「长尾疲劳」。
  3. **覆盖不一致**：`InitiativeManager.CHAR_INITIATIVE_CONFIG` 仅 6 角色（yutong/jingjing/wanqing/xiaoxia/yifei/zicheng），`FAVOR_MILESTONES` 仅 4 角色；而 `keke`/`beichen`/`zijun`/`jingjing_m` 有 relCold/relRecover 事件但**缺主动邀请与瓶颈锁配置** → 内容覆盖不对称，部分角色关系成长路径与主线角色不一致。
- **初步结论**：曲线「前快后陡」存在失衡风险，**建议 design-strategist 评估**：①是否引入每日/每周好感增益上限；②85 锁以上系数是否需从 0.05 上调至 0.08-0.10；③补齐 yifei/zicheng/keke 等角色的里程碑与主动邀请配置。

### 4.2 ExamManager stress 乘数
- **结算**（`calculate_exam_score`）：stress >80 → `randf_range(0.85,0.95)`；<30 → `(0.98,1.05)`；否则 `(0.95,1.02)`；addict>60 随机单科 -10~25。
- **预估**（`project_exam_score`，用于 UI 提示）：stress >80 → **0.90**；<30 → **1.015**；否则 **0.985**。
- **初步问题**：预估用「中值」（0.90/1.015/0.985），真实结算用「区间随机」（0.85-0.95 等），玩家看到的预估与实际存在**感知偏差**（尤其 >80 时预估 0.90 但可能落到 0.85，偏差 -5.6%）。
- **初步结论**：偏差幅度小、方向一致（高 stress 必降），**暂不构成平衡问题**，但建议 design 确认「预估是否应展示区间而非单点」，避免玩家误判。

### 4.3 570 天流程曲线评估
- 关键节点：`PRESSURE_START_DAY=361`（压力期起点）、`EXAM_DAY=570`（考试日）；长假窗口 winter[90,100]/spring[150,155]/summer[270,300]/autumn[303,309]。
- 评估：学业压力在 361 天后陡增，但好感系统无对应「考前降温」机制（仅 DailyCycle 全局 -1~-2）。若好感已在 300 天前拉满，361-570 的 200 天压力期**缺乏关系侧目标**，玩家可能进入「纯刷分」空窗。
- **初步结论**：流程曲线在**中后期（361-570）关系目标真空**，建议 design 在压力期补充关系事件或「考前羁绊」机制。

### 4.4 调参初步结论汇总
| 维度 | 是否需调参 | 责任方 |
|---|---|---|
| 好感早期过快 / 后期过陡 | **需**（待方案） | design-strategist 出方案 → engineering-lead 落地 |
| 角色覆盖率不一致（里程碑/主动邀请） | **需**（补齐配置） | design 定表 → engineering-lead 填数据 |
| ExamManager 预估偏差 | 暂不需（可优化展示） | design 确认展示方式 |
| 361-570 关系目标真空 | **需**（补事件） | design 出事件 → engineering-lead 接入 |

---

## ⑤ 优先级排序 Stories 表

> 工作量：S（<0.5d）/ M（0.5-2d）/ L（>2d）。
> 归属块：①性能 ②存档 ③Mock ④数值 ＋R（额外风险）。
> 实施方标注：**[ENG]** 下 sprint 可直接交 engineering-lead；**[DES]** 需 design-strategist 先出方案；**[QA]** 需 quality-lead 配合回归/测试。

| Story ID | 标题 | 归属块 | 严重度 | 工作量 | 验收标准 | 依赖 | 实施方 |
|---|---|---|---|---|---|---|---|
| **R1** | 修复 Android release 缺 INTERNET 权限（云存档/排行榜/聊天/NG+ 真机全失效） | R | **Critical** | S | `export_presets.cfg` `permissions/internet=true`；真机联网功能可用或明确降级提示 | 无 | **[ENG]** |
| **S1** | NG+ 云端拉取失败时继承数据兜底（防丢档） | ② | **High** | M | 云端不可达时保留旧档并弹提示，不进入空 NG+；或本地 fallback 继承字段 | R1（网络降级约定） | **[ENG]** + design 确认意图 |
| **ENG-08** | 删除 `DialogueUI.finish_event` L546 冗余 bool 写入 | ① | Medium | S | L546 删除，L547 `int day` 保留；存档 `last_interact_*` 仍为 int；回归对话结算 | 无 | **[ENG]** |
| **ENG-09** | `_try_memory_echo` 加 `is_playing_echo` 重入守卫 | ① | Low | S | 回响播放中重复触发不叠加 | 无 | **[ENG]** |
| **P4a** | 立绘加 dirty 检测，避免每帧重算 `update_sprites` | ① | Medium | M | `update_sprites` 仅在立绘状态变更时执行；profiler 确认调用频次下降 | 无 | **[ENG]** + [QA] 实测 |
| **P4b** | 替换/压缩 20MB jingjing ogv 立绘 + 清理 `anim11111.ogv` | ① | High | M | jingjing 立绘资源 < 5MB；场景进入无卡顿；废弃资源删除 | 美术（林绘澄）协同 | **[ENG]** + 美术 |
| **S3** | 存档损坏/解析失败返回可识别错误码 + meta 配对校验 | ② | Medium | M | `load_game` 区分无档/损坏/不兼容；损坏时 UI 弹对应提示 | 无 | **[ENG]** + design UX |
| **S2** | 旧档 v1~v5 迁移单测（relationship_state 自洽） | ② | Medium | S | 构造 v1-v5 样例存档，断言读入 v6 后状态机自洽 | 无 | **[ENG]** + [QA] |
| **S4** | 定义 `PERSISTENT_FLAG_WHITELIST`，`save_game` 仅序列化白名单键 | ② | Low | M | 幽灵键（调试/冗余）不再入档；存量档兼容 | 无 | **[ENG]** |
| **M2** | 清理 mock_server 超界脏数据（intellect:110） | ③ | Low | S | `intellect` 落在 0-100；标注测试桩 | 无 | **[ENG]** |
| **M1** | mock_server 端口改为可配置（env/参数） | ③ | Low | S | 支持 `--port`；`NetworkManager` 经环境变量注入 | 无 | **[ENG]** |
| **M4** | 心愿测试数据外置到 `mock_server_db/wishes.json` | ③ | Low | S | 代码不含写死心愿；初始化读文件 | 无 | **[ENG]** |
| **P1** | `advance_time` 快进多日改为批量推进（避免 ×N 全量扫描） | ① | Medium | L | 快进 N 天成本 ≈ 单日 ×1.2 而非 ×N；数值结算结果与旧逻辑一致 | design 确认快进语义 | **[ENG]** + [QA] |
| **P6** | `girls_ui` 加 dirty 检测或信号驱动刷新 | ① | Medium | M | HUD 仅在状态变更时重绘；[QA] 实测帧时间下降 | 确认 `_process` 调用频率 | **[ENG]** + [QA] |
| **DES-01** | 好感度曲线调参方案（日/周增益上限、85+ 系数、角色补齐） | ④ | Medium | L | design 出正式数值表；覆盖 yifei/zicheng/keke 等缺失配置 | 无 | **[DES]** → [ENG] 落地 |
| **DES-02** | 361-570 压力期关系目标/考前羁绊事件设计 | ④ | Medium | L | design 出事件；关系侧中期目标非空窗 | 无 | **[DES]** → [ENG] 接入 |
| **DES-03** | ExamManager 预估展示方式确认（单点 vs 区间） | ④ | Low | S | design 确认 UI 呈现；偏差可接受 | 无 | **[DES]** |

**优先级排序（首 sprint 落地顺序）**：
1. **R1（Critical，阻断上线）** → 先解真机联网失效。
2. **S1（High，防丢档）** → 上线前存档安全。
3. **ENG-08 / ENG-09 / M2 / M1 / M4（零风险 trivial 清理）** → 顺手清，不阻塞。
4. **P4b（High，移动端卡顿）** + **P4a / P6（性能瘦身）** → 打磨帧率。
5. **S3 / S2 / S4（存档加固）** → 健壮性收尾。
6. **P1（性能重构）** → 需 design 确认语义，放后。
7. **DES-01 / DES-02 / DES-03（数值调参）** → **必须 design-strategist 先出方案**，engineering-lead 不擅自改数值。

---

## ⑥ 额外风险（上线级，超出本 4 块范围）

| ID | 风险 | 严重度 | 说明 | 建议 |
|---|---|---|---|---|
| **R1** | **Android release 缺 INTERNET 权限** | **Critical** | `export_presets.cfg` L136 `permissions/internet=false`。Godot Android 导出**不会自动加 INTERNET 权限**；设为 false 后，云存档 / 排行榜 / 世界聊天 / NG+ profile 拉取在真机**全部静默失败**（HTTPRequest 直接无网络）。这是**上线阻断级**问题。 | 上线前将 `permissions/internet=true`；并配合 S1 做无网降级，避免「假成功」提示。 |
| **R2** | 资源体积 / 首包大小 | Medium | assets 135MB，单 ogv 19.7MB；移动端首包/热更体积压力大，下载与安装转化受影响。 | 资源压缩（etc2/astc 已开）、立绘瘦身（见 P4b）、评估是否分包/按需下载。 |
| **R3** | 移动端权限与隐私合规 | Medium | 若启用云存档/排行榜，涉及用户数据上传，需隐私政策与权限声明；`internet` 开启后需合规告知。 | 上线前补隐私政策与权限说明页。 |
| **R4** | 存档加密密钥硬编码 | Low | `_SAVE_KEY` 写死在 `SaveSystem.gd`，反编译可提取；属轻度风险（单机游戏影响有限）。 | 可接受；若上云需服务端托管密钥或用户口令派生。 |
| **R5** | Debug 热键残留 | Low | `MainGame` F6/F7/F9/F10 仅在 `OS.is_debug_build()` 生效，release 自动失效——**已正确隔离**，仅记录无风险。 | 无需改动，保持现状。 |

---

## 审计结论与下一步

1. **本冲刺产出**：仅本报告，未改任何业务代码、未提交。
2. **可立即下 sprint 交 engineering-lead 直接实施的**：R1、ENG-08、ENG-09、P4a、S1、S3、S2、S4、M1、M2、M4、P4b（资源侧需美术协同）、P6（需 QA 实测）。
3. **必须 design-strategist 先出方案再动的**：DES-01（好感曲线）、DES-02（压力期关系目标）、DES-03（预估展示）；P1（快进语义）也建议 design 确认。
4. **上线阻断项**：R1（INTERNET 权限）须在首 sprint 立即处理，否则联网功能真机全失效。

— 报告完 —
