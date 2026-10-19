# 立绘多 Pose 补全 GDD · 西湖边的青春

> **负责人**：文策渊（设计 / 叙事）  
> **阶段**：规划（纯设计文档，**不含**立绘生成、不改事件 JSON、不改 GameManager）  
> **本轮范围**：补齐「无资产」硬缺口 **10 张新立绘** + 对应事件 pose 接入方案 + 画廊编目方案  
> **执行方**：§2 提示词与生成 → art-director（林绘澄）；§3/§4/§5 落地改动 → engineering（程基岩）；本文件只出规格与清单  
> **状态**：待用户签字（见 §8）

---

## §0 读盘证据（Ground Truth）

### 0.1 立绘资产现状（`assets/sprites/` 实扫）

| 角色 ID | 中文名（`scripts/characters.json`） | 目录实有文件 | 格式/尺寸备注 |
|---|---|---|---|
| yutong | 陈雨桐 | default / casual / serious / shy / sport / study (+anim.ogv) | default 为 1024，其余 2048 PNG |
| jingjing | 叶菁菁 | default / casual / serious / shy / sport (+视频) | 2048 PNG |
| xiaoxia | 林小夏 | `casual.png` / `default.png` / `shy.png` | 2048 PNG，**无 sport** ❌ |
| wanqing | 苏晚晴 | `default.jpg` **仅 1 张** | 1024×1024 白底 JPG（旧标准） |
| yifei | 沈逸飞 | `default.jpg` **仅 1 张** | 1024×1024 白底 JPG（旧标准） |
| zicheng | 周子诚 | `default.jpg` **仅 1 张** | 1024×1024 白底 JPG（旧标准） |
| keke | 方可可 | default / shy / upset | 2048 RGBA PNG（2026-07-27 批次） |
| beichen | 顾北辰 | default / serious / shy | 同上 |
| jingjing_m | 叶明轩 | default / shy / upset | 同上 |
| zijun | 林紫君 | default / serious / shy | 同上 |

> 依据：`design/pose_asset_manifest.md` §2/§4 + `ls assets/sprites/*` 实扫复核，两者一致。

### 0.2 硬缺口（本轮范围）

```
wanqing : 缺 shy / serious / casual      → 3 张
yifei   : 缺 shy / serious / casual      → 3 张
zicheng : 缺 shy / serious / casual      → 3 张
xiaoxia : 缺 sport                       → 1 张
────────────────────────────────────────────
合计                                        10 张
```

其余 6 角色（yutong / jingjing / keke / beichen / jingjing_m / zijun）pose 已较全，**本轮不补**（用户决策 ①）。

### 0.3 事件文件位置与加载事实（关键）

`scripts/DataManager.gd:10-21` `const EVENT_FILES` 实际加载 **10 个文件**：

```
events_yutong / events_jingjing / events_wanqing / events_xiaoxia / events_keke
events_male / events_special / events_break / events_daily / events_life
```

> ⚠️ **`scripts/events.json`（5022 行，89 事件）不在 EVENT_FILES 中 —— 是拆分前的历史单体文件，运行时不加载。**  
> 其中同样存在 `yf_001 / zc_001 / yf_walk / zc_team / …`（events.json:720 / 824 / 2491 / 2598 …），与 `events_male.json` 内容重复。  
> **本轮所有 pose 写入必须落在 `events_male.json`，写进 `events.json` 无任何运行时效果。** 这是最容易踩的坑，已在 §7-R1 列为风险。

### 0.4 四角色事件分布（活跃文件实扫，scene 级）

| 角色 | 文件 | 角色发言 scene 数 | 已带 pose 字段 | 现有 pose 取值 |
|---|---|---|---|---|
| wanqing | `events_wanqing.json`（11 事件 / 559 行） | 29 | 2 | default ×2（:513 / :549） |
| wanqing | `events_special.json` | 15 | 0 | — |
| wanqing | `events_break.json` | 3 | 0 | — |
| xiaoxia | `events_xiaoxia.json`（10 事件 / 516 行） | 27 | 3 | casual（:20）/ default（:470）/ shy（:506） |
| xiaoxia | `events_special.json` | 12 | 0 | — |
| xiaoxia | `events_break.json` | 2 | 0 | — |
| yifei | `events_male.json`（18 事件 / 2321 行） | 26 | 2 | default ×2（:839 / :875） |
| yifei | `events_special.json` | 11 | 0 | — |
| yifei | `events_break.json` | 2 | 0 | — |
| zicheng | `events_male.json` | 26 | 2 | default ×2（:898 / :934） |
| zicheng | `events_special.json` | 11 | 0 | — |
| zicheng | `events_break.json` | 2 | 0 | — |

**yifei / zicheng 事件锚点行号（`events_male.json`）**：
`yf_001`:3 / `yf_002`:54 / `zc_001`:107 / `yf_walk`:161 / `yf_concert`:214 / `zc_team`:268 / `zc_injured`:321 / `yf_hallway`:375 / `zc_sideline`:428 / `yf_name_piece`:481 / `zc_gameday_eve`:567 / `yf_chat`:649 / `zc_chat`:710 / `friend_warning_addict_zc`:772 / `yf_cold_war_01`:827 / `yf_cold_recover_01`:862 / `zc_cold_war_01`:886 / `zc_cold_recover_01`:921

**`events_special.json` 锚点行号**：
`ng_first_wanqing`:107 / `ng_first_xiaoxia`:159 / `ng_first_yifei`:211 / `ng_first_zicheng`:263 / `special_valentine_wq`:705 / `special_grad_wq`:763 / `special_valentine_xx`:847 / `special_grad_xx`:923 / `special_valentine_yf`:1007 / `special_grad_yf`:1061 / `special_valentine_zc`:1148 / `special_grad_zc`:1202 / `west_lake_autumn_wanqing`:1418

