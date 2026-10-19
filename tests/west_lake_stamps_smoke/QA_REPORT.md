# QA-RN-03 · 西湖十景集章（DS-RN-03）质量门报告

| 项 | 值 |
|---|---|
| 特性 | 西湖十景集章（DS-RN-03） |
| 设计依据 | `design/west_lake_stamps_gdd.md`（§8-④ T-1 ~ T-12） |
| 测试套件 | `tests/west_lake_stamps_smoke/verify_qa.py` |
| 测试类型 | 静态断言（逻辑级），无 Godot runtime |
| 执行环境 | `C:/Users/Administrator/.workbuddy/binaries/python/versions/3.13.12/python.exe` |
| 审核 | 严守真（quality-lead），独立于 engineering-lead 与 scratch 验证器 |
| **断言总数** | **165** |
| **通过 / 失败** | **165 / 0** |
| **质量门判定** | ✅ **PASS** |
| 阻塞项 | **无** |
| 非阻塞关注项 | 7 项（见 §4） |

---

## 1. 执行结果

```
assertions=165  passed=165  failed=0  concerns=0  notes=7
VERDICT: PASS      (exit code 0)
```

**稳定性**：连续两次执行输出逐字节一致，无 flaky 断言（纯静态解析，无时间/随机/网络依赖）。

**交叉验证**：`scratch/verify_west_lake_stamps.py`（engineering-lead 的临时验证器）独立跑出
114/114 全过。本套件 165 条断言与之**结论一致**，且覆盖面更大——两个独立实现互为佐证。

### 1.1 Phase 5 sprint1 后复跑：A136 门禁作用域误报（已修复，非产品回归）

Phase 5 首个 sprint 结束后复跑本套件，一度出现 `164/165  failed=1  VERDICT: FAIL`，
失败项为 **A136「CollectionManager 集章区 不含任何 minAff/好感/关系状态/charId 门槛」**。

经独立定位，**这是门禁脚本自身的作用域 bug，不是产品回归**：

- `CollectionManager.gd` 在本 sprint 之后成为**多特性共居文件**——集章区（L114–339）之后
  追加了「记忆回响 · 情境回响」区（L340 起）。该区**按设计**合法使用 `favorability` 打分与
  `get_rel_state()` 排除冷战（memory_echo GDD G9）。
- 原 `GATE_PAT` 扫描只截上界（从 `const WEST_LAKE_STAMP_SCENES` 起）、**不截下界**，
  把整个记忆回响区一并扫入，命中 4 行（L496 / L537 / L554 / L567，其中 L496、L567 仅为
  docstring 注释文字）——全部来自记忆回响区，**无一来自集章区**。
- 集章区本身自始至终零门槛；engineering-lead 本 sprint 未改动集章区代码。

**修复**（仅动门禁脚本，未触碰任何产品代码）：在 `verify_qa.py` 中引入 `stamp_area()`
区块切片——起点 `const WEST_LAKE_STAMP_SCENES`，终点取记忆回响区起点标记
（优先级链 `# ── 记忆回响` → `## 记忆回响` → `## 情境回响` → `const ECHO_MATURE_DAYS`
→ `const MEMORY_ECHO_CONTEXTS`，容忍下游改名），仅对切片后的集章区文本（L114–339，226 行）
做 GATE_PAT 扫描；标记缺失时退化为全文件扫描（安全失败：宁可误报，不可漏检）。
命中详情同时从占位符 `L?:` 改为**真实绝对行号**，便于后续定位。

**有效性反向验证**：向集章区注入 3 类真实门槛（`favorability` 阈值判断、`minAff` 字段读取、
`charId` 引用）后，收窄作用域的 A136 **全部仍能捕获**并给出正确行号——作用域收窄未削弱断言强度。

**结论**：A136 复测通过，`165/165  failed=0  VERDICT: PASS`，**判定维持 PASS**。
本条不影响其余 164 条断言，也不改变 S-1 ~ S-4 / R-1 的既有结论
（存档加固由 `verify_save_hardening.py` 170/170 独立覆盖；R-1 为 `export_presets.cfg`
配置改动，`internet=true` 已由主理人手动核验）。

