# 《西湖边的青春》· 生活支柱补强 P0 三件套 · 设计草案（GDD / 事件蓝图）

> **阶段**：✅ 已落地（2026-07-30）—— 用户确认决策 D1–D5 后，24 个事件已写入 `scripts/events_life.json`、ExamManager.gd 接入 stress 乘数、stress_collapse 死键已修；校验 14/14 PASS，质量门 PASS。
> **本文件性质**：设计文档（已落地）。落地产物：`scripts/events_life.json`(24 事件) / `scripts/DataManager.gd`(EVENT_FILES 注册) / `scripts/ExamManager.gd`(project_exam_score stress 乘数) / `scripts/events_daily.json`+`events.json`(stress_collapse 死键修复) / `tests/life_smoke/validate_life.py`(校验)。
> **负责人**：文策渊（design-strategist）　**调度者**：游承峰
> **目标**：让"生活事件"真正回写 `stress` / `social` / `money` 与中考预估分，把生活从"演出"变成"核心循环的一部分"，直击审计结论 ⚠️**支柱漂移**。

---

## 0. 命名空间核查（Grep 实证，先查后写）

| 检查项 | 命令 | 结果 |
|---|---|---|
| `life_health_*` / `life_conflict_*` / `life_family_*` 前缀是否被占用 | `Grep life_health_\|life_conflict_\|life_family_ 于 scripts/*.json` | **0 命中** —— 三前缀完全空闲，可安全使用 |
| 现有 `stress_collapse` 位置 | `Grep stress_collapse` | 存在于 `events_daily.json:279` 与 `events.json:4406`（跨文件重复 id，沿用既有去重管线） |
| 现有事件总数 | 审计 §一 | 10 文件 / 262 条（含跨文件重复 id） |

**结论**：本草案 24 个事件 id 全部以 `life_*` 前缀，不与现有 262 事件冲突。

---

## 1. 字段名 / 门控变量核查表（真实存在，附文件:行）

写事件前必须确认字段名真实存在。以下均来自**真实读盘**，非臆造：

### 1.1 属性字段（`statDelta` 的合法 key）
| 设计名 | 引擎 key | 类型/范围 | 证据 |
|---|---|---|---|
| 学习 | `intellect` | `stats` 字典，clamp 0–100 | `GameManager.gd:9`；`STAT_DISPLAY` L480 |
| 运动 | `strength` | `stats`，0–100 | `GameManager.gd:10` |
| 社交 | `social` | `stats`，0–100 | `GameManager.gd:11` |
| 艺术 | `art` | `stats`，0–100 | `GameManager.gd:12` |
| 魅力 | `charm` | `stats`，0–100（**不进中考公式**） | `GameManager.gd:13` |
| 压力 | `stress` | `stats`，0–100 | `GameManager.gd:14` |
| 网瘾 | `addict` | `stats`，0–100 | `GameManager.gd:15` |
| 金钱 | `money` | **独立属性** `GameManager.money`（非 stats，无 clamp） | `GameManager.gd:18`；`add_stat` L603 |

> ⚠️ **关键陷阱**：旧事件 `stress_collapse`（`events_daily.json:296-300`）写了 `statDelta: {study:-10, social:-10, stress:-40}`，其中 `study` **不是合法 key**（`stats` 里只有 `intellect`），`add_stat` 对不存在的 key 静默丢弃（`GameManager.gd:611` `if stats.has(stat_name)`）。即 `study:-10` 是**死键**，从不生效。
> **草案决策**：本 P0 事件一律用 `intellect`（不用 `study`）。并建议落地时顺手把 `stress_collapse` 的 `study` 改为 `intellect`（见 §11 决策点 D4）。

