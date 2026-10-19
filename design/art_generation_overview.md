# 角色立绘生成批次报告 · 西湖边的青春

## 管线变更

- **旧管线（已废弃）**：`background: "transparent"` 直接请求透明 PNG → 工具输出 1024×1024 RGB 不透明图，背景为棋盘格/灰底，且带右下角水印。
- **新管线**：改为请求**纯绿幕背景 #00FF00**，再通过 OpenCV 色键（green-dominant chroma-key）+ 形态学清理 + 高斯抗锯齿 + 背景区 inpaint（去水印）+ LANCZOS 2× 放大，输出 **2048×2048 RGBA 透明 PNG**。

## 已完成

- 为 4 名原零资产角色产出并落位 **12 张最终 sprite**：
  - `keke` 方可可：`default` / `shy` / `upset`
  - `beichen` 顾北辰：`default` / `serious` / `shy`
  - `jingjing_m` 叶明轩：`default` / `shy` / `upset`
  - `zijun` 林紫君：`default` / `serious` / `shy`
- 全部文件位于 `res://assets/sprites/<char>/<pose>.png`，新建目录 `assets/sprites/jingjing_m/`。
- 技术校验全绿：
  - 12 张均为 **2048×2048 RGBA**，alpha 通道包含 0/255（真透明）。
  - `scratch/verify_pose_assets.py`：385 个事件引用全部解析，**0 missing**，**0 upset 坏引用**。

## 生成 / 后处理流程

1. ImageGen 单张串行生成（避免并行覆盖 bug），每张约 1024×1024 绿底图。
2. `scratch/matte_sprite.py` 处理：
   - 绿通道主导判定 `(G > R + margin) & (G > B + margin)` 作为背景掩码。
   - `cv2.morphologyEx(open/close)` 去噪点，`cv2.GaussianBlur` 边缘抗锯齿。
   - `cv2.inpaint` 对背景区（掩码=0）做 TELEA 修复，擦除右下角水印残留。
   - PIL LANCZOS 放大到 2048×2048 并保存为 PNG。

## 抽检结论

- `beichen/default`：清冷神秘气质，黑发遮眼、执书、藏青制服带酒红滚边，透明底干净。
- `zijun/serious`：暗紫棕短发、持画笔与速写本，符合美术委员设定。
- `jingjing_m/shy`：黑发青梅竹马，抱篮球、挠头脸红，情绪 pose 到位。
- `keke/default`：高马尾 + 橙蝴蝶结 + 叉腰姿态，傲娇感明确。

## 已知局限 / 后续打磨项

1. **AI 风格一致性**：同一角色在不同 pose 间存在轻微发色深浅、校服细节（领带结、袖口）波动，属生成式模型常态；当前已达到可运行品质，但非最终美术品控级。
2. **角色细节漂移**：
   - `beichen` 原设定为右眼被发丝半遮，部分生成图遮住的是左眼。
   - `keke` 蝴蝶结在个别图中呈现波点而非纯橙奶油色。
   - 这些可在打磨阶段由美术统一修图，或通过更重的负向提示/局部重绘控制。
3. **分辨率本质**：原图由 ImageGen 输出为 1024×1024，2048 为 LANCZOS 放大，细节并未真正倍增。若后续需要原生 2048 细节，需换支持该尺寸输出的生成器。
4. **事件 pose 接入**：当前事件 JSON 仍只引用这 4 角色的 `default`；新生成的 `shy` / `serious` / `upset` 需在后续文案 pass 中写入 `pose` 字段才能触发对应表情与画廊解锁。

## 文件清单

| 文件 | 说明 |
|---|---|
| `assets/sprites/keke/{default,shy,upset}.png` | 方可可 3 pose（RGBA 透明） |
| `assets/sprites/beichen/{default,serious,shy}.png` | 顾北辰 3 pose（RGBA 透明） |
| `assets/sprites/jingjing_m/{default,shy,upset}.png` | 叶明轩 3 pose（RGBA 透明） |
| `assets/sprites/zijun/{default,serious,shy}.png` | 林紫君 3 pose（RGBA 透明） |
| `scratch/matte_sprite.py` | 绿幕图 → 透明 sprite 的批量后处理脚本 |
| `design/art_spec_characters.md` | 角色美术规格书（提示词来源） |
| `design/pose_asset_manifest.md` | 资产状态清单（已刷新为最终状态） |
