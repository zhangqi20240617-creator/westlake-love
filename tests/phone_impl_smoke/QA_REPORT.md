# QA-RN-01 · 拟真手机UI闭环 — 独立逻辑级烟雾测试报告

- **测试负责人**：严守真（quality-lead）
- **测试类型**：逻辑级静态验证（无 Godot 运行时；Python 3.13 文本解析 `.gd` 源码 → `ast.literal_eval` 结构化断言）
- **独立性**：与 `scratch/verify_phone_impl.py`（工程侧自验）完全独立编写，检查深度覆盖其未验证项（夜聊树全路径走查、数值区间、setFlag 预算、开场白双源一致性、char_meta 三字段交叉核对、`check_night_chat()` 五项守卫静态审查、NG+ 重置链）
- **验证脚本**：`tests/phone_impl_smoke/verify_qa.py`（可重复执行；退出码 0=PASS，1=FAIL）
- **依据**：`design/realistic_phone_gdd.md`（决策 C-1/C-2/C-3 = A/A/A）、`design/realistic_phone_content.md`
- **被测文件**：WeChatUI.gd / InitiativeManager.gd / GameManager.gd / EndingScreen.gd / NGPlusManager.gd（只读，未改动任何游戏代码）

---

## 结果总览

| 检查块 | 断言数 | 结果 |
|---|---|---|
| A. 朋友圈 moments_db | 34 | ✅ 全过 |
| B. 聊天 chats_db 结构 | 6 | ✅ 全过 |
| C. 夜聊树完整性/数值/开场白 | 61 | ✅ 全过 |
| D. char_meta 三字段交叉核对 | 8 过 + 2 关注 | ⚠️ 2 项遗留漂移 |
| E. check_night_chat() 逻辑审查 | 9 | ✅ 全过 |
| F. 集成与 NG+ 重置（R-4） | 4 | ✅ 全过 |
| **合计** | **121 PASS / 0 FAIL / 2 CONCERN** | |

## 门控判定：**PASS（附 2 项非阻塞关注项）**

---

## 分项详情

### A. MOMENTS（GDD §5.1/§1.2）— PASS
- `moments_db` 恰好 10 条。
- 6 条新贴（zijun_sketch / jingjing_m_bike / zicheng_match / yifei_recital / keke_transfer / beichen_moon）均 2 条评论；评论 aff 全部落在 [4,12] 且同贴两评论 aff 互异（11/6、12/5、11/6、12/6、12/6、12/7）。
- `post_keke_transfer` unlock_day=305 ≥300；`post_beichen_moon` unlock_day=320 ≥300（转学生不提前泄露）。
- C-2=A 复核：6 条新贴均无 `min_rel_state` 键，无关系门槛，符合决策。

### B. CHATS（GDD §3）— PASS
- `chats_db` 恰好 10 键：yutong / jingjing / wanqing / xiaoxia / yifei / zicheng / keke / beichen / **jingjing_m**（拼写正确，非 jingjingm）/ zijun。
- 4 个新角色条目均含 name / emoji / avatar_color / current_node / nodes 完整骨架。

### C. NIGHT TREES（GDD §5.2/§2.3）— PASS
- 10 角色均有 `night_start` 与 `night_end`；从 `night_start` 全路径 BFS 走查：**无悬空 next**，所有终结点唯一为 `night_end`（choices==[]）。
- 夜聊选项数值全部合规：aff∈[3,6]，stress∈[-5,2]。
- setFlag 预算：9 角色各 ≤1；**beichen 例外确认**——2 个 setFlag（`night_promise_beichen`@night_moon、`night_heart_beichen`@night_ask）位于互斥分支，单次走查只会命中其一，符合设计豁免，予以放行并留档。
- 开场白双源一致：10 角色 `night_start.text` 与 `InitiativeManager.NIGHT_CHAT_OPENERS` **逐字符相等**（含 `\n`），微信列表预览气泡与进入会话首条消息不会出现文案分叉。jingjing_m 白天树中的 `capsule_promise_jmx` setFlag 不在夜聊可达集内，未计入预算（正确隔离）。