### 1.2 门控字段（来自 `DataManager.gd` 事件引擎，L196–309）
| 字段 | 语义 | 证据 |
|---|---|---|
| `triggerDay` | **从该天起可用**（下界，无上界） | L202-203 |
| `minStress` | `stats.stress >= 值` 才触发 | L256-257 |
| `minAddict` | `stats.addict >= 值` | L252-253 |
| `minAff` | 对 `charId` 好感度下界 | L220-222 |
| `requireFlags` | 列出的 flag **全部**须已置位 | L225-227 |
| `excludeFlags` | 列出的 flag **任一**已置位则跳过 | L235 |
| `requireHoliday` | `winter`/`spring`/`summer`/`autumn`/`any`（长假期间） | L275-280 |
| `requireSeason` | `spring`(≤150)/`summer`(≤300)/`autumn`(≤450)/`winter`(>450) | L270-272；`WeatherManager.gd:28-33` |
| `requireWeather` | `sunny`/`cloudy`/`rainy`/`snowy` | L265-267 |
| `requireRelState` / `excludeRelState` | 仅当 `charId` 非空时，对**恋爱关系状态机**生效 | L292-300 |
| `charId` / `location` / `slotId` / `priority` / `repeatable` | 角色 / 地点 / 时段 / 优先级 / 可重复 | 多行 |
| `exam_week` | **是 flag**（`GameManager.flags["exam_week"]`），期中(day60)/期末(day180)期间由 `MainGame.gd:244/265` 置位/擦除 | `MainGame.gd:244,265` |

> ⚠️ **无上界日期门控**：引擎只有 `triggerDay`（下界），**没有 `maxDay`/`untilDay`**。需要"仅某窗口"的事件，用 `triggerDay` 下界 + `requireFlags`/`excludeFlags` 表达上界（见 §8.1）。

### 1.3 现有冲突/状态机制（须区分）
| 机制 | 归属 | 用途 | 证据 |
|---|---|---|---|
| 冷战 `rel_cold_<charId>` | `RelationshipManager`（恋爱状态机） | **仅情侣间**，close/crush + 21天无互动触发 | `RelationshipManager.gd:64-87`；`DailyCycleManager.gd:134-145` |
| `current_holiday` | `DailyCycleManager` | 长假类型，门控/校内事件抑制 | `DailyCycleManager.gd:40-47` |
| 网瘾衰减 | `DailyCycleManager._check_daily_decay` | `addict>60/80` 全局好感衰减；`stress>90` 全局好感衰减 | `DailyCycleManager.gd:111-129` |

---

## 2. 设计目标与支柱对齐

- **支柱一（既有）**：恋爱情感弧。
- **支柱二（本次立）**：初中生活真实度 —— 通过"生活事件 → 属性 delta → 中考预估分"**闭环**让生活回写核心循环。
- **反支柱漂移**：每个 P0 事件至少有 1 个属性 delta 真实进入 `ExamManager` 结算或 `DailyCycleManager` 衰减链；纯演出事件数量为 0。
- **零新建系统**：不新增 Autoload；同伴冲突走 `social` + 可选 `flags`，**不碰 `RelationshipManager`**。

---

## 3. 维度一 · 青春期身心健康（9 事件）

> 命名 `life_health_*`。全部 `charId: null`（主角 solo / 内心独白 / 微信，性别天然对称）。
> 回写：`stress`（核心）+ 可接 `social`（倾诉降 stress）+ 可接 `intellect`（失眠影响次日效率→中考预估）。