**`events_break.json` 锚点行号**：
`break_winter_chapter_yifei`:392 / `break_spring_chapter_wanqing`:463 / `break_spring_chapter_xiaoxia`:533 / `break_autumn_chapter_zicheng`:815 / `break_autumn_companion`:1277

### 0.5 运行时解锁链路（`DialogueUI.gd`）

- `DialogueUI.gd:212-216`：`pose = scene.get("pose", "")`；**仅当 scene 显式写了 `pose` 且 speaker 非 player/空时**，才调用 `unlock_gallery("seen_<speaker>_<pose>")`。  
  → **省略 pose 的 scene 不会解锁任何 flag**，这正是"生成了立绘也解不开画廊"的根因。
- `DialogueUI.gd:219-240`：渲染时 `pose = scene.get("pose", "default")`，路径 `res://assets/sprites/<char>/<pose>`，查找顺序 `.ogv` → `.png` → `.jpg`。

### 0.6 画廊与好感解锁现状

- `GameManager.gd:292-347` `GALLERY_ITEMS` 当前 **43 条**（含 11 条长假记忆 + 3 条 player 类）。其中：
  - `wanqing` 仅 1 条（:312 default）、`yifei` 仅 1 条（:314 default）、`zicheng` 仅 1 条（:316 default）、`xiaoxia` 3 条（:308-310 default/casual/shy）。
- `CollectionManager.gd:48-63` `FAVOR_GALLERY_UNLOCKS`：
  ```
  yutong  : anim@50
  jingjing: casual@40
  xiaoxia : sport@30 / casual@60
  wanqing : serious@30 / casual@60
  ```
- ⚠️ **孤儿 flag 实证**：`seen_xiaoxia_sport` / `seen_wanqing_serious` / `seen_wanqing_casual` 这 3 个 flag 会被好感度逻辑置真，但 `GALLERY_ITEMS` 里**没有任何条目引用它们** → 达标后玩家既看不到卡片、也无资产可展示。本 GDD §4 一并修复。
- ⚠️ **命名不一致**：`GameManager.gd:314` 把 `yifei` 标为「谢怡菲」，而 `characters.json` 与全部事件文本为「**沈逸飞**」。新增条目一律用「沈逸飞」，并建议顺手修正 :314（见 §7-R5）。

### 0.7 质量基线（补全前）

`python scratch/verify_pose_assets.py` 实跑结果：

```
total (speaker,pose) refs: 385
RESOLVED (asset exists) : 385
MISSING (no asset)      : 0
'upset' refs remaining  : 3
```

> ⚠️ 该脚本 `EVENT_FILES`（`scratch/verify_pose_assets.py:5-9`）只含 **8 个文件**，**漏扫 `events_break.json` 与 `events_life.json`**。本轮 casual 接入点全部落在 `events_break.json`，**必须先补齐脚本清单**，否则质量门形同虚设（§6-QG0）。

---

## §1 补全矩阵（10 张）· 逐 Pose 语义定义

> 用途：给 art-director 写提示词的语义锚点。每条含【情绪】【典型场景】【身体语言】【禁止事项】。  
> 全部沿用 `design/art_spec_characters.md` §1 统一风格（日系赛璐璐 / 全身 / 5.5–6.5 头身 / 透明底 / 2048²）。

### 1.1 苏晚晴 wanqing（文艺委员 · 黑长直 · 紫灰瞳 · 主题色 `#a78bfa`）

| # | pose | 情绪定义 | 典型场景 | 身体语言 | 禁止 |
|---|---|---|---|---|---|
| 1 | `shy` | **被窥见内心的慌乱**——不是娇羞，是"手稿被人看到"的防御性羞赧 | 湖边合上本子、白色情人节递书、毕业前夜"只给你看" | 双手抱本子挡在胸前 / 用书半遮下半脸，耳尖泛红，视线下垂偏移 45° | 不要甜系笑容、不要飞吻手势 |
| 2 | `serious` | **创作者的专注与叩问**——冷静、思辨，眼神有分量 | 图书馆推荐书、追问"不完美结局值不值得写" | 正面站姿，一手执笔或书脊，另一手垂落；眉心极轻蹙，直视镜头 | 不要愤怒表情、不要抱臂对抗姿 |
| 3 | `casual` | **假期的松弛与柔和**——校服卸下后的另一面 | 春假桃林写生、秋假湖边写秋日 | 米白/藕紫针织开衫 + 长裙，肩挎帆布包，手持速写本；重心一侧，微笑幅度小 | **不得出现校服元素**（校徽/领带/百褶校裙） |

### 1.2 沈逸飞 yifei（音乐课代表 · 小提琴 · 清冷 · 主题色 `#5b9fd4`）

| # | pose | 情绪定义 | 典型场景 | 身体语言 | 禁止 |
|---|---|---|---|---|---|
| 4 | `shy` | **冷面下的破绽**——罕见的不自然，克制的动摇 | "加油……不必要。但，谢谢你来"、"曲子还没名字，你来定？" | 琴与弓垂在身侧，头微侧、视线避开，耳尖薄红，唇线绷紧后微松 | 不要大幅挠头（那是 jingjing_m 的动作语汇）、不要咧嘴笑 |
| 5 | `serious` | **演奏中的入定**——全副心神在音乐上，不看人 | 赛前反复练同一段、为你拉完整版、毕业前夜最后一曲 | 标准演奏姿：琴架肩、弓落弦、下颌压琴托，眼半阖或看向弦上 | 不要面向观众"表演式"微笑 |
| 6 | `casual` | **校外的放低戒备**——寒假影院、围巾与保温杯 | 冬夜影院门口、散场雪中 | 深蓝大衣 + 灰针织 + 围巾，一手抱保温杯，肩上落雪；表情比平时软一度 | **不得出现校服元素**；不必带琴盒（可选） |

### 1.3 周子诚 zicheng（篮球队长 · 虎牙 · 阳光 · 主题色 `#4caf8a`）

