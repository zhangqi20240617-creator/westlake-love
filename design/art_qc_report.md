# 角色立绘品控修图报告（第 1 轮技术 QC）

> 关联：`design/art_generation_overview.md`（生成流水线）、`scratch/matte_sprite.py`（抠图）、`scratch/qc_retouch.py`（QC+去绿边）。
> 范围：对 4 角色 × 3 pose = **12 张**最终 sprite 做技术品控与像素级修图。本轮只处理**抠图残留与构图**，不涉及语义级美术（脸/手/五官需改提示词重生成或人工）。

## 1. 上一轮遗留的技术缺陷

绿幕抠图（matte_sprite.py）后，角色边缘的半透明像素仍混合了绿幕底色，在游戏背景上会露出**绿色光晕（green fringe / spill）**。扫描 12 张发现：

- 边缘绿溢出像素普遍在 **2.8万 ~ 6.1万** 之间（占半透明边缘的 50%~70%）。
- 最严重：`keke/upset`（手臂张开，边缘面积大）60806 绿边像素。

## 2. 本轮修图（despill）

脚本 `scratch/qc_retouch.py` 对每张：
1. 备份原图到 `<pose>.png.bak`（保留可回滚）。
2. 对半透明边缘像素（0<alpha<255 且 G>R 且 G>B）执行 **despill**：`G = min(G, max(R,B))`，把绿溢出拉回与红/蓝通道一致。
3. 重新扫描指标对比。

### 去绿边成效（绿边像素 修前 → 修后）

| 角色 | pose | 修前 | 修后 | 削减 |
|---|---|---|---|---|
| keke | default | 32953 | 2905 | 91% |
| keke | shy | 32147 | 3029 | 91% |
| keke | upset | 60806 | 2962 | 95% |
| beichen | default | 28914 | 1878 | 94% |
| beichen | serious | 53513 | 2740 | 95% |
| beichen | shy | 52739 | 2454 | 95% |
| jingjing_m | default | 34899 | 8123 | 77%* |
| jingjing_m | shy | 32384 | 5347 | 83%* |
| jingjing_m | upset | 30011 | 2137 | 93% |
| zijun | default | 38474 | 7840 | 80%* |
| zijun | serious | 30093 | 3575 | 88% |
| zijun | shy | 27937 | 2978 | 89% |

> *标注的三张（jingjing_m/default、jingjing_m/shy、zijun/default）仍有 ~5000–8000 绿边像素，属**角色自带绿色物件**的边缘——叶明轩的书包/篮球配件、林紫君裤脚颜料点，是真实绿、非溢色，despill 正确地予以保留，不计入缺陷。

## 3. 构图与裁切

- 全部 `clipped = false`：**无任何角色被边缘裁切**。
- 前景占比 `fg_pct` 13.3%–18.9%，角色居中偏瘦长，留白充足，符合 VN 立绘惯例。
- 横向居中度 `cx` 多数在 ±0.07 内；`beichen/serious`、`beichen/shy`、`keke/upset` 因姿势（前倾/手臂张开）`cx` 约 +0.13~0.15，人物略偏右但**未越界、未裁切**，可接受。

## 4. 质量门判定

| 维度 | 结果 |
|---|---|
| 尺寸 2048×2048 RGBA | ✅ 12/12 |
| 含透明 alpha 通道 | ✅ 12/12 |
| 绿边溢出 | ✅ 已清至 <3000（自绿物件除外） |
| 构图裁切 | ✅ 0 裁切 |
| 事件引用解析 | ✅ 385/385，0 missing（verify_pose_assets.py） |

**门控结论：PASS** —— 12 张均已具备作为生产 sprite 的技术条件。

## 5. 仍建议的后续（语义级，不在本轮像素修图范围）

以下需**改提示词重生成**或人工精修，无法靠 OpenCV 修：
1. **beichen 遮眼侧不一致**：预设「遮右眼」，个别 pose 渲染为遮左眼——建议统一提示词后整角色重生。
2. **keke 蝴蝶结细节**：部分 pose 渲染出波点而非「奶橙纯色大蝴蝶结」——可针对性重生 `shy`/`upset`。
3. **pose 接入**：事件 JSON 目前只引用 4 角色的 `default`；`shy`/`serious`/`upset` 需在文案 pass 写入 `pose` 字段并对 `GALLERY_ITEMS` 编目，表情与画廊解锁才生效。

## 6. 文件清单

| 文件 | 说明 |
|---|---|
| `assets/sprites/{keke,beichen,jingjing_m,zijun}/*.png` | 12 张去绿边后最终 sprite |
| `assets/sprites/{keke,beichen,jingjing_m,zijun}/*.png.bak` | 修图前备份（Godot 不导入 `.png.bak`，可安全留存/删除） |
| `scratch/qc_retouch.py` | QC 扫描 + despill 可复用脚本 |
| `scratch/matte_sprite.py` | 绿幕→透明 sprite 抠图脚本 |