| # | id | 标题 | 触发条件 | 涉及角色 | 属性变化（delta，±量级） | 与中考预估分关联 |
|---|---|---|---|---|---|---|
| H1 | `life_health_anxiety_attack` | 焦虑发作与自我调节 | `minStress:45`，`repeatable:true`，`priority:280` | 主角 solo | 选择：**自我调节** `stress:-12`；**硬扛** `stress:+6` | `stress` 经 §7 结算乘数；自我调节降 stress 防临界 |
| H2 | `life_health_insomnia` | 备考失眠 | `minStress:40`，`repeatable:true`，`priority:260`，`slotId:"night"` | 主角 solo | `stress:+8`，`intellect:-2`；选择"刷手机到天亮"追加 `addict:+8`（联动 NetworkManager） | `intellect:-2` → 预估分 ≈ −3（§7 公式）；`addict:+8` 累积→中考网瘾惩罚 |
| H3 | `life_health_glasses` | 近视与配镜 | `triggerDay:120`，`requireFlags:["flag_health_glasses_done"]`(排他，防重复) 或 `repeatable:false` | 主角 solo | `money:-50`（配镜），`stress:-5`（看清世界） | `money` 不进中考公式（消费向）；`stress` 走乘数 |
| H4 | `life_health_body_anxiety` | 青春期外貌/身材焦虑 | `minStress:35`，`repeatable:true`，`priority:270` | 主角 solo | `stress:+8`，`social:-3`；选择"接纳自己"`stress:-5` | `social:-3` → 预估分 ≈ −0.6；`stress` 走乘数 |
| H5 | `life_health_counseling` | 主动寻求心理咨询 | `minStress:55`，`repeatable:false`，`priority:300` | 主角 solo（校心理老师） | `stress:-20`，`social:+2` | `stress:-20` 显著拉开与临界区距离，避免 collapse |
| H6 | `life_health_vent_friend` | 情绪波动向朋友倾诉 | `minStress:30`，`repeatable:true`，`priority:250` | 主角 solo（微信/放学路，无 charId） | `stress:-12`，`social:+3` | `social:+3` → 预估分 ≈ +0.6；`stress` 走乘数 |
| H7 | `life_health_panic_prelude` | 崩溃前兆（预警） | `minStress:75`，`repeatable:true`，`priority:290` | 主角 solo | `stress:-10`，`social:-3`（预警但已伤社交） | 承接 `stress_collapse`：75≤stress<90 区间给玩家"最后自救窗口" |
| H8 | `life_health_exercise_relief` | 运动疏导 | `repeatable:true`，`priority:200`（无门槛，常驻疏导） | 主角 solo | `strength:+3`，`stress:-12`，`social:+2` | `strength:+3` → pe ≈ +0.9；`social:+2` → +0.4 |
| H9 | `life_health_art_relief` | 艺术疏导 | `repeatable:true`，`priority:200` | 主角 solo | `art:+3`，`stress:-10`，`social:+1` | `art:+3` → chinese ≈ +0.3 |

> **说明**：既有 `stress_collapse`（`events_daily.json:279`，`minStress:90`/`repeatable:false`）作为**临界崩溃 capstone** 保留并衔接（见 §7.2）。H7 填补 75–89 的预警真空。

---

## 4. 维度二 · 同学关系冲突 / 校园欺凌·排挤·孤立（6 事件）

> 命名 `life_conflict_*`。**全部 `charId: null`**，走 `social` + 可选 `flags` 表达同伴关系，**不碰 `RelationshipManager`/冷战**（那是恋爱）。
> 回写：`social`（核心，降/升）+ `stress`（升）。

| # | id | 标题 | 触发条件 | 涉及角色 | 属性变化（delta） | 与中考预估分关联 |
|---|---|---|---|---|---|---|
| C1 | `life_conflict_excluded` | 被小团体排挤 | `triggerDay:60`，`repeatable:false`，`priority:240` | 主角 solo（群像，无 charId） | `social:-6`，`stress:+10` | `social:-6` → 预估 ≈ −1.2 |
| C2 | `life_conflict_rumor` | 谣言/八卦中伤 | `triggerDay:90`，`excludeFlags:["flag_conflict_resolved"]`，`repeatable:false`，`priority:245` | 主角 solo | `social:-5`，`stress:+12` | `social:-5` → ≈ −1.0 |
| C3 | `life_conflict_bystander` | 站队抉择·旁观者良知 | `triggerDay:120`，`requireFlags:["flag_conflict_active"]`（由 C1/C2 置位），`priority:255` | 主角 solo | 选择**出面制止**：`social:+5`，`stress:+5`，置 `flag_peer_upstander`；**沉默**：`social:-3`，`stress:+8` | `social:+5`→+1.0 / `social:-3`→−0.6 |
| C4 | `life_conflict_reconcile` | 和解 | `requireFlags:["flag_conflict_active"]`，`excludeFlags:["flag_conflict_resolved"]`，`priority:260` | 主角 solo | `social:+6`，`stress:-12`，置 `flag_conflict_resolved` | `social:+6`→+1.2；`stress:-12` 脱离高危 |
| C5 | `life_conflict_transfer_buffer` | 转学缓冲 / 新环境融入 | `triggerDay:271`（呼应 keke 初二转学线，见 `events_keke.json` "转学来的她"），`repeatable:false`，`priority:250` | 主角 solo（你是转学生 / 或帮助新同学，对称双视角文本） | `social:+4`，`stress:-8`，`money:-10`（安家/请客） | `social:+4`→+0.8；`stress:-8` 缓解 |
| C6 | `life_conflict_new_kid` | 新同学接纳 vs 从众压力 | `triggerDay:150`，`repeatable:false`，`priority:235` | 主角 solo | 选择**真诚接纳**：`social:+4`，`stress:-3`；**随大流排挤**：`social:-2`，`stress:+6` | 双向 delta 均进预估 |

