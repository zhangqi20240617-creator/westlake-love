# 《西湖边青春》Phase 5 打磨平衡 — 首 Sprint 工程改动交付记录（eng_sprint1_changelog）

> **实施人**：程基岩（engineering-lead）
> **交付日期**：2026-08-02（续）
> **任务性质**：**实现**（依据 `docs/balance/eng_balance_audit.md` 的 Stories 表，按主理人游承峰批准范围落地）
> **范围边界**：
> - 严格落在审计报告 Stories 表 + 用户批准的 10 项（R1 / ENG-08 / ENG-09 / M1 / M2 / M4 / S1 / S2 / S3 / S4）。
> - **未触碰** `design/` 数值方案、未动 DES-01/02/03（好感曲线/压力期事件/预估展示）—— 这些待 design-strategist 出方案。
> - **未触碰** 性能重构类（P1 快进批量、P4a dirty 检测、P4b 立绘瘦身、P6 girls_ui），不在本 sprint 范围。
> - **未执行 git commit**（按用户约束）。

---

## 0. 铁律合规自检（上线前硬约束）

| 约束 | 状态 | 说明 |
|---|---|---|
| 缩进铁律：CollectionManager/NetworkManager 用 tab；GameManager/MainGame/DialogueUI/events 用 4 空格；同文件禁混用 | ✅ 合规 | 本 sprint 改动文件：NetworkManager.gd（tab，L19 `SERVER_URL` 已确认 `\t` 起始）、DialogueUI.gd / EndingScreen.gd / SaveSystem.gd / PopupManager.gd（4 空格）。`verify_save_hardening.py` 模块 0 断言（tab/space 行级统计）全过。 |
| 不新增 Autoload | ✅ 合规 | 仅在既有 Autoload（SaveSystem/NetworkManager/EndingScreen/PopupManager/DialogueUI）内修改，无新增单例。 |
| 不破坏已放行 3 特性（手机UI闭环/西湖十景集章/记忆回响） | ✅ 合规 | 4 个正式回归脚本：memory_echo 286/286、west_lake 164/165（A136 为 pre-existing）、verify_memory_echo 111/111、verify_phone_impl 全过。见 §回归结果。 |
| 不写隐私政策文本 | ✅ 合规 | R3 仅作为「待办标注」列出，未编写任何隐私政策正文。 |

---

## 1. 逐 Story 交付明细

### R1 · Android release INTERNET 权限修复 — **Critical**
- **文件**：`export_presets.cfg`
- **Diff**：
  - L136 `permissions/internet=false` → `permissions/internet=true`（解锁真机云存档/排行榜/世界聊天/NG+ profile 拉取）。
  - L10-11 新增 `exclude_filter="mock_server_db/*, scripts/mock_seed_data.json"`。原因：`include_filter` 含 `*.json`，会将联调数据库 `mock_server_db/` 与种子文件打进 release 包（M1 衍生出的打包污染），现明确排除。
- **验证手段**：`verify_save_hardening.py` 模块 R1 断言（配置项解析 + exclude_filter 存在性）。
- **回归结果**：无业务代码改动，3 特性回归不受影响。
- **关联风险**：见 §R3 合规待办。

### ENG-08 · 删除 DialogueUI 冗余 bool 写入 — Medium
- **文件**：`scripts/DialogueUI.gd`
- **Diff**：删除原 L546 `GameManager.set_flag("last_interact_" + char_id, true)`（写入即被下一行覆盖的冗余 bool）。保留 `GameManager.flags["last_interact_" + char_id] = GameManager.day`（现 L548），并加注释说明消费方 `DailyCycleManager` L118/L155 以 `last_day is int` 计时。
- **验证手段**：`verify_save_hardening.py` 模块 ENG-08 断言（L546 行不存在 + L548 仍为 int 写入 + 4 空格缩进）。
- **回归结果**：memory_echo 286/286、verify_memory_echo 111/111 全过（对话结算路径未受影响）。
- **说明**：审计报告误标位于 `CollectionManager.gd`，实际定位在 `DialogueUI.gd`（报告正文已正确标注 P5），已按真实位置清理。

