# 画廊 Pose 补丁文档（Gallery Pose Patch）

> **作者**：文策渊（design-strategist）
> **阶段**：Phase 3「内容厚度」→「事件 pose 接入」子任务
> **配套改动**：`scripts/events_keke.json`、`scripts/events_male.json`（仅新增/修正 `pose` 字段，未改动任何对话文本）
> **用途**：本文件是**补丁说明**，由 engineering-lead 落地到 `GALLERY_ITEMS` 数组本身。本文不直接改写 `GALLERY_ITEMS`。

---

## 一、背景路径说明（重要）

任务简报中给出的回退路径为 `res://assets/bg/lakeside.jpg`，但本仓库**实际不存在** `assets/bg/` 目录。
经核对，背景图位于 **`assets/backgrounds/`**（复数），且以下用到的背景均已就绪：

- `assets/backgrounds/lakeside.jpg`
- `assets/backgrounds/snack_bar.jpg`   （对应 off_campus_shop 场景）
- `assets/backgrounds/library.jpg`
- `assets/backgrounds/school_gate.png`
- `assets/backgrounds/art_room.jpg`
- `assets/backgrounds/community.png`

因此下方 `bg` 字段统一使用 `res://assets/backgrounds/<file>`，**请勿使用简报中的 `res://assets/bg/...` 回退路径**（该路径在本仓库无效）。

---

## 二、Pose 接线汇总（事件 JSON 侧已完成）

引擎机制：非 `player` 说话人带 `pose` 时，自动解锁 `seen_<char>_<pose>`。
下列 scene 已补 `pose`（字符与 PNG 文件名一致：`keke/beichen/jingjing_m/zijun` × `shy/upset/serious`）：

| 事件 id | scene 序号 | 角色 | 新增 pose | 依据 |
|---|---|---|---|---|
| `kk_cold_recover_01` | s1 | keke | `shy` | 复合场景 s0 已是 shy，s1「还像刚转来那会儿那样，行吗？」为明确的含羞/试探，属情绪贴合 |
| `bc_cold_war_01` | s0 | beichen | `serious` | 闭馆对峙、主动开口质问，情绪为认真/严肃 |
| `bc_cold_recover_01` | s0 | beichen | `shy` | 校门口撑伞道歉「昨天是我不对」，含羞/局促，与 zijun 同型事件对齐 |
| `jm_cold_war_01` | s0 | jingjing_m | `upset` | 「你那句『不用你管』说得挺顺口」为被刺伤的委屈，补齐 jingjing_m 唯一缺失的 upset 立绘解锁点 |
| `jm_cold_recover_01` | s0 | jingjing_m | `shy` | 塞糖、耳根发红，含羞，与 zijun 同型事件对齐 |

**未改动**：所有初见/相遇事件（`keke_meet_01`、`bc_meet_01`、`jm_meet_01`、`zj_meet_01`）保持默认无 `pose`；其余已存在的 `shy/upset/serious` 立绘接线原样保留；对话文本一字未改。

---

## 三、Zijun 代词修正

**修正处数：0。**

经全量检索 `scripts/events_male.json`：**全文不含任何「她」**。zijun（林紫君，男角色）在叙述与台词中一律以「他 / 少年」指代（如 `zj_cold_war_01`「他握着画笔」、`zj_close_01`「像个普通少年」、`zj_crush_01`「我喜欢你，紫君说的，算数」）。
因此本任务无需任何代词改动；该文件中的 zijun 称呼已正确为男性。其他角色（beichen / jingjing_m 亦为男性）代词同样无需处理。

---

## 四、待补 GALLERY_ITEMS（8 条）

覆盖：keke shy/upset、beichen serious/shy、jingjing_m shy/upset、zijun serious/shy。
每条字段：`id` / `char` / `name` / `pose` / `bg` / `unlock` / `caption`。

### 4.1 速查表

| id | char | name | pose | bg | unlock | caption |
|---|---|---|---|---|---|---|
| `gallery_keke_shy` | keke | 可可 | shy | `res://assets/backgrounds/lakeside.jpg` | `seen_keke_shy` | 别过脸时那点红，比西湖的晚霞还好看。 |
| `gallery_keke_upset` | keke | 可可 | upset | `res://assets/backgrounds/snack_bar.jpg` | `seen_keke_upset` | 叉子被捏得发白，赌气的样子藏着一点委屈。 |
| `gallery_beichen_serious` | beichen | 北辰 | serious | `res://assets/backgrounds/school_gate.png` | `seen_beichen_serious` | 闭馆铃响，他第一次直视你，把藏了很久的话说了出来。 |
| `gallery_beichen_shy` | beichen | 北辰 | shy | `res://assets/backgrounds/library.jpg` | `seen_beichen_shy` | 低头抿茶，耳尖微红，说「下次别破费」时的北辰。 |
| `gallery_jingjing_m_shy` | jingjing_m | 叶明轩 | shy | `res://assets/backgrounds/community.png` | `seen_jingjing_m_shy` | 叶明轩耳根发红，却还嘴硬说「才没有」的模样。 |
| `gallery_jingjing_m_upset` | jingjing_m | 叶明轩 | upset | `res://assets/backgrounds/community.png` | `seen_jingjing_m_upset` | 那句「不用你管」，到底还是刺到了他。 |
| `gallery_zijun_serious` | zijun | 子君 | serious | `res://assets/backgrounds/art_room.jpg` | `seen_zijun_serious` | 握着画笔挑眉，林紫君较真起来比谁都认真。 |
| `gallery_zijun_shy` | zijun | 子君 | shy | `res://assets/backgrounds/library.jpg` | `seen_zijun_shy` | 速写本里画着你，他红着耳尖说「画着画着就成你了」。 |

