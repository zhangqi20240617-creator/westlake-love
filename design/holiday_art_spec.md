# 长假特殊事件 · 美术规格书（Set-piece CG）

> **负责人**：林绘澄（art-director）
> **关联**：`design/holiday_events_design.md` §10 美术清单 / §11 事件清单 · `design/art_spec_characters.md`（角色立绘锚点） · `design/gallery_pose_patch.md`（画廊 pose 接线）
> **项目**：《西湖边的青春》· Godot 4.5 mobile · 1280×720 横屏 · 杭州西湖中学初中恋爱模拟 · 现言 / 校园恋爱画风
> **本文用途**：为 4 张长假 set-piece 背景 CG（chapter / kickoff 共用）+ 10 个画廊记忆缩略图（直接复用 4 张 CG）的美术生产规格。本文件**不触发生成**；图像生产由主理人另行按 §2 的 ImageGen 提示要点执行。
> **范围**：仅写规格，**不动任何 `.gd`、不生成任何图像文件**。

---

## 0. 阅读对象与决策一览

| 决策点 | 本规格决定 | 理由 |
|---|---|---|
| 画风 | 沿用**既有 backgrounds 目录的 painterly 中国风景插画风**（Ghibli / 新海诚式渲染光感），**不复用角色立绘的 anime cel-shaded 风** | 既有 17 张背景（lakeside 系列 / title_bg / snack_bar 等）已统一为 painterly；CG 作为背景板，须与既有 location 背景同框不穿帮 |
| 分辨率 | **1280 × 720（16:9 横屏）**，JPEG | 任务明确指定 16:9；与项目 viewport（`project.godot`: 1280×720, `canvas_items`+`expand`）原生匹配；故意偏离既有 1024×1024 方形规格，让 set-piece 满屏铺满（无上下黑边 / 两侧裁切） |
| 是否含角色 | **全部不含人物** | 角色由透明 PNG sprite 在 `DialogueUI` 上叠加；CG 只承载场景与情绪；避免 sprite 风格与 CG 风格混搭穿帮 |
| 是否含可读文字 | 仅允许**远景小型氛围性汉字**（灯笼/匾额，与 `lakeside_evening` / `title_bg` 一致），**禁止近景可读大段文字 / 霓虹招牌正文 / 水印** | 防止与对话气泡、UI 文字抢焦 |
| 是否追加 set-piece 角色专属立绘 | **v1 不追加**，复用角色 `emoji` 标识（👩‍🎓🌸📚⚽🎻🏀🌟）+ 已有 `<char>/default.png` sprite | 风险见 §6；v1 优先把 4 张 CG 落地，role 立绘作为可选打磨项 |

---

## 1. 美术方向总则（与现有资源对齐）

### 1.1 风格锚定（双轨制）

本项目美术实际存在**两种风格**：
1. **背景 / CG 风格**（本规格覆盖）：painterly 半写实中国风景插画。代表作：
   - `assets/backgrounds/lakeside_evening.jpg` —— 满月 + 飞檐亭 + 红灯笼 + 漂浮河灯 + 垂柳 + 远塔 + 水面倒影，**冷蓝夜空 ↔ 暖橙灯笼光**互补对比，是 4 张 CG 的最强锚点（4/10 章在 lakeside·evening 发生）。
   - `assets/backgrounds/title_bg.jpg` —— 樱花飘落 + 满月 + 远亭 + 水面小舟，浪漫梦幻范式。
   - `assets/backgrounds/lakeside_morning_sunny.jpg` —— 朝霞粉橙 + 雷峰塔 + 苏堤石桥 + 垂柳 + 远山薄雾，最适合 spring CG 复刻。
   - `assets/backgrounds/lakeside_rainy.jpg` —— 雨丝 + 油纸伞 + 石拱桥 + 雾山冷调，最适合 winter CG 的「雪」氛围移植。
2. **角色立绘风格**（**不**被本规格覆盖）：anime cel-shaded（`design/art_spec_characters.md` §1.1）。

**核心约束**：CG 是背景板，sprite 叠在 CG 之上。两种风格本来就有差异（painterly 背景 + cel-shaded 角色），但因为 sprite 透明 PNG 居中、CG 留出中央安全区，二者已被 DialogueUI 接受；继续遵守"CG 不画人物"即可维持视觉妥协。

### 1.2 分辨率与构图规则

| 项目 | 规格 | 说明 |
|---|---|---|
| 输出分辨率 | **1280 × 720 px**（16:9 横屏） | 任务硬性要求 |
| 格式 | **JPEG**（与既有 17 张背景统一） | 不用 PNG（无透明需求）；quality ≥ 90 |
| 构图安全区 | 中央偏下约 **720×560** 矩形为「角色 sprite 落位区」，**该区不放置主体细节**（远景可虚化） | 防止遮挡 sprite；保证背景 CG 满屏时不与 sprite 抢焦 |
| 地平线位置 | 上 1/3 线附近（黄金分割），中景桥/亭/树为主体，远景山/塔点缀 | 与 `lakeside_*` / `title_bg` 一致 |
| 画面边框 | 画面四角允许少量虚化或留白；中央偏上允许细碎元素（飘落花瓣 / 飞萤 / 雪花）作为动态氛围层 | 给 UI 浮层留呼吸空间 |
| 渲染层数 | 建议 ImageGen prompt 描述为 3 层：前景（飘落物 / 栏杆 / 树枝）/ 中景（桥 / 亭 / 摊 / 树）/ 远景（塔 / 山 / 月 / 城市灯火） | 利于生成稳定深度 |

