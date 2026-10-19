# 社团毕业画廊 · 美术圣经（Club Graduation Gallery — Art Spec）

> 负责人：林绘澄（美术方向 / Art Director）
> 模块：社团目标层 DS-RN-05b「毕业成就 CG」
> 生成状态：**像素未落盘**（ImageGen 5 次调用均 completed，但返回 `localPath` 为服务内部路径，未持久化到 `D:\zkgame`，无法写盘）。本文档为 fallback 交付物，供主理人用可落盘的生成流程直接产出。
> 交付目标：5 张 1280×720 横屏 JPG，风格与现有背景统一。

---

## 0. 统一风格锚定（Style Anchor）

| 维度 | 规格 |
|---|---|
| 画风 | 柔和水彩 + 日系校园 cel-shaded 插画感；线条柔和，色块平涂带轻 cel 阴影，明亮清新 |
| 协调基准 | 与现有背景一致：`classroom.jpg` / `library.jpg` / `art_room.jpg` / `playground.jpg` / `lakeside*.jpg`（暖色、西湖元素、青春校园） |
| 色彩 | 暖色调基底；饱和度中高；天文社为冷蓝夜色但保留暖光源点缀 |
| 分辨率 | **1280 × 720 px**，横屏 16:9 |
| 格式 | JPG（quality 90–92），落盘到 `D:\zkgame\assets\backgrounds\` |
| 禁忌 | 血腥 / 裸露 / 过多文字 logo；AI 文字易错乱，手写体标题（如《湖畔》）建议**后期合成**，不要在生成阶段依赖可读文字 |
| 人物 | 背景图以空镜/环境为主；如含人物用背面、剪影或半身虚焦，避免清晰人脸特写（角色立绘另由 sprites 层叠加） |
| 文件命名 | 严格对应下表 |

---

## 1. 资产清单（Asset Manifest）

| # | 文件名 | 社团 | 主题 |
|---|---|---|---|
| 1 | `grad_club_literature.jpg` | 文学社 | 停刊三年的社刊《湖畔》复刊，教室堆满新印期刊，暖光洒入，桌上摊排版稿 |
| 2 | `grad_club_astronomy.jpg` | 天文社 | 校园天台望远镜，流星雨划过夜空，远处西湖倒映星光，冷蓝夜中带暖 |
| 3 | `grad_club_broadcast.jpg` | 广播站 | 清晨广播室，麦克风与调音台，窗外晨光，墙贴毕业特辑节目单 |
| 4 | `grad_club_basketball.jpg` | 篮球队 | 学校篮球场，比分牌定格，队员击掌，逆光剪影，青春热血 |
| 5 | `grad_club_art.jpg` | 美术社 | 校庆画展，长廊墙面挂满画作，中央一幅未干水彩，暖厅灯光 |

---

## 2. 逐 CG 规格

### 2.1 `grad_club_literature.jpg` · 文学社《湖畔》复刊

- **构图**：中景室内，画面左侧大窗占 1/3，暖光斜射；中央木桌摊开排版稿与校样，右侧与前景地面堆叠成捆新印期刊；纵深 bookshelf 在右墙。
- **色调**：暖琥珀 + 奶油米白；窗光区高亮，暗部偏橘棕；整体 nostalgic 暖。
- **主体**：新印文学期刊（素色封面、无可读文字）、手写校样纸、旧书脊、小盆栽。
- **光线**：午后斜射窗光（key light），柔和体积感，桌面高光与轻阴影分层（cel）。
- **参考**：`library.jpg` 暖调书墙、`classroom.jpg` 窗光；氛围对标「复刊的喜悦」。
- **AI 提示词（English, reusable）**：
  `Cozy high school literature club room interior, warm golden afternoon sunlight streaming through a tall window with sheer curtains, stacks of freshly printed literary magazines and an open layout manuscript on a wooden desk, bookshelves with old books, a small potted plant, warm amber and cream palette, nostalgic graduation achievement atmosphere. Soft Japanese anime campus illustration background, cel-shaded clean lineart, flat warm color blocks, bright fresh youth aesthetic, Hangzhou West Lake high school, cozy heartwarming mood, wide 16:9 composition, no human characters, no readable UI text, high detail.`
- **Negative**：text logos, people faces, blood, dark horror tone.

### 2.2 `grad_club_astronomy.jpg` · 天文社流星雨

- **构图**：高点俯瞰天台；前景天台栏杆 + 三脚架望远镜（指向右上）；中景夜空占 2/3，流星雨斜划；远景西湖水面横亘画面下缘，倒映星点。
- **色调**：深蓝 / 靛蓝夜空，星点冷白；天台暖灯与西湖暖反光形成冷暖对比。
- **主体**：望远镜、流星轨迹（3–5 条）、湖面星倒影、远处城市/山轮廓剪影。
- **光线**：环境冷光为主，单点暖灯（railing lamp）作为暖点缀；流星自带微光拖尾。
- **参考**：`lakeside_evening.jpg` / `lakeside_night` 系列的水面与远山；青春梦幻 CG。
- **AI 提示词**：
  `School rooftop at night with a telescope on a tripod pointing at the sky, a meteor shower streaking across a deep blue starry sky, distant West Lake water reflecting starlight, cool blue night tones with a warm glow from a rooftop lamp, peaceful dreamy youth campus graduation CG. Soft Japanese anime campus illustration background, cel-shaded clean lineart, flat color blocks, bright fresh youth aesthetic, Hangzhou West Lake high school, cozy heartwarming mood, wide 16:9 composition, no human characters, no readable UI text, high detail.`
- **Negative**：harsh neon, people, text.

### 2.3 `grad_club_broadcast.jpg` · 广播站毕业特辑

- **构图**：中近景室内，左侧窗占 1/3 透入晨光；中央调音台 + 立麦；右墙贴手写节目单（虚焦、不可读文字）；桌面散落磁带/耳机。
- **色调**：蜜桃晨曦（peach dawn）暖调，窗光偏橙粉，室内奶白。
- **主体**：播音麦克风、调音台推子、节目单便签、卡带、耳机。
- **光线**：清晨侧窗柔光（key），室内补光均匀，暖而安静。
- **参考**：`music_room.jpg` 设备与暖光；安静「最后一次播音」情绪。
- **AI 提示词**：
  `Early morning school broadcast room interior, a microphone on a stand and an audio mixing console on the desk, soft peach morning sunlight through the window, a handwritten program schedule sheet pinned on the wall, warm dawn tones, quiet cozy graduation special broadcast mood. Soft Japanese anime campus illustration background, cel-shaded clean lineart, flat warm color blocks, bright fresh youth aesthetic, Hangzhou West Lake high school, cozy heartwarming mood, wide 16:9 composition, no human characters, no readable UI text, high detail.`
- **Negative**：people, readable text, night, cold tone.

### 2.4 `grad_club_basketball.jpg` · 篮球队定格

- **构图**：低角仰拍球场；左侧比分牌定格（不可读数字，虚焦）；中央两队员背面击掌剪影；右侧篮筐与场地线；暖阳光晕在画面右上。
- **色调**：金黄日落暖调，逆光橙红 rim light，剪影深褐/近黑。
- **主体**：击掌的双人背面剪影、比分牌、篮筐、球场线、光斑。
- **光线**：逆光（backlight）强 rim，镜头光晕（lens flare），高对比热血感；cel 硬边阴影。
- **参考**：`playground.jpg` 户外暖光；青春热血运动 CG。
- **AI 提示词**：
  `School outdoor basketball court at golden hour, a frozen scoreboard, two players' backs high-fiving as backlit silhouettes, hoop and court lines, warm sunset rim light and lens flare, energetic youthful passion, dynamic graduation achievement CG. Soft Japanese anime campus illustration background, cel-shaded clean lineart, flat warm color blocks, bright fresh youth aesthetic, Hangzhou West Lake high school, cozy heartwarming mood, wide 16:9 composition, no human faces, no readable UI text, high detail.`