### 4.2 可落地代码片段（追加到 `GALLERY_ITEMS`）

```gdscript
# === Phase 3 pose 接入补丁：以下 8 条由 design/gallery_pose_patch.md 生成 ===
{
    "id": "gallery_keke_shy",
    "char": "keke",
    "name": "可可",
    "pose": "shy",
    "bg": "res://assets/backgrounds/lakeside.jpg",
    "unlock": "seen_keke_shy",
    "caption": "别过脸时那点红，比西湖的晚霞还好看。"
},
{
    "id": "gallery_keke_upset",
    "char": "keke",
    "name": "可可",
    "pose": "upset",
    "bg": "res://assets/backgrounds/snack_bar.jpg",
    "unlock": "seen_keke_upset",
    "caption": "叉子被捏得发白，赌气的样子藏着一点委屈。"
},
{
    "id": "gallery_beichen_serious",
    "char": "beichen",
    "name": "北辰",
    "pose": "serious",
    "bg": "res://assets/backgrounds/school_gate.png",
    "unlock": "seen_beichen_serious",
    "caption": "闭馆铃响，他第一次直视你，把藏了很久的话说了出来。"
},
{
    "id": "gallery_beichen_shy",
    "char": "beichen",
    "name": "北辰",
    "pose": "shy",
    "bg": "res://assets/backgrounds/library.jpg",
    "unlock": "seen_beichen_shy",
    "caption": "低头抿茶，耳尖微红，说「下次别破费」时的北辰。"
},
{
    "id": "gallery_jingjing_m_shy",
    "char": "jingjing_m",
    "name": "叶明轩",
    "pose": "shy",
    "bg": "res://assets/backgrounds/community.png",
    "unlock": "seen_jingjing_m_shy",
    "caption": "叶明轩耳根发红，却还嘴硬说「才没有」的模样。"
},
{
    "id": "gallery_jingjing_m_upset",
    "char": "jingjing_m",
    "name": "叶明轩",
    "pose": "upset",
    "bg": "res://assets/backgrounds/community.png",
    "unlock": "seen_jingjing_m_upset",
    "caption": "那句「不用你管」，到底还是刺到了他。"
},
{
    "id": "gallery_zijun_serious",
    "char": "zijun",
    "name": "子君",
    "pose": "serious",
    "bg": "res://assets/backgrounds/art_room.jpg",
    "unlock": "seen_zijun_serious",
    "caption": "握着画笔挑眉，林紫君较真起来比谁都认真。"
},
{
    "id": "gallery_zijun_shy",
    "char": "zijun",
    "name": "子君",
    "pose": "shy",
    "bg": "res://assets/backgrounds/library.jpg",
    "unlock": "seen_zijun_shy",
    "caption": "速写本里画着你，他红着耳尖说「画着画着就成你了」。"
},
```

---

## 五、解锁可达性核对（8 条均可触发）

| unlock 标志 | 可达来源 scene（requireRelState / minAff） |
|---|---|
| `seen_keke_shy` | `kk_cold_recover_01` s0、`keke_daily_01` s3、`keke_close_01` s3/s4、`keke_crush_01` s1/s3/s5 |
| `seen_keke_upset` | `kk_cold_war_01` s0（close/60）、`keke_friend_01` s4（30） |
| `seen_beichen_serious` | `bc_crush_01` s3（crush/85）、`bc_cold_war_01` s0（close/60） |
| `seen_beichen_shy` | `bc_friend_01` s4、`bc_close_01` s3、`bc_chat` s2、`bc_gate_01` s4、`bc_cold_recover_01` s0 |
| `seen_jingjing_m_shy` | `jm_community_01` s2、`jm_friend_01` s3/s4、`jm_close_01` s1/s3/s4、`jm_crush_01` s3/s6、`jm_chat` s2、`jm_school_01` s3/s4、`jm_cold_recover_01` s0 |
| `seen_jingjing_m_upset` | `jm_cold_war_01` s0（close/60）✅ 本次新增补齐 |
| `seen_zijun_serious` | `zj_cold_war_01` s0（close/60） |
| `seen_zijun_shy` | `zj_cold_recover_01` s0、`zj_art_01` s3/s4、`zj_friend_01` s3、`zj_close_01` s1/s3/s4、`zj_crush_01` s1/s3/s5、`zj_library_01` s1/s4 |

> 备注：上述 4 个角色各自的 `serious/shy/upset` 立绘资源（2048×2048 PNG）均已存在于 `assets/sprites/<char>/<pose>.png`，与 `pose` 字段及 `unlock` 命名一致，可直接加载。

---

## 六、待主理人/工程侧确认项

1. **背景路径**：本文使用 `res://assets/backgrounds/...`；若工程侧画廊实际读取的是 `res://assets/bg/...`，需先补足该目录或调整读取逻辑（当前仓库无 `assets/bg/`）。
2. **Pose 接线范围**：本次仅补齐「情绪贴合且非初见」的 5 处空白/默认点（含 jingjing_m 缺失的 upset）。若希望更激进地为每个含羞/认真台词都挂立绘，可再扩展，但当前已满足 8 条画廊全部解锁可达。
3. **文本零改动**：所有事件 JSON 仅插入 `pose` 字段，对话文本与 `next`/`choices` 等结构均未变动，已通过 JSON 解析校验。