### 1.3 季节色调总览（4 张 CG 色板一览）

| 季节 | CG 文件 | 主调色 | 关键辅助色 | 季节情绪关键词 |
|---|---|---|---|---|
| 冬 | `holiday_winter.jpg` | 冷靛蓝 / 雪白（主 60%） | 暖橙琥珀（灯笼光，30%）+ 远处屋檐暗红（10%） | 静谧、暖光留白、初雪、并肩 |
| 春 | `holiday_spring_outing.jpg` | 樱花粉 / 嫩柳绿（主 50%） | 晨光金 / 湖面浅蓝（30%）+ 远山雾蓝（20%） | 明亮、桃花、春风、初恋 |
| 夏 | `holiday_summer_trip.jpg` | 深青蓝 / 暗墨绿（主 55%） | 萤火暖黄点（25%）+ 远岸橘红夜市灯（20%） | 闷热夜风、萤火、河流灯、河灯 |
| 秋 | `holiday_autumn_osmanthus.jpg` | 金桂暖黄 / 焦糖橙（主 55%） | 湖面青绿（25%）+ 远山雾紫蓝（20%） | 桂花香、午后金光、落叶、纸笺 |

> **统一逻辑**：4 张主调沿"冬冷蓝 ↔ 春粉绿 ↔ 夏青蓝 ↔ 秋金黄"四季循环；远景始终保留西湖的"湖 + 远塔 + 远山"三件套，保证四张 CG 视觉一脉。

### 1.4 与现有 locations 背景的衔接

- **元素复用**：四张 CG 的"远塔（雷峰 / 保俶）""石桥 / 苏堤""垂柳""飞檐亭""水面倒影""灯笼"等元素，与 `lakeside_evening` / `lakeside_morning_sunny` / `lakeside_rainy` / `title_bg` / `lakeside_after_sunny` 高度重合；视觉一脉相承，玩家不会觉得是"贴图换了季节"。
- **构图延续**：四张 CG 均以**水 / 桥 / 远岸**为骨架，复用 `lakeside_evening` 的"前景虚物 + 中景建筑 + 远景月塔"三段式构图，便于在 chapter 切换时给玩家"同一地点、不同季节"的连续感。
- **不冲突原则**：四张 CG 的**远景**避免与既有 location 背景中的具体场景标识物冲突（如 `cinema_bg` 的影厅内景、`community.png` 的便利店招牌、`snack_bar.jpg` 的霓虹店招）；CG 是"户外 / 半户外"环境，不进入室内场景。

### 1.5 镜头语言与人物站位

- **镜头**：固定镜头（wide establishing shot）。无推拉摇移；CG 是一次性背景板，无视差。
- **角色立绘落位**：CG 中央偏下 720×560 安全区内可同时叠加 player + NPC 两张 sprite（间距约 280 px 居中）。NPC sprite 默认贴右、player 贴左（或按事件 `pose` 与对话位置调整）。
- **角色朝向**：NPC 立绘默认**面向镜头 / 微 3/4 侧身**，与已有 `default.png` 立绘朝向一致（朝向 = 玩家一侧），便于语义上"面向玩家"。

---

## 2. 4 张假期背景 CG · 构图 + 提示要点

> 每张含：① 用途定位 ② 构图 / 镜头 ③ 色板与光感 ④ 关键元素清单 ⑤ 是否含角色 / 站位 ⑥ 镜头语言 ⑦ **ImageGen 提示要点**（含参考图、构图锚点、风格后缀、负向提示）。
> 主理人执行 ImageGen 时，可按要点直接拼装英文 prompt；本规格不写完整 prompt（避免越权触发生成）。

---

### A. `res://assets/backgrounds/holiday_winter.jpg` —— 寒假·雪后断桥 / 糖水铺暖光

**A.1 用途定位**
寒假 set-piece 共享背景。覆盖 chapter：`break_winter_chapter_yutong`（lakeside·evening）/ `break_winter_chapter_jingjing`（off_campus_shop·after）/ `break_winter_chapter_yifei`（cinema·noon）。

**A.2 构图（1280×720 横屏）**
- **前景（下 1/8）**：石桥栏杆覆薄雪，栏杆雕花细节被雪覆盖呈柔软白线；左下角可挂一串小红灯笼（同 `lakeside_evening`），但被薄雪压住一半。
- **中景（画面 1/3–2/3）**：**断桥**（白堤 / 锦带桥式拱桥）横跨画面，桥面与栏杆有半融化的薄雪；**桥头或桥尾设一间暖光糖水铺 / 小亭摊**：飞檐 + 2–3 串红灯笼 + 暖橙色灯光从门窗透出，铺前可挂"糖水""桂花酒酿"小型匾额（仅氛围，远景小型字）。桥面留出中央安全区。
- **远景（画面上 1/3）**：深靛蓝夜空 + 满月（位置偏右上，月相比 `lakeside_evening` 更满、更亮，月光在雪面投冷蓝光）；远山雾蓝色剪影 + 远处城市灯火稀疏点（暖黄）。
- **动态层**：零星雪花从画面上 1/3 缓缓飘落（呈小而稀疏白点，**非暴风雪**）。

