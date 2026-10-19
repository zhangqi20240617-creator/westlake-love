# 社团 / 兴趣小组系统 · MVP 交付记录（DS-RN-05）

> 主理人：游承峰 · 阶段：模式创新扩展期 · 状态：✅ 放行（质量门双重独立确认）
> 设计：design-strategist 文策渊（design/club_system_gdd.md）
> 实现：engineering-lead 程基岩 · 门禁：quality-lead 严守真

## 1. 一句话定位
社团系统是「时间即代价」支柱的**新增真实时段竞争者**：初一适应期后加入一个社团，每周放学后（after 时段）参加一次活动，消耗时段换取属性成长 + 社交，但挤占学习/约会/探索时间。零新 Autoload，纯事件驱动。

## 2. 设计决策（已拍板）
| 项 | 决策 |
|---|---|
| 方案 | α 纯事件周活动：全靠 `events_life.json` + 既有门控引擎，仅周一钩子 1 行擦除 |
| 范围 | MVP 闭环：1 入社 hub + 5 周活动 + 1 行重置 + 第11菜单按钮（成就/专属链留目标层） |
| 入社 | 一次入社不可转社（承诺制，强化支柱 B） |
| 入口 | 更多菜单新增第 11 按钮「🎏 社团」 |
| NG+ | 入社状态随 `flags={}` 自然重置重选；社团成就（目标层）未来列入携带白名单 |

## 3. 实现落点
- `scripts/events_life.json` 66 → 72 事件（append-only 末位，免注册）：
  - `club_join_hub`：triggerDay 30、priority 212、excludeFlags joined、5 选项各置 `flag_club_joined` + `flag_club_<type>` + 主属性+1
  - 5× `club_weekly_<type>`（literature/astronomy/broadcast/basketball/art）：repeatable、slotId after、requireFlags joined+type、excludeFlags week_done、**无 noTimeCost**、statDelta 主+2/次+1/stress+1、setFlag week_done
- `scripts/DailyCycleManager.gd` L102（2×tab 缩进）：`_check_weekly_allowance` 周一分支内追加 `GameManager.flags.erase("flag_club_week_done")`
- `scripts/MainGame.gd` L444（第11按钮）+ L480–546（纯只读面板 `_show_club_popup`，复用 `_make_overlay_popup`，不写任何 flag）
- `EndingScreen.gd` / `project.godot` 零改动；autoload 仍 15（S-1）

## 4. 质量门（主理人独立重跑确认）
| 脚本 | 结果 |
|---|---|
| `scratch/verify_club.py`（工程侧自验） | 231 / 231 PASS，exit 0 |
| `tests/club_smoke/verify_qa.py`（quality-lead 独立门禁） | 100 / 100 PASS，concerns=0，exit 0 |
| `tests/club_smoke/mutation_check_club.py`（变异测试） | 15 / 15 缺陷被抓，0 逃逸，exit 0 |

成功标准 S-1~S-6 全过；红线 R1–R10 全守；已放行特性（风物志/十景/记忆回响/长假/生活支柱 P2）零回归。

## 5. 主理人已裁决的偏差
- **priority 205（天文/篮球/美术）**：与 `life_health_exercise_relief`(playground,p200,repeatable,零门控,slotId:null) / `life_health_art_relief`(art_room,p200) 竞争。若 ≤200 此三社将永久无法触发（功能死亡），故取 205。代价：成员每周一次在本社 after 从「stress−12 疏导」变为「社团主+2/次+1/stress+1」，约 13 点 stress 摆动，因疏导 slotId:null 仍可在其他时段获取，影响上限每周 1 次。已锁为正向断言（Q5.9–Q5.11 + Q13 计算式饿死防护）。
- **缩进**：`events_life.json` 实际基准为 2 空格（非记忆中记的 4 空格），社团区块沿用 2 空格匹配宿主；DailyCycleManager 用 tab、MainGame 用 4 空格，均匹配宿主，无混用。

## 6. 后续（未做，待排）
- 目标层：5 条社团专属事件链（社刊/联赛/晨间播报/流星观测/画展）+ 社团成就 flag + 毕业画廊条目
- NG+：目标层加 `flag_club_achievement_<x>` 时须显式加入携带白名单（否则随 `flags={}` 丢失）
- 顺带发现（非本轮）：`fest_newyear`/`fest_teacherday`/`fest_midautumn`/`fest_dragonboat` 为 priority 300、零门控一次性事件，理论上开局即被消费而非节日触发——建议另开单评估
- git 未初始化，多文件待提交（message 锚定 DS-RN-05）
