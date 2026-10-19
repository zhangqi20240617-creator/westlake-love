# 《立绘多 pose 补全》独立质量门校验报告

- **校验人**：quality-lead（独立复核，不依赖 engineering-lead 的 scratch/verify_pose_assets.py）
- **校验脚本**：`tests/pose_completion_smoke/validate_pose.py`
- **运行环境**：`C:\Users\Administrator\.workbuddy\binaries\python\versions\3.13.12\python.exe`（Pillow 12.3.0）
- **校验对象**：10 张新立绘 PNG、10 个事件 JSON 的 pose 引用、GameManager.gd（GALLERY_ITEMS / C-5）、CollectionManager.gd（FAVOR_GALLERY_UNLOCKS / C-6）、events.json（R1 防误改）
- **校验方式**：全程真实读盘，只读校验，零源码改动

---

## 一、校验概要

本轮落地范围：wanqing / yifei / zicheng 各补 shy、serious、casual，xiaoxia 补 sport，共 **10 张新立绘**；配套 29 处事件 pose 接入、GALLERY_ITEMS 新增 10 条、FAVOR_GALLERY_UNLOCKS 按 C-6 新增 yifei/zicheng 阈值解锁、GameManager「谢怡菲」笔误（C-5）修正。

校验脚本独立重写了 pose 引用 × 资产交叉校验逻辑（等价于 scratch/verify_pose_assets.py）：从 DataManager.gd 的 `EVENT_FILES` 常量实际解析出 10 个事件 JSON，递归收集全部 `(speaker, pose)` 引用（跳过空 speaker / player / narrator，缺省 pose 记 `default`），逐条比对 `assets/sprites/<char>/<pose>.{png,jpg,ogv}` 磁盘存在性。

**运行结果：9/9 断言全部 PASS，退出码 0。**

## 二、逐项结论

| # | 校验项 | 结果 | 实测数据 |
|---|--------|------|----------|
| A1 | DataManager.gd EVENT_FILES 数量 == 10 | ✅ PASS | 实际 10 个（yutong/jingjing/wanqing/xiaoxia/keke/male/special/break/daily/life） |
| A2 | 10 个事件 JSON 全部存在且可解析 | ✅ PASS | 全部加载成功，无缺文件、无解析错误 |
| A3 | (speaker,pose) 引用 → 资产 **MISSING == 0** | ✅ PASS | total refs = 408，resolved = 408，missing = **0** |
| A4 | 总引用数 == 408（预期基线） | ✅ PASS | 实际 408，与 engineering-lead 侧口径一致（交叉印证） |
| B1 | 10 张新立绘 PNG 存在且 2048×2048 RGBA | ✅ PASS | 10/10 存在，PIL 实读均为 2048×2048、模式 RGBA |
| C1 | GALLERY_ITEMS 含 10 条新增 flag | ✅ PASS | seen_wanqing_{shy,serious,casual}、seen_yifei_{shy,serious,casual}、seen_zicheng_{shy,serious,casual}、seen_xiaoxia_sport 10/10 命中 |
| D1 | FAVOR_GALLERY_UNLOCKS 按 C-6 | ✅ PASS | yifei: shy@30、serious@60；zicheng: shy@30、serious@60，4 条阈值均正确 |
| E1 | GameManager.gd 全文无「谢怡菲」（C-5 已修） | ✅ PASS | 0 处残留 |
| F1 | events.json 的 yf_/zc_ 事件未被本轮改写（R1 防误改） | ✅ PASS | events.json 共 89 事件，其中 yf_/zc_ 事件 13 个，pose 键出现 **0 处**；该历史文件不在 EVENT_FILES 加载列表中，未被本轮触碰 |

补充旁证：
- events.json 全文件层面仅存在历史遗留 pose 值 `default/serious/shy`（非 yf_/zc_ 事件），无本轮新增 pose 注入痕迹。
- CollectionManager 的 `_check_favor_gallery_unlocks` 采用「prev < threshold ≤ current」单次跨越触发 + `_retroactive_gallery_check` 存档补偿扫描，新增 4 条阈值条目与既有机制兼容，无需额外迁移逻辑。

## 三、质量门总判定

# ✅ PASS

10 张新资产齐备且规格合规、408 条 pose 引用全解析（MISSING=0）、画廊与好感度解锁数据完整、C-5 笔误清零、R1 防误改确认。功能与数据完整性维度**无阻塞项**，同意放行（最终放行由用户签字，本判定为 advisory 门控）。

## 四、已知风险（不阻塞，纳入后续打磨清单）

| 风险 | 说明 | 建议处置 |
|------|------|----------|
| wanqing shy/serious 绿残留略高 | 抠图后边缘绿色残留数值偏高，但经人工复核**非真绿幕残留**（角色本身含绿色系元素），视觉可接受 | Playtest 阶段在深色背景下重点目检边缘 |
| xiaoxia sport 发夹差异 | 运动装立绘发夹细节与其他 pose 存在差异 | 美术侧登记为角色一致性打磨项 |
| 同角色新旧画风撕裂（C-7，预期内） | 新生成立绘与旧立绘画风存在可感知差异，属 C-7 已知预期 | 后续统一重绘批次内消化，不单独返工 |
| bechen / keke 细节漂移 | 非本轮范围角色存在细节漂移，留待打磨 | 纳入下一轮美术 QC 清单 |
| matte_sprite.py 已升级 HSV 色键 | 抠图管线本轮升级为 HSV 色键，历史资产未用新管线重跑 | 如后续重跑历史资产，需回归本报告 A3 项 |

## 五、复跑方式

```
C:\Users\Administrator\.workbuddy\binaries\python\versions\3.13.12\python.exe D:\zkgame\tests\pose_completion_smoke\validate_pose.py
```

退出码 0 = 质量门 PASS；非 0 = 存在 FAIL 项，控制台会打印逐项明细。
