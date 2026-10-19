# 角色立绘美术规格书 · 西湖边的青春

> 负责人：林绘澄（美术方向）  
> 用途：为 4 名零资产角色（keke / beichen / jingjing_m / zijun）定义 ImageGen 生成规格，并储备 3 名单 pose 角色（wanqing / yifei / zicheng）的扩产规格。  
> 交付状态：规格设计完成，待主理人审批后由主理人执行 ImageGen 生成（涉及额度，本文件不触发生成）。

---

## 1. 统一风格定义（Style Anchor）

### 1.1 画风锚定

以现有真实立绘 **`yutong`（除 default 外的多 pose）/ `jingjing` / `xiaoxia`** 为唯一风格锚点：

- **风格**：日系校园动画赛璐璐（anime cel-shaded），线条清晰，色块平涂，阴影为明确的 cel 分层，整体明亮清新。
- **人体比例**：写实向初中生比例，头身比约 5.5–6.5 头身；**全身立绘**，角色居中，从头顶到脚底完整可见。
- **构图**：正面或 3/4 侧面站姿，双臂自然下垂或做小幅动作，重心稳定，适合作为 `TextureRect` 叠在背景下方中央。
- **背景**：**必须透明背景（alpha 通道）**，保存为 PNG；禁止白底、渐变底或场景底，避免在 `DialogueUI` 叠加时穿帮。
- **色彩**：饱和度中等偏高，肤色柔和，校服以深蓝/藏青为主，配饰/发色按角色主题色点缀。

### 1.2 校服款式（西湖中学制服）

#### 女生校服（参考 yutong / jingjing）

- 藏青色西装式短外套，领边/袋口有**酒红色细滚边**；左胸佩戴**盾形校徽**。
- 内搭白色衬衫，系**红蓝斜条纹领带**。
- 下装为**蓝灰格子百褶裙**，长度及膝上。
- 黑色及膝袜 / 黑色中筒袜 + 棕色乐福鞋。

#### 男生校服（与 yifei / zicheng 的 1024 旧图同款式，但按 yutong/jingjing 画风重制）

- 藏青色西装式外套，**酒红色细滚边**，左胸**盾形校徽**。
- 白色衬衫 + 红蓝斜条纹领带。
- 深灰/黑色直筒西裤。
- 黑色皮鞋或深色运动鞋（运动场景可换，但默认站姿用皮鞋）。

> 注意：现有 `yifei / zicheng / wanqing` 的 `default.jpg` 为 1024×1024、白底、偏厚涂风格，与目标锚点不一致，**不建议作为新角色生成参考**，仅作为校服款式辅助参考。

### 1.3 尺寸与格式

| 项目 | 规格 |
|---|---|
| 格式 | PNG（RGBA，透明背景） |
| 目标尺寸 | **2048 × 2048 px** |
| 色深 | 8-bit / channel |
| 命名 | `<pose>.png`（小写） |
| 目录 | `res://assets/sprites/<char_id>/` |

> **尺寸说明**：`jingjing/default.png`、`xiaoxia/default.png` 及 `yutong` 全部非 default pose 均为 **2048×2048** 透明 PNG；仅 `yutong/default.png` 为 1024×1024（疑似早期导出）。为保证新角色与当前生产标准一致，统一按 **2048×2048** 输出。若移动端显存吃紧，可后续由程基岩统一压缩/生成 `.import` 缩放，但源图建议保持 2048。

---

## 2. 角色视觉规格

### 2.1 本次必须生成的 4 角色

---

#### keke · 方可可

| 项目 | 规格 |
|---|---|
| 性别 | 女 |
| 身份 | 初二转学生（上海转来），傲娇毒舌，内心孤独 |
| 主题色 | `#f59e0b`（暖橙琥珀） |
| 发型/发色 | **单侧高马尾**，深栗棕色，发尾微卷；刘海整齐，两侧留鬓发；马尾用**大蝴蝶结发圈**固定（事件多次提及“蝴蝶结”） |
| 瞳色 | 琥珀/蜜糖色，眼神常带一点挑衅或闪躲 |
| 身高体态 | 158 cm 左右，纤细，手脚比例偏小，显机灵 |
| 校服 | 女生标准校服，外套纽扣规范扣好，裙子百褶清晰 |
| 标志性配饰 | 蝴蝶结发圈（橙/米白配色，呼应主题色）；可默认空手，或 shy/upset  pose 中抱臂/捏衣角 |
| 性格外化 | 挑眉、嘴角微撇、抱臂、别过脸；害羞时脸红但嘴硬；委屈时眼尾下垂、蹙眉 |