**A.3 色板**
- 主 60%：冷靛蓝（#0f1b3d / #1a2950） + 雪白（#f0f4fa 偏冷白）
- 辅 30%：暖橙琥珀（#ffb86b / #ff8a4c，糖水铺灯光 + 灯笼）
- 点缀 10%：远塔暗金 + 屋檐酒红（#8b1f1f）

**A.4 关键元素清单**
✅ 必备：薄雪、断桥、暖光糖水铺（亭摊型）、红灯笼、满月、雪点飘落
✅ 强烈建议：远塔剪影（保俶塔或雷峰塔二选一，建议雷峰，更冬夜感）
❌ 禁止：人物（任何站姿 / 剪影）、近景可读文字（铺招只允许 1–2 个氛围小字）、雨（与季节冲突）、樱花（春季物）

**A.5 是否含角色及站位**
**不含**。NPC 与 player 由 sprite 叠加在中央安全区（720×560）。

**A.6 镜头语言**
wide establishing shot / 微微俯视（视平线略高于桥面，强调桥的延展）/ 黄金时刻（满月 + 灯笼暖光双光源）。情绪锚：糖水铺暖光 = "寒假里的避风港"。

**A.7 ImageGen 提示要点**
```
【参考图（强约束）】
- D:/zkgame/assets/backgrounds/lakeside_evening.jpg      // 构图 + 灯笼 + 满月锚
- D:/zkgame/assets/backgrounds/lakeside_rainy.jpg         // 冷蓝主调 + 拱桥锚

【构图锚点（按顺序）】
- horizontal landscape 1280x720, 16:9
- camera: wide establishing shot, slightly elevated eye level, looking down at a snow-covered arched bridge spanning the middle third of the frame
- foreground: stone bridge railing dusted with fresh snow, soft white accumulation on carvings; one small cluster of red lanterns at lower-left, half-covered by snow
- midground: arched stone bridge (Duanqiao / West Lake Broken Bridge) with thin snow layer; on one end of the bridge, a small traditional sweet-soup shop pavilion with red hanging lanterns and warm orange light spilling from doors/windows; small wooden sign with Chinese characters (atmospheric, not readable); keep central 720x560 area clean of large objects
- background: deep indigo night sky, large luminous full moon at upper-right, faint blue-tinted moonlight on snow; distant blue-mist mountains; sparse warm city lights on far shore; a pagoda silhouette (Leifeng)
- dynamic layer: gentle sparse snowfall, small white flakes drifting down across upper third

【风格后缀（强制）】
painterly Chinese landscape illustration, Ghibli/Makoto Shinkai atmospheric lighting style, soft cel-soft shading on architecture, semi-realistic, high detail on lantern light and snow texture, cinematic color grading, dreamy winter night mood, 1280x720 landscape, no characters, no watermark, no neon signs

【负向提示（必须）】
(no humans, no people, no silhouettes, no readable large text, no neon signage, no spring blossoms, no cherry petals, no rain, no watermark, no signature, no logo)
```

---

### B. `res://assets/backgrounds/holiday_spring_outing.jpg` —— 春假·苏堤桃花 / 攀岩馆

**B.1 用途定位**
春假 set-piece 共享背景。覆盖 chapter：`break_spring_chapter_wanqing`（lakeside·evening）/ `break_spring_chapter_xiaoxia`（community·after）/ `break_spring_chapter_beichen`（cinema·noon）。

**B.2 构图**
- **前景（下 1/8）**：苏堤石栏旁一枝低垂的桃花枝（粉色桃花盛开），花瓣零星落入水；底部有少量青苔与小花。
- **中景（1/3–2/3）**：**苏堤弯曲石桥**（与 `lakeside_morning_sunny` 同构图骨架：S 形弯堤 + 矮石栏），桥面有少量被风吹落的桃花瓣；堤两侧桃树成行（粉色花海）；**画面右侧约 15% 远处可点缀一个彩色户外攀岩墙**（户外攀岩馆一角 / 高度约 10–15 米，块状彩色把手清晰可辨，但只占画面边缘小区域，**不抢**桃花主体）。
- **远景（上 1/3）**：晨光 / 上午金色阳光（视平线低，太阳位于左上后方，形成顺光）；雷峰塔在远岸；薄雾中的远山；湖面有 1–2 艘游船小剪影。
- **动态层**：桃花瓣从画面上方缓缓飘落（粉色小瓣，比 `title_bg` 樱花更稀疏、瓣更大）。