### ENG-09 · 记忆回响重入守卫复核 — Low
- **结论**：**判定为冗余，不加代码**。
- **理由**：重入防护已被三层既有机制全覆盖——① `commit_memory_echo()` 先于 `start_event()` 写冷却（day569 修复）；② BUG-ME-01「同日仅一次」刹车（`CollectionManager.pick_memory_echo`）；③ G6 全局间隔（常态 14 天 / 终章 5 天）。额外的 `is_playing_echo` 布尔守卫会引入与 day569 修复的交互风险，且 `verify_memory_echo.py` 已对 BUG-ME-01 刹车断言。故**最小改动 = 不改动**，保留既有设计。
- **验证手段**：`verify_memory_echo.py` A273-A275 等复测通过；`verify_save_hardening.py` 模块 ENG-09 断言（确认未新增 `is_playing_echo` 守卫且既有刹车存在）。
- **回归结果**：memory_echo 286/286、verify_memory_echo 111/111 全过。

### M1 · Mock Server 端口可配置 — Low
- **文件**：`scripts/mock_server.py`、`scripts/NetworkManager.gd`
- **Diff**：
  - `mock_server.py`：删除顶层 `PORT = 8000` 常量，改为 `DEFAULT_PORT = 8000` + `--port` 命令行参数 + `MOCK_SERVER_PORT` 环境变量 + `resolve_port()`（优先级：命令行 > 环境变量 > 默认）。
  - `NetworkManager.gd`（tab 缩进）：`const SERVER_URL` → `var SERVER_URL`，新增 `_init()` 经 `_resolve_server_url()` 解析，优先级：环境变量 `ZKGAME_SERVER_URL` > `project.godot` `application/config/server_url` > `DEFAULT_SERVER_URL`（http://127.0.0.1:8000）。
- **验证手段**：`verify_save_hardening.py` 模块 M1 断言（顶层 `PORT = 8000` 已不存在；`DEFAULT_PORT`/`--port`/`MOCK_SERVER_PORT` 存在；NetworkManager 经 `_init` 解析）。
- **回归结果**：无游戏业务改动，3 特性回归不受影响。
- **说明**：Mock Server 为 Python，不被 Godot 导出（见 R3/③影响说明），不影响 release 包；但 `NetworkManager` 硬编码本机地址在真机无 server 时静默失败，R1 已解锁权限，真机仍需真实后端或彻底降级（R3 范围内）。

### M2 · 清理 Mock Server 超界脏数据 — Low
- **文件**：`scripts/mock_server.py`、`mock_server_db/leaderboard.json`
- **Diff**：
  - `mock_server.py`：新增 `INTELLECT_MIN=0` / `INTELLECT_MAX=100` 常量；新增 `_sanitized_leaderboard_seed()`，种子入库前过 0-100 校验，越界项丢弃并告警（杜绝脏数据回潮）；常量与提交校验共用。
  - `leaderboard.json`：移除 9 条脏数据（「卷王本王」intellect=110 + 8 条联调垃圾账号），保留 5 条合法（学霸君 95 / 陈雨桐 88 / 林大白 82 / 叶菁菁 60 / 张语翰 29）。原越界项「卷王本王」已修正为 intellect=99 留在种子文件并过校验。
- **验证手段**：`verify_save_hardening.py` 模块 M2 断言（种子 5 条全在 0-100；落盘 leaderboard.json 无越界；入库前校验拦截）。
- **回归结果**：无游戏业务改动。

### M4 · 心愿测试数据外置 — Low
- **文件**：`scripts/mock_server.py`（新建 `scripts/mock_seed_data.json`、`mock_server_db/leaderboard.json` 已并入种子）
- **Diff**：
  - 新增 `scripts/mock_seed_data.json`：含 `leaderboard`（5 条）、`world_chat`、`wishes`（NPC 心愿 + virtual_replies）、`npc_usernames` 等种子。
  - `mock_server.py`：`init_db()` 替代 `init_wishes_db()`，NPC 名单 / virtual_replies 一律来自 `SEED`（`load_seed()` 读 JSON），代码内不再写死测试数据。
  - 清理死代码：移除函数内重复 `import random/time`、未使用的异常变量 `e`。
- **验证手段**：`verify_save_hardening.py` 模块 M4 断言（代码内无 `default_wishes` 写死；SEED 来源为 JSON；死代码已清理）。
- **回归结果**：无游戏业务改动。
- **说明**：`scripts/mock_seed_data.json` 已被 `exclude_filter` 排除出 release 包。