---

#### beichen · 顾北辰

| 项目 | 规格 |
|---|---|
| 性别 | 男 |
| 身份 | 初二转学生（Day 300 解锁），神秘清冷，话少，常最后一个离开图书馆 |
| 主题色 | `#a78bfa`（淡紫藤） |
| 发型/发色 | 偏长的深灰黑发，前额碎发略遮右眼，发尾微乱；整体显得低调、疏离 |
| 瞳色 | 浅紫/冰蓝紫，眼神沉静、常半垂 |
| 身高体态 | 172 cm 左右，修长单薄，肩线平直，姿态收敛 |
| 校服 | 男生标准校服，衬衫领口一丝不苟，外套扣一粒扣；深灰西裤 |
| 标志性配饰 | 左手常夹一本书或笔记本； shy pose 可撑一把黑伞（呼应“撑伞等你”事件） |
| 性格外化 | 默认：面无表情、眼神淡然；serious：眉心轻蹙、目光直视；shy：视线移开、耳尖微红、嘴唇抿紧 |

---

#### jingjing_m · 叶明轩

| 项目 | 规格 |
|---|---|
| 性别 | 男 |
| 身份 | 青梅竹马，住隔壁，默默保护，开口难为情；与 jingjing（叶菁菁）是平行/对应角色 |
| 主题色 | `#e87d9a`（樱花粉，与 jingjing 共用） |
| 发型/发色 | 黑色短发，发质偏软，刘海自然分向一侧，后脑勺略蓬松；阳光少年感 |
| 瞳色 | 温暖深棕，笑时眼角弯起 |
| 身高体态 | 170 cm 左右，运动型匀称体格，站姿放松 |
| 校服 | 男生标准校服，衬衫最上一颗扣常解开，领带稍松，显得随性 |
| 标志性配饰 | 单肩背书包，或把篮球夹在身侧（事件提及“把篮球往肩上颠”）； default 可拿一颗糖 |
| 性格外化 | 默认：爽朗温和、虎牙微露；shy：耳根红透、眼神闪躲、挠头；upset：眉头紧锁、嘴角下压、受伤又隐忍 |

---

#### zijun · 林紫君

| 项目 | 规格 |
|---|---|
| 性别 | 男（按用户要求按男生处理；注意：现有 events_male.json 部分文本使用“她”，文案侧需同步校验） |
| 身份 | 美术课代表，画画第一，性格飒爽，对喜欢的人会脸红 |
| 主题色 | `#f59e0b`（暖橙，与 keke 撞主题色，通过发型/配饰区分） |
| 发型/发色 | 深墨绿色或暗紫棕色中短发，发梢微翘，略显凌乱艺术感；前额一缕挑染或浅色发梢可选（美术生个性） |
| 瞳色 | 琥珀/金棕，认真时眼神锐利，害羞时瞳孔放大 |
| 身高体态 | 168 cm 左右，偏瘦，手指修长，站姿带点随性的艺术生气质 |
| 校服 | 男生标准校服，但**袖口卷起至小臂**，领口微敞，可能沾有不易察觉的颜料点 |
| 标志性配饰 | 手持画笔或夹速写本；serious pose 可托调色盘 |
| 性格外化 | 默认：自信挑眉、嘴角带笑；serious：专注蹙眉、目光锁定画面方向；shy：脸红、用速写本半遮脸 |

---

### 2.2 储备角色（本轮不生成，仅作规格储备）

| 角色 | 性别 | 关键视觉特征 | pose 缺口 |
|---|---|---|---|
| wanqing · 苏晚晴 | 女 | 文艺委员，黑长直，紫灰瞳，抱书，安静忧郁气质 | 现有 default.jpg（1024×1024 白底，需按锚点风格重制/扩展） |
| yifei · 沈逸飞 | 男 | 音乐课代表，黑发，闭眼或垂眸，持小提琴，清冷疏离 | 现有 default.jpg（1024×1024 白底，需重制/扩展） |
| zicheng · 周子诚 | 男 | 篮球队长，黑发，虎牙笑，持篮球，阳光可靠 | 现有 default.jpg（1024×1024 白底，需重制/扩展） |

> 储备角色当前仅有 1024×1024 `.jpg` 单 pose，且风格/底色与 yutong/jingjing/xiaoxia 不一致。建议后续统一按本规格书重制为 2048×2048 透明 PNG，再补 `serious / shy / casual` 等 pose。

---

## 3. ImageGen 生成提示词

### 3.1 提示词模板要素