> **同伴关系"轻量状态"**：本维度用 3 个 flag 串联弧线 —— `flag_conflict_active`（C1/C2 触发）→ `flag_peer_upstander` / `flag_conflict_resolved`（C3/C4 收束）。**不新建字典/Autoload**（见 §10 / §11 D3）。

---

## 5. 维度三 · 家庭深度（9 事件）

> 命名 `life_family_*`。全部 `charId: null`（父母/长辈为场景角色，无 charId 依赖 → 性别对称）。
> 回写：`stress`（冲突升/和解降）、`money`（经济压力）、`social`（亲情）；部分接 `intellect`（期望冲突影响备考）。

| # | id | 标题 | 触发条件 | 涉及角色 | 属性变化（delta） | 与中考预估分关联 |
|---|---|---|---|---|---|---|
| F1 | `life_family_quarrel` | 亲子争吵 | `triggerDay:60`，`repeatable:false`，`priority:230` | 主角 solo（父母） | `social:-4`（亲情），`stress:+12` | `stress:+12` 推高临界风险；`social:-4`→−0.8 |
| F2 | `life_family_reconcile` | 亲子和解 | `requireFlags:["flag_family_quarrel"]`（F1 置位），`priority:265` | 主角 solo | `social:+5`，`stress:-15`，置 `flag_family_ok` | `intellect` 不受直接影响；`stress:-15` 大幅缓解 |
| F3 | `life_family_second_child` | 二胎·注意力转移 | `triggerDay:200`，`repeatable:false`，`priority:225` | 主角 solo | `social:-3`，`stress:+8`，`money:-20`（弟妹开销） | `social:-3`→−0.6 |
| F4 | `life_family_parents_fight` | 父母吵架/离异 | `triggerDay:240`，`repeatable:false`，`priority:240`，`minStress:30` | 主角 solo | `stress:+15`，`social:-4`；若选"父母离异"分支追加 `money:-30` | `stress:+15` 高危；`social:-4`→−0.8 |
| F5 | `life_family_money_pressure` | 家里经济压力 | `triggerDay:150`，`repeatable:false`，`priority:220` | 主角 solo | `money:-30`，`stress:+10`，`social:+2`（理解父母） | `money` 消费向；`stress:+10` 走乘数 |
| F6 | `life_family_grandparent` | 长辈隔代关爱 | `triggerDay:100`，`requireHoliday:"any"`（长假探亲），`repeatable:false`，`priority:210` | 主角 solo（祖辈） | `stress:-12`，`social:+5`，`money:+20`（红包） | `social:+5`→+1.0；`stress:-12` 缓解 |
| F7 | `life_family_expectation` | 家长期望与自我意愿冲突 | `triggerDay:361`（初三开学 `ExamManager.PRESSURE_START_DAY`，见 `ExamManager.gd:165`），`priority:255` | 主角 solo | 选择**顺从期望**：`stress:+5`，`intellect:+3`；**坚持自我**：`stress:-5`，`social:+2` | `intellect:+3`→预估 ≈ +5（直接影响中考！） |
| F8 | `life_family_trip` | 家庭旅行温情（呼应 `break_winter_family`） | `requireHoliday:"winter"` 或 `"summer"`，`priority:215`，`repeatable:false` | 主角 solo | `stress:-15`，`social:+6`，`money:-40`（旅费） | `social:+6`→+1.2；`stress:-15` 缓解 |
| F9 | `life_family_support_study` | 父母支持备考 | `triggerDay:361`，`priority:250`，`repeatable:true` | 主角 solo | `stress:-10`，`social:+4`，`intellect:+2` | `intellect:+2`→≈ +3.3；`social:+4`→+0.8 |

---

## 6. 事件总数核算

| 维度 | 事件数 | 区间要求 | 达标 |
|---|---|---|---|
| 身心健康 `life_health_*` | 9 | 8–10 | ✅ |
| 同学冲突 `life_conflict_*` | 6 | 5–7 | ✅ |
| 家庭深度 `life_family_*` | 9 | 8–10 | ✅ |
| **合计** | **24** | **21–27** | ✅ |