| # | pose | 情绪定义 | 典型场景 | 身体语言 | 禁止 |
|---|---|---|---|---|---|
| 7 | `shy` | **豪爽外壳裂开一条缝**——被戳中心事的窘迫 | "你别这么担心，我会……不好意思"、"那以后我打给你看" | 一手抓后脑勺/摸头，另一手拎球，身体半侧，脸颊红、虎牙半露的尴尬笑 | 不要低头默然（那是 beichen 语汇） |
| 8 | `serious` | **认真起来的队长**——收起笑容，直视，带压迫感的关心 | 手腕缠绷带说"要休息两周"、赛前夜直视问"你会来吗"、夺手机劝阻 | 正面站定，眉压低，一手护腕/叉腰；篮球夹在腋下 | 不要凶狠瞪眼（是关心不是发怒） |
| 9 | `casual` | **秋假的闲晃**——桂花林、纸袋点心 | 秋假桂花林章节 | 连帽卫衣 + 运动外套 + 牛仔裤，一手拎纸袋，笑得没心没肺 | **不得出现校服元素** |

### 1.4 林小夏 xiaoxia（体育系 · 爽朗 · 主题色 `#4caf8a`）

| # | pose | 情绪定义 | 典型场景 | 身体语言 | 禁止 |
|---|---|---|---|---|---|
| 10 | `sport` | **赛场上的燃**——汗水、喘息、赢/输都全力以赴 | 短跑约战、运动会冲线、联赛惨败后抱膝 | 校队运动服（深蓝速干短袖 + 白边运动短裤 + 护腕 + 跑鞋），马尾扎高、额发被汗贴住；一手叉腰一手抱球或比"第一" | **不得穿校服/便服**；不要静态站桩，要有运动余韵 |

> **风格统一硬约束（xiaoxia）**：已有 `default/casual/shy` 三张为最终资产，`sport` 必须与之同发型（同马尾高度/刘海分缝）、同瞳色、同头身比。生成时**必须以 `assets/sprites/xiaoxia/casual.png` 为 reference**，而非通用锚点（见 §7-R4）。

---

## §2 美术规格与管线

### 2.1 角色设定复用

全部复用 `design/art_spec_characters.md`：
- §1.1 画风锚定 / §1.2 西湖中学校服款式（女生：藏青西装外套+酒红滚边+盾形校徽+红蓝斜纹领带+蓝灰格百褶裙；男生：同款外套+深灰西裤）
- §1.3 尺寸格式：PNG / RGBA / 2048×2048 / 8-bit
- §2.2 储备角色视觉特征（wanqing 黑长直紫灰瞳抱书；yifei 黑发垂眸持琴；zicheng 黑发虎牙持球）
- §3.1 提示词结构：`[风格锚定] + [角色身份/外形] + [表情与姿态] + [技术要求]`，技术后缀原样复用
- §3.2 参考图：女生首选 `assets/sprites/jingjing/default.png`；男生画风同样以 `jingjing/default.png` 主导（现有男生 `.jpg` 仅作校服款式辅助，**不作画风参考**）

> ⚠️ `casual` 三张是**便服**，不套用校服款式段落，改用 §1 各角色的便服描述；技术后缀不变。

### 2.2 绿幕生产管线（复用 `design/art_generation_overview.md`）

```
① ImageGen 单张串行生成（禁止并行，避免覆盖 bug）
   背景请求：纯绿幕 #00FF00（不要请求 transparent，工具会返回棋盘格+水印）
        ↓
② scratch/matte_sprite.py 后处理
   · 绿通道主导判定  (G > R + margin) & (G > B + margin) → 背景掩码
   · cv2.morphologyEx(open/close) 去噪点
   · cv2.GaussianBlur 边缘抗锯齿
   · cv2.inpaint (TELEA) 修复背景区，擦除右下角水印残留
   · PIL LANCZOS 放大 → 2048×2048
        ↓
③ 落位 assets/sprites/<char>/<pose>.png   （RGBA 透明 PNG）
        ↓
④ Godot 侧自动生成 .import（首次运行编辑器时）
```

### 2.3 命名与落位表（10 张）

| # | 角色 | pose | 落地路径 | 参考图（reference） |
|---|---|---|---|---|
| 1 | wanqing | shy | `assets/sprites/wanqing/shy.png` | `assets/sprites/jingjing/shy.png` |
| 2 | wanqing | serious | `assets/sprites/wanqing/serious.png` | `assets/sprites/jingjing/serious.png` |
| 3 | wanqing | casual | `assets/sprites/wanqing/casual.png` | `assets/sprites/jingjing/default.png` |
| 4 | yifei | shy | `assets/sprites/yifei/shy.png` | `assets/sprites/jingjing/shy.png` |
| 5 | yifei | serious | `assets/sprites/yifei/serious.png` | `assets/sprites/beichen/serious.png` |
| 6 | yifei | casual | `assets/sprites/yifei/casual.png` | `assets/sprites/beichen/default.png` |
| 7 | zicheng | shy | `assets/sprites/zicheng/shy.png` | `assets/sprites/jingjing_m/shy.png` |
| 8 | zicheng | serious | `assets/sprites/zicheng/serious.png` | `assets/sprites/jingjing_m/default.png` |
| 9 | zicheng | casual | `assets/sprites/zicheng/casual.png` | `assets/sprites/jingjing_m/default.png` |
| 10 | xiaoxia | sport | `assets/sprites/xiaoxia/sport.png` | **`assets/sprites/xiaoxia/casual.png`（强制）** |

> 命名铁律：全小写 `<pose>.png`；目录 `<char_id>`（与 `characters.json` id 完全一致，注意 `jingjing_m` 带下划线）。  
> 本轮**不覆盖**任何已存在文件；`wanqing/yifei/zicheng` 的 `default.jpg` 原样保留（用户决策 ②）。

---

## §3 事件接入点（Pose 写入清单）

### 3.0 接入原则（红线）