每条 prompt 均为英文，结构固定为：

```
[风格锚定] + [角色身份/外形] + [表情与姿态] + [技术要求]
```

技术要求统一后缀：

```
full body character sprite, transparent background, anime cel-shaded style, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only
```

### 3.2 风格参考图（ImageGen reference）

| 性别向 | 首选参考图 | 备选参考图 |
|---|---|---|
| 女生 | `D:/zkgame/assets/sprites/jingjing/default.png` | `D:/zkgame/assets/sprites/yutong/serious.png` |
| 男生 | `D:/zkgame/assets/sprites/jingjing/default.png`（用于画风）+ `D:/zkgame/assets/sprites/yifei/default.jpg`（仅校服款式辅助，非画风参考） | `D:/zkgame/assets/sprites/zicheng/default.jpg`（仅校服款式辅助） |

> 因现有男生锚点画风与目标不一致，建议以 `jingjing/default.png` 的赛璐璐画风为主导参考，再辅以文字约束校服款式。

---

### 3.3 keke（方可可）3 pose 提示词

#### keke_default

```
Anime cel-shaded full-body character sprite of a Chinese middle-school girl, 14 years old, transfer student tsundere. Deep chestnut-brown hair in a high side ponytail tied with a large cream-and-orange bow, neat bangs with side tendrils. Amber-honey eyes, slightly raised eyebrow, confident but defensive expression. Wearing Xihu Middle School girls' uniform: navy blazer with wine-red piping, white dress shirt, red-and-navy diagonal striped tie, shield-shaped school crest on left chest, blue-grey plaid pleated skirt, black knee-high socks, brown loafers. Standing with weight on one leg, arms loosely crossed or one hand on hip, chin tilted slightly up. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/default.png`

#### keke_shy

```
Anime cel-shaded full-body character sprite of a Chinese middle-school girl, 14 years old, transfer student tsundere. Deep chestnut-brown hair in a high side ponytail with a large cream-and-orange bow, neat bangs. Amber-honey eyes looking away to the side, cheeks flushed pink, lips pressed together as if hiding embarrassment. Wearing Xihu Middle School girls' uniform: navy blazer with wine-red piping, white shirt, red-and-navy striped tie, shield crest, blue-grey plaid pleated skirt, black knee-high socks, brown loafers. Standing with hands clasped in front or fidgeting with skirt hem, shoulders slightly hunched, gaze averted. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/shy.png`

#### keke_upset

```
Anime cel-shaded full-body character sprite of a Chinese middle-school girl, 14 years old, transfer student. Deep chestnut-brown hair in a high side ponytail with a large cream-and-orange bow, slightly messy from emotion. Amber-honey eyes narrowed, eyebrows furrowed, lower lip trembling, expressing grievance and restrained anger. Wearing Xihu Middle School girls' uniform: navy blazer with wine-red piping, white shirt, red-and-navy striped tie, shield crest, blue-grey plaid pleated skirt, black knee-high socks, brown loafers. Standing with arms crossed tightly or one hand clenched at side, body slightly turned away, head lowered but eyes glaring sideways. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/serious.png`

---

### 3.4 beichen（顾北辰）3 pose 提示词

#### beichen_default

```
Anime cel-shaded full-body character sprite of a Chinese middle-school boy, 14 years old, mysterious transfer student. Dark grey-black hair of medium length, strands partly covering right eye, slightly tousled. Pale skin, calm lavender-blue eyes half-lidded, neutral distant expression. Wearing Xihu Middle School boys' uniform: navy blazer with wine-red piping, white dress shirt, red-and-navy diagonal striped tie, shield-shaped school crest on left chest, dark charcoal trousers, black leather shoes. Standing straight with one hand holding a closed book or notebook against his side, posture relaxed but aloof, gaze leveled forward. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/default.png`

#### beichen_serious

```
Anime cel-shaded full-body character sprite of a Chinese middle-school boy, 14 years old, mysterious transfer student. Dark grey-black medium-length hair with strands over one eye. Pale skin, lavender-blue eyes now fully open and focused, eyebrows drawn together in a serious frown, lips pressed thin. Wearing Xihu Middle School boys' uniform: navy blazer with wine-red piping, white shirt, red-and-navy striped tie, shield crest, dark charcoal trousers, black leather shoes. Leaning slightly forward, book held in both hands at chest height as if making a point, intense but quiet expression. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/serious.png`

#### beichen_shy