---

## 7. 数值回路设计

### 7.1 生活事件 → 属性 delta → 中考预估分（复用 `ExamManager` 现有逻辑，不另起炉灶）

**预估分权威函数**：`ExamManager.project_exam_score()`（`ExamManager.gd:169-196`），HUD 实时读取。其基础折算（已核实）：

```
chinese  = 60 + 0.25·intellect + 0.10·art  + 0.45·sub_chinese
math     = 40 + 0.40·intellect              + 0.50·sub_math
english  = 50 + 0.25·intellect + 0.10·social + 0.40·sub_english
science  = 60 + 0.55·intellect              + 0.55·sub_science
society  = 40 + 0.20·intellect + 0.10·social + 0.40·sub_society
pe       = min(strength/100 · 30, 30)
total    = chinese+math+english+science+society+pe
```

**生活事件 delta → 预估分变化（生活事件不动 `subject_scores`，仅动 7 维属性）**：

| 属性 delta | 预估分变化 ≈ | 示例（本草案事件） |
|---|---|---|
| `Δintellect` | **1.65·Δi**（系数和 0.25+0.40+0.25+0.55+0.20） | H2 失眠 `intellect:-2` → −3.3；F7 顺从 `intellect:+3` → +5.0；F9 支持 `+2` → +3.3 |
| `Δsocial` | **0.20·Δs**（english 0.1 + society 0.1） | C3 制止 `+5` → +1.0；F6 长辈 `+5` → +1.0；C1 排挤 `−6` → −1.2 |
| `Δart` | **0.10·Δa**（仅 chinese） | H9 艺术 `+3` → +0.3 |
| `Δstrength` | **min(Δk/100·30, 30)**（仅 pe） | H8 运动 `+3` → +0.9 |
| `Δmoney` | **不进中考公式**（装饰/消费向） | H3/F5/F8 等仅影响 `money` |
| `Δcharm` | **不进中考公式**（魅力/关系向） | 本草案未用 |

> ✅ **闭环成立**：生活事件改变 `intellect/social/strength/art` → `project_exam_score()` 即时变动（无需改代码）。这是"生活回写核心循环"的主通道。

### 7.2 stress 安全阈值与崩溃衔接（与现有 `stress_collapse` 衔接）

`stress` **不进 `project_exam_score()`**，但通过**结算乘数**进中考（`calculate_exam_score()`，`ExamManager.gd:82-89`）：

```
stress > 80  → multiplier = randf_range(0.85, 0.95)   # 临界：−5%~−15%
stress < 30  → multiplier = randf_range(0.98, 1.05)   # 轻松：略加成
否则          → multiplier = randf_range(0.95, 1.02)
```

**建议阈值（草案默认，待确认 §11 D1）**：

| 区 | stress 区间 | 机制 |
|---|---|---|
| 🟢 健康 | < 50 | 无事件强约束；<30 结算略加成 |
| 🟡 注意 | 50–74 | H1/H4/H6 等可触发（minStress 35–45） |
| 🟠 高危 | 75–89 | H7 `panic_prelude`（minStress 75）预警窗口 |
| 🔴 临界 | ≥ 90 | 既有 `stress_collapse`（minStress 90）触发 |

**崩溃衔接要点**：
- `stress_collapse`（`events_daily.json:279`）`minStress:90` + `repeatable:false` + `priority:300` → 为**一次性 capstone**。其 `statDelta` 应为 `stress:-40`（已正确），但 `study:-10` 为**死键**（见 §1.1），建议落地时改为 `intellect:-10`。
- ⚠️ 因 `repeatable:false`，崩溃后即便 stress 再次 ≥90 也不会重触发。草案以 H7 预警 + 常驻疏导（H8/H9）填补，并建议评估将 `stress_collapse` 改为 `repeatable:true` 或新增可重复崩溃事件（§11 D4）。

### 7.3 stress 二次回路（经 `DailyCycleManager` + NetworkManager）

- `DailyCycleManager._check_daily_decay`：`stress>90` → 全局好感衰减（`favorability-2`，`DailyCycleManager.gd:120-129`）。好感下降 → 后续 `social` 相关事件阈值受影响，间接牵动预估分。
- **NetworkManager 联动**（§8.4）：高 stress 选择"刷手机" → `addict:+8`（H2），`addict>60` 触发中考网瘾惩罚（`ExamManager.gd:98-105`）+ `addict>80` 全局好感衰减（`DailyCycleManager.gd:114-119`）。形成 `stress→addict→中考/社交` 二级回路。