### 与 scratch 验证器的关系

本套件是**重写**而非复用：独立的断言编号体系（A01–A165）、独立的 GDScript
字面量解析器（字符串感知 + `#` 注释剥离 + `Vector2()`/`Color()` 转换）、独立的分组结构。
在 scratch 版 T-1~T-19 之外新增的检查项包括：

- 事件根级 `setFlag` 的**读取方**审计（证明该字段确为死数据，删除无副作用）
- 全 11 个事件 JSON 的根级 `setFlag` 全量扫描（不止 `events_special.json`）
- 场景级 `setFlags` 使用者普查（量化零回归面）
- `repeatable` / `statDelta` / `isSpecial` 字段名与 DialogueUI **实际读取处**的一致性
- `picked_sid` 赋值点的**守卫上下文**分析（证明限速无法绕过）
- 称号 flag 命名惯例的全工程交叉核验（见 §3 独立发现）
- 缩进风格审计（防 GDScript mixed-indent 解析失败）
- board 按钮配色去重、GALLERY flag 去重、临时热点坐标基线漂移检测

---

## 2. 覆盖矩阵

GDD §8-④ 要求的 T-1 ~ T-12 **全部覆盖**，另扩展 7 组：

| GDD | 断言组 | 编号 | 结论 |
|---|---|---|---|
| T-1 / S-5 | A. 十景注册表唯一真源 | A01–A12 | ✅ 10 键、顺序、字段、季节配平 3/2/2/2/1、全工程单点定义 |
| T-2 | B. 与 `WeatherManager.WEST_LAKE_SCENES` 前四景一致性 | A13–A17 | ✅ name/emoji 逐项一致；旧常量 4 条未被改动 |
| T-3 / S-3 | C. 浪漫事件终局 `setFlags` | A18–A31 | ✅ 4 事件 5 条终局全含 `stamp_*`；winter 双分支 idx=[8,9] 均覆盖 |
| T-4 | D. 根级 `setFlag` 死数据清零 | A32–A33 | ✅ 11 个 JSON 根级 `setFlag` 计数为 0；且确认无任何 .gd 读取该字段 |
| T-5 | E. DialogueUI 场景级 `setFlags` | A34–A38 | ✅ 数组分支在单值分支之前；全仓使用者恰 5 处且全为 `west_lake_*` |
| T-6 | F. `stamp_` 字面量无拼写漂移 | A39–A41 | ✅ .gd 与 JSON 双向属于注册表；用 `"stamp_" + sid` 拼接 |
| T-7 | G. 画廊条目 + CG 资产 | A42–A50 | ✅ 条目唯一、字段齐全、`west_lake_stamps_complete.jpg`（186 KB）+ `.import` 已落盘 |
| T-8 | H. 路由闭合 | A51–A60 | ✅ 热点 `west_lake_stamp` ↔ `_open_west_lake_stamp_checkin()` 双向闭合，无孤儿/重复分支 |
| T-9 | I. 热点坐标间距 | A61–A66 | ✅ 5 基础热点两两 ≥ 0.20；与 3 个长假临时热点 ≥ 0.15 |
| T-10 / S-4 | J. 零新 Autoload / 零迁移 | A67–A71 | ✅ `[autoload]` 15 项未变；SaveSystem 无任何 stamp 特判 |
| T-11 | K. `stamp_` 单一写入源 | A72–A74 | ✅ 逻辑侧仅 `CollectionManager.gd`，数据侧仅 `events_special.json` |
| T-12 | L. StampBookUI 单向数据流 | A75–A82 | ✅ 零 flag 写、零 `grant_stamp` 调用、唯一输出 `picked_sid` |
| 扩展 | M. `grant_stamp` 幂等 + 集满原子语义 | A83–A101 | ✅ 幂等守卫、`from_checkin` 分流、集满四动作原子、toast 合并防刷屏 |
| 扩展 | N. 每日 1 章限速 | A102–A108 | ✅ `stamp_checkin_day` 守卫；`picked_sid` 赋值受 `if selectable` 保护 |
| 扩展 | O. MainGame 入口 + 补偿扫描链 | A109–A120 | ✅ board 第 9 键；开局/读档/事件完成三处补偿点全通 |
| 扩展 | P. vignette 契约 | A121–A135 | ✅ `repeatable:true` / `next:99` / `statDelta` 字段名与 DialogueUI 读取处一致 |
| S-1 / S-2 | Q. 路线解耦 | A136–A142 | ✅ 集章链路零 `minAff`/`charId`/`relState`/好感门槛；季节非门槛（A136 扫描域已收窄至集章区，见 §1.1） |
| 扩展 | R. NG+ 语义 + 称号往返 | A143–A153 | ✅ 中文 `title_` flag `substr(6)` 往返无损；见 §3 |
| 扩展 | S. 缩进一致性 | A154–A165 | ✅ CollectionManager 纯 tab；其余 5 文件纯 4 空格；零行内混用 |