| 编号 | 原则 | 理由 |
|---|---|---|
| P-1 | **只加 `pose` 键，不动任何既有键**（text/choices/next/affDelta/emoji 全部原样） | 保证叙事与数值零回归 |
| P-2 | **初见事件保持 default**（`sq_001` / `xx_001` / `yf_001` / `zc_001` / 全部 `ng_first_*`） | 首因印象必须是标准校服形象；NG+ 初见同理 |
| P-3 | **不改已有 `pose` 值**（wq_cold_war_01、xx_001[1]、yf_cold_war_01 等 9 处） | 用户决策 ②：只加不改 |
| P-4 | **`casual`（便服）只写在假期章节事件（`events_break.json`）** | 同一事件内校服↔便服切换会造成换装穿帮；假期场景天然合理 |
| P-5 | **同一事件内 pose 切换只允许"表情"层级**（default↔shy↔serious↔sport），不跨"服装"层级 | 同 P-4 |
| P-6 | **一律写进活跃文件**：`events_wanqing.json` / `events_xiaoxia.json` / `events_male.json` / `events_special.json` / `events_break.json`。**`events.json` 一个字都不要动** | §0.3：该文件不被加载 |

### 3.1 苏晚晴 wanqing —— 9 个接入点

| 优先级 | 文件 | 事件 id（起始行） | scene idx | 触发文本片段 | 建议 pose |
|---|---|---|---|---|---|
| P1 | events_wanqing.json | `sq_002`（:107） | [3]（:146） | 「（慌忙合上本子，耳朵红）……这个不给人看的。」 | **shy** |
| P1 | events_special.json | `special_valentine_wq`（:705） | [4] | 「（沉默三秒，用书架挡住脸）……只是觉得你会喜欢。」 | **shy** |
| P1 | events_special.json | `special_grad_wq`（:763） | [3] | 「（耳尖红了，声音很小）……只给你看。」 | **shy** |
| P1 | events_wanqing.json | `wq_book`（:160） | [3]（:199） | 「（想了很久，从第三排抽出一本）……这本。」 | **serious** |
| P1 | events_wanqing.json | `wq_readback`（:329） | [3]（:368） | 「……你是第一个提那段的。那是我最喜欢的一页。」 | **serious** |
| P1 | events_wanqing.json | `wq_writing`（:382） | [2]（:405） | 「……如果早就注定了一个不完美的结局，这个故事还值得被写出来吗？」 | **serious** |
| P1 | events_break.json | `break_spring_chapter_wanqing`（:463） | [1] | 「来了。（拍拍身边）坐吧，这儿光线最好。」 | **casual** |
| P1 | events_break.json | `break_spring_chapter_wanqing`（:463） | [5] | 「我写了个关于春天的故事……主角的名字，我想好了。」 | **casual** |
| P1 | events_break.json | `break_autumn_companion`（:1277） | [1] | 「主角……还没有名字。也许，等我想好了，第一个告诉你。」 | **casual** |
| P2（可选） | events_wanqing.json | `wq_publish`（:267） | [2]（:301） | 「（抬头，眼睛里有些不一样的东西）……你看了？」 | shy |
| P2（可选） | events_special.json | `west_lake_autumn_wanqing`（:1418） | [4] | 「……在写一个关于秋天的故事。主角还没名字。」 | serious |

**可达性**：shy 最早于 `sq_002`（minAff 25）触达；serious 最早于 `wq_book`（minAff 8）触达；casual 于春假章节（minAff 30）触达。三者均先于/等于好感阈值，无死锁。

### 3.2 沈逸飞 yifei —— 8 个接入点

| 优先级 | 文件 | 事件 id（起始行） | scene idx | 触发文本片段 | 建议 pose |
|---|---|---|---|---|---|
| P1 | events_male.json | `yf_concert`（:214） | [4]（:260） | 「……（第一次有一点点不自然）加油……不必要。但，谢谢你来。」 | **shy** |
| P1 | events_male.json | `yf_name_piece`（:481） | [7]（:553） | 「（眼底罕见地闪过一丝紧张）……还没起名字。……你来定？」 | **shy** |
| P1 | events_special.json | `special_valentine_yf`（:1007） | [3] | 「（转身去收琴，声音很平）……写了很久。」 | **shy** |
| P1 | events_male.json | `yf_concert`（:214） | [3]（:254） | 「（停顿，然后再次举起弓——这次拉得格外认真）」 | **serious** |
| P1 | events_male.json | `yf_name_piece`（:481） | [3]（:521） | 「（琴弓落下，旋律流淌——比初听时更长了……）」 | **serious** |
| P1 | events_special.json | `special_grad_yf`（:1061） | [3] | 「（举弓，拉了起来——是那首以你名字命名的曲子）」 | **serious** |
| P1 | events_break.json | `break_winter_chapter_yifei`（:392） | [1] | 「（在影院门口抱着保温杯）来得正好，开场前三分钟。」 | **casual** |
| P1 | events_break.json | `break_winter_chapter_yifei`（:392） | [5] | 「（雪花落在他肩头）下次……还一起看吗？」 | **casual** |
| P2（可选） | events_male.json | `yf_hallway`（:375） | [3]（:414） | 「……你听得很仔细。（低头）……谢谢你告诉我。」 | shy |
| P2（可选） | events_male.json | `yf_002`（:54） | [4]（:99） | 「……习惯了。清醒一点，才能拉出想拉的音。」 | serious |

> 注意 `yf_concert` 内 [3]=serious / [4]=shy 属两条互斥分支（choices 分别 next→3 / next→4），玩家单次只见其一，**不构成同事件内表情跳变**，设计上成立。`yf_name_piece` 的 [3]（演奏中 serious）→ [7]（曲终 shy）是同一路径内的合理情绪推进，符合 P-5。

**可达性**：serious/shy 最早于 `yf_concert`（minAff 35）触达；casual 于寒假章节（minAff 30）触达。

### 3.3 周子诚 zicheng —— 8 个接入点