**B.3 色板**
- 主 50%：樱花粉（#ffd1dc / #f9b6c4）+ 嫩柳绿（#a8d5a8）
- 辅 30%：晨光金（#ffd98a）+ 湖面浅蓝（#a8c8e0）
- 点缀 20%：远山雾蓝（#6e88a8）+ 攀岩墙小块原色（蓝/黄/绿，不饱和）

**B.4 关键元素清单**
✅ 必备：苏堤弯桥、桃花枝（前景特写）、雷峰塔、晨光、飘落桃花瓣
✅ 强烈建议：攀岩墙小元素（呼应 spring chapter xiaoxia "攀岩馆"子场景，但不主导画面）
❌ 禁止：人物、近景大段文字、霓虹招牌、灯笼（春主题过暖物）、雪 / 萤火 / 桂花

**B.5 是否含角色及站位**
**不含**。NPC + player 由 sprite 叠加在中央安全区。

**B.6 镜头语言**
wide establishing shot / 视平线低（强调桃花枝前景）/ 晨光暖调 / 情绪锚：桃花前景 = "春天故事的封面"。

**B.7 ImageGen 提示要点**
```
【参考图（强约束）】
- D:/zkgame/assets/backgrounds/lakeside_morning_sunny.jpg    // 苏堤 + 远塔 + 晨光主锚
- D:/zkgame/assets/backgrounds/title_bg.jpg                     // 飘落花瓣氛围锚（参照但换成桃花）

【构图锚点】
- horizontal landscape 1280x720, 16:9
- camera: wide establishing shot, low eye level (just above stone railing), looking across a curving Su Causeway stone bridge
- foreground: a low-hanging peach blossom branch in the bottom-left or upper-left corner, dense pink peach flowers (not cherry blossoms), a few fallen petals on stone railing; small green moss and wildflowers at base
- midground: S-shaped curving stone causeway (Su Di) crossing the middle third of the frame, peach trees in full bloom lining both sides of the causeway, scattered pink petals on the stone path; on the far right edge (about 15% of frame), a small partial view of an outdoor climbing wall with colored holds (red/yellow/green blocks) — must NOT dominate; keep central 720x560 area clean
- background: warm golden morning sunlight from upper-left, Leifeng Pagoda silhouette across the lake, soft misty blue mountains, calm lake with 1-2 small tour boat silhouettes
- dynamic layer: gentle peach petals drifting down from upper third

【风格后缀】
painterly Chinese landscape illustration, Ghibli/Makoto Shinkai atmospheric style, warm spring morning light, soft pastel palette, semi-realistic, high detail on peach blossom texture and water reflections, cinematic, dreamy spring mood, 1280x720 landscape, no characters, no watermark

【负向提示】
(no humans, no people, no silhouettes, no readable large text, no neon signs, no red lanterns, no snow, no fireflies, no osmanthus, no autumn leaves, no watermark)
```

---

### C. `res://assets/backgrounds/holiday_summer_trip.jpg` —— 暑假·萤火夜跑 / 夜市

**C.1 用途定位**
暑假 set-piece 共享背景。覆盖 chapter：`break_summer_chapter_keke`（lakeside·evening）/ `break_summer_chapter_zijun`（community·after）。

**C.2 构图**
- **前景（下 1/6）**：湖边**芦苇荡**（高约画面 1/5，密集细长，深绿偏墨色）；芦苇顶端有几只萤火虫小亮点（萤火点在画面下 1/3 开始出现，往上渐疏）。
- **中景（1/3–2/3）**：开阔的西湖湖面，平静微反光；远处对岸可见**夜市 / 摊贩群**：一排挂灯笼的小摊（橙红 + 暖黄 + 个别霓虹小色点），轮廓清晰但比冬 CG 的糖水铺更"群聚"，营造"夜市人声"的氛围层；可隐约见烧烤烟雾 / 摊顶招牌横旗。
- **远景（上 1/3）**：深青蓝夜空（比冬 CG 更黑、略偏青绿）+ 月亮（**新月或细眉月**，比冬 CG 弱，避免与萤火争光）+ 远处雷峰塔剪影 + 极稀疏星点。
- **动态层**：**萤火虫**作为画面"动态核心"——从画面下 1/3 芦苇丛向上 / 向中央飞舞扩散，约 30–50 个暖黄小光点（带柔光晕），分布在中景 + 中上区域，营造"夏夜精灵群"。

**C.3 色板**
- 主 55%：深青蓝（#0a2540 / #14304d）+ 暗墨绿（#1f3a2e，芦苇）
- 辅 25%：萤火暖黄（#ffd97a 散点光晕）
- 点缀 20%：远岸夜市橙红（#ff7a4c 灯笼 / 烧烤摊）+ 湖面月光冷白反光

**C.4 关键元素清单**
✅ 必备：芦苇荡、萤火虫、夜市摊贩群、远塔、月（弱光）
✅ 强烈建议：湖面萤火倒影、远岸零星霓虹小色块（呼应 zijun 夜市淘宝）
❌ 禁止：人物（剪影也不行，避免与萤火角色抢戏）、雪 / 桃花 / 桂花、可读大段文字 / 摊招文字（只允许氛围小字）