---

## 3. 独立复核的关键结论

### 3.1 断桥残雪既有 bug —— 确认已修复

`west_lake_winter_jingjing` 此前写在**事件根节点**的 `setFlag`。经独立审计确认：

1. 全工程 **11 个事件 JSON** 中根级 `setFlag` 计数现为 **0**（A32）；
2. 全工程 `.gd` 中**不存在**任何读取事件根级 `setFlag` 的代码（A33）
   —— 即该字段过去确实是死数据，删除它没有任何副作用；
3. 该 flag 现改由两条 `next:99` 终局场景（idx 8 / idx 9）的 `setFlags` 置位，
   **两条分支都覆盖了**（A29/A30）——这是最容易漏的一处，实现方没有漏。

结论：bug 已实修，且有回归守卫（A32 会在任何人未来把根级 `setFlag` 写回来时立即 FAIL）。

### 3.2 `setFlags` 引擎能力改动 —— 零回归面已量化

新增的场景级 `setFlags` 是**纯新增分支**，既有 `setFlag` 单值路径逐字未动（A35）。
全仓普查确认：场景级 `setFlags` 的使用者**恰好 5 处，全部是本次新增的 `west_lake_*` 终局**（A38）。
即回归面为**空集**——不存在任何既有事件会因这次引擎改动而行为变化。

### 3.3 单向数据流 —— 确认无法绕过

`StampBookUI` 可执行代码中零 `set_flag` / 零 `flags[...] =` / 零 `unlock_gallery` / 零 `grant_stamp`（A75–A76）。
唯一输出 `picked_sid` 在全文件中**仅被赋值一次**，且该赋值语句位于 `if selectable:` 分支内（A107–A108）；
而 `selectable = (mode=="checkin") and (not owned) and (not _checkin_locked)`（A103）。
→ 幂等守卫与每日限速在 UI 层**结构性不可绕过**，而非依赖调用方自觉。

### 3.4 ⚠️ GDD 的一处事实错误（不影响实现，建议回填文档）

GDD §4.3 / §9 D-2 称：「本 GDD 未在工程中检出任何 `title_*` 的授予点，说明本特性可能是第一个称号授予方」。

**独立复核发现这是错的**：`scripts/SeasonManager.gd:206` 早已存在称号授予——
赛季奖励 `title_西湖游客` / `title_清河坊熟客` / `title_烟雨客`，**全部是中文名**（A148–A150）。

好消息是**结论方向不变、反而更强**：工程既有惯例就是「`title_` 前缀 + 中文后缀」，
所以 D-2(a) 选择 `title_西湖十景通` 不是"确立新惯例"，而是**对齐既有惯例**——
这比 GDD 原本设想的理由更稳妥。另外核验：

- 「西湖十景通」与 3 个既有赛季称号**无重名冲突**（A151）；
- 集章路径**不写** `active_title`（佩戴态仍由赛季系统独占，无语义争夺）（A152）；
- `active_title` 键**不以 `title_` 开头**，因此不会被 `EndingScreen:337` 误当成一个称号上传（A153）。

→ 建议把这条事实回填 GDD §4.3，避免后续设计再基于「本项目还没有称号系统」的错误前提。

---

## 4. 非阻塞关注项（advisory，不阻塞放行）