### S1 · NG+ 云端拉取失败时继承数据兜底 — **High**
- **文件**：`scripts/EndingScreen.gd`（4 空格）
- **Diff**：
  - 新增成员变量 `var _ng_profile_snapshot: Dictionary = {}`（L161，结算时留存本周目继承快照）。
  - `_upload_profile_on_ending`（L388）：在 `NetworkManager.save_player_profile(profile)` 前加 `_ng_profile_snapshot = profile.duplicate(true)`——快照与上传载荷同源，保证两条路径继承语义一致。
  - 新增 `_merge_inherit_profile(cloud, local)`（L395）：云端优先；空列表/空字典不覆盖本地已有值；`ng_count` 取 max；`seen_endings`/`unlocked_titles`/`unlocked_recipes`/`gallery_flags` 取并集（只增不减）。
  - `_on_ng_plus_pressed` 的 `on_loaded` lambda（L451-460）：改为 `var src = _merge_inherit_profile(cloud, _ng_profile_snapshot)`；云端失败（`not success`）不中止 NG+，回落本地快照并弹「📴 云端不可用，已用本地记录继承」提示；`if src.is_empty()` 守卫在 `flags = {}` 之前（**绝不清档**，保留旧档并提示异常）。
- **验证手段**：`verify_save_hardening.py` 模块 S1 断言（快照留存、`_merge_inherit_profile` 语义、失败回落、空源守卫前置）。
- **回归结果**：memory_echo 286/286、verify_memory_echo 111/111 全过（NG+ 路径不触及回响/集章特性）。
- **关键决策**：采用「本地兜底优先于云端失败」而非「延迟清空 flags 直到云端成功」——因为延迟清空需在云端回调前保持旧 flags 存活，而 NG+ 流程的 `flags = {}` 与继承写入强耦合；改为「先快照 → 云端回调决定 src 来源 → 仅在 src 非空时才清 flags」，既保证离线可玩，又保证云端不可达时绝不丢继承数据。

### S2 · 旧档 v1~v5 跨版本迁移验证 — Medium
- **性质**：**纯验证交付**（审计报告：补测试交 quality-lead，代码侧加断言交 engineering-lead）。无业务代码改动——迁移链 `_migrate_save_dict` / `_migrate_vN_to_vN+1` 已存在且完整。
- **验证手段**：`scratch/verify_save_hardening.py` 模块 S2 = **数据级重放**：构造 v1~v5 样例存档字典，逐版本跑 `_migrate_save_dict` 语义重放（Python 复刻迁移逻辑），断言读入 v6 后 `relationship_state` 非空且状态机自洽（每版本样例均通过）。同时源码解析确认 `load_from_dict` 末尾已有 `recompute_all_states(true)` 且迁移路径走到该末尾。
- **可复跑性**：脚本为独立 Python，可随时重跑（无需 Godot 运行时）。
- **回归结果**：无业务代码改动，3 特性回归不受影响。

### S3 · 存档损坏/解析失败返回可识别错误码 + meta 配对校验 — Medium
- **文件**：`scripts/SaveSystem.gd`、`scripts/PopupManager.gd`（均 4 空格）
- **Diff（SaveSystem.gd）**：
  - 新增 `signal load_failed(slot, code, msg)`（L16）。
  - 新增 `enum LoadError { NONE, NOT_FOUND, DECRYPT_FAILED, CORRUPTED, VERSION_TOO_NEW, MIGRATE_FAILED }`（L21-28）与 `const LOAD_ERROR_MSG`（L30-37）。
  - 新增 `var last_load_error / last_load_error_msg` + 统一出口 `func _fail_load(...)`（L44-55）+ `func get_last_load_error()`（L58-59）。
  - 重写 `load_game`（L120-187）：区分 `NOT_FOUND`（空槽位，`push_warning` 非 error）/ `DECRYPT_FAILED`（密钥不符/截断/占用）/ `CORRUPTED`（JSON 解析失败）/ `VERSION_TOO_NEW`（orig_ver > SAVE_VER 拒读，防写坏高版本档）/ `MIGRATE_FAILED`；进入前复位错误态；明文兼容路径同套错误码。
  - 新增 `_verify_meta_pairing(slot, body_text)`（L192-205）：读档时比对 `.meta` 的 `body_hash` 与主体 hash；meta 缺失 `body_hash` 字段时向后兼容跳过；不一致仅 `push_warning` 并重写 meta，**不阻断读档**（主体已解析成功，阻断反而判死可玩存档）。
  - `save_game`（L112）：meta 写入加 `"body_hash": str(body_text.hash())`。
