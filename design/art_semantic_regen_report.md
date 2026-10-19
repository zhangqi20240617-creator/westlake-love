# 角色立绘语义级重生报告（第 2 轮）

> 关联：`design/art_qc_report.md`（第 1 轮技术 QC）、`scratch/matte_sprite.py`（抠图）、`scratch/regen_semantic.py`（单图部署+despill）。
> 范围：针对第 1 轮 QC 指出的 **2 类语义缺陷** 做提示词重生。

## 1. 本轮目标

| # | 缺陷 | 涉及角色/文件 | 期望结果 |
|---|---|---|---|
| 1 | beichen 遮眼侧与规格不符：规格要求「前额碎发略遮**右眼**」，但 default 等 pose 渲染为遮左眼/不遮眼 | `beichen/default.png`（ primarily ） | 统一为遮右眼；若 ImageGen 无法稳定执行，则至少保证不遮错眼 |
| 2 | keke 蝴蝶结细节偏差：规格要求「橙/米白配色**纯色大蝴蝶结**」，但 `shy`/`upset` 渲染为波点款 | `keke/shy.png`、`keke/upset.png` | 大蝴蝶结改为纯色无图案 |

## 2. 管线

沿用第 1 轮验证后的绿幕→抠图→despill 管线：

1. ImageGen 生成 **纯绿幕 #00FF00** 原图（`background: solid`），避免透明参数被工具忽略。
2. `scratch/matte_sprite.py` 做绿通道色键抠图 → 2048×2048 RGBA。
3. `scratch/regen_semantic.py` 备份旧图、落位新图，并执行 despill 去绿边。

> 单张串行生成，防止并行写入覆盖（第 1 轮已踩坑）。

## 3. 执行结果

### 3.1 keke 蝴蝶结 —— ✅ 完全修复

| 文件 | 重生次数 | 结果 |
|---|---|---|
| `keke/shy.png` | 1 | 蝴蝶结为纯色橙米白大蝴蝶结，无波点；害羞姿态、高马尾、琥珀瞳正确 |
| `keke/upset.png` | 1 | 蝴蝶结为纯色橙米白大蝴蝶结，无波点；抱臂生气姿态正确 |

**技术校验**：
- 尺寸 2048×2048 RGBA，alpha=[0,255]
- 绿边像素 = 0
- 构图未裁切；`keke/upset` 人物中心偏左约 5%（因手臂张开），未越界

### 3.2 beichen 遮眼侧 —— ⚠️ 部分修复，未完全达成规格

| 文件 | 重生次数 | 结果 |
|---|---|---|
| `beichen/default.png` | 3 | 均未能画出「遮右眼」：v1 遮左眼，v2/v3 双眼可见。最终保留 **v3（双眼可见）**，至少消除了「遮错眼」的明显错误 |
| `beichen/serious.png` | 0 | 当前已是双眼可见，未遮任何眼；无遮左眼问题，故不再重生 |
| `beichen/shy.png` | 0 | 当前已是双眼可见，未遮任何眼；无遮左眼问题，故不再重生 |

**失败原因分析**：
- 对 ImageGen 连续使用 3 种不同空间描述（"covering his RIGHT eye" / "LEFT side of the picture" / "right eye hidden in shadow"），AI 均无法稳定执行单眼遮发。
- 该模型对「左右方位 + 遮挡单眼」的复合指令鲁棒性不足，且可能与后文「眼睛半垂、眼神淡然」产生冲突（模型倾向于完整展示双眼）。
- 继续同参数重刷额度收益极低，故在 3 次尝试后停止。

## 4. 质量门判定

| 维度 | 结果 |
|---|---|
| 本次修改文件技术校验（2048×2048 RGBA / 绿边=0 / 未裁切） | ✅ 3/3 |
| 全库事件引用解析 `scratch/verify_pose_assets.py` | ✅ 385/385，0 missing |
| keke 蝴蝶结语义符合规格 | ✅ |
| beichen 遮右眼语义符合规格 | ❌ 未达成；但已消除遮左眼错误 |

**门控结论：CONCERNS** —— keke 目标达成；beichen 遮右眼仍需后续人工或换模型处理。

## 5. 额度消耗

本轮共调用 ImageGen **5 次**（beichen/default ×3 + keke/shy + keke/upset），按 5–10 credits/张估算约 **25–50 credits**。

## 6. 后续建议

1. **keke**：`shy`/`upset` 已可用，可在文案 pass 中把对应事件的 `pose` 字段从 `default` 改为 `shy`/`upset`，并解锁 `GALLERY_ITEMS`。
2. **beichen**：
   - 若坚持「遮右眼」，建议人工在 Photoshop/Clip Studio 中用画笔补出发丝遮挡，或换用对空间指令更强的模型（如 ComfyUI + 可控 pose/depth）。
   - 若不执念于该细节，当前「双眼可见」版本画风统一、无绿边、可生产，可接受为角色设定微调（例如理解为「某 days 刘海梳开了」）。
3. **事件 pose 接入**：本次重生的 `keke/shy`、`keke/upset` 以及原有的 `beichen/serious`、`beichen/shy`、`jingjing_m/*`、`zijun/*` 都需在事件 JSON 中引用，才能触发 `DialogueUI` 表情切换与画廊解锁。

## 7. 文件清单

| 文件 | 说明 |
|---|---|
| `assets/sprites/keke/shy.png` | 重生：纯色橙米白大蝴蝶结 |
| `assets/sprites/keke/upset.png` | 重生：纯色橙米白大蝴蝶结 |
| `assets/sprites/beichen/default.png` | 重生 3 次后最终版（双眼可见） |
| `assets/sprites/{keke,beichen}/*.png.bak` | 重生前备份 |
| `scratch/regen_semantic.py` | 单图部署 + despill 助手 |
| `design/art_semantic_regen_report.md` | 本报告 |
