# 立绘资产缺失清单（Pose Asset Manifest）

> **用途**：美术生产清单。汇总全部 `(角色, pose)` 组合——哪些被事件引用、哪些已有真实资产、哪些缺资产；按角色列出「还差哪些美术资源」。
>
> **生成依据**：自动扫描 `scripts/events_*.json` 中实际出现的 `(speaker, pose)`（含 `DialogueUI` 的 `pose`→`"default"` 回退）与 `res://assets/sprites/<char>/` 实际资产目录交叉核对。`bg` 字段复用的背景见 §1。
>
> **关联改动**：配套 `GameManager.gd` 的 `GALLERY_ITEMS` 已扩展为 10 角色 / 22 条；本清单中的「缺资产 pose」即为对应画廊占位条目（`flag = seen_<char>_<pose>`，资产补全后由 `DialogueUI` 自动解锁）。
>
> **状态**：
> - content-lead C-1 收尾：全库 `upset` 引用 = 0，坏引用已清零。
> - 2026-07-27：keke / beichen / jingjing_m / zijun 的 12 张立绘（各 default + shy/upset/serious）已由主理人通过「绿幕生成 + OpenCV 色键 + inpaint 去水印 + 2× 放大」管线产出，最终为 **2048×2048 RGBA 透明 PNG**，可直接叠入 `DialogueUI`。
> - `scratch/verify_pose_assets.py` 全绿：385 个事件引用全部解析到真实资产，0 missing。

---

## 1. 可用背景资产（`res://assets/backgrounds/`，供 `bg` 复用）

```
amusement_park_bg.jpg  art_room.jpg        cinema_bg.jpg
classroom.jpg          community.png       home.png
lakeside.jpg          lakeside_after_sunny.jpg  lakeside_evening.jpg
lakeside_morning_sunny.jpg  lakeside_rainy.jpg  library.jpg
music_room.jpg         playground.jpg      school_gate.png
snack_bar.jpg          title_bg.jpg
```

> 画廊 `bg` 字段全部取自以上真实存在的文件，无缺失。

---

## 2. 总览表（C-1 收尾后当前状态）

| 角色 ID | 中文名 | 立绘目录 | 已有立绘 pose | 事件引用 pose（含 default 回退） | 缺资产 pose（已引用） | 画廊条目 |
|---|---|---|---|---|---|---|
| yutong | 陈雨桐 | ✅ 有 | default / casual / serious / shy / sport / study (+anim 视频) | default, casual, serious, shy, study | —（无） | 7 |
| jingjing | 叶菁菁 | ✅ 有 | default / casual / serious / shy / sport (+anim 视频) | default, casual, serious, shy | —（无） | 5 |
| xiaoxia | 林小夏 | ✅ 有 | default / casual / shy | default, casual, shy | —（无） | 3 |
| wanqing | 苏晚晴 | ✅ 仅 default | default | default | —（无） | 1 |
| yifei | 谢怡菲 | ✅ 仅 default | default | default | —（无） | 1 |
| zicheng | 周子诚 | ✅ 仅 default | default | default | —（无） | 1 |
| keke | 方可可 | ✅ 已补齐 | default / shy / upset | default | —（无） | 3 |
| beichen | 顾北辰 | ✅ 已补齐 | default / serious / shy | default | —（无） | 3 |
| jingjing_m | 叶明轩 | ✅ 已补齐 | default / shy / upset | default | —（无） | 3 |
| zijun | 林紫君 | ✅ 已补齐 | default / serious / shy | default | —（无） | 3 |
| **合计** | 10 角色 | — | — | — | — | **22** |

> 说明：表中「缺资产 pose」= 事件 JSON 已引用（含 `pose` 字段省略时 `DialogueUI` 回退的 `default`）、但 `res://assets/sprites/<char>/<pose>.{png,jpg,ogv}` 不存在的组合。**当前全库被引用 pose 均已解析到真实资产**；keke / beichen / jingjing_m / zijun 额外生成的 shy/upset/serious 尚未被事件 JSON 引用，后续可在文案 pass 中按需接入。`upset` 类坏引用已清零（全库引用数 = 0）。

---

## 3. 各角色还需补齐的美术资源（生产清单）

> **结论**：经 C-1 收尾后，除 keke / beichen / jingjing_m / zijun 这 4 个「整角色缺立绘」外，其余 6 角色当前被事件引用的 pose **已全部解析到真实资产**，无需补齐。

### 方可可 `keke` —— 已补齐
- 已有：`default.png` / `shy.png` / `upset.png`
- 缺（事件回退引用）：无

### 顾北辰 `beichen` —— 已补齐
- 已有：`default.png` / `serious.png` / `shy.png`
- 缺（事件回退引用）：无

### 叶明轩 `jingjing_m` —— 已补齐
- 已有：`default.png` / `shy.png` / `upset.png`
- 缺（事件回退引用）：无