- **Diff（PopupManager.gd）**：本地读档失败分支（L453-454）改为 `var err = SaveSystem.get_last_load_error()` 并展示 `err.msg`，不再把「损坏/版本过新」一律误报成「没有存档」。云端下载分支（L502）的「Slot %d 没有存档或下载失败」为独立合法分支，未改动。
- **验证手段**：`verify_save_hardening.py` 模块 S3 断言（枚举完整、各错误码路径、meta body_hash 写入/配对、PopupManager 消费错误码、空槽位非 error）。
- **回归结果**：memory_echo 286/286、verify_memory_echo 111/111、verify_phone_impl 全过。
- **设计原则**：任何路径都不得崩溃（审计 S3 要求）；错误码可被 UI 精确映射为中文提示。

### S4 · NG+ flag 白名单审计 + 关系状态机漏清修复 — Low
- **文件**：`scripts/EndingScreen.gd`（4 空格）
- **Diff**：
  - 在 `GameManager.flags = {}` 之后（L484），新增 `GameManager.relationship_state = {}`（L488）—— 修复漏清：`relationship_state` 是内存缓存，**不在 flags 内**，整体清空 flags 清不掉上周目冷战/好感缓存，会带入新周目 day1。
  - 好感重置后新增 `RelationshipManager.recompute_all_states(true)`（L505，silent 模式）—— 此刻 flags 已清空（无 `rel_cold_*`），状态机由好感纯函数推导，自洽。
- **白名单最终确认**（NG+ `flags = {}` 清空后仅回写继承键）：
  - 继承键：`ng_count`、`seen_endings`、`title_*`（含 `title_西湖十景通` 等跨周目称号）—— **无误清**。
  - 回响键 `mem_echo_*` / `holiday_memory_*` 随 `flags = {}` 整体清空（GDD 要求新周目无残留）—— **无漏清**。
  - `relationship_state` 单独重置（L488）—— **无漏清**（此前缺口已补）。
- **说明**：审计报告 S4 建议的「`PERSISTENT_FLAG_WHITELIST` 序列化裁剪」属打磨期优化，本 sprint 按用户批准范围**仅做审计确认 + 漏清修复**，未引入持久化白名单机制（避免改动 `save_game` 序列化契约带来回归风险）。如需可下 sprint 单独立项。
- **验证手段**：`verify_save_hardening.py` 模块 S4 断言（relationship_state 重置 + recompute 调用 + 白名单键集合正确）。
- **回归结果**：west_lake 164/165（A136 pre-existing）、memory_echo 286/286 全过。

---

## 2. 回归结果汇总

### 2.1 用户指定的 4 个正式回归脚本（用托管 Python 重跑）

| 脚本 | 断言数 | 结果 | 与基线对比 |
|---|---|---|---|
| `tests/memory_echo_smoke/verify_qa.py` | 286 | **PASS（286/286）** | 基线同 PASS，无新失败 |
| `tests/west_lake_stamps_smoke/verify_qa.py` | 165 | **FAIL（164/165）** | 与基线一致：**A136 为 pre-existing**，非本 sprint 引入 |
| `scratch/verify_memory_echo.py` | 111 | **PASS（111/111）** | 基线同 PASS，无新失败 |
| `scratch/verify_phone_impl.py` | 121 | **PASS（全部校验通过）** | 基线同 PASS，无新失败 |

> **west_lake A136 失败性质说明（pre-existing）**：该断言的 `GATE_PAT` 正则扫描 `CollectionManager.gd` 全函数体，命中的是**注释行**（`## 刻意不设的守卫…minAff…`）与**独立的打分优先级分支**（G9 冷战排除、`favorability`/`charId` 打分），并非集章门槛本身。本 sprint **未修改 `CollectionManager.gd` 任何逻辑**，故该失败与本次改动无关，属历史既有 false-positive。任务书未要求修此门禁，保留并在本表标注。建议下 sprint 由 quality-lead 收紧 `GATE_PAT` 作用域（仅扫描集章函数体）以消除噪声。

