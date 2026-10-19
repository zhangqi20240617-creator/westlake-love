# 项目记忆录 (MEMORY.md)

## 西湖成就中心系统（Achievement Center Matrix）

> **更新日期**：2026-10-16
> **更新模块**：成就中心系统 (Achievement System) / 杭州印记与微观正反馈矩阵
> **状态**：全部 QA 通过 (VERDICT: PASS)

- **系统核心**：
  - 新增 `res://scripts/achievements.json`，构建 65 项精美成就，总成就点数 1040 🎖️，涵盖 6 大模块：
    - 🏞️ **人间西湖 (hangzhou)**：西湖十景集章、廿四风物志、杭帮名菜烹饪（东坡肉/龙井虾仁/叫化鸡）、西湖醋鱼劝退彩蛋、假摔碰瓷橘猫、西湖闲人等 21 项。
    - 📘 **学海无涯 (academics)**：刷题连击、单科登顶、奥赛金牌保送、六边形战士、晨读等 11 项。
    - 🌸 **青春羁绊 (social)**：动态立绘解锁、便服/运动装差分、微信深聊、生日送礼、心愿树祈福、知己阶段等 10 项。
    - 🎮 **闲暇微光 (minigames)**：手作奶茶黄金糖分、娃娃机一发入魂与清道夫、代号静音传纸条、羽毛球凌空击羽、快门光影大师等 7 项。
    - 🎭 **天地万象 (curiosities)**：高压逆风起飞、零食批发户、西湖烟雨漫步、月亮不睡我不睡、钱包鼓鼓等 6 项隐藏彩蛋。
    - 🏆 **光阴长卷 (milestones)**：五大社团毕业、全能王·西湖之夏、毕业合影、纪念册装订、通关结局与 NG+ 传承等 10 项。
  - 新增 `res://scripts/AchievementManager.gd` Autoload 服务单例：统一管理加载、条件判断、计数器（`quiz_correct_count`, `claw_won_count`, `cat_pet_count`, `visit_lakeside_count` 等）、状态派发与横幅播放队列。
  - 新增 `res://scripts/AchievementBannerUI.gd`：原神风格金黑玻璃质感、滑入回弹动画动效的即时成就达成弹窗。
  - 新增 `res://scripts/AchievementPopupUI.gd`：分类标签页、成就点数统计、双向筛选、已达成/未达成/隐藏神秘卡片呈现的完整成就中心弹窗。
  - **系统联动与持久化**：
    - `MainGame.gd` 更多菜单接入“🎖️ 成就中心”入口，支持地点漫步联动。
    - `EndingScreen.gd` 将 `achv_*` 前缀 flag 全集纳入跨周目快照与回注，保证玩家成就永久继承。
    - `QuizUI.gd`, `BobaTeaCraftUI.gd`, `ClawMachineUI.gd`, `PaperSlipStealthUI.gd`, `BadmintonRallyUI.gd`, `WestLakeShutterUI.gd`, `WeChatUI.gd`, `DialogueUI.gd`, `ShopUI.gd`, `LakesideWishesUI.gd` 全面埋入事件与成就触发钩子。
  - **质量门禁**：`tests/achievement_smoke/verify_qa.py` → **14/14 PASS, VERDICT: PASS**。

---

## 奥赛事件链层（DS-RN-05c）

> **更新日期**：2026-08-07
> **更新模块**：奥赛事件链 (Olympiad Event Chain) / 生活事件库 (Life Events Library)
> **状态**：全部 QA 通过

- **事件库重建**：`events_life.json` 从 1 条乱码事件完整重建为 **30 个事件**：
  - 24 条 `life_` 前缀生活事件（C线冲突链×4、F线家庭链×3、G线日常×17）
  - 6 条 `olympiad_` 前缀奥赛链事件（班主任密谈→三轮集训→市级初赛→省决赛金牌）
- **奥赛保送钩挂**：`ExamManager.gd` 的 `get_admission_result()` 开头拦截 `flag_olympiad_gold`，直接保送 hz2（西湖二中），绕过裸分结算。
- **UI 标记**：`StudySubjectPopup.gd` 数学科目行动态显示奥赛状态标签（集训中 / 金牌保送 / 已退赛）。
- **质量门禁**：`tests/olympiad_smoke/verify_qa.py` → **VERDICT: PASS**；`tests/life_smoke/validate_life.py` → **14/14 PASS，QUALITY GATE: CONCERNS（仅1条预期WARN）**。
- **测试脚本修复**：两个 QA 脚本顶部添加 `sys.stdout.reconfigure(encoding="utf-8")` 解决 Windows GBK 终端崩溃问题；`validate_life.py` 的 A2/A3 断言已适配 30 个事件（24+6）。

详细变更日志，请查阅 `docs/balance/olympiad_chain_changelog.md`（待补）。

---

## 社团目标层（DS-RN-05b）

> **更新日期**：2026-08-03
> **更新模块**：社团目标层 (Club Target Layer) / 社团画廊层 (Club Gallery Layer)
> **状态**：A 线交付完成