---

## 8. 与现有系统 / 事件的衔接

### 8.1 门控复用（优先现有字段，无上界则靠 flag）
- **考试周**：`exam_week` 是**真实存在的 flag**（`MainGame.gd:244/265`，期中 day60 / 期末 day180 置位）。备考类事件如需"仅考试周"，用 `requireFlags:["exam_week"]`（如既有 `exam_result_*`）。
- **长假**：直接用 `requireHoliday`（F6/F8）；`current_holiday` 由 `DailyCycleManager` 自动维护。
- **窗口上界**：无 `maxDay`。本草案用 `triggerDay`（下界）+ `requireFlags`/`excludeFlags`（上界/互斥）实现，例如 C2 `excludeFlags:["flag_conflict_resolved"]` 保证和解后不再中伤。
- **季节/天气**：可用 `requireSeason`/`requireWeather`（四季西湖限定，本草案未强依赖）。

### 8.2 不新建 Autoload
- 所有生活维度复用 `GameManager.stats`（`intellect/strength/social/art/stress/addict`）+ `money` + `flags`。
- 同伴冲突 **不碰 `RelationshipManager`**（那是恋爱状态机，冷战仅情侣）。冲突走 `social` delta + 3 个 `flag_*`（§4）。

### 8.3 与网瘾机制（NetworkManager）联动点
- H2 失眠"刷手机到天亮"分支：`addict:+8` → 累积触发 `ExamManager` 网瘾惩罚 + `DailyCycleManager` 好感衰减。
- 既有的"网瘾预警"（班长/球场关切，审计 §1.1）仍生效，形成"压力→深夜刷机→网瘾→中考/社交"的真实青春链路。

### 8.4 与既有事件呼应（非冲突）
- F8 呼应 `break_winter_family`（家的温度）；C5 呼应 keke `events_keke.json` 转学线。
- `stress_collapse` 作为 capstone 保留，本草案 H7 补预警、H8/H9 补常驻疏导。

---

## 9. 质量门草案（PASS / CONCERNS / FAIL）

> 口径参考长假冒烟标准：事件级联可达、数值回写字段真实存在、不与现有 262 事件门控冲突、男女路线对称。

| 维度 | PASS 标准 | CONCERNS（需复核） | FAIL（一票否决） |
|---|---|---|---|
| 级联可达 | 每个有前置的事件（C3/C4/F2）其 `requireFlags` 能被上游事件置位；flag 名一致 | 个别 flag 拼写/置位遗漏 | 上游永不置位导致下游死锁 |
| 字段真实 | 全部 `statDelta` key ∈ {intellect,strength,social,art,charm,stress,addict,money} | 误用 `study` 等死键（同 `stress_collapse` 旧 bug） | 写入不存在的 stats key 且未察觉 |
| 门控无冲突 | `life_*` 前缀 0 命中现有事件；`priority` 不与同槽高优事件互压致死 | 与既有日常事件同 slot 竞争需排优先级 | id 与现有 262 事件重名 |
| 男女对称 | 全部 `charId:null`，无性别分支 | 个别事件误带性别专属 charId | 生活事件依赖恋爱 charId 导致某性别不可见 |
| 数值闭环 | 每个事件 ≥1 个 delta 进 `project_exam_score` 或 `stress` 乘数或 `DailyCycleManager` 衰减 | `money` 单事件（如 H3）不进中考，需确认"消费向"定位可接受 | 纯演出事件（0 数值回写）存在 → 支柱漂移复发 |
| 阈值安全 | stress 正负 delta 设计使典型周目可维持 <90，且崩溃有预警(H7) | 疏导事件频率不足以抵消累积 | 必崩（无可达疏导路径） |

---

## 10. 风险与取舍