- **Negative**：front-facing faces, text, gloomy, desaturated.

### 2.5 `grad_club_art.jpg` · 美术社校庆画展

- **构图**：纵深透视长廊，左右墙满挂画框（虚焦不可读），中央 easel 一幅未干水彩为视觉焦点；暖厅灯沿顶排列，地面反光。
- **色调**：奶油 + 琥珀暖厅光，画框木色，水彩中央点高饱和。
- **主体**：长廊挂画、中央未干水彩（湿润反光）、画架、暖吊灯、长椅。
- **光线**：顶部暖厅灯均匀洗墙，中央聚光于未干画作，柔和体积光。
- **参考**：`art_room.jpg` 暖厅与画具；「展览落成」自豪感。
- **AI 提示词**：
  `School anniversary art exhibition in a long corridor, both walls hung with framed paintings and sketches, in the center an easel with a still-wet watercolor painting, warm gallery hall lighting, cream and amber tones, soft anime illustration, proud graduation achievement atmosphere. Soft Japanese anime campus illustration background, cel-shaded clean lineart, flat warm color blocks, bright fresh youth aesthetic, Hangzhou West Lake high school, cozy heartwarming mood, wide 16:9 composition, no human characters, no readable UI text, high detail.`
- **Negative**：people, readable signatures, cold fluorescent, clutter.

---

## 3. 统一生成约束（供主理人复现）

- **尺寸**：强制 1280×720；若模型输出非 16:9，先中心裁切至 16:9 再 LANCZOS 缩放至 1280×720，避免拉伸变形。
- **风格串（每图必带）**：`Soft Japanese anime campus illustration background, cel-shaded clean lineart, flat warm color blocks, bright fresh youth aesthetic, Hangzhou West Lake high school, cozy heartwarming mood, wide 16:9 composition, no readable UI text, high detail.`
- **一致性检查**：5 图共用同一画风串、同一西湖中学暖色基底；天文社允许冷蓝但须保留暖光源。
- **文字处理**：全部「不可读/虚焦」，《湖畔》等标题由程基岩/主理人后期用 `Label`/`TextureRect` 合成，不依赖 AI 出字。
- **落盘后**：Godot 重新打开工程会自动生成 `*.jpg.import`；如需显存优化由程基岩统一生成压缩 `.import`。

---

## 4. 后续建议

1. 像素生成请走**可落盘**的生成路径（本地 diffusers / 主理人侧 ImageGen 且 output 回传字节），避免本次「completed 但不可达」的情况。
2. 生成后按 §3 校验尺寸与风格一致性，再提交资产审计（命名 / 格式 / 预算）。
3. 若需《湖畔》可读标题，单独出一张透明 PNG 文字层叠加。