| # | 关注项 | 严重度 | 建议 |
|---|---|---|---|
| N-1 | **CG 水印残留**：`west_lake_stamps_complete.jpg` 为 AI 生成，右下角可能有极淡水印残留。逻辑侧无影响（文件已落盘、`.import` 已生成、画廊条目已接通） | Minor | 人工目视确认；若有残留，裁切或重绘后**原名覆盖**即可，无需改任何代码 |
| N-2 | **vignette 消耗 1 个时段**：盖章走 `DialogueUI.finish_event()` → `advance_time()`。打开面板本身免费（空手退出不消耗时段，A132 已验证兜底路径） | 产品确认 | 与 GDD §2.5 L2 设计一致；请用户确认「盖一枚章 = 半天」的成本符合体感预期 |
| N-3 | **NG+ 行为**：`stamp_*` / `stamp_*_day` / `stamp_checkin_day` / `west_lake_stamps_complete` 在 NG+ 全部清空（`EndingScreen:440` `flags = {}`），`title_西湖十景通` 保留（`:466` 回写） | 已确认符合预期 | 与 GDD §5.2 表格逐行一致，与既有 `holiday_memory_*` / `grad_photo` 行为同构。无需动作 |
| N-4 | **GDD §4.3 事实错误**（见 §3.4）：漏检了 SeasonManager 的既有称号授予点 | Minor（文档） | 回填 GDD，避免后续设计基于错误前提 |
| N-5 | **emoji 字形缺失**：⛰️ / 🌇 在部分低端安卓设备可能渲染为豆腐块 | Minor | 格子下方恒有中文景名兜底，功能不受影响；实机若确认，可降级为纯文字格 |
| N-6 | **lakeside 热点密度**：最坏情况（长假 + lakeside）= 5 基础 + 1 临时 = 6 个按钮 | Minor | 坐标间距已静态验证（基础热点最近 0.279、与临时热点最近 0.362，A61–A62），但建议实机在 1280×720 下目视确认 `HFlowContainer` 不溢出 |
| N-7 | **`format_stamp_day()` 分段口径**：实现用 90 天/学期（对齐 `GameManager` 学制真源），GDD §3.3 正文写的是 150 天季节分段 | Minor | 实现的选择更正确（对齐真源）。且格子内只显示「第 N 天」，学期文案仅出现在详情区，影响面极小。建议以实现为准，回填 GDD |

**无 Blocker / Critical / Major 级问题。**

---

## 5. 未覆盖范围（静态断言的固有边界）

本次为**逻辑级**验证，以下需实机 playtest 确认，**不构成放行阻塞**：

- 集章簿面板在 1280×720 下的实际布局（820×530 面板 + 5×2 格子 + 详情区是否溢出）
- 入场/退场 Tween 动画观感
- 打卡 → vignette → `advance_time()` 的完整时序在真机上的流畅度
- toast 在「第 10 章即集满」时的合并表现（逻辑已验证 A88，视觉待观察）
- 画廊 CG 在 `GalleryPopupUI` 中的实际渲染效果

---

## 6. 质量门结论与放行建议

> ### ✅ 判定：**PASS**
>
> 165 条静态断言全数通过，**未发现任何需要阻塞的真实缺陷**。
> GDD §8-④ 要求的 T-1 ~ T-12 全部覆盖并通过，另有 7 组扩展检查通过。
> 与 engineering-lead 的独立验证器（114/114）结论一致，双向印证。
>
> 顺带修复的既有 bug（`west_lake_winter_jingjing` 根级 `setFlag` 从未生效）
> 经独立审计确认**已实修**，并已建立回归守卫。
>
> **建议放行。** 7 项非阻塞关注项中，仅 N-1（CG 水印）建议在发布前顺手处理，
> 其余为文档回填或实机观察项，可在后续 playtest 中跟进。

**质量门为建议性门控（advisory）——最终放行由用户决定。**

---

## 7. 复现方式

```bash
cd D:/zkgame
C:/Users/Administrator/.workbuddy/binaries/python/versions/3.13.12/python.exe \
    tests/west_lake_stamps_smoke/verify_qa.py
# exit 0 = PASS / PASS-with-concerns, exit 1 = FAIL
```

套件对游戏代码**只读**，无副作用，可随时纳入回归套件重复执行。