**C.5 是否含角色及站位**
**不含**。NPC + player 由 sprite 叠加在中央安全区（注意：芦苇较高，sprite 落位区下沿需保证芦苇不挡 sprite 脚部）。

**C.6 镜头语言**
wide establishing shot / 视平线接近水面，强调萤火纵深感 / 月弱萤强，让萤火成为画面情绪主角。情绪锚：萤火群 = "夏夜最浪漫的精灵"。

**C.7 ImageGen 提示要点**
```
【参考图（强约束）】
- D:/zkgame/assets/backgrounds/lakeside_evening.jpg    // 夜 + 月 + 灯笼主锚（参考灯笼但弱化月）
- D:/zkgame/assets/backgrounds/snack_bar.jpg             // 夜市 / 摊贩群元素锚（远景虚化参考）

【构图锚点】
- horizontal landscape 1280x720, 16:9
- camera: wide establishing shot, eye level just above the water surface, looking across West Lake at night
- foreground: dense tall lake reeds (Phragmites) occupying the lower 1/6 of the frame, dark green-black color, with a few firefly glows peeking from the reed tops
- midground: calm lake surface with subtle reflections; across the far shore, a cluster of night market stalls (5-8 small food stalls with red/yellow lanterns, light smoke wisps, distant small neon color accents) — slightly soft-focused to keep central 720x560 clean
- background: deep teal-indigo night sky, thin crescent moon or waning moon at upper-left (deliberately dimmer than winter CG to let fireflies dominate); faint star points; Leifeng Pagoda silhouette across the lake
- dynamic layer: 30-50 firefly points (warm amber-yellow #ffd97a with soft glow halo) flying upward and outward from the reed foreground into the middle frame; gentle water reflections

【风格后缀】
painterly Chinese landscape illustration, Ghibli/Makoto Shinkai atmospheric style, night summer scene, semi-realistic, magical firefly bioluminescence effect, soft glow halos, high contrast between warm fireflies and cool lake, cinematic, dreamy summer night mood, 1280x720 landscape, no characters, no watermark

【负向提示】
(no humans, no people, no silhouettes, no readable text, no neon shop signs as main subject, no snow, no peach blossoms, no osmanthus, no autumn leaves, no full moon, no watermark)
```

---

### D. `res://assets/backgrounds/holiday_autumn_osmanthus.jpg` —— 秋假·桂花林 / 诗会

**D.1 用途定位**
秋假 set-piece 共享背景。覆盖 chapter：`break_autumn_chapter_zicheng`（lakeside·evening）/ `break_autumn_chapter_jingjing_m`（community·after）。

**D.2 构图**
- **前景（下 1/8 与左上 1/4）**：**金桂枝叶**从画面**左上角下垂**（或右上一侧），细碎密集的金黄色桂花簇 + 深绿革质叶；前景下沿可见石径旁落了一层金黄桂花瓣。
- **中景（1/3–2/3）**：湖边小径 / 石板路（S 形，从前景延伸入中景），路旁有一棵桂花老树（满树金黄）；**石径旁可设一张小石桌 + 两张石凳**，桌面散落 2–3 张纸笺（诗笺，毛笔字迹虚化，不抢焦，可辨识"诗 / 词 / 秋"等氛围字）—— 呼应 autumn chapter jingjing_m "桂花诗会"。**留出中央安全区供 sprite 站位**。
- **远景（上 1/3）**：午后金色阳光（视平线高，光线偏侧后，形成桂花枝叶的逆光勾边）；远岸雷峰塔剪影；湖面青绿平静；远山雾紫蓝（比 spring CG 的雾蓝更偏紫）；可点缀 1–2 只归巢飞鸟小剪影。
- **动态层**：零星桂花瓣从画面上方飘落（金黄色小瓣，比桃花瓣更小更密，**落速慢**，强化午后宁静）。

**D.3 色板**
- 主 55%：金桂暖黄（#e8b54a / #f4d35e）+ 焦糖橙（#d97835）
- 辅 25%：湖面青绿（#7fa8a0）+ 桂花叶深绿（#3a5a3a）
- 点缀 20%：远山雾紫蓝（#7a6e8f）+ 纸笺米白（#f5ecd5）

**D.4 关键元素清单**
✅ 必备：金桂花枝 / 花簇、石径 / 石桌诗笺、午后金光、远塔、飘落桂花瓣
✅ 强烈建议：纸笺毛笔字（虚化）、归巢飞鸟剪影
❌ 禁止：人物、近景大段文字（纸笺仅氛围小字）、霓虹、灯笼（春冬物）、雪 / 萤火 / 桃花 / 暴雨

**D.5 是否含角色及站位**
**不含**。NPC + player 由 sprite 叠加在中央安全区（注意：石桌诗笺在中央安全区，需 ImageGen 时把石桌偏左 / 偏右下，sprite 站位避开纸笺正面）。

**D.6 镜头语言**
wide establishing shot / 视平线略高（金光从后方斜射，形成桂花枝逆光）/ 黄金时刻。情绪锚：金桂 + 诗笺 = "秋天的故事被写下来"。