```
Anime cel-shaded full-body character sprite of a Chinese middle-school boy, 14 years old, mysterious transfer student. Dark grey-black medium-length hair, slightly tousled. Pale skin, lavender-blue eyes looking down and to the side, ear tips faintly pink, lips slightly parted in rare embarrassment. Wearing Xihu Middle School boys' uniform: navy blazer with wine-red piping, white shirt, red-and-navy striped tie, shield crest, dark charcoal trousers, black leather shoes. Standing with shoulders slightly hunched, book held close to chest, umbrella handle visible in one hand, gaze averted. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/shy.png`

---

### 3.5 jingjing_m（叶明轩）3 pose 提示词

#### jingjing_m_default

```
Anime cel-shaded full-body character sprite of a Chinese middle-school boy, 14 years old, cheerful childhood friend. Soft black short hair with natural part, warm deep-brown eyes smiling, friendly open expression with slight canine tooth visible. Wearing Xihu Middle School boys' uniform: navy blazer with wine-red piping, white dress shirt with top button undone, red-and-navy striped tie slightly loosened, shield-shaped school crest, dark charcoal trousers, black leather shoes. Standing relaxed, basketball tucked under one arm or school bag slung over one shoulder, free hand in pocket, warm confident smile. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/default.png`

#### jingjing_m_shy

```
Anime cel-shaded full-body character sprite of a Chinese middle-school boy, 14 years old, childhood friend. Soft black short hair, warm deep-brown eyes looking away, ears bright red, awkward smile. Wearing Xihu Middle School boys' uniform: navy blazer with wine-red piping, white shirt, red-and-navy striped tie loosened, shield crest, dark charcoal trousers, black leather shoes. Standing with one hand scratching the back of his head, basketball held loosely against his leg, body turned slightly away, shy and flustered. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/shy.png`

#### jingjing_m_upset

```
Anime cel-shaded full-body character sprite of a Chinese middle-school boy, 14 years old, childhood friend. Soft black short hair slightly disheveled, warm deep-brown eyes now clouded, eyebrows drawn down, hurt and stubborn expression. Wearing Xihu Middle School boys' uniform: navy blazer with wine-red piping, white shirt, red-and-navy striped tie, shield crest, dark charcoal trousers, black leather shoes. Standing with basketball held down at his side, shoulders tense, head slightly bowed, lips pressed in a line as if holding back words. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/serious.png`

---

### 3.6 zijun（林紫君）3 pose 提示词

#### zijun_default

```
Anime cel-shaded full-body character sprite of a Chinese middle-school boy, 14 years old, confident art committee representative. Dark muted green or dark auburn short hair with artfully messy strands, one lock lighter at the tip. Amber-gold eyes, one eyebrow slightly raised, self-assured smile. Wearing Xihu Middle School boys' uniform: navy blazer with wine-red piping, white shirt with sleeves rolled up to forearms, red-and-navy striped tie, shield-shaped school crest, dark charcoal trousers with tiny paint splatter details, black leather shoes. Holding a paintbrush in one hand and a sketchbook under the other arm, confident artistic stance. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/default.png`

#### zijun_serious

```
Anime cel-shaded full-body character sprite of a Chinese middle-school boy, 14 years old, art committee representative. Dark muted green or dark auburn messy short hair. Amber-gold eyes focused and intense, eyebrows lowered in concentration, lips closed in a serious line. Wearing Xihu Middle School boys' uniform: navy blazer with wine-red piping, white shirt sleeves rolled up, red-and-navy striped tie, shield crest, dark charcoal trousers, black leather shoes. Holding a paintbrush like he is about to paint, sketchbook open against his chest, gaze fixed forward with artistic focus. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/serious.png`

#### zijun_shy

```
Anime cel-shaded full-body character sprite of a Chinese middle-school boy, 14 years old, art committee representative. Dark muted green or dark auburn messy short hair with a lighter tip. Amber-gold eyes looking down and away, cheeks flushed pink, embarrassed smile. Wearing Xihu Middle School boys' uniform: navy blazer with wine-red piping, white shirt sleeves rolled up, red-and-navy striped tie, shield crest, dark charcoal trousers, black leather shoes. Hugging a sketchbook in front of chest with both arms, paintbrush tucked behind ear, body slightly turned away, shy and flustered. full body character sprite, transparent background, clean black lineart, soft cel shading, vibrant natural colors, no background elements, centered composition, 2048x2048 pixels, PNG with alpha channel, visual novel sprite, single character only.
```

**参考图**：`D:/zkgame/assets/sprites/jingjing/shy.png`

---

## 4. 资产落地路径表

本次必须生成 **12 张**立绘：

