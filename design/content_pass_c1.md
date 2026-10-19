# C-1 内容润色 / 角色加厚 / 立绘 Pose 修正 · 交付摘要

> 执行角色：content-lead（设计/叙事专家）
> 协作方式：原地编辑 8 个活跃事件 JSON，未直连其他 agent，结果经 SendMessage 回传主理人
> 配套脚本：`D:\zkgame\scratch\pose_fix_c1.py`（可复现的 pose 规范化变换）

---

## 1. 编辑文件清单（均保持 2 空格缩进）

仅触碰 `text` / `speaker` / `choices` 文本与 `pose` 字段，**未改动任何结构字段与数值**（id / triggerDay / requireRelState / excludeRelState / minAff / maxAff / reqFlags / setFlag / next / affDelta / location / slot 等原样保留）。

| 文件 | 改动类型 | 改动处数 |
|------|---------|---------|
| events_yutong.json | 文本润色 1（错别字）+ pose 丰富 2 | 3 |
| events_jingjing.json | pose 修正 1（upset→serious）+ 丰富 1 | 2 |
| events_xiaoxia.json | pose 修正 1（upset→default）+ 丰富 1 | 2 |
| events_wanqing.json | pose 修正 2（serious/shy→default） | 2 |
| events_keke.json | pose 全移除 16 | 16 |
| events_male.json | pose 修正/移除 52（beichen/jingjing_m/zijun 全移除 + yifei/zicheng→default） | 52 |
| events_special.json | 无改动（已通读审，无坏 pose、文本合规） | 0 |
| events_daily.json | 无改动（已通读审，无坏 pose、文本合规） | 0 |

---

## 2. 对话润色（Deliverable 1）

通读全部 8 个文件，逐条核对自然度 / 口语化 / 人设一致性 / 错别字与语病：

- **实际落地的文本修正（1 处）**：`events_yutong.json` 第 249 行
  `风把她的发绹吹散了` → `风把她的发丝吹散了`
  （「绹 táo」为错别字，应为「丝」。）
- **其余 7 个文件经通读评估**：文本已具备杭州初中生口语质感，各角色口头禅/说话方式一致且可辨识——
  - 叶菁菁「笨蛋」「顺路」；林小夏「废话」「妈」「爽」；
  - 顾北辰「顺路」「话少」；方可可「你管得真宽」「笨蛋」；
  - 苏晚晴文学化留白、多用省略号；沈逸飞极简「……」；周子诚「哥们儿」「虎牙」等。
  
  未见书面腔、错别字或人设漂移，故未做无谓改写，以避免引入新偏差。

---

## 3. 角色加厚（Deliverable 2）

先统计各角色当前事件数（grep charId + `validate_phase3.py` 输出），对照 `content_density_blueprint.md` 配额（每角色 9–12 专属事件）。

| 角色 | 路线 | 解锁日 | 当前事件数 | 蓝图配额 | 是否达标 |
|------|------|--------|-----------|---------|---------|
| yutong | 男主 | 1 | 17 | 9–12（基线 17 已达标） | ✅ |
| jingjing | 男主 | 1 | 12 | 9–12 | ✅ |
| wanqing | 男主 | 3 | 11 | 9–12 | ✅ |
| xiaoxia | 男主 | 2 | 10 | 9–12 | ✅ |
| keke | 男主 | 300 | 9 | 9 | ✅ |
| yifei | 女主 | 1 | 9（male 文件） | 9–12 | ✅ |
| zicheng | 女主 | 2 | 9（male 文件） | 9–12 | ✅ |
| beichen | 女主 | 300 | 9 | 9 | ✅ |
| jingjing_m | 女主 | 1 | 9 | 9 | ✅ |
| zijun | 女主 | 1 | 9 | 9 | ✅ |

**结论**：全部 10 个可攻略角色均已达到/超过蓝图配额。原「只有冷战+挽回」的 4 个角色（keke / beichen / jingjing_m / zijun）在既有文件中已具备完整弧光（meet → daily → friend → close → crush + repeatable + bonus + cold_war/cold_recover），与 blueprint 第 2 节「补完后」列完全一致——表明厚度补完已在先前 pass 落地。

**本轮无需新增事件**，新增事件数按角色均为 **0**。本 C-1 的加厚职责以「核对 + 确认达标」形式完成，未重复造事件、未扩大任何 schema 风险。

---

## 4. 立绘 Pose 修正与丰富（Deliverable 3）

仅改动 `pose` 字段，不动文本与任何结构字段。判定依据 `res://assets/sprites/<char>/<pose>` 实际资产：