### 林紫君 `zijun` —— 已补齐
- 已有：`default.png` / `serious.png` / `shy.png`
- 缺（事件回退引用）：无

> **美术交付规范**：每个 pose 资产命名遵循 `<pose>.<ext>`（如 `default.png`）；如为动态立绘则提供 `<pose>.ogv`。`DialogueUI` 查找顺序为 `.ogv` → `.png` → `.jpg`。

---

## 4. 设计期望的完整 pose 集（美术生产总清单）

> 本节约等于「设计上希望每个角色拥有、且 `GALLERY_ITEMS` 已登记/留位的全部 pose」——美术一眼可见要补什么，避免被 stale 的 `upset` 误导。数据源：`GameManager.gd` 的 `GALLERY_ITEMS`（10 角色 / 22 条）。

- **6 个有资产角色**：其 `GALLERY_ITEMS` 条目已 1:1 对应真实立绘，无需补：
  - 陈雨桐 yutong：default / casual / serious / shy / sport / study (+anim 视频)
  - 叶菁菁 jingjing：default / casual / serious / shy / sport (+anim 视频)
  - 林小夏 xiaoxia：default / casual / shy
  - 苏晚晴 wanqing / 沈逸飞 yifei / 周子诚 zicheng：各 default
- **4 个原零资产角色**：2026-07-27 已产出第一批最终 sprite，**2048×2048 RGBA 透明 PNG**：
  - 方可可 keke：`default` / `shy` / `upset` ✅
  - 顾北辰 beichen：`default` / `serious` / `shy` ✅
  - 叶明轩 jingjing_m：`default` / `shy` / `upset` ✅
  - 林紫君 zijun：`default` / `serious` / `shy` ✅
- **解锁联动**：事件展示对应 `(speaker, pose)` 时，`DialogueUI` 自动解锁 `seen_<char>_<pose>`；当前事件 JSON 已引用这 4 角色的 `default`，因此 `default` 画廊条目已可达。`shy` / `serious` / `upset` 尚未被事件引用，后续文案 pass 可择机接入以触发对应表情变化与画廊解锁。
- **质量备注**：这批 Asset 已是透明无水印的可运行 sprite，但 AI 生成图仍存在 pose 间细节波动（发色深浅、校服小件等），进入打磨阶段前建议做统一修图或品控审核。

---

## 5. 画廊解锁联动说明（供策划 / 程序核对）

- **自动解锁（展示触发）**：`DialogueUI.gd` 在每次展示 `(speaker, pose)` 时调用 `unlock_gallery("seen_%s_%s" % [speaker, pose])`；若场景省略 `pose` 字段，则按 `DialogueUI` 的 `scene.get("pose", "default")` 回退为 `default` 再解锁。
- **好感度阈值解锁**：`CollectionManager.FAVOR_GALLERY_UNLOCKS` 定义：
  - `yutong`：anim @ 50
  - `jingjing`：casual @ 40
  - `xiaoxia`：sport @ 30 / casual @ 60
  - `wanqing`：serious @ 30 / casual @ 60
- **一致性**：`GALLERY_ITEMS` 全部条目 `flag` 已统一为 `seen_<char>_<pose>`，与 `DialogueUI` 自动解锁命名完全一致。
- **占位条目**：`keke` / `beichen` / `jingjing_m` / `zijun` 的 `default` 条目 `flag = seen_<char>_default`，资产已补齐，事件展示 `default` 时即可解锁；其余 pose 尚未在 `GALLERY_ITEMS` 中编目，可按需添加。

---

## 6. 已知不一致 / 待策划确认（**非本次修改范围**，仅供排期）

1. **好感度阈值解锁引用了「无资产」的 pose**（达标也无法展示/解锁）：
   - `wanqing`：serious (@30) / casual (@60) 均无立绘资产
   - `xiaoxia`：sport (@30) 无立绘资产
   - 建议：补齐对应资产，或在 `FAVOR_GALLERY_UNLOCKS` 中移除 / 改指向有资产的 pose。

2. **画廊条目存在，但当前事件未展示其 pose**（仅能靠好感度或未来事件触发，长期不可达）：
   - `yutong`：**sport**（事件当前引用 default/casual/serious/shy/study；其中 anim 由好感度 @50 解锁）
   - `jingjing`：**sport**（事件当前引用 default/casual/serious/shy）
   - 建议：在事件中接入这些 pose 的展示，或调整解锁配置。

3. **清理项（非阻塞，建议确认后删除）**：
   - `yutong` 目录下 `anim11111.ogv` 疑似重复 / 废弃文件。
   - `jingjing` 目录下 `Girl_looking_at_night_sky_202607241047.mp4` 命名不规范（非 `<pose>` 约定）。

---

*Generated / refreshed by engineering-lead (C-2 + C-1 收尾刷新). 数据可经 `scripts/events_*.json` 与 `res://assets/sprites/` 重新核对复现。*