1. **信息过载控制（认知过载）**：新增 24 事件 + 既有 262，需避免与日常事件同 slot 抢优先级。取舍：生活事件 `priority` 设 200–300（低于核心恋爱事件 500–1000），且多数 `repeatable:false` 一次性，避免刷屏。门控靠 `minStress`/`requireFlags` 自然节流。
2. **性别路线一致性**：本草案 24 事件 **全部 `charId:null`**，NPC（父母/同学/长辈/朋友）均为场景文本、无 charId 依赖 → 男女路线**天然对称**，无需双份脚本。这是相对恋爱事件（按性别分 5F/5M 两套）的最大简化收益。
3. **轻量"同伴关系"状态**：**建议 P0 不引入**（见 §11 D3）。理由：本维度效果已由 `social` delta + 3 个 flag 完整表达；引入 per-NPC 字典会增加认知负载且违背"不新建系统"。若 P1 社交圈深化需要，可在 `GameManager` 内加 `peer_bond` 字典（非新 Autoload）。
4. **stress 无自然衰减**：引擎无每日 stress 自动回落（`DailyCycleManager` 仅加不减）。取舍：靠 H5/H6/H8/H9/F2/F6/F8/F9 等常驻/条件疏导事件提供下行通道；若玩家长期忽略，崩溃是"设计内"后果（核心循环的一部分），非 bug。

---

## 11. 待用户确认的关键决策点（Decision Points）

| # | 决策点 | 草案默认建议 | 影响 |
|---|---|---|---|
| **D1** | stress 崩溃阈值定多少？`stress_collapse` 沿用 `minStress:90` 还是调至 85？预警 H7 阈值 75 是否合理？ | 沿用 90（capstone），预警 75 | 难度曲线 |
| **D2** | 是否将 `stress` 乘数**也**写进 `project_exam_score()`，让 HUD 预估分随 stress 实时波动（小代码改动，复用现有乘数逻辑）？ | **建议做**（反馈更直观），但非必需——当前 `stress` 已通过结算乘数 + 衰减链闭环 | 是否改 `ExamManager.gd` 一行 |
| **D3** | 是否引入轻量"同伴关系"状态？ | **P0 不引入**，用 `social`+flags | 是否加 `peer_bond` 字典 |
| **D4** | 既有 `stress_collapse` 死键 `study:-10` 是否顺手改为 `intellect:-10`？`stress_collapse` 是否改 `repeatable:true`？ | 改 key 为 intellect；崩溃可重复待定 | 历史 bug 修复范围 |
| **D5** | 部分家庭/冲突事件 `money` 单 delta（H3/F5/F8）不进中考，是否符合"生活不回写核心循环"担忧？ | 接受：money 定位"消费/回忆向"（审计 §六 已定性无经济失衡风险） | 经济维度是否需接中考 |

> **用户确认（2026-07-30）**：D1 沿用 90+75（崩溃 capstone minStress:90 / 预警 H7 minStress:75）；D2 **做**（stress 乘数写进 `project_exam_score()`，改 `ExamManager.gd` 一行复用现有乘数，HUD 预估分随压力实时波动）；D3 **不引入** `peer_bond`（用 social + flag 表达）；D4 **修 key**（`stress_collapse` 的 `study`→`intellect`）+ 崩溃保持 `repeatable:false`；D5 默认接受（money 不进中考）。决策已定，进入工程落地。

---

## 12. 附录 · 与现有 262 事件门控冲突检查（草案自检）

- **id 冲突**：`life_*` 前缀 Grep 0 命中（§0）。✅
- **slot 冲突**：生活事件多不设 `slotId`（任意时段可触发），设 `slotId` 者仅 H2（`night`）；与既有 `night` 事件（如通宵打游戏 `events_daily.json`）可能同槽，靠 `priority`(260) 协调，不互压致死。
- **flag 命名**：本草案新增 flag 统一 `flag_health_*` / `flag_conflict_*` / `flag_family_*`，不与现有 `rel_cold_*` / `seen_*` / `date_*` / `exam_week` 冲突（Grep 确认无前缀占用）。
- **`requireRelState` 误用**：生活事件**不写** `requireRelState`/`excludeRelState`（避免误入恋爱状态机门控）。✅

---

*本文档为 P0 三件套设计草案，所有字段名/门控/系数均来自 `GameManager.gd` / `ExamManager.gd` / `RelationshipManager.gd` / `DailyCycleManager.gd` / `DataManager.gd` / `WeatherManager.gd` / `MainGame.gd` / `DialogueUI.gd` 真实读盘。未写任何事件 JSON、未改任何 `.gd` 源码。待用户确认后进入工程落地。*
