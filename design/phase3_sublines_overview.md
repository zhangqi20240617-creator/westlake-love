# Phase 3 三条子线 · 交付总览

> 项目：西湖边的青春（Godot 4.5 移动端初中恋爱模拟 / 杭州西湖中学 / 570天）
> 子线：立绘多pose（丰富+修复+补画廊）· 对话润色 · 角色加厚
> 日期：2026-07-24 ｜ 编排：主理人（游承峰）

## 一、编排与诊断

- **Phase 0 诊断**：`pose` 渲染管线已通（`DialogueUI`+`GalleryPopupUI` 消费 `pose`，自动解锁 `seen_<char>_<pose>`）；但 8/10 角色缺 pose 资产，且事件已引用不存在的 pose（`upset`×5 + wanqing/beichen `serious/shy` + `jingjing_m` 整角色无目录）→ 实打实的错帧/缺图缺陷。
- **用户拍板**：立绘多pose = 丰富+修复+补画廊；三线并行。
- **编排**：2 个并行成员（文件互不冲突）
  - `content-lead`（design-strategist）独占 8 个事件 JSON —— 保证人设与结构连贯（润色+加厚+pose 修正同一个人做）
  - `gallery-lead`（engineering-lead）改 `GameManager.gd`/`DialogueUI.gd`/新文档

## 二、交付物

| # | 子线 | 交付 | 产出物 |
|---|------|------|--------|
| 1 | 对话润色 | 通读 8 文件，仅 1 处错别字修正（发绹→发丝）；其余人设/口语已达标，未妄改以免引入偏差 | `design/content_pass_c1.md` |
| 2 | 角色加厚 | 10 角色事件数全部达/超蓝图 9–12 配额；原 4 空角色弧光已在 Phase 3 首批量铺完，本轮新增 0 事件，以"核对+确认达标"收口 | 同上 |
| 3 | 立绘 pose 修正 | `upset` 引用全清零；keke/beichen/jingjing_m/zijun 省略 pose 字段；wanqing/yifei/zicheng→default；jingjing upset→serious；yutong/jingjing/xiaoxia 铺 study/casual | 同上 |
| 4 | GALLERY_ITEMS 扩展 | 2→10 角色 / 12→22 条；flag 命名 `seen_<char>_<pose>` 零 mismatch；bg 全真实；hint 按真实解锁条件重写 | `GameManager.gd` |
| 5 | DialogueUI 安全回退 | 缺图分支补 `sprite_center.hide()`，消除残留上一幕错帧/首幕空白 | `DialogueUI.gd` |
| 6 | 美术缺图清单 | 给美术的生产清单（已按 C-1 最终状态刷新，✅ 无 stale 的 upset） | `design/pose_asset_manifest.md` |

**角色事件数**：yutong17 / jingjing12 / wanqing11 / xiaoxia10 / keke9 / yifei9 / zicheng9 / beichen9 / jingjing_m9 / zijun9

## 三、质量门判定：PASS（游戏改动）

- `validate_phase3.py` ✅ PASS：147 事件；4 目标角色各 9 件；JSON 合法 / ID 唯一 / relState 合法 / close≥60 crush≥85 / recover 无 affDelta / next 合法。79 条 `excludeRelState` 警告为 legacy 债、非本次回归。
- `verify_pose_assets.py`（主理人交叉核对，跑在两者落盘后）：385 个 `(speaker,pose)` 引用 → 285 解析到真实资产；**`upset`=0**；仅剩 keke/beichen/jingjing_m/zijun 4 个零资产角色的 `default` 缺失（连默认立绘都没有 = 已知美术缺口，已被 C-5 的安全回退优雅隐藏，非代码缺陷）。

> CONCERN（manifest 因并行扫到改前快照致 §2/§3 stale）已由 `gallery-lead` 按最终事件状态刷新解决。

## 四、已知 follow-up（Phase 3 下一批，非阻塞）

1. **79 个普通事件补 `excludeRelState:"cold"`** —— 防冷战期仍弹日常邀约（Phase 2 就记录的暂缓项）
2. **`FAVOR_GALLERY_UNLOCKS` 引用无资产 pose**：wanqing serious@30 / casual@60、xiaoxia sport@30（达标也展示不出）
3. **yutong sport + jingjing sport 画廊条目当前事件未展示**（仅好感度阈值/未来事件可达）
4. **6 角色立绘资产待美术补齐**：keke/beichen/jingjing_m/zijun（零立绘）、wanqing/yifei/zicheng（仅 default）—— 生产清单见 `pose_asset_manifest.md` §4
5. **资源清理**：yutong 目录 `anim11111.ogv` 疑似重复；jingjing 目录 `Girl_looking_at_night_sky_*.mp4` 命名不规范

## 五、风险与缓解

- **立绘多pose 受限于美术资产**：当前仅 yutong/jingjing/xiaoxia 能铺多 pose；其余 6 角色待美术补资源（manifest §4 已列生产清单）。代码侧已无坏引用。
- **未提交 git、未跑游戏构建**（环境无 Godot 实机），需用户在编辑器验证：① DialogueUI 缺图回退表现；② 画廊解锁联动；③ 已润色/加厚事件的实际文本与触发。

## 六、可复现脚本

- `scratch/verify_pose_assets.py` —— pose 引用 vs 真实资产交叉核对（主理人验证用）
- `scratch/validate_phase3.py` —— 事件结构质量门
- `scratch/pose_fix_c1.py` —— content-lead 的 pose 规范化变换（保留 key 顺序 / 2 空格 / UTF-8）
- `scratch/backup_c1/` —— C-1 编辑前 8 事件 JSON 备份