**D.7 ImageGen 提示要点**
```
【参考图（强约束）】
- D:/zkgame/assets/backgrounds/lakeside_morning_sunny.jpg    // 苏堤 + 远塔 + 阳光锚
- D:/zkgame/assets/backgrounds/title_bg.jpg                     // 飘落花瓣氛围锚（参照但换成金桂花）

【构图锚点】
- horizontal landscape 1280x720, 16:9
- camera: wide establishing shot, slightly elevated eye level, looking across West Lake from a lakeside stone path
- foreground: golden osmanthus (gui hua) branches hanging from upper-left corner, dense clusters of tiny golden flowers and dark green waxy leaves; ground covered with scattered fallen golden petals
- midground: a curving lakeside stone path leading into the scene; one large osmanthus tree mid-frame with full golden bloom; a small stone table with two stone stools slightly off-center (left or lower-right, NOT center) with 2-3 sheets of rice paper (poem sheets) and faint brush calligraphy (atmospheric, not readable Chinese characters); keep central 720x560 area clean for character sprites
- background: warm golden afternoon sunlight from upper-right back-lighting the osmanthus branches; Leifeng Pagoda silhouette across the lake; calm teal-green lake surface; distant mountains in misty purple-blue
- dynamic layer: small golden osmanthus petals drifting down slowly across upper third

【风格后缀】
painterly Chinese landscape illustration, Ghibli/Makoto Shinkai atmospheric style, autumn afternoon golden hour, warm amber palette, semi-realistic, high detail on osmanthus flower clusters and leaf texture, backlit golden rim lighting, cinematic, dreamy autumn mood, 1280x720 landscape, no characters, no watermark

【负向提示】
(no humans, no people, no silhouettes, no readable large text, no neon signs, no red lanterns, no snow, no fireflies, no peach blossoms, no rain, no watermark)
```

---

## 3. 10 个画廊记忆缩略图映射

> **原则**：画廊缩略图**直接复用** §2 的 4 张 CG，不另画缩略；`GALLERY_ITEMS` 的 `bg` 字段对应填写 `holiday_<type>.jpg`。每条给出**一句文案基调**（caption 由 engineering-lead 落到 GALLERY_ITEMS 的 `caption` 字段；本规格只定基调，文字正文不出现在本规格交付中）。
> **命名对照**：flag `holiday_memory_<season>_<char>` ←→ CG `holiday_<season>.jpg`。

| # | 画廊 flag | 复用 CG | 角色 | 路线 | 一句文案基调（caption 风格） |
|---|---|---|---|---|---|
| 1 | `holiday_memory_winter_yutong` | `holiday_winter.jpg` | yutong（陈雨桐·女） | 男 | 雪夜断桥上，牵起手才发现谁都没松开过 |
| 2 | `holiday_memory_winter_jingjing` | `holiday_winter.jpg` | jingjing（叶菁菁·女） | 男 | 糖水铺里那碗热桂花酒酿，是"明年同班"的约定 |
| 3 | `holiday_memory_winter_yifei` | `holiday_winter.jpg` | yifei（沈逸菲·女） | 女 | 冬夜散场后的影院，街灯把两个人的影子叠得很长 |
| 4 | `holiday_memory_spring_wanqing` | `holiday_spring_outing.jpg` | wanqing（苏晚晴·女） | 男 | 苏堤桃花落满裙摆，她念出春天故事的主角名 |
| 5 | `holiday_memory_spring_xiaoxia` | `holiday_spring_outing.jpg` | xiaoxia（林小夏·女） | 男 | 攀岩馆岩壁下的桃花瓣，是"每年春天都来"的凭证 |
| 6 | `holiday_memory_spring_beichen` | `holiday_spring_outing.jpg` | beichen（顾北辰·男） | 女 | 桃花影里看科幻片，他第一次答应"下个春假老地方" |
| 7 | `holiday_memory_summer_keke` | `holiday_summer_trip.jpg` | keke（方可可·女） | 男 | 萤火点亮芦苇荡，她指着水面说"这是我们的秘密基地" |
| 8 | `holiday_memory_summer_zijun` | `holiday_summer_trip.jpg` | zijun（林紫君·男） | 女 | 夜市的河灯顺水漂远，他说"愿望要两个人一起许" |
| 9 | `holiday_memory_autumn_zicheng` | `holiday_autumn_osmanthus.jpg` | zicheng（周子诚·男） | 女 | 桂花雨里翻过石桌，他低声说"每年秋天都来，好不好" |
| 10 | `holiday_memory_autumn_jingjing_m` | `holiday_autumn_osmanthus.jpg` | jingjing_m（叶明轩·男） | 女 | 诗会的最后一行，他为她把整首桂花念完 |