- **资产为空 / 无目录角色**（keke / beichen / jingjing_m / zijun）：全部 `pose` 字段统一收敛为**省略（omit）**，交由 DialogueUI 回退默认精灵，从根上杜绝坏引用导致的错帧/空白。
- **仅有 default.jpg 角色**（wanqing / yifei / zicheng）：serious / shy / upset 等非 default pose 一律收敛为 `default`（资产存在）。
- **有 serious 资产但引用 upset**（jingjing）：`upset` → `serious`。
- **无 serious 资产但引用 upset**（xiaoxia）：`upset` → `default`。
- **丰富（仅在资产确实存在时）**：
  - yutong：图书馆做笔记用 `study`、一起吃饭用 `casual`；
  - jingjing：家门口便服等候用 `casual`；
  - xiaoxia：操场初遇用 `casual`。

### Pose 修正清单（原 pose → 新 pose）

**events_keke.json（16 处，全部移除 pose 字段）**
- 原引用：upset×1、shy×13、default×2 → 全部省略（keke 资产目录为空）

**events_male.json（52 处）**
- 顾北辰 beichen（bc_*，16 处）→ 全部省略（资产目录为空）
- 叶明轩 jingjing_m（jm_*，16 处）→ 全部省略（无资产目录）
- 林紫君 zijun（zj_*，16 处）→ 全部省略（资产目录为空）
- 沈逸飞 yifei（yf_*，2 处）：serious→default、shy→default（仅 default.jpg）
- 周子诚 zicheng（zc_*，2 处）：upset→default、shy→default（仅 default.jpg）

**events_wanqing.json（2 处）**
- serious→default、shy→default（仅 default.jpg）

**events_jingjing.json（2 处）**
- upset→serious（修正坏引用，serious 资产存在）
- 丰富：default→casual（jj_001 家门口便服等候）

**events_xiaoxia.json（2 处）**
- upset→default（修正坏引用，无 serious 资产）
- 丰富：xx_001 操场初遇新增 casual（casual 资产存在）

**events_yutong.json（2 处，丰富）**
- yt_002 图书馆做笔记：serious→study（study 资产存在）
- yt_003 一起吃饭：新增 casual（casual 资产存在）
- （yutong 其余 serious/default/shy 均为合法资产，保留）

**修正后状态**：全库不再存在任何 `upset` 引用；空资产角色不再带任何 `pose` 键；wanqing / yifei / zicheng 仅余 `default`；jingjing / xiaoxia / yutong 仅使用其真实存在的 pose。

---

## 5. validate_phase3.py 运行结果

- 运行：`python3 D:\zkgame\scratch\validate_phase3.py`（在 `D:\zkgame` 根目录执行，确保 `scripts/events_*.json` 通配命中）
- 结果：**✅ 本次交付质量门 PASS**
  - JSON 合法（8 文件均通过 `python3 -c "import json;json.load(open(...))"` 复验）
  - ID 唯一（无冲突）
  - requireRelState / excludeRelState 合法
  - close≥60、crush≥85 双保险通过
  - recover 事件无 affDelta
  - next 合法（全部落在 0..n-1 或 99）
  - 目标角色事件数：keke / beichen / jingjing_m / zijun 均为 9
- 统计：总计 147 事件，分布 yutong 17 / jingjing 12 / wanqing 11 / xiaoxia 10 / keke 9 / male 45 / special 23 / daily 20。
- **存量警告（非本次回归）**：79 个普通事件缺 `excludeRelState:cold` —— 属 legacy 存量债，非本 C-1 引入；本 C-1 未新增任何事件，故未扩大该债。建议列入 Phase 3 下一刀「普通事件补 excludeRelState:cold」统一清理。

---

## 6. 仍因缺美术无法加非 default pose 的角色

以下角色因立绘资产尚未交付（目录为空或无目录），本轮只能使用 `default`（或省略 pose 回退默认），无法铺 serious / shy / casual / sport / study 等差异姿态：

- **keke**：资产目录为空 → 全部省略 pose
- **beichen**：资产目录为空 → 全部省略 pose
- **jingjing_m**：无资产目录 → 全部省略 pose
- **zijun**：资产目录为空 → 全部省略 pose
- **wanqing / yifei / zicheng**：仅有 default.jpg → 仅可使用 default

需美术（林绘澄）补齐对应立绘后，方可在上述角色事件中铺开丰富姿态，提升演出层次。yutong / jingjing / xiaoxia 因资产齐备，本轮已做初步丰富（study / casual 等）。

---

## 7. 备份与可复现

- 编辑前已备份 8 个文件至 `D:\zkgame\scratch\backup_c1\`，如需回滚可参照。
- pose 规范化变换由 `D:\zkgame\scratch\pose_fix_c1.py` 执行（按 charId 策略表对 scenes 内 `pose` 做移除/收敛，保留 key 顺序与 2 空格缩进、UTF-8），可复现。