| 优先级 | 文件 | 事件 id（起始行） | scene idx | 触发文本片段 | 建议 pose |
|---|---|---|---|---|---|
| P1 | events_male.json | `zc_injured`（:321） | [3]（:361） | 「……你别这么担心，我会……不好意思。」 | **shy** |
| P1 | events_male.json | `zc_sideline`（:428） | [4]（:473） | 「……你喜欢看我打？（摸头）……那以后我打给你看。」 | **shy** |
| P1 | events_male.json | `zc_gameday_eve`（:567） | [7]（:641） | 「（露出虎牙）……废话，当然想啊！（摸后脑勺）」 | **shy** |
| P1 | events_male.json | `zc_injured`（:321） | [4]（:367） | 「（皱了皱眉）……医生说要休息两周。（苦笑）」 | **serious** |
| P1 | events_male.json | `zc_gameday_eve`（:567） | [4]（:613） | 「（破天荒没有立刻接话）……你明天会来现场吗？」 | **serious** |
| P1 | events_male.json | `friend_warning_addict_zc`（:772） | [2]（:805） | 「（一把夺过你的手机，皱眉）再这样下去你人都傻了！」 | **serious** |
| P1 | events_break.json | `break_autumn_chapter_zicheng`（:815） | [1] | 「（靠在桂树下，手里拎着纸袋）来啦！趁热……」 | **casual** |
| P1 | events_break.json | `break_autumn_chapter_zicheng`（:815） | [5] | 「下个秋天……还一起晃吗？（手却攥紧了纸袋）」 | **casual** |
| P2（可选） | events_special.json | `special_valentine_zc`（:1148） | [3] | 「……也不是每个人都给的，就你。」 | shy |
| P2（可选） | events_special.json | `special_grad_zc`（:1202） | [3] | 「废话，我了解你。（难得认真）……我一直都了解你。」 | serious |

> `zc_injured` [3]/[4] 与 `zc_gameday_eve` [4]/[7] 均为分支互斥或"沉默→释然"的合理推进。

**可达性**：shy/serious 最早于 `zc_sideline`（minAff 12）/`friend_warning_addict_zc`（minAff 10 + minAddict 50）触达；casual 于秋假章节（minAff 30）触达。

### 3.4 林小夏 xiaoxia —— 4 个接入点（sport）

| 优先级 | 文件 | 事件 id（起始行） | scene idx | 触发文本片段 | 建议 pose |
|---|---|---|---|---|---|
| P1 | events_xiaoxia.json | `xx_002`（:58） | [1]（:76） | 「呼——爽！喂，要不要来比试一下短跑？」 | **sport** |
| P1 | events_xiaoxia.json | `xx_sports_day`（:168） | [1]（:187） | 「（喘着气）……看见了吗？！（比了个第一）」 | **sport** |
| P1 | events_xiaoxia.json | `xx_lose`（:328） | [2]（:363） | 「……你难道不打算说点『下次一定会更好』之类的安慰话吗？」 | **sport** |
| P1 | events_xiaoxia.json | `xx_lose`（:328） | [5]（:389） | 「……无论如何，谢谢你能来陪我。」 | **sport** |
| P2（可选） | events_xiaoxia.json | `xx_teach`（:275） | [1]（:293） | 「没事，重来！我教你。」 | sport |
| P2（可选） | events_xiaoxia.json | `xx_chat`（:397，repeatable） | [2]/[3] | 「……谢啦！刚好渴了。」 | sport（repeatable，解锁保底） |

> `xx_lose` 内 [2]→[3]→[5] 均为同一联赛场景，统一 sport 无穿帮。`xx_001[1]` 现为 `casual`（既有值，P-3 不动），但语义上操场踢球更应是 sport —— **列为打磨期候选修正，本轮不动**（§7-R6）。

**可达性**：`xx_002` minAff 15 < 好感阈值 sport@30 → 事件路径先于好感路径解锁，双保险。

### 3.5 接入点汇总

| 角色 | shy | serious | casual | sport | P1 小计 | P2 备选 |
|---|---|---|---|---|---|---|
| wanqing | 3 | 3 | 3 | — | **9** | 2 |
| yifei | 3 | 3 | 2 | — | **8** | 2 |
| zicheng | 3 | 3 | 2 | — | **8** | 2 |
| xiaoxia | — | — | — | 4 | **4** | 2 |
| **合计** | 9 | 9 | 7 | 4 | **29** | 8 |

**改动量**：29 个 scene 各新增 1 行 `"pose": "<value>",`，涉及 5 个 JSON 文件、13 个事件。零删除、零改写。

---

## §4 GALLERY_ITEMS 更新（新增 10 条：43 → 53）

在 `GameManager.gd` `const GALLERY_ITEMS` 中，于对应角色注释块下追加。**flag 格式统一 `seen_<char>_<pose>`**，与 `DialogueUI.gd:215` 自动解锁完全一致。