**§3 工程对接备忘**：
- `GALLERY_ITEMS` 新增 10 条目，字段：`id = "gallery_<...>"` / `char` / `name` / `pose = "default"`（沿用当前 default sprite）/ `bg = "res://assets/backgrounds/holiday_<season>.jpg"` / `unlock = "holiday_memory_<season>_<char>"` / `caption = <正文，由工程按基调落地>`。
- flag `holiday_memory_*` 由对应 chapter 的 `setFlag` 在分支收尾场景自动写入（与现有 `west_lake_*` 同机制）。
- 缩略图：复用全尺寸 CG；engine 端在画廊 UI 中按 gallery 卡片尺寸做 `TextureRect` 缩放，**不需要单独生成缩略**（保持 §3 "不另画"原则）。

---

## 4. 一致性约束清单

### 4.1 与既有 backgrounds 资源对齐

| 维度 | 既有规格 | 本规格 CG 规格 | 是否一致 |
|---|---|---|---|
| 画风 | painterly 中国风景插画（Ghibli / 新海诚光感） | 同 | ✅ |
| 格式 | JPEG | JPEG（quality ≥ 90） | ✅ |
| 已有规格分辨率 | 1024×1024（方形） | 1280×720（横屏） | ⚠️ 故意不同，理由见 §0 |
| 文件位置 | `res://assets/backgrounds/` | 同 | ✅ |
| .import 参数 | `compress/mode=0`, `mipmaps=false`, `compress/lossy_quality=0.7`, `vram_texture=false` | 沿用相同导入参数（无需修改 `.import` 默认值） | ✅ |
| 是否含人物 | 不含（背景板） | 不含 | ✅ |
| 远景西湖元素 | 雷峰塔 / 保俶塔 / 苏堤 / 白堤 / 远山 | 沿用（统一远塔 = 雷峰塔，避免与 `lakeside_after_sunny` 的保俶塔撞视觉） | ✅ |

### 4.2 与角色立绘对齐（sprite × CG 复合）

- 角色 sprite 是 anime cel-shaded（2048×2048 透明 PNG），CG 是 painterly。两者**已**在 DialogueUI 上叠加，玩家已接受这一风格妥协（参考现有 chapter）。
- 本规格 CG **不含人物**，sprite 居中偏下叠加，二者不直接在同一画面内"风格混搭"——降低穿帮风险。
- sprite 落位安全区（720×560 居中偏下）已写入 §1.2 / §2 各 CG 构图要求；主理人 ImageGen 时需复核"中央安全区无大型物遮挡"。

### 4.3 与 DialogueUI 背景切换对齐

- §10 §3.5 / §6 #12：engineering 在 `DialogueUI.start_event` 检测事件 `bg` 字段后切换背景层。本规格 CG 作为 kickoff + chapter 的 `bg` 字段值。
- 1280×720 横屏与项目 viewport（`canvas_items` + `expand`）原生匹配，CG 满屏显示不裁切重要元素。

### 4.4 与现有 location 背景的衔接（同框场景）

- winter CG 主视觉 = `lakeside_evening` 的冬日变体（保持同一组"飞檐亭 + 红灯笼 + 远塔 + 月"骨架，但加雪 + 糖水铺 + 暖光）。
- spring CG 主视觉 = `lakeside_morning_sunny` 的春日变体（同一苏堤骨架 + 雷峰塔，加桃花 + 攀岩墙点缀）。
- summer CG 主视觉 = `lakeside_evening` 的夏夜变体（弱月、强萤火、加夜市摊贩群）。
- autumn CG 主视觉 = `lakeside_morning_sunny` 的秋日变体（同一苏堤骨架 + 雷峰塔，加金桂 + 诗笺）。

→ 玩家在 chapter 触发看到 CG 时，会自然感到"这是同一片西湖，换了季节"。chapter 完结后切回 location 既有背景（lakeside_evening 等），视觉过渡无突兀。

---

## 5. 角色专属立绘建议（v1 决策）

**决策**：v1 **不追加** set-piece 角色专属立绘。

**理由**：
1. 当前事件系统复用角色 `emoji` 标识 + `<char>/default.png` 已可表达角色；set-piece 的视觉重量已由 4 张 CG 承载。
2. 现有 4 个原零资产角色（keke / beichen / jingjing_m / zijun）2026-07-27 才完成第一轮 sprite 落地（参见 `design/art_generation_overview.md` / `design/art_qc_report.md`），尚有风格一致性与细节打磨空间；本批次不宜再叠加新角色立绘需求。
3. CG + sprite 的 painterly × cel-shaded 风格妥协已被 DialogueUI 接受；新增角色专属立绘无法改变这一妥协，且会拉高生产周期与图像额度成本。
4. 若 quality 门要求"set-piece 必须有专属角色立绘"或"独立路线支线结尾需角色高光 CG"，则升级为 v2 再评估（见 §6）。

**v2 候选（如未来追加）**：
- 每个 chapter 在分支收尾 scene 显示**角色半身特写**（default pose 之外加一个 `holiday_<season>_<char>` 专用 pose，如 winter_yutong 手牵手 pose）。
- 需要 10 张新立绘（4 季 × 主角代表），或退一步 4 张（每季 1 张主角代表）。
- 不在本规格交付范围。

---

## 6. 风险与待确认

