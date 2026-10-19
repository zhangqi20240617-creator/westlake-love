# Game Design Document: 社团目标层 OQ-4「五社通」大成成就 (DS-RN-05c)

## 📌 一、项目概况 (Overview)
- **目标代号**：DS-RN-05c
- **子系统系属**：NG+ 继承系统向 / 游戏全收集向结束内容
- **核心一句话**：奖励那些游玩超过 5 个周目且精准全数体验了初中五个社团路线硬核玩家，为《西湖边的青春》赋予最高规格的“全能天才”毕业隐藏结局图。
- **设计基调**：零新 Autoload，完全依托于 Phase 1 分离且已就绪的现有 `GameManager` 与 `EndingScreen` 组件。

---

## 🎯 二、核心机制支柱 (Core Mechanics)

### 1. 跨周目数据继承检验 (NG+ Condition)
得益于此前工程的架构支持，目前 `EndingScreen.gd` 已经在所有周目结束时，通过重置逻辑将 `CLUB_ACHIEVEMENT_FLAGS` （总共 5 项）作为跨周目字典持续保存至磁盘中。
新的机制不再需要额外的变量追踪，只需在展示画廊或毕业动画时检查：
- `flag_club_achievement_literature`
- `flag_club_achievement_astronomy`
- `flag_club_achievement_broadcast`
- `flag_club_achievement_basketball`
- `flag_club_achievement_art`
这 5 个 Flag 是否在继承态或当前存档中处于 `true`。

### 2. 画廊与大结局植入路径 (Execution Path)
为了使得“五社通”充满仪式的荣誉感且代码侵入最小化：
* **不新增特殊的 UI 界面**。
* **在 `EndingScreen.gd` 的播放收尾或者结尾黑幕之后追加一秒检查判定**：
   - 玩家顺利中考毕业并播放完当前选择社团的单社团立绘后。
   - 检测如果集齐 5 张成就，直接抛出隐秘画廊触发的播报逻辑并将玩家转至“五社全通全彩 CG”。
   
### 3. “五社通”画廊条目 (Gallery Listing)
在画廊中加入一张独特的传说级藏品 `gallery_club_master`。位置安排在所有画廊的最顶端或单独页以作纪念。
- **名称**：【全能王·西湖之夏】
- **介绍文案**：“有人选择专精，有人选择广博。你化作了文体兼备的传说，这是专属于你的西湖之夏……”

---

## 🏗️ 三、实施方案建议与工程界限 (Engineering Boundaries)

### 1. 零 Autoload 侵入 (Zero-Autoload Constraint)
不得新设诸如 `ClubMasterManager` 之类的悬浮挂载。所有的判定代码均只能落脚于：
- `EndingScreen.gd` 的结尾 CG 调用判断中。
- `GameManager.gd` 内的 `GALLERY_ITEMS` 预设字块。

### 2. 软资产依赖 (Asset Dependencies)
- 需要生成一张独一无二的大一统插图作为大结局和画廊封面。
- **美术规格**：`assets/backgrounds/grad_club_master.jpg` (1280x720) 风格需展示校门和远处的西湖落日，或是多个社团器械的桌角拼盘特写。

### 3. 测试策略边界 (Testing scope)
不需要复杂的黑盒推演。只需在测试类中编写一个单测方法：利用 API 硬写入五个 achievement_flags，接着呼叫 `EndingScreen.trigger_ending()` 并断言结果数组中是否推入了大成 CG。

---

## 📏 四、红线与防腐

1. **不可干预单社团路线**：大成就只允许**顺势覆盖**或**延后发生**，不得夺取或压制最后一次通关所应有的最后一天正常体验与社团 CG。
2. **存档白名单机制校验**：须确认新追加的 `flag_club_achievement_master` 能否被正确接纳记录。
3. **数据幂等性**：即玩家完成六次或五次以上社团分支（有重复）时，代码也能借助字典机制忽略重叠，正常触发全收集识别。