```gdscript
    # ── 苏晚晴（wanqing）──────────────────────────────── 追加于 :312 之后
    { "char": "wanqing",      "pose": "shy",      "label": "苏晚晴·羞涩",    "hint": "在对话中展示「苏晚晴·羞涩」立绘时自动解锁",      "flag": "seen_wanqing_shy",     "bg": "res://assets/backgrounds/library.jpg" },
    { "char": "wanqing",      "pose": "serious",  "label": "苏晚晴·认真",    "hint": "与苏晚晴好感度达到30后解锁，或对话中展示时自动解锁",  "flag": "seen_wanqing_serious", "bg": "res://assets/backgrounds/library.jpg" },
    { "char": "wanqing",      "pose": "casual",   "label": "苏晚晴·便服",    "hint": "与苏晚晴好感度达到60后解锁（便服）",         "flag": "seen_wanqing_casual",  "bg": "res://assets/backgrounds/lakeside.jpg" },

    # ── 沈逸飞（yifei）────────────────────────────────── 追加于 :314 之后
    { "char": "yifei",        "pose": "shy",      "label": "沈逸飞·羞涩",    "hint": "在对话中展示「沈逸飞·羞涩」立绘时自动解锁",      "flag": "seen_yifei_shy",       "bg": "res://assets/backgrounds/music_room.jpg" },
    { "char": "yifei",        "pose": "serious",  "label": "沈逸飞·认真",    "hint": "在对话中展示「沈逸飞·认真」立绘时自动解锁",      "flag": "seen_yifei_serious",   "bg": "res://assets/backgrounds/music_room.jpg" },
    { "char": "yifei",        "pose": "casual",   "label": "沈逸飞·便服",    "hint": "在寒假章节展示「沈逸飞·便服」立绘时自动解锁",     "flag": "seen_yifei_casual",    "bg": "res://assets/backgrounds/cinema_bg.jpg" },

    # ── 周子诚（zicheng）──────────────────────────────── 追加于 :316 之后
    { "char": "zicheng",      "pose": "shy",      "label": "周子诚·羞涩",    "hint": "在对话中展示「周子诚·羞涩」立绘时自动解锁",      "flag": "seen_zicheng_shy",     "bg": "res://assets/backgrounds/snack_bar.jpg" },
    { "char": "zicheng",      "pose": "serious",  "label": "周子诚·认真",    "hint": "在对话中展示「周子诚·认真」立绘时自动解锁",      "flag": "seen_zicheng_serious", "bg": "res://assets/backgrounds/playground.jpg" },
    { "char": "zicheng",      "pose": "casual",   "label": "周子诚·便服",    "hint": "在秋假章节展示「周子诚·便服」立绘时自动解锁",     "flag": "seen_zicheng_casual",  "bg": "res://assets/backgrounds/holiday_autumn_osmanthus.jpg" },

    # ── 林小夏（xiaoxia）──────────────────────────────── 追加于 :310 之后
    { "char": "xiaoxia",      "pose": "sport",    "label": "林小夏·运动装",   "hint": "与林小夏好感度达到30后解锁，或对话中展示时自动解锁",  "flag": "seen_xiaoxia_sport",   "bg": "res://assets/backgrounds/playground.jpg" },
```

**校验点**：
1. 全部 `bg` 路径已对照 `assets/backgrounds/` 实扫存在（`library.jpg` / `lakeside.jpg` / `music_room.jpg` / `cinema_bg.jpg` / `snack_bar.jpg` / `playground.jpg` / `holiday_autumn_osmanthus.jpg`）✅
2. 本次一并修复 §0.6 的 3 个孤儿 flag（`seen_xiaoxia_sport` / `seen_wanqing_serious` / `seen_wanqing_casual`）—— 追加后它们首次拥有对应画廊卡片。
3. `yifei` label 统一为「**沈逸飞**」；建议同批修正既有 `GameManager.gd:314` 的「谢怡菲」笔误（**需用户点头**，见 §7-R5）。
4. 条目总数：**43 → 53**。画廊进度分母随之变化，`get_gallery_progress()` 无需改代码。

---

## §5 FAVOR_GALLERY_UNLOCKS 核对与建议

### 5.1 现有配置：**无需修改** ✅

| 角色 | 现有配置 | 补齐后是否可达 | 结论 |
|---|---|---|---|
| wanqing | `serious@30` | ✅ 资产 `wanqing/serious.png` 到位 + §4 新增画廊卡片 | **保持不动** |
| wanqing | `casual@60` | ✅ 资产 `wanqing/casual.png` 到位 + §4 新增卡片 | **保持不动** |
| xiaoxia | `sport@30` | ✅ 资产 `xiaoxia/sport.png` 到位 + §4 新增卡片 | **保持不动** |
| xiaoxia | `casual@60` | ✅ 早已可达 | 不动 |
| yutong `anim@50` / jingjing `casual@40` | — | ✅ | 不动 |

> 即：`pose_asset_manifest.md` §6-1 记录的"好感阈值指向无资产 pose"缺陷，**本轮 10 张立绘落地后自动闭环**，无需改一行解锁配置。

### 5.2 建议新增（yifei / zicheng）—— **待用户拍板**

沿用 wanqing 的 30/60 双档节奏，保持跨角色一致（避免"某角色更好解锁"的隐性主导路径）：

```gdscript
    "yifei": [
        { "threshold": 30, "flag": "seen_yifei_shy",       "label": "沈逸飞·羞涩" },
        { "threshold": 60, "flag": "seen_yifei_serious",   "label": "沈逸飞·认真" },
    ],
    "zicheng": [
        { "threshold": 30, "flag": "seen_zicheng_shy",     "label": "周子诚·羞涩" },
        { "threshold": 60, "flag": "seen_zicheng_serious", "label": "周子诚·认真" },
    ],
```

**设计说明**：
- 这两档是**兜底**而非主路径 —— 事件接入（§3.2/§3.3）已让 shy 最早在 minAff 12–35 触达。阈值存在的意义是"漏看分支的玩家也能集齐"。
- **casual 不设阈值**：casual 绑定假期章节（一年一次的强节点），若加阈值会削弱假期章节的独占奖励感（支柱：假期章节 = 关系里程碑）。—— 若用户希望与 wanqing/xiaoxia 的 `casual@60` 对齐，可加 `casual@75`，但会稀释章节价值，**不推荐**。
- 一致性检查：加完后 6 角色阈值分布 = yutong 50 / jingjing 40 / xiaoxia 30·60 / wanqing 30·60 / yifei 30·60 / zicheng 30·60 —— 无角色被显著优待，无主导策略。

**用户需拍板的 3 个选项**：
- **A（推荐）**：按上表加 yifei/zicheng 的 shy@30 + serious@60，casual 只走事件。
- **B**：只加 shy@30，serious 完全交给事件。
- **C**：不加任何阈值，yifei/zicheng 全靠事件解锁（最纯粹，但漏分支即漏收藏）。

---

## §6 命名 / 管线规范与质量门

### 6.1 规范清单