| # | 风险 / 待确认 | 影响 | 建议处理 |
|---|---|---|---|
| R1 | ImageGen 生成 painterly 风格比 anime cel-shaded 更难稳定（同参考图风格可能漂移到厚涂 / 写实摄影） | CG 与既有 17 张背景出现明显风格断层 | 主理人执行时 **必须**把 `lakeside_evening.jpg` + 对应季节参考图作为 ImageGen `reference_image` 输入，并在 prompt 中显式声明"Ghibli/Makoto Shinkai atmospheric lighting style"与"painterly illustration"双重后缀；首轮生成后人工对比既有背景，偏差过大则同 seed 微调 |
| R2 | 4 张 CG 都含"飘落物"（雪 / 桃花 / 萤火 / 桂花），可能在 DialogueUI 静态背景上显呆板 | 玩家在长对话时觉得背景"像贴图" | 优先级低：set-piece CG 出现频率不高（每假一次 kickoff + chapter 高潮 moment），玩家不会长时盯 CG。若 quality 门反馈，再评估是否用 shader 加 particle 动效（属工程层，非美术层） |
| R3 | 1280×720 横屏与既有 1024×1024 方形规格不一致 | 与其他背景在 `.import` 默认处理上不同 | 已在 §0 / §4.1 标注；建议主理人在 §A–§D 生成完毕后统一给 4 张 CG 单独写 `.import`（参数照抄 lakeside_evening），避免 Godot 自动导入时被默认参数误压 |
| R4 | spring CG 的攀岩墙元素若位置 / 比例失控会破坏画面 | 视觉失衡 | ImageGen 时显式约束攀岩墙占画面 ≤ 15% 且位于右 / 左侧边缘；生成后主理人若觉得抢焦则用 inpaint 缩小或移除 |
| R5 | autumn CG 的纸笺毛笔字若太清晰会与对话 UI 抢焦 | 文字可读 = 信息干扰 | 提示词已要求"atmospheric, not readable Chinese characters"；生成后主理人模糊化处理或缩小纸笺 |
| R6 | summer CG 的萤火虫数量过多会变成"圣诞树"感 | 失真 | 提示词已约束 30–50 个萤火点 + 柔光晕；超出则提示词收紧 |
| R7 | 工程侧 `DialogueUI.start_event` 的 `bg` 切换未实现（见 `holiday_events_design.md` §7 风险 7） | CG 已落地但不会显示 | 与 engineering-lead 同步：本规格仅写美术方向，**§6 #12 的 `bg` 切换属工程任务**；CG 资产先就位，工程同步接线才能呈现 |
| R8 | 现有 `events_break.json` 引用 `bg` 路径已写入占位 | 当前若未接线，启动事件会 fallback 至 location 默认背景 | 与 R7 同解：engineering 须完成 §3.5 接线 |
| R9 | `holiday_events_design.md` §10.C 提及"角色立绘（可选增强）" — 与本规格 §5 决策一致（v1 不追加） | 无 | 不需处理 |

---

## 7. 交付清单

- [x] §0 决策一览
- [x] §1 美术方向总则（画风 / 分辨率 / 色板 / 衔接 / 镜头）
- [x] §2 4 张假期背景 CG 的构图 + 色板 + ImageGen 提示要点（winter / spring / summer / autumn）
- [x] §3 10 个画廊记忆缩略图映射（flag → 复用 CG → 角色 → caption 基调）
- [x] §4 一致性约束清单（与既有 backgrounds / sprite / DialogueUI / location 衔接）
- [x] §5 v1 不追加角色专属立绘决策
- [x] §6 风险与待确认（9 项，含与 engineering 的接线依赖 R7/R8）
- [x] §7 交付清单（本表）

**生成物统计**：
- 4 张 CG（holiday_winter / holiday_spring_outing / holiday_summer_trip / holiday_autumn_osmanthus），均为 1280×720 JPEG；
- 10 条画廊记忆条目复用上述 4 张 CG，**不另画缩略图**；
- 0 张新角色立绘（v1 不追加）。

**与现有 4 张 holiday CGs 的关系**：
- 本规格产出的 4 张 CG 落入 `res://assets/backgrounds/`，文件名严格匹配 `design/holiday_events_design.md` §10.A 与 `events_break.json` 中已写入的占位路径，可直接替换占位。
- 与既有 17 张 location 背景（`lakeside_*.jpg` / `title_bg.jpg` / `snack_bar.jpg` 等）共享同一 painterly 画风锚点与西湖元素谱系。

**待主理人 / 工程侧确认**：
1. 主理人：按 §2 各 ImageGen 提示要点生成 4 张 CG（含参考图上传 + 负向提示 + 人工复核）。
2. 主理人：批量写 4 张 CG 的 `.import`（参数照抄 `lakeside_evening.jpg.import`）。
3. engineering-lead：按 `holiday_events_design.md` §6 #12 落地 `DialogueUI.start_event` 的 `bg` 字段背景切换，否则 CG 不会显示（见 R7/R8）。
4. engineering-lead：按 §3 表 10 条扩展 `GALLERY_ITEMS`（id / char / pose / bg / unlock / caption），caption 正文按本规格"一句文案基调"落地。