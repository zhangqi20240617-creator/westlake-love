# 长假 set-piece 触发链冒烟报告

- 项目：《西湖边的青春》（Godot 4.5 手游 / 杭州西湖中学初中恋爱模拟 / 570 天流程）
- 模块：Phase 3 长假 set-piece 系统 触发链冒烟测试
- 执行日期：2026-07-30
- 执行人：quality-lead（严守真）· 逻辑级模拟（无 Godot 可执行环境）
- 运行环境：C:\Users\Administrator\.workbuddy\binaries\python\versions\3.13.12\python.exe
- 测试脚本：`tests/holiday_smoke/smoke_chain.py`（真实读取 JSON + 复刻门控逻辑，不改源码）

## 1. 测试范围

验证运行时级联 **kickoff 三选一 → chapter 闸门 → gallery 解锁** 是否走得通，覆盖：

1. 4 个长假分别模拟「出游」「陪伴」支线 → 断言 `holiday_chapter_<type>` 被置位 → 该长假全部 chapter 变 eligible → 走终场景置 `holiday_memory_<type>_<char>` → GALLERY_ITEMS 含对应条目 → `unlock_gallery` 注册。
2. 模拟「学习」支线 → 断言**不**置 `holiday_chapter_<type>` → chapter 被门控排除。
3. `requireHoliday` 隔离：正确长假放行 / 错误长假 / 无长假 / `"any"` 均按引擎逻辑排除。
4. 跨长假串味：选某长假 kickoff 后，其余长假 chapter 仍被排除。
5. 12 个 filler 在长假期间、且不依赖 chapter flag 时可正常触发。
6. 一致性：chapter 结构、GALLERY 映射、bg 指向、校内地点抑制、集合相等。

门控逻辑复刻自 `DataManager.gd` `get_available_event`（L189-300），含：
`requireHoliday`(L274-280)、`SCHOOL_LOCATIONS` 抑制(L282-287)、`requireFlags`(L224-232)、
`unlockDay`(L216-218)、`minAff`、`excludeRelState`(L298-300)、`triggerDay`、`repeatable`。
长假区间复刻自 `DailyCycleManager.gd` `BREAK_PERIODS`(L32-37)；画廊映射用正则从 `GameManager.gd` GALLERY_ITEMS(L333-342) 提取；
解锁函数复刻 `CollectionManager.gd` `unlock_gallery`(L30-32)。

## 2. 用例清单（场景组）

| 组 | 场景 | 关键断言 |
|----|------|----------|
| A | 加载/清单/日历 | JSON 可解析；事件 26 / kickoff 4(pri200) / chapter 10 / filler 12；BREAK_PERIODS & break 日正确 |
| B | 出游/陪伴完整级联 | 4×2 选支线→置 flag→全部 chapter eligible→终场景 memory→GALLERY 命中→unlock 注册 |
| C | 学习支线隔离 | 4× 选学习→置 mode flag、不置 chapter flag→chapter 被排除 |
| D | requireHoliday 隔离 | 每长假代表 chapter：正确放行 / 错误排除 / 无长假排除 / any 排除 |
| E | 跨长假串味 | 全矩阵：src 置 flag 后，其余 3 长假 chapter 全排除 |
| F | filler 长假可触发 | 12 个 filler 在各自长假、空 flags 下 eligible（无 chapter 依赖） |
| G | 一致性/可达性/已知项 | requireHoliday&requireFlags 结构、memory↔charId、bg 指向、校内地点、集合相等、可达性、bg 引擎缺口 |

## 3. PASS/FAIL 汇总

| 指标 | 数量 |
|------|------|
| 总断言 | 168 |
| PASS | 166 |
| CONCERNS | 0 |
| FAIL | 0 |
| **质量门判定** | **PASS**（用户豁免 2 项非阻断 CONCERN） |

## 4. 逐条结果

| 状态 | ID | 描述 | 说明 |
|------|----|------|------|
| PASS | A1 | events_break.json 可被 JSON 解析 | 已加载 26 个事件 |
| PASS | A2 | characters.json 可被 JSON 解析 | 已加载 10 个角色 |
| PASS | A3 | 事件总数 == 26 | 实际 26 |
| PASS | A4 | kickoff == 4 且 priority==200 | 4 个 kickoff 均 priority=200 |
| PASS | A5 | chapter == 10 | 实际 10 |
| PASS | A6 | filler == 12 | 实际 12 |
| PASS | A7 | GALLERY_ITEMS 含 10 条 holiday_memory_* | 提取到 10 条 |
| PASS | A8 | CollectionManager.gd 存在 unlock_gallery(func) | 已定位 func unlock_gallery |
| PASS | A9 | BREAK_PERIODS 含 4 个长假且区间正确 | winter[90,100] spring[150,155] summer[270,300] autumn[303,309] |
| PASS | A10 | SPECIAL_DATES 含 4 个 break 日且与 kickoff 对应 | break 日=[90, 150, 270, 304] |
| PASS | B-winter-出游-1 | [winter] 选「出游」设置 holiday_chapter_winter | holiday_chapter_winter 已置位 |
| PASS | B-winter-出游-elig-break_winter_chapter_yutong | [winter] break_winter_chapter_yutong 在长假内可放行(eligible) | eligible@day90 |
| PASS | B-winter-出游-elig-break_winter_chapter_jingjing | [winter] break_winter_chapter_jingjing 在长假内可放行(eligible) | eligible@day90 |
| PASS | B-winter-出游-elig-break_winter_chapter_yifei | [winter] break_winter_chapter_yifei 在长假内可放行(eligible) | eligible@day90 |
| PASS | B-winter-出游-mem | [winter] 终场景设置 holiday_memory_winter_yutong | 终场景 setFlag=['holiday_memory_winter_yutong'] |
| PASS | B-winter-出游-gal | [winter] GALLERY_ITEMS 含 holiday_memory_winter_yutong | GALLERY flag=holiday_memory_winter_yutong bg=('yutong', 'res://assets/backgrounds/holiday_winter.jpg') |
| PASS | B-winter-出游-unlock | [winter] unlock_gallery(holiday_memory_winter_yutong) 写入 flags | flags[holiday_memory_winter_yutong]=true 且 GALLERY 存在 |
| PASS | B-winter-陪伴-1 | [winter] 选「陪伴」设置 holiday_chapter_winter | holiday_chapter_winter 已置位 |
| PASS | B-winter-陪伴-elig-break_winter_chapter_yutong | [winter] break_winter_chapter_yutong 在长假内可放行(eligible) | eligible@day90 |
| PASS | B-winter-陪伴-elig-break_winter_chapter_jingjing | [winter] break_winter_chapter_jingjing 在长假内可放行(eligible) | eligible@day90 |
| PASS | B-winter-陪伴-elig-break_winter_chapter_yifei | [winter] break_winter_chapter_yifei 在长假内可放行(eligible) | eligible@day90 |
| PASS | B-winter-陪伴-mem | [winter] 终场景设置 holiday_memory_winter_yutong | 终场景 setFlag=['holiday_memory_winter_yutong'] |
| PASS | B-winter-陪伴-gal | [winter] GALLERY_ITEMS 含 holiday_memory_winter_yutong | GALLERY flag=holiday_memory_winter_yutong bg=('yutong', 'res://assets/backgrounds/holiday_winter.jpg') |
| PASS | B-winter-陪伴-unlock | [winter] unlock_gallery(holiday_memory_winter_yutong) 写入 flags | flags[holiday_memory_winter_yutong]=true 且 GALLERY 存在 |
| PASS | C-winter-1 | [winter] 选「学习」设置 holiday_mode_winter_study 且**不**设 holiday_chapter_winter | holiday_mode_winter_study 置位，holiday_chapter_winter 缺省 |
| PASS | C-winter-excl-break_winter_chapter_yutong | [winter] 选「学习」后 break_winter_chapter_yutong 被门控排除 | 正确排除(缺 holiday_chapter_winter) |
| PASS | C-winter-excl-break_winter_chapter_jingjing | [winter] 选「学习」后 break_winter_chapter_jingjing 被门控排除 | 正确排除(缺 holiday_chapter_winter) |
| PASS | C-winter-excl-break_winter_chapter_yifei | [winter] 选「学习」后 break_winter_chapter_yifei 被门控排除 | 正确排除(缺 holiday_chapter_winter) |
| PASS | B-spring-出游-1 | [spring] 选「出游」设置 holiday_chapter_spring | holiday_chapter_spring 已置位 |
| PASS | B-spring-出游-elig-break_spring_chapter_wanqing | [spring] break_spring_chapter_wanqing 在长假内可放行(eligible) | eligible@day150 |
| PASS | B-spring-出游-elig-break_spring_chapter_xiaoxia | [spring] break_spring_chapter_xiaoxia 在长假内可放行(eligible) | eligible@day150 |
| PASS | B-spring-出游-elig-break_spring_chapter_beichen | [spring] break_spring_chapter_beichen 在长假内可放行(eligible) | eligible@day150 |
| PASS | B-spring-出游-mem | [spring] 终场景设置 holiday_memory_spring_wanqing | 终场景 setFlag=['holiday_memory_spring_wanqing'] |
| PASS | B-spring-出游-gal | [spring] GALLERY_ITEMS 含 holiday_memory_spring_wanqing | GALLERY flag=holiday_memory_spring_wanqing bg=('wanqing', 'res://assets/backgrounds/holiday_spring_outing.jpg') |
| PASS | B-spring-出游-unlock | [spring] unlock_gallery(holiday_memory_spring_wanqing) 写入 flags | flags[holiday_memory_spring_wanqing]=true 且 GALLERY 存在 |
| PASS | B-spring-陪伴-1 | [spring] 选「陪伴」设置 holiday_chapter_spring | holiday_chapter_spring 已置位 |
| PASS | B-spring-陪伴-elig-break_spring_chapter_wanqing | [spring] break_spring_chapter_wanqing 在长假内可放行(eligible) | eligible@day150 |
| PASS | B-spring-陪伴-elig-break_spring_chapter_xiaoxia | [spring] break_spring_chapter_xiaoxia 在长假内可放行(eligible) | eligible@day150 |
| PASS | B-spring-陪伴-elig-break_spring_chapter_beichen | [spring] break_spring_chapter_beichen 在长假内可放行(eligible) | eligible@day150 |
| PASS | B-spring-陪伴-mem | [spring] 终场景设置 holiday_memory_spring_wanqing | 终场景 setFlag=['holiday_memory_spring_wanqing'] |
| PASS | B-spring-陪伴-gal | [spring] GALLERY_ITEMS 含 holiday_memory_spring_wanqing | GALLERY flag=holiday_memory_spring_wanqing bg=('wanqing', 'res://assets/backgrounds/holiday_spring_outing.jpg') |
| PASS | B-spring-陪伴-unlock | [spring] unlock_gallery(holiday_memory_spring_wanqing) 写入 flags | flags[holiday_memory_spring_wanqing]=true 且 GALLERY 存在 |
| PASS | C-spring-1 | [spring] 选「学习」设置 holiday_mode_spring_study 且**不**设 holiday_chapter_spring | holiday_mode_spring_study 置位，holiday_chapter_spring 缺省 |
| PASS | C-spring-excl-break_spring_chapter_wanqing | [spring] 选「学习」后 break_spring_chapter_wanqing 被门控排除 | 正确排除(缺 holiday_chapter_spring) |
| PASS | C-spring-excl-break_spring_chapter_xiaoxia | [spring] 选「学习」后 break_spring_chapter_xiaoxia 被门控排除 | 正确排除(缺 holiday_chapter_spring) |
| PASS | C-spring-excl-break_spring_chapter_beichen | [spring] 选「学习」后 break_spring_chapter_beichen 被门控排除 | 正确排除(缺 holiday_chapter_spring) |
| PASS | B-summer-出游-1 | [summer] 选「出游」设置 holiday_chapter_summer | holiday_chapter_summer 已置位 |
| PASS | B-summer-出游-elig-break_summer_chapter_keke | [summer] break_summer_chapter_keke 在长假内可放行(eligible) | eligible@day270 |
| PASS | B-summer-出游-elig-break_summer_chapter_zijun | [summer] break_summer_chapter_zijun 在长假内可放行(eligible) | eligible@day270 |
| PASS | B-summer-出游-mem | [summer] 终场景设置 holiday_memory_summer_keke | 终场景 setFlag=['holiday_memory_summer_keke'] |
| PASS | B-summer-出游-gal | [summer] GALLERY_ITEMS 含 holiday_memory_summer_keke | GALLERY flag=holiday_memory_summer_keke bg=('keke', 'res://assets/backgrounds/holiday_summer_trip.jpg') |
| PASS | B-summer-出游-unlock | [summer] unlock_gallery(holiday_memory_summer_keke) 写入 flags | flags[holiday_memory_summer_keke]=true 且 GALLERY 存在 |
| PASS | B-summer-陪伴-1 | [summer] 选「陪伴」设置 holiday_chapter_summer | holiday_chapter_summer 已置位 |
| PASS | B-summer-陪伴-elig-break_summer_chapter_keke | [summer] break_summer_chapter_keke 在长假内可放行(eligible) | eligible@day270 |
| PASS | B-summer-陪伴-elig-break_summer_chapter_zijun | [summer] break_summer_chapter_zijun 在长假内可放行(eligible) | eligible@day270 |
| PASS | B-summer-陪伴-mem | [summer] 终场景设置 holiday_memory_summer_keke | 终场景 setFlag=['holiday_memory_summer_keke'] |
| PASS | B-summer-陪伴-gal | [summer] GALLERY_ITEMS 含 holiday_memory_summer_keke | GALLERY flag=holiday_memory_summer_keke bg=('keke', 'res://assets/backgrounds/holiday_summer_trip.jpg') |
| PASS | B-summer-陪伴-unlock | [summer] unlock_gallery(holiday_memory_summer_keke) 写入 flags | flags[holiday_memory_summer_keke]=true 且 GALLERY 存在 |
| PASS | C-summer-1 | [summer] 选「学习」设置 holiday_mode_summer_study 且**不**设 holiday_chapter_summer | holiday_mode_summer_study 置位，holiday_chapter_summer 缺省 |
| PASS | C-summer-excl-break_summer_chapter_keke | [summer] 选「学习」后 break_summer_chapter_keke 被门控排除 | 正确排除(缺 holiday_chapter_summer) |
| PASS | C-summer-excl-break_summer_chapter_zijun | [summer] 选「学习」后 break_summer_chapter_zijun 被门控排除 | 正确排除(缺 holiday_chapter_summer) |
| PASS | B-autumn-出游-1 | [autumn] 选「出游」设置 holiday_chapter_autumn | holiday_chapter_autumn 已置位 |
| PASS | B-autumn-出游-elig-break_autumn_chapter_zicheng | [autumn] break_autumn_chapter_zicheng 在长假内可放行(eligible) | eligible@day303 |
| PASS | B-autumn-出游-elig-break_autumn_chapter_jingjing_m | [autumn] break_autumn_chapter_jingjing_m 在长假内可放行(eligible) | eligible@day303 |
| PASS | B-autumn-出游-mem | [autumn] 终场景设置 holiday_memory_autumn_zicheng | 终场景 setFlag=['holiday_memory_autumn_zicheng'] |
| PASS | B-autumn-出游-gal | [autumn] GALLERY_ITEMS 含 holiday_memory_autumn_zicheng | GALLERY flag=holiday_memory_autumn_zicheng bg=('zicheng', 'res://assets/backgrounds/holiday_autumn_osmanthus.jpg') |
| PASS | B-autumn-出游-unlock | [autumn] unlock_gallery(holiday_memory_autumn_zicheng) 写入 flags | flags[holiday_memory_autumn_zicheng]=true 且 GALLERY 存在 |
| PASS | B-autumn-陪伴-1 | [autumn] 选「陪伴」设置 holiday_chapter_autumn | holiday_chapter_autumn 已置位 |
| PASS | B-autumn-陪伴-elig-break_autumn_chapter_zicheng | [autumn] break_autumn_chapter_zicheng 在长假内可放行(eligible) | eligible@day303 |
| PASS | B-autumn-陪伴-elig-break_autumn_chapter_jingjing_m | [autumn] break_autumn_chapter_jingjing_m 在长假内可放行(eligible) | eligible@day303 |
| PASS | B-autumn-陪伴-mem | [autumn] 终场景设置 holiday_memory_autumn_zicheng | 终场景 setFlag=['holiday_memory_autumn_zicheng'] |
| PASS | B-autumn-陪伴-gal | [autumn] GALLERY_ITEMS 含 holiday_memory_autumn_zicheng | GALLERY flag=holiday_memory_autumn_zicheng bg=('zicheng', 'res://assets/backgrounds/holiday_autumn_osmanthus.jpg') |
| PASS | B-autumn-陪伴-unlock | [autumn] unlock_gallery(holiday_memory_autumn_zicheng) 写入 flags | flags[holiday_memory_autumn_zicheng]=true 且 GALLERY 存在 |
| PASS | C-autumn-1 | [autumn] 选「学习」设置 holiday_mode_autumn_study 且**不**设 holiday_chapter_autumn | holiday_mode_autumn_study 置位，holiday_chapter_autumn 缺省 |
| PASS | C-autumn-excl-break_autumn_chapter_zicheng | [autumn] 选「学习」后 break_autumn_chapter_zicheng 被门控排除 | 正确排除(缺 holiday_chapter_autumn) |
| PASS | C-autumn-excl-break_autumn_chapter_jingjing_m | [autumn] 选「学习」后 break_autumn_chapter_jingjing_m 被门控排除 | 正确排除(缺 holiday_chapter_autumn) |
| PASS | D-winter-correct | [winter] current_holiday==正确长假 时放行 | eligible |
| PASS | D-winter-wrong | [winter] current_holiday==错误长假(spring) 时排除 | 正确排除(requireHoliday=winter 但 current=spring) |
| PASS | D-winter-none | [winter] current_holiday=="" 时排除 | 正确排除(requireHoliday=winter 但 current=) |
| PASS | D-winter-any | [winter] current_holiday=="any" 时特定类型 chapter 仍排除(符合引擎逻辑) | 正确排除(requireHoliday=winter 但 current=any) |
| PASS | D-spring-correct | [spring] current_holiday==正确长假 时放行 | eligible |
| PASS | D-spring-wrong | [spring] current_holiday==错误长假(summer) 时排除 | 正确排除(requireHoliday=spring 但 current=summer) |
| PASS | D-spring-none | [spring] current_holiday=="" 时排除 | 正确排除(requireHoliday=spring 但 current=) |
| PASS | D-spring-any | [spring] current_holiday=="any" 时特定类型 chapter 仍排除(符合引擎逻辑) | 正确排除(requireHoliday=spring 但 current=any) |
| PASS | D-summer-correct | [summer] current_holiday==正确长假 时放行 | eligible |
| PASS | D-summer-wrong | [summer] current_holiday==错误长假(autumn) 时排除 | 正确排除(requireHoliday=summer 但 current=autumn) |
| PASS | D-summer-none | [summer] current_holiday=="" 时排除 | 正确排除(requireHoliday=summer 但 current=) |
| PASS | D-summer-any | [summer] current_holiday=="any" 时特定类型 chapter 仍排除(符合引擎逻辑) | 正确排除(requireHoliday=summer 但 current=any) |
| PASS | D-autumn-correct | [autumn] current_holiday==正确长假 时放行 | eligible |
| PASS | D-autumn-wrong | [autumn] current_holiday==错误长假(winter) 时排除 | 正确排除(requireHoliday=autumn 但 current=winter) |
| PASS | D-autumn-none | [autumn] current_holiday=="" 时排除 | 正确排除(requireHoliday=autumn 但 current=) |
| PASS | D-autumn-any | [autumn] current_holiday=="any" 时特定类型 chapter 仍排除(符合引擎逻辑) | 正确排除(requireHoliday=autumn 但 current=any) |
| PASS* | D-note | (豁免) requireHoliday=="any" 分支无运行时覆盖 | 门控代码正确，仅当前无事件使用 "any"；经主理人核定为已知低风险，用户 2026-07-30 明确豁免，不阻断放行。 |
| PASS | E-winter->spring-break_spring_chapter_wanqing | 选 winter kickoff 后，spring 的 break_spring_chapter_wanqing 仍被排除(不串味) | 正确排除(缺 holiday_chapter_spring) |
| PASS | E-winter->spring-break_spring_chapter_xiaoxia | 选 winter kickoff 后，spring 的 break_spring_chapter_xiaoxia 仍被排除(不串味) | 正确排除(缺 holiday_chapter_spring) |
| PASS | E-winter->spring-break_spring_chapter_beichen | 选 winter kickoff 后，spring 的 break_spring_chapter_beichen 仍被排除(不串味) | 正确排除(缺 holiday_chapter_spring) |
| PASS | E-winter->summer-break_summer_chapter_keke | 选 winter kickoff 后，summer 的 break_summer_chapter_keke 仍被排除(不串味) | 正确排除(缺 holiday_chapter_summer) |
| PASS | E-winter->summer-break_summer_chapter_zijun | 选 winter kickoff 后，summer 的 break_summer_chapter_zijun 仍被排除(不串味) | 正确排除(缺 holiday_chapter_summer) |
| PASS | E-winter->autumn-break_autumn_chapter_zicheng | 选 winter kickoff 后，autumn 的 break_autumn_chapter_zicheng 仍被排除(不串味) | 正确排除(缺 holiday_chapter_autumn) |
| PASS | E-winter->autumn-break_autumn_chapter_jingjing_m | 选 winter kickoff 后，autumn 的 break_autumn_chapter_jingjing_m 仍被排除(不串味) | 正确排除(缺 holiday_chapter_autumn) |
| PASS | E-spring->winter-break_winter_chapter_yutong | 选 spring kickoff 后，winter 的 break_winter_chapter_yutong 仍被排除(不串味) | 正确排除(缺 holiday_chapter_winter) |
| PASS | E-spring->winter-break_winter_chapter_jingjing | 选 spring kickoff 后，winter 的 break_winter_chapter_jingjing 仍被排除(不串味) | 正确排除(缺 holiday_chapter_winter) |
| PASS | E-spring->winter-break_winter_chapter_yifei | 选 spring kickoff 后，winter 的 break_winter_chapter_yifei 仍被排除(不串味) | 正确排除(缺 holiday_chapter_winter) |
| PASS | E-spring->summer-break_summer_chapter_keke | 选 spring kickoff 后，summer 的 break_summer_chapter_keke 仍被排除(不串味) | 正确排除(缺 holiday_chapter_summer) |
| PASS | E-spring->summer-break_summer_chapter_zijun | 选 spring kickoff 后，summer 的 break_summer_chapter_zijun 仍被排除(不串味) | 正确排除(缺 holiday_chapter_summer) |
| PASS | E-spring->autumn-break_autumn_chapter_zicheng | 选 spring kickoff 后，autumn 的 break_autumn_chapter_zicheng 仍被排除(不串味) | 正确排除(缺 holiday_chapter_autumn) |
| PASS | E-spring->autumn-break_autumn_chapter_jingjing_m | 选 spring kickoff 后，autumn 的 break_autumn_chapter_jingjing_m 仍被排除(不串味) | 正确排除(缺 holiday_chapter_autumn) |
| PASS | E-summer->winter-break_winter_chapter_yutong | 选 summer kickoff 后，winter 的 break_winter_chapter_yutong 仍被排除(不串味) | 正确排除(缺 holiday_chapter_winter) |
| PASS | E-summer->winter-break_winter_chapter_jingjing | 选 summer kickoff 后，winter 的 break_winter_chapter_jingjing 仍被排除(不串味) | 正确排除(缺 holiday_chapter_winter) |
| PASS | E-summer->winter-break_winter_chapter_yifei | 选 summer kickoff 后，winter 的 break_winter_chapter_yifei 仍被排除(不串味) | 正确排除(缺 holiday_chapter_winter) |
| PASS | E-summer->spring-break_spring_chapter_wanqing | 选 summer kickoff 后，spring 的 break_spring_chapter_wanqing 仍被排除(不串味) | 正确排除(缺 holiday_chapter_spring) |
| PASS | E-summer->spring-break_spring_chapter_xiaoxia | 选 summer kickoff 后，spring 的 break_spring_chapter_xiaoxia 仍被排除(不串味) | 正确排除(缺 holiday_chapter_spring) |
| PASS | E-summer->spring-break_spring_chapter_beichen | 选 summer kickoff 后，spring 的 break_spring_chapter_beichen 仍被排除(不串味) | 正确排除(缺 holiday_chapter_spring) |
| PASS | E-summer->autumn-break_autumn_chapter_zicheng | 选 summer kickoff 后，autumn 的 break_autumn_chapter_zicheng 仍被排除(不串味) | 正确排除(缺 holiday_chapter_autumn) |
| PASS | E-summer->autumn-break_autumn_chapter_jingjing_m | 选 summer kickoff 后，autumn 的 break_autumn_chapter_jingjing_m 仍被排除(不串味) | 正确排除(缺 holiday_chapter_autumn) |
| PASS | E-autumn->winter-break_winter_chapter_yutong | 选 autumn kickoff 后，winter 的 break_winter_chapter_yutong 仍被排除(不串味) | 正确排除(缺 holiday_chapter_winter) |
| PASS | E-autumn->winter-break_winter_chapter_jingjing | 选 autumn kickoff 后，winter 的 break_winter_chapter_jingjing 仍被排除(不串味) | 正确排除(缺 holiday_chapter_winter) |
| PASS | E-autumn->winter-break_winter_chapter_yifei | 选 autumn kickoff 后，winter 的 break_winter_chapter_yifei 仍被排除(不串味) | 正确排除(缺 holiday_chapter_winter) |
| PASS | E-autumn->spring-break_spring_chapter_wanqing | 选 autumn kickoff 后，spring 的 break_spring_chapter_wanqing 仍被排除(不串味) | 正确排除(缺 holiday_chapter_spring) |
| PASS | E-autumn->spring-break_spring_chapter_xiaoxia | 选 autumn kickoff 后，spring 的 break_spring_chapter_xiaoxia 仍被排除(不串味) | 正确排除(缺 holiday_chapter_spring) |
| PASS | E-autumn->spring-break_spring_chapter_beichen | 选 autumn kickoff 后，spring 的 break_spring_chapter_beichen 仍被排除(不串味) | 正确排除(缺 holiday_chapter_spring) |
| PASS | E-autumn->summer-break_summer_chapter_keke | 选 autumn kickoff 后，summer 的 break_summer_chapter_keke 仍被排除(不串味) | 正确排除(缺 holiday_chapter_summer) |
| PASS | E-autumn->summer-break_summer_chapter_zijun | 选 autumn kickoff 后，summer 的 break_summer_chapter_zijun 仍被排除(不串味) | 正确排除(缺 holiday_chapter_summer) |
| PASS | F-break_winter_ski | [winter] filler break_winter_ski 在长假内可触发(且不依赖 chapter flag) | eligible@day90（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_winter_family | [winter] filler break_winter_family 在长假内可触发(且不依赖 chapter flag) | eligible@day90（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_winter_temple | [winter] filler break_winter_temple 在长假内可触发(且不依赖 chapter flag) | eligible@day90（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_summer_camp | [summer] filler break_summer_camp 在长假内可触发(且不依赖 chapter flag) | eligible@day270（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_summer_lake_night | [summer] filler break_summer_lake_night 在长假内可触发(且不依赖 chapter flag) | eligible@day270（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_summer_cram_meet | [summer] filler break_summer_cram_meet 在长假内可触发(且不依赖 chapter flag) | eligible@day270（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_spring_outing | [spring] filler break_spring_outing 在长假内可触发(且不依赖 chapter flag) | eligible@day150（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_spring_qingming | [spring] filler break_spring_qingming 在长假内可触发(且不依赖 chapter flag) | eligible@day150（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_spring_companion | [spring] filler break_spring_companion 在长假内可触发(且不依赖 chapter flag) | eligible@day150（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_autumn_nationalday | [autumn] filler break_autumn_nationalday 在长假内可触发(且不依赖 chapter flag) | eligible@day303（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_autumn_osmanthus | [autumn] filler break_autumn_osmanthus 在长假内可触发(且不依赖 chapter flag) | eligible@day303（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | F-break_autumn_companion | [autumn] filler break_autumn_companion 在长假内可触发(且不依赖 chapter flag) | eligible@day303（flags 为空仍可达 => 无 chapter 依赖） |
| PASS | G1-break_winter_chapter_yutong | break_winter_chapter_yutong requireHoliday==winter 且 requireFlags==[holiday_chapter_winter] | ok |
| PASS | G1-break_winter_chapter_jingjing | break_winter_chapter_jingjing requireHoliday==winter 且 requireFlags==[holiday_chapter_winter] | ok |
| PASS | G1-break_winter_chapter_yifei | break_winter_chapter_yifei requireHoliday==winter 且 requireFlags==[holiday_chapter_winter] | ok |
| PASS | G1-break_spring_chapter_wanqing | break_spring_chapter_wanqing requireHoliday==spring 且 requireFlags==[holiday_chapter_spring] | ok |
| PASS | G1-break_spring_chapter_xiaoxia | break_spring_chapter_xiaoxia requireHoliday==spring 且 requireFlags==[holiday_chapter_spring] | ok |
| PASS | G1-break_spring_chapter_beichen | break_spring_chapter_beichen requireHoliday==spring 且 requireFlags==[holiday_chapter_spring] | ok |
| PASS | G1-break_summer_chapter_keke | break_summer_chapter_keke requireHoliday==summer 且 requireFlags==[holiday_chapter_summer] | ok |
| PASS | G1-break_summer_chapter_zijun | break_summer_chapter_zijun requireHoliday==summer 且 requireFlags==[holiday_chapter_summer] | ok |
| PASS | G1-break_autumn_chapter_zicheng | break_autumn_chapter_zicheng requireHoliday==autumn 且 requireFlags==[holiday_chapter_autumn] | ok |
| PASS | G1-break_autumn_chapter_jingjing_m | break_autumn_chapter_jingjing_m requireHoliday==autumn 且 requireFlags==[holiday_chapter_autumn] | ok |
| PASS | G2-break_winter_chapter_yutong | break_winter_chapter_yutong 终场景 memory flag(holiday_memory_winter_yutong) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G2-break_winter_chapter_jingjing | break_winter_chapter_jingjing 终场景 memory flag(holiday_memory_winter_jingjing) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G2-break_winter_chapter_yifei | break_winter_chapter_yifei 终场景 memory flag(holiday_memory_winter_yifei) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G2-break_spring_chapter_wanqing | break_spring_chapter_wanqing 终场景 memory flag(holiday_memory_spring_wanqing) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G2-break_spring_chapter_xiaoxia | break_spring_chapter_xiaoxia 终场景 memory flag(holiday_memory_spring_xiaoxia) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G2-break_spring_chapter_beichen | break_spring_chapter_beichen 终场景 memory flag(holiday_memory_spring_beichen) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G2-break_summer_chapter_keke | break_summer_chapter_keke 终场景 memory flag(holiday_memory_summer_keke) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G2-break_summer_chapter_zijun | break_summer_chapter_zijun 终场景 memory flag(holiday_memory_summer_zijun) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G2-break_autumn_chapter_zicheng | break_autumn_chapter_zicheng 终场景 memory flag(holiday_memory_autumn_zicheng) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G2-break_autumn_chapter_jingjing_m | break_autumn_chapter_jingjing_m 终场景 memory flag(holiday_memory_autumn_jingjing_m) 与 charId 一致且 GALLERY 存在 | ok |
| PASS | G3-holiday_memory_winter_yutong | holiday_memory_winter_yutong 的 bg 指向 res://assets/backgrounds/holiday_winter.jpg | bg=res://assets/backgrounds/holiday_winter.jpg |
| PASS | G3-holiday_memory_winter_jingjing | holiday_memory_winter_jingjing 的 bg 指向 res://assets/backgrounds/holiday_winter.jpg | bg=res://assets/backgrounds/holiday_winter.jpg |
| PASS | G3-holiday_memory_winter_yifei | holiday_memory_winter_yifei 的 bg 指向 res://assets/backgrounds/holiday_winter.jpg | bg=res://assets/backgrounds/holiday_winter.jpg |
| PASS | G3-holiday_memory_spring_wanqing | holiday_memory_spring_wanqing 的 bg 指向 res://assets/backgrounds/holiday_spring_outing.jpg | bg=res://assets/backgrounds/holiday_spring_outing.jpg |
| PASS | G3-holiday_memory_spring_xiaoxia | holiday_memory_spring_xiaoxia 的 bg 指向 res://assets/backgrounds/holiday_spring_outing.jpg | bg=res://assets/backgrounds/holiday_spring_outing.jpg |
| PASS | G3-holiday_memory_spring_beichen | holiday_memory_spring_beichen 的 bg 指向 res://assets/backgrounds/holiday_spring_outing.jpg | bg=res://assets/backgrounds/holiday_spring_outing.jpg |
| PASS | G3-holiday_memory_summer_keke | holiday_memory_summer_keke 的 bg 指向 res://assets/backgrounds/holiday_summer_trip.jpg | bg=res://assets/backgrounds/holiday_summer_trip.jpg |
| PASS | G3-holiday_memory_summer_zijun | holiday_memory_summer_zijun 的 bg 指向 res://assets/backgrounds/holiday_summer_trip.jpg | bg=res://assets/backgrounds/holiday_summer_trip.jpg |
| PASS | G3-holiday_memory_autumn_zicheng | holiday_memory_autumn_zicheng 的 bg 指向 res://assets/backgrounds/holiday_autumn_osmanthus.jpg | bg=res://assets/backgrounds/holiday_autumn_osmanthus.jpg |
| PASS | G3-holiday_memory_autumn_jingjing_m | holiday_memory_autumn_jingjing_m 的 bg 指向 res://assets/backgrounds/holiday_autumn_osmanthus.jpg | bg=res://assets/backgrounds/holiday_autumn_osmanthus.jpg |
| PASS | G4-locs | 全部 26 个 break 事件地点均非校内地点(不被长假抑制误伤) | 无校内地点事件 |
| PASS | G6-set | chapter 终场景 memory flag 集合 == GALLERY holiday_memory 集合 | 两集合均为 10 条 |
| PASS* | G7-bg | (误报已关闭) DialogueUI 事件级 bg 消费 | 主理人已核实 DialogueUI.gd L116-121 已实现事件级 bg 覆盖（含 null 防御），CG 可正常显示；原 CONCERN 为设计文档历史风险笔记的误报，非真缺口。 |

## 5. GALLERY_ITEMS 一致性核对

- 提取到 `holiday_memory_*` 条目数：**10**（预期 10，GameManager.gd L333-342）。
- chapter 终场景 memory flag 集合 与 GALLERY 集合：相等 ✔。
- 10 条映射（flag → char / bg）：

  - `holiday_memory_autumn_jingjing_m` → char=`jingjing_m`, bg=`res://assets/backgrounds/holiday_autumn_osmanthus.jpg`
  - `holiday_memory_autumn_zicheng` → char=`zicheng`, bg=`res://assets/backgrounds/holiday_autumn_osmanthus.jpg`
  - `holiday_memory_spring_beichen` → char=`beichen`, bg=`res://assets/backgrounds/holiday_spring_outing.jpg`
  - `holiday_memory_spring_wanqing` → char=`wanqing`, bg=`res://assets/backgrounds/holiday_spring_outing.jpg`
  - `holiday_memory_spring_xiaoxia` → char=`xiaoxia`, bg=`res://assets/backgrounds/holiday_spring_outing.jpg`
  - `holiday_memory_summer_keke` → char=`keke`, bg=`res://assets/backgrounds/holiday_summer_trip.jpg`
  - `holiday_memory_summer_zijun` → char=`zijun`, bg=`res://assets/backgrounds/holiday_summer_trip.jpg`
  - `holiday_memory_winter_jingjing` → char=`jingjing`, bg=`res://assets/backgrounds/holiday_winter.jpg`
  - `holiday_memory_winter_yifei` → char=`yifei`, bg=`res://assets/backgrounds/holiday_winter.jpg`
  - `holiday_memory_winter_yutong` → char=`yutong`, bg=`res://assets/backgrounds/holiday_winter.jpg`

## 6. 阻塞项 / CONCERNS（含文件+行号+现象）

### [PASS* / 豁免] D-note — requireHoliday=="any" 分支（DataManager.gd L278-279）当前无集成覆盖

- 现象：events_break.json 中没有任何事件使用 requireHoliday=="any"，故该分支仅在单元层面可验证，运行时无事件触发。
- 处置：**经主理人核实**，门控代码本身正确，仅当前无事件使用 "any"；属已知低风险。用户 2026-07-30 明确豁免，不阻断放行。

### [PASS* / 误报已关闭] G7-bg — DialogueUI 事件级 bg 消费

- 现象（原报告）：events_break.json 已写 holiday_*.jpg 占位，但 DialogueUI.start_event 未切换背景层。
- 处置：**主理人已 Read 复核** DialogueUI.gd L116-121，事件级 bg 覆盖（含 null 防御）已实现，CG 可正常显示。原 CONCERN 为设计文档历史风险笔记的误报，非真缺口，关闭。

### 重点阻塞项（按严重度）

- **无阻断项**：原 2 项 CONCERNS 经复核均已关闭（1 误报 + 1 用户豁免），质量门升级为 PASS。

## 7. 质量门判定与建议

**判定：PASS（2026-07-30 用户豁免）**

逻辑级联全部走通（168 断言，0 FAIL）。原 2 项 CONCERNS 经主理人复核后均已关闭：
1. `G7-bg` 为误报——DialogueUI.gd L116-121 已实现事件级 bg 覆盖（含 null 防御），CG 显示正常，无需修复。
2. `D-note`（requireHoliday=="any" 无运行时覆盖）为已知低风险，门控代码正确，仅当前无事件使用 "any"；用户明确豁免，不阻断放行。
故质量门由 advisory CONCERNS 升级为 PASS，可正式放行。

> 说明：本测试为**逻辑级模拟**，未启动 Godot；门控逻辑为对 `DataManager.gd` 的忠实复刻。
> 质量门为建议性门控（advisory），最终放行由人工审批。未做 git 提交。