| 项 | 规范 |
|---|---|
| 文件名 | 全小写 `<pose>.png`，无版本号/无空格/无中文 |
| 目录 | `assets/sprites/<char_id>/`，`char_id` 严格等于 `characters.json` 的 id |
| 格式 | PNG，RGBA，8-bit/channel，2048×2048 |
| 透明度 | alpha 通道须同时含 0 与 255；角色轮廓外无绿色残留（H 值 60±20 像素占比 < 0.1%） |
| 水印 | 右下角必须已被 inpaint 清除 |
| pose 词表 | 仅 `default / shy / serious / casual / sport / study / upset / anim`，**不得自创新词**（新词 = 画廊 flag 断链） |
| flag | `seen_<char>_<pose>`，禁止大写、禁止连字符 |
| JSON 改动 | 仅新增 `"pose"` 键；缩进 2 空格，UTF-8 无 BOM，尾随逗号规范同文件既有风格 |

### 6.2 质量门（Definition of Done）

| # | 门禁 | 判定标准 | 执行者 |
|---|---|---|---|
| **QG0** | **先修校验脚本** | `scratch/verify_pose_assets.py:5-9` 的 `EVENT_FILES` 补入 `events_break.json` 与 `events_life.json`，与 `DataManager.gd:10-21` 的 10 文件完全对齐 | engineering |
| QG1 | 资产存在 | 10 个新路径全部存在，`verify_pose_assets.py` 输出 **MISSING = 0** | art-director |
| QG2 | 资产技术合格 | 10 张均 2048×2048 RGBA，alpha 含 0/255，无绿边、无水印（`scratch/check_new_sprites.py` 复用） | art-director |
| QG3 | **新 pose 全部被解析** | 脚本输出中，`(wanqing,shy)(wanqing,serious)(wanqing,casual)(yifei,shy)(yifei,serious)(yifei,casual)(zicheng,shy)(zicheng,serious)(zicheng,casual)(xiaoxia,sport)` **10 个组合各出现 ≥ 1 次且均 RESOLVED** | QA |
| QG4 | 引用总数不回归 | `total (speaker,pose) refs` 在补 QG0 前的口径下仍为 **385**（本轮只把既有 scene 的隐式 default 改为显式 pose，不新增 scene）；补 QG0 后总数会因纳入 break/life 而上升，**以新基线重新记录** | QA |
| QG5 | JSON 结构完好 | `python scripts/validate_events.py` 全绿；5 个被改文件 `json.load` 成功；事件数不变（wanqing 11 / xiaoxia 10 / male 18 / special 23 / break 不变） | QA |
| QG6 | 画廊编目一致 | `GALLERY_ITEMS` = 53 条；每条 `flag` 都能被某条 `DialogueUI` 路径或 `FAVOR_GALLERY_UNLOCKS` 置真（**孤儿 flag = 0**） | QA |
| QG7 | 运行时抽验 | 启动游戏，走 `xx_002` / `zc_sideline` / `wq_book` 三条最低门槛路径，确认立绘切换可见且画廊卡片点亮 | QA |
| QG8 | 存量存档兼容 | `GameManager._retroactive_gallery_check()`（:379-381）对老存档补扫，确认已达阈值的老档能补解锁 | engineering |

> 建议在 QG3 补一段断言脚本（`scratch/verify_new_poses.py`），把 10 组合硬编码成 expected set，缺一即 exit 1。

---

## §7 已知风险与取舍

| # | 风险 | 影响 | 缓解 / 取舍 |
|---|---|---|---|
| **R1** | **`events.json` 陷阱**：该文件含同 id 的 yifei/zicheng 事件但**不被 DataManager 加载** | 若把 pose 写进 events.json，改了等于没改，且后续排查成本极高 | §3-P6 已硬性规定写入 `events_male.json`；建议顺手在 `events.json` 顶部加注释或改名 `events.legacy.json`（**需用户拍板，本轮不做**） |
| **R2** | **ImageGen 代理不可用（当前 502）** | 10 张生成无法开工，本 GDD 只能停在规划 | 本轮交付纯规格；生成步骤挂起，待代理恢复由 art-director 按 §2 串行执行。§3/§4/§5 的 JSON/GD 改动**可与生成解耦并行**（资产未到位时 `DialogueUI` 会 fallback 到找不到贴图，故建议改动与资产同批合入，不要提前上线） |
| **R3** | **同角色内画风撕裂**：`wanqing/yifei/zicheng` 的 `default.jpg` 是 1024 白底厚涂旧图，新 3 pose 按赛璐璐锚点生成后，同一角色 default 与其余 pose 会明显不是一套画 | 玩家在画廊里并排看到 4 张卡，第 1 张风格突兀 | 三选一，**待用户拍板**：<br>**A（本轮方案）** 只补 3 pose，default 保持不动，撕裂问题记入打磨阶段；<br>**B** 顺带重制 3 张 default（+3 张，总量 13 张，超出决策 ① 范围）；<br>**C** 反向做：新 pose 迁就旧 default 的厚涂白底风（**不推荐**，会拉低整体品控） |
| **R4** | **xiaoxia sport 与既有 casual/shy 不统一**：sport 是唯一插进"已有成套资产"角色的新图，发型/瞳色/头身比稍偏就极显眼 | 四连图并排时 sport 像另一个人 | §2.3 强制以 `xiaoxia/casual.png` 作 reference；QG2 增加"与 casual 并排目检"人工卡口；若两次生成仍偏，降级为局部重绘 |
| **R5** | **yifei 名称不一致**：`GameManager.gd:314` 写「谢怡菲」，`characters.json` 与全部文本为「沈逸飞」 | 画廊里出现玩家没见过的名字 | 新增 3 条一律用「沈逸飞」；既有 :314 的修正**需用户点头**（属"动已有内容"，与决策 ② 边界擦边） |
| **R6** | **`xx_001[1]` 现值 `casual` 语义存疑**：操场踢足球场景穿便服 | 轻微违和 | 决策 ② 下本轮不动；列入打磨阶段候选（改为 sport 更贴切） |
| **R7** | **beichen 遮眼侧 / keke 蝴蝶结波点漂移** | 已知细节缺陷 | 用户决策 ②：本轮明确**不动**，留打磨阶段统一修图 |
| **R8** | **校验脚本漏扫 break/life**（§0.7） | casual 的 3 个接入点写完后校验脚本看不见，假绿 | QG0 设为**前置阻塞门**，必须先修脚本再验收 |
| **R9** | **画廊分母变化影响成就/进度** | 53 条后进度百分比下降，老玩家看到"倒退" | `get_gallery_progress()` 为动态计算，无硬编码分母；但建议 QA 在 QG7 顺带确认无成就系统按固定张数判定 |
| **R10** | 生成额度消耗 | 10 张 ImageGen 调用产生额度成本 | 生成前由主理人向用户明示并确认；本 GDD 阶段零消耗 |