- **逻辑层**：`events_life.json` 中加入了 20 条社团相关的目标导向链事件 (`club_chain_<type>_s1..s4`)，用以在平时周末提供除了常规增加基础数值以外的长线成就奖励。当前事件总数已定版在 92 条（fest_smoke 测试通过）。
- **成就保留**：`EndingScreen.gd` 实现了带有成就和画廊系统旗标的软重置 (`GameManager.flags` 软重置白名单，`flag_club_achievement_*` 将在下个 NG+ 被继承回注）。门禁已经更新准入 `CLUB_ACHIEVEMENT_FLAGS` 和 `gallery_flags` 的判定许可（club_smoke 测试通过）。
- **画廊收集层**：对应新增的 5 张（5 个社团类型）毕业 CG 图片资产暂由 1280x720 纯色 JPG 取代，已落盘于 `assets/backgrounds/`（因缺少本机 Godot 二进制环境，未生成 `.import` 元文件，后继流程需自行处理）。Godot 工程端的配置逻辑，包括 UI 组件与 GameManager.gd 数据已开发完毕。
- **质量门禁层**：`tests/club_target_smoke/verify_qa.py` 中的 T11 递归死循环已经利用 `QA_MUTATION_DEPTH` 注入解决了问题，所有测试全面转亮（VERDICT: PASS）。

详细变更日志，请查阅 `docs/balance/club_target_layer_changelog.md`。

---

## 原神风全量成就系统（Achievement Center Subsystem）

> **更新日期**：2026-10-16
> **更新模块**：成就系统 (Achievement System) / 意想不到的彩蛋成就 / 杭州文化成就
> **状态**：全面交付完成，109个成就矩阵，全系统钩子联通

- **成就矩阵规格**：`scripts/achievements.json` 共收纳 **109** 个成就，总积分 **2155** 分，涵盖 6 大模块：
  - 🌸 **人间西湖 (hangzhou)**: 27项（西湖十景、风物烹饪、龙井问茶、钱塘弄潮、拱宸桥、西溪湿地等）
  - 📚 **学海无涯 (academics)**: 19项（满分卷系列、六边形战士、文理双状元、题海征服者、图书馆地缚灵等）
  - 🤝 **青春羁绊 (social)**: 15项（命定之羁绊、雨季同心伞、微信置顶好友、专属心愿礼物、独家秘密等）
  - 🎮 **闲暇微光 (minigames)**: 12项（金色传说抓娃娃、踏雪无痕传纸条、50连击羽毛球、三连神级快门、特级奶茶大师等）
  - 🎭 **天地万象 (curiosities)**: 22项（偏科之神、心跳临界点/压力98+、钱包比脸干净/0元、就差一厘米娃娃脱落、纸条掉过道、羽毛球上树、核能防身奶茶、碰瓷橘猫长期饭票、学神课间大睡、修罗场微风等）
  - 🏆 **光阴长卷 (milestones)**: 14项（百团大战体验家、校园理财大亨、无悔青春史诗、全画廊大圆满等）
- **核心单例与浮窗**：
  - `AchievementManager.gd`: Autoload 单例，负责成就匹配、组合衍生判定、计数器管理、横幅排队播放。
  - `AchievementBannerUI.gd`: 原神风金色渐变毛玻璃顶部滑入滑出横幅 Toast（带音效、光晕与微动效）。
  - `AchievementPopupUI.gd`: 全量成就中心弹窗，支持分类 Tab 切换、总分进度条、完成率仪表盘、已完成/未完成过滤、隐藏成就“？？？”脱敏。
- **全链路小游戏与系统联动**：
  - [MainGame.gd](file:///d:/zkgame/scripts/MainGame.gd) 主界面挂载 `🎖️ 成就中心` 入口与西湖漫步钩子。
  - [EndingScreen.gd](file:///d:/zkgame/scripts/EndingScreen.gd) 支持 NG+ 多周目成就与计数器永续继承。
  - [ClawMachineUI.gd](file:///d:/zkgame/scripts/minigames/ClawMachineUI.gd)、[PaperSlipStealthUI.gd](file:///d:/zkgame/scripts/minigames/PaperSlipStealthUI.gd)、[BadmintonRallyUI.gd](file:///d:/zkgame/scripts/minigames/BadmintonRallyUI.gd)、[WestLakeShutterUI.gd](file:///d:/zkgame/scripts/minigames/WestLakeShutterUI.gd)、[BobaTeaCraftUI.gd](file:///d:/zkgame/scripts/minigames/BobaTeaCraftUI.gd)、[WeChatUI.gd](file:///d:/zkgame/scripts/WeChatUI.gd)、[DialogueUI.gd](file:///d:/zkgame/scripts/DialogueUI.gd) 全面注入成就判定。
- **质量门禁**：`tests/achievement_smoke/verify_qa.py` 17 项全检通过 (`VERDICT: PASS`)。

---

## 全局音频管理系统（Audio & Sound System）

> **更新日期**：2026-10-16
> **更新模块**：音频管理系统 (AudioManager.gd) / 拟真原生WAV音效库 / BGM交叉淡入淡出
> **状态**：交付完成，全链路注入与门禁验证通过

- **音频架构与单例**：
  - `scripts/AudioManager.gd`: 注册为 `project.godot` Autoload 单例。
  - 双轨道播放器（Player A / Player B）实现平滑 Crossfade 交叉淡入淡出，避免切歌卡顿。
  - 8 通道 SFX 播放器对象池，支持多音效并发播放不截断；支持随机音高微调 (pitch variance) 杜绝机械重复感。
  - 提供全局主音量、BGM 音量、SFX 音量线性与 dB 转换控制接口。
- **内置原生无损 WAV 资源库** (`assets/audio/`):
  - `sfx/achievement_unlock.wav`: 原神风五度和弦琶音璀璨清亮钟鸣（C5→E5→G5→B5→C6）。
  - `sfx/ui_click.wav`: 清脆高级轻量按键点击音。
  - `sfx/ui_hover.wav`: 细腻微弱悬停音。
  - `sfx/ui_popup.wav`: 柔和上升式毛玻璃弹窗升腾音。
  - `sfx/camera_shutter.wav`: 单反相机快门双击微动音。
  - `sfx/coin_drop.wav`: 街机清脆金属投币叮当音。
  - `sfx/badminton_hit.wav`: 弹性羽毛球拍扣球声。
  - `sfx/paper_rustle.wav`: 课桌课下传纸条摩擦纸张声。
  - `bgm/bgm_peaceful_campus.wav`: 和缓舒畅的四和弦抒情校园环境氛围长循环曲。
- **全系统音效钩子注入**：
  - [AchievementBannerUI.gd](file:///d:/zkgame/scripts/AchievementBannerUI.gd)：横幅滑落时播放原神风璀璨解锁提示音。
  - [AchievementPopupUI.gd](file:///d:/zkgame/scripts/AchievementPopupUI.gd)：弹窗打开与 Tab 点击播放相应 UI 音。
  - [ClawMachineUI.gd](file:///d:/zkgame/scripts/minigames/ClawMachineUI.gd)：投币动作播放金属投币声。
  - [WestLakeShutterUI.gd](file:///d:/zkgame/scripts/minigames/WestLakeShutterUI.gd)：按下快门瞬间播放机械快门声。
  - [BadmintonRallyUI.gd](file:///d:/zkgame/scripts/minigames/BadmintonRallyUI.gd)：接球与绝杀暴扣播放球拍击打声。
  - [PaperSlipStealthUI.gd](file:///d:/zkgame/scripts/minigames/PaperSlipStealthUI.gd)：蓄力发射纸条播放纸张滑动声。
  - [MainGame.gd](file:///d:/zkgame/scripts/MainGame.gd)：进入游戏主场景自动平滑淡入校园环境 BGM。
- **质量门禁**：`tests/audio_smoke/verify_qa.py` 10 项全检通过 (`VERDICT: PASS`)。

---

## 全功能系统设置系统（System Settings Center）

> **更新日期**：2026-10-16
> **更新模块**：设置中心 (SettingsPopupUI.gd) / 持久化单例 (SettingsManager.gd) / ESC快捷键
> **状态**：交付完成，三层模块与门禁验证通过

- **持久化配置管理**：
  - `scripts/SettingsManager.gd`: 注册为 `project.godot` Autoload 单例，保存至 `user://settings.cfg`。
  - 自动管理 Master/BGM/SFX 音量滑块并在启动时应用到 `AudioManager`。
  - 支持窗口模式 (Windowed 1280x720 / Fullscreen) 与垂直同步 (VSync) 动态切换。
  - 支持打字机速度 (慢速/标准/极速/瞬间) 与自动播放延时联动。
- **现代化毛玻璃设置面板** (`scripts/SettingsPopupUI.gd`):
  - 🔊 **声音音效**：实时百分比显示，拉动 SFX 滑块即时播放反馈点击音。
  - 🖥️ **显示偏好**：窗口化与独占全屏一键切换、垂直同步开关。
  - 📖 **文本剧情**：4 档打字机速度、自动播放等待时长、快进未读剧情开关。
- **全链路入口注入**：
  - [MainGame.gd](file:///d:/zkgame/scripts/MainGame.gd) 更多菜单首项挂载 `⚙️ 系统设置`。
  - [MainGame.gd](file:///d:/zkgame/scripts/MainGame.gd) `_input` 接入全局 `KEY_ESCAPE` 键呼出/关闭设置。
  - [DialogueUI.gd](file:///d:/zkgame/scripts/DialogueUI.gd) 打字机 `type_text` 动态绑定 `SettingsManager.text_speed_idx`。
- **质量门禁**：`tests/settings_smoke/verify_qa.py` 5 项全检通过 (`VERDICT: PASS`)。