### D. CHAR_META 交叉核对（GameManager.gd L105-115）— PASS with CONCERNS
8/10 角色三字段（name/emoji/color，色值忽略大小写）与 char_meta 完全一致，**4 个新角色（keke/beichen/jingjing_m/zijun）全一致**。2 项遗留静态漂移：

| 角色 | chats_db 静态值 | char_meta | 差异 |
|---|---|---|---|
| yutong | 🌸 / #4A7BB7 | 👩‍🎓 / #5b9fd4 | emoji + 颜色 |
| jingjing | 林菁菁 / 🌿 | **叶**菁菁 / 🌸 | 姓氏 + emoji |

**缓解事实**：WeChatUI.gd L1084-1093 在 `_ready()` 中无条件用 char_meta 覆写 chats_db 的 name/emoji/avatar_color，先于任何渲染执行，运行时表现正确。故判定为**非阻塞**（遗留数据漂移，非本特性引入）。建议后续顺手对齐静态字面量，避免误导后来的维护者。

### E. check_night_chat() 逻辑审查（InitiativeManager.gd L152-200）— PASS
- (a) `night_chat_day_<day>` 每日一次守卫（L157 早退）；且**无候选时也置位**（L174），可防网瘾跳时段 `advance_time(true)` 递归重复触发——实现比要求更稳。
- (b) `meta.get("unlockDay",1)` 未解锁跳过（L163）；`cold` 排除（L165）；rel_state 限 {friend, close, crush}（L166）。
- (c) `state.get("wechat_msg","") != ""` 有未读主动消息即跳过，不覆盖（L168）。
- (d) `day - flags.get("night_chat_last_"+cid, -999) < 3` 三天冷却（L169）。
- (e) `sort_custom(_night_candidate_sorter)`：好感降序 → 关系阶梯降序 → char_id 字典序升序（L193-200），**全序、确定可复现**。
- 崩溃风险审计：函数内对 flags/favorability 全部 `.get` 访问；`char_initiative[best_cid]` 写入前由 L153 `_init_char_initiative()` 保证键存在。`RelationshipManager.get_rel_state()` 对无记录角色回退 `_derive_base_state`，无裸键访问。**未发现崩溃风险。**

### F. 集成与 NG+（R-4）— PASS
- `GameManager.advance_time()`：**L460** `elif sid == "evening":` → **L462** `InitiativeManager.check_night_chat()`。evening 为 slot_index==3，不落入日结分支，接线正确；网瘾递归由 (a) 守卫兜底。
- NG+ 重置链：EndingScreen.gd **L439** `GameManager.reset_char_initiative()`（经 GameManager.gd L760-761 门面转发）→ **L440** `GameManager.flags = {}` 整体重置 → `night_chat_day_* / night_chat_last_* / night_chat_pending_* / wechat_node_* / moment_*` 随之自动清空，L463-466 仅回写 ng_count/seen_endings/title_* 跨周目白名单。**R-4 满足。**

---

## 关注项与备忘（非阻塞）

1. **[CONCERN] 遗留静态漂移**（见 D）：yutong emoji/色值、jingjing 姓名/emoji 与 char_meta 不一致，运行时被 L1089-1093 同步覆写。建议低优先级清理。
2. **[CONCERN] flags 增长**：`night_chat_day_<day>` 每天新增一键，全周目约 +365 键（另 `night_chat_last_<cid>` 至多 10 键）。量级无害，NG+ 会清空；若未来做存档瘦身可改为单键存"最后触发日"。
3. **[NOTE] EndingScreen 重置顺序**：`reset_char_initiative()`（L439）先于 `flags={}`（L440），两者状态互不依赖，当前顺序无害；留档提醒防止未来引入耦合。

## 复测方式
```
python tests/phone_impl_smoke/verify_qa.py    # 退出码 0=门控通过
```