**设计理论红线自检**：
- 主导策略：❌ 无 —— 本轮不引入任何数值/资源机制，pose 纯表现层；§5 阈值跨角色对齐，无"最优攻略角色"。
- 经济失衡：❌ 无 —— 不涉及金钱/道具/好感增量改动（29 处改动全部只加 `pose` 键）。
- 认知过载：❌ 无 —— 玩家侧无新学习成本；画廊 +10 卡属于渐进收集，不在同一屏爆发。
- 支柱漂移：⚠️ 轻微 —— casual 若加好感阈值会稀释"假期章节 = 关系里程碑"支柱，故 §5.2 明确不推荐给 casual 加阈值。

---

## §8 确认记录区（待用户签字）

| # | 待确认事项 | 选项 | 用户决定 | 签字/日期 |
|---|---|---|---|---|
| C-1 | §1 十条 pose 语义定义是否认可（尤其 wanqing shy「防御性羞赧」而非甜系娇羞） | 认可 / 需调整 | ☐ | |
| C-2 | §3 的 **29 个 P1 接入点**是否全量执行；8 个 P2 备选是否一并纳入 | 只做 P1 / P1+P2 / 自选 | ☐ | |
| C-3 | §3-P4「casual 只写在假期章节」的换装规则是否认可 | 认可 / 放宽 | ☐ | |
| C-4 | §4 的 **10 条新增画廊条目**（含 bg 配图）是否照此落地 | 认可 / 改 bg / 改文案 | ☐ | |
| C-5 | §4-3 是否顺手修正 `GameManager.gd:314`「谢怡菲」→「沈逸飞」 | 修 / 不修 | ☐ | |
| C-6 | §5.2 yifei/zicheng 好感阈值方案 | **A（推荐）** / B / C | ☐ | |
| C-7 | §7-R3 三角色 `default.jpg` 旧图撕裂处理 | **A（本轮不动，推荐）** / B（+3 重制） / C | ☐ | |
| C-8 | §6-QG0 是否同意先修 `verify_pose_assets.py` 的 EVENT_FILES 再验收 | 同意 / 另行处理 | ☐ | |
| C-9 | §7-R1 `events.json` 是否改名/加注释以防误改 | 改名 / 加注释 / 不动 | ☐ | |
| C-10 | 生成时机：ImageGen 恢复后是否立即由 art-director 执行 10 张（额度消耗） | 立即 / 待通知 | ☐ | |

---

## 附录 A · 执行顺序建议（供主理人排期）

```
① [本文件] 设计签字（§8 C-1 ~ C-10）
        ↓
② engineering: 修 verify_pose_assets.py EVENT_FILES（QG0，5 分钟，无依赖，可立即做）
        ↓
③ art-director: ImageGen 恢复后串行生成 10 张绿幕图 → matte_sprite.py → 落位（QG1/QG2）
        ↓                                   ↕ 可与 ④ 并行准备，但合入需同批
④ engineering: 写入 29 处 pose（5 文件）+ GALLERY_ITEMS ×10 + FAVOR_UNLOCKS（按 C-6 决定）
        ↓
⑤ QA: QG3 ~ QG9 全量跑 → 刷新 design/pose_asset_manifest.md 状态段
        ↓
⑥ 打磨阶段挂起项：beichen 遮眼侧 / keke 蝴蝶结 / 3 张旧 default 重制 / xx_001 casual→sport
```

## 附录 B · 本文件读盘来源

| 文件 | 用途 |
|---|---|
| `design/pose_asset_manifest.md` | 资产现状、缺口、解锁联动、已知不一致 |
| `design/art_generation_overview.md` | 绿幕管线、后处理步骤、已知局限 |
| `design/art_spec_characters.md` | 统一风格、校服款式、尺寸格式、提示词模板、储备角色规格 §2.2 |
| `scripts/events_wanqing.json` (559 行 / 11 事件) | wanqing 接入点 |
| `scripts/events_xiaoxia.json` (516 行 / 10 事件) | xiaoxia 接入点 |
| `scripts/events_male.json` (2321 行 / 18 事件) | yifei / zicheng 接入点（**活跃文件**） |
| `scripts/events.json` (5022 行 / 89 事件) | 仅作对照 —— **未被加载的历史文件** |
| `scripts/events_special.json` / `events_break.json` | 节日 / 假期章节接入点 |
| `scripts/DataManager.gd:10-21` | EVENT_FILES 加载清单 |
| `scripts/DialogueUI.gd:200-240` | pose 渲染与自动解锁链路 |
| `scripts/GameManager.gd:292-347` | GALLERY_ITEMS（43 条） |
| `scripts/CollectionManager.gd:48-63` | FAVOR_GALLERY_UNLOCKS |
| `scratch/verify_pose_assets.py` | 质量门脚本（当前 385 refs / 0 missing） |
| `scripts/characters.json` | 角色 id ↔ 中文名 ↔ 主题色 |

---

*文策渊（design-strategist）出品 · 纯规划文档，未生成任何立绘、未改动任何事件 JSON 或 GameManager。*