### 2.2 自研综合验证脚本

| 脚本 | 断言数 | 结果 |
|---|---|---|
| `scratch/verify_save_hardening.py` | 170 | **PASS（170/170）** |

覆盖模块：缩进铁律（tab/space 行级统计）/ R1 / ENG-08 / ENG-09 / S2（v1~v5 数据级迁移重放）/ S3（错误码+meta 配对）/ S1（NG+ 兜底合并）/ S4（白名单+relationship_state 重置）/ M1（端口可配置）/ M2（脏数据清理）/ M4（数据外置+死代码）。

---

## 3. R3 合规待办（上线前 release-ops 负责）

> **本 sprint 未编写任何隐私政策文本**（用户约束）。仅标注待办，供 release-ops 跟踪。

- [ ] **R3-1**：`permissions/internet=true` 已开启（R1），但涉及用户数据（云存档/排行榜/世界聊天/NG+ profile）上传，**上线前须补隐私政策与权限说明页**，在首次联网前明确告知用户数据用途与范围。
- [ ] **R3-2**：确认 Google Play / 国内渠道的「联网权限 + 数据收集」合规声明与《个人信息保护政策》链接就位。
- [ ] **R3-3（建议）**：真机无后端时 `NetworkManager` 应彻底降级（不弹「成功」假提示）—— 当前依赖 R1 权限 + 云端失败回落（S1 仅覆盖 NG+ 继承，云存档/排行榜/聊天的失败提示需单独走 S3 错误码路径确认 UX）。

---

## 4. 遗留风险与待办

| 风险/待办 | 严重度 | 说明 | 建议归属 |
|---|---|---|---|
| west_lake A136 门禁噪声 | Low | pre-existing false-positive，非本 sprint 引入 | quality-lead 下 sprint 收紧 `GATE_PAT` |
| S4 持久化白名单未做 | Low | 仅审计+漏清修复，未引入 `PERSISTENT_FLAG_WHITELIST` 序列化裁剪 | engineering-lead 下 sprint 立项 |
| 性能重构（P1/P4a/P4b/P6） | Medium~High | 不在本 sprint 范围，20MB ogv 立绘卡顿/快进×N/每帧重绘仍待处理 | engineering-lead + 美术（P4b） |
| 数值调参（DES-01/02/03） | Medium | 好感曲线失衡/压力期关系真空/预估展示——**必须 design-strategist 先出方案** | design-strategist → engineering-lead 落地 |
| R2 资源体积 | Medium | assets 135MB，移动端首包压力 | 美术 + release-ops 分包策略 |
| R4 存档密钥硬编码 | Low | `_SAVE_KEY` 写死在 SaveSystem，反编译可提取；单机可接受 | 上云时服务端托管/口令派生 |
| Mock Server 真机无后端 | Low | Python 不打包；真机需真实后端或降级 | release-ops / backend |

---

## 5. 交付物清单

| 类型 | 路径 |
|---|---|
| 改动配置 | `export_presets.cfg`（internet=true + exclude_filter） |
| 改动脚本 | `scripts/DialogueUI.gd`（ENG-08）、`scripts/EndingScreen.gd`（S1/S4）、`scripts/SaveSystem.gd`（S3）、`scripts/PopupManager.gd`（S3）、`scripts/NetworkManager.gd`（M1）、`scripts/mock_server.py`（M1/M2/M4） |
| 新建数据 | `scripts/mock_seed_data.json`（M4）、`mock_server_db/leaderboard.json`（清理后） |
| 验证脚本 | `scratch/verify_save_hardening.py`（170 断言，新建主交付验证） |
| 本记录 | `docs/balance/eng_sprint1_changelog.md` |

---

## 6. 下一步建议（供主理人游承峰调度）

1. **回传 quality-lead 门禁复判**：本 sprint 工程改动已完成，4 正式回归 + 1 综合验证全绿（除 west_lake A136 pre-existing）。建议交 quality-lead 复判 A136 是否需收紧门禁。
2. **R3 合规**：release-ops 立项补隐私政策与权限声明（已开启 INTERNET）。
3. **下 sprint 候选**：性能重构（P1/P4a/P4b/P6）+ 数值调参（待 design 方案）+ S4 持久化白名单 + ENG-09 已闭环（无需做）。

— 交付完 —