| 角色 ID | 角色名 | pose | 生成提示词 | 落地路径（TextureRect 加载路径） |
|---|---|---|---|---|
| keke | 方可可 | default | §3.3 keke_default | `res://assets/sprites/keke/default.png` |
| keke | 方可可 | shy | §3.3 keke_shy | `res://assets/sprites/keke/shy.png` |
| keke | 方可可 | upset | §3.3 keke_upset | `res://assets/sprites/keke/upset.png` |
| beichen | 顾北辰 | default | §3.4 beichen_default | `res://assets/sprites/beichen/default.png` |
| beichen | 顾北辰 | serious | §3.4 beichen_serious | `res://assets/sprites/beichen/serious.png` |
| beichen | 顾北辰 | shy | §3.4 beichen_shy | `res://assets/sprites/beichen/shy.png` |
| jingjing_m | 叶明轩 | default | §3.5 jingjing_m_default | `res://assets/sprites/jingjing_m/default.png` |
| jingjing_m | 叶明轩 | shy | §3.5 jingjing_m_shy | `res://assets/sprites/jingjing_m/shy.png` |
| jingjing_m | 叶明轩 | upset | §3.5 jingjing_m_upset | `res://assets/sprites/jingjing_m/upset.png` |
| zijun | 林紫君 | default | §3.6 zijun_default | `res://assets/sprites/zijun/default.png` |
| zijun | 林紫君 | serious | §3.6 zijun_serious | `res://assets/sprites/zijun/serious.png` |
| zijun | 林紫君 | shy | §3.6 zijun_shy | `res://assets/sprites/zijun/shy.png` |

> 注意：`jingjing_m` 目录当前不存在，生成后需新建 `assets/sprites/jingjing_m/`。

---

## 5. 风险备注与待确认项

### 5.1 画风一致性风险

- AI 生成难以 100% 复刻手绘角色的线条粗细与眼型细节。建议：
  1. 优先使用 **ImageGen 的参考图功能**上传 `jingjing/default.png` 作为 style reference。
  2. 生成后由美术/主理人逐张复核：眼距、头身比、校服纹样、校徽位置、透明度。
  3. 若某张偏差过大，可用同一角色的其他 pose 或 `yutong/serious.png` 作为二次参考重新生成。

### 5.2 透明背景 PNG 必要性

`DialogueUI.gd` 加载路径为 `res://assets/sprites/<char>/<pose>.png`，并直接作为 `TextureRect.texture` 叠在背景之上。若输出为 JPG 或 PNG 但无 alpha，角色边缘会出现白边/黑边，导致穿帮。因此：

- **必须保存为带 alpha 的 PNG**。
- 生成后可用图像软件检查：非角色区域必须为纯透明，无噪点/灰边。

### 5.3 尺寸与移动端性能

- 建议源图为 **2048×2048**，与 `jingjing/xiaoxia` 及 `yutong` 非 default pose 保持一致。
- `yutong/default.png` 为 1024×1024，属旧标准；不建议新角色再降至 1024。
- 若程基岩反馈移动端显存/包体压力，可在 Godot `.import` 侧设置压缩/最大尺寸，源图仍保持 2048 以便未来高清重制。

### 5.4 设定不一致（待文案/策划确认）

1. **zijun 性别**：用户要求按男生处理，但 `events_male.json` 中 zijun 相关文本多次使用“她”。需在文案 pass 中统一为“他”，或确认角色性别设定。
2. **content_density_blueprint.md** 将 keke / beichen / jingjing_m / zijun 标注为“男主/女主”且与用户给的性别相反，该表可能存在 stale 数据，建议主理人同步核查。
3. **jingjing_m 名称**：`pose_asset_manifest.md` 第 39 行仍写为“菁菁妈”，已按用户要求按“叶明轩（男）”处理，但 manifest 需文案侧修正。

### 5.5 储备角色风格缺口

`wanqing / yifei / zicheng` 的现有 `default.jpg` 为白底、1024×1024、偏厚涂，与本次 4 角色的目标画风不一致。若后续启用这些角色的额外 pose，建议先重制其 `default`，保持全角色视觉统一。

---

## 6. 交付清单

- [x] 统一风格定义
- [x] 4 主角视觉规格 + 3 储备角色概要
- [x] 12 条 ImageGen 英文 prompt（4 角色 × 3 pose）
- [x] 12 条资产落地路径
- [x] 风险备注与待确认项

**总计待生成图数：12 张**  
**建议输出尺寸：2048 × 2048 px**  
**输出格式：透明背景 PNG**
