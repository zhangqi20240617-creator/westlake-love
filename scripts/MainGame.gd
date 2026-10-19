extends Control

@onready var date_lbl      = %DateLbl
@onready var time_lbl      = %TimeLbl
@onready var stats_row     = %StatsRow
@onready var money_lbl     = %MoneyLbl
@onready var location_list = %LocationList
@onready var quick_list    = %QuickList
@onready var dialogue_ui   = %DialogueUI
@onready var center_info   = %CenterInfo
@onready var info_title    = %Title
@onready var info_sub      = %Sub
@onready var location_explore_ui = %LocationExploreUI
@onready var loc_bg        = %LocBG
@onready var hotspot_container = %HotspotContainer
@onready var girls_grid    = %GirlsGrid
@onready var log_list      = %LogList
@onready var ending_screen = %EndingScreen
@onready var char_profile_popup = %CharProfilePopup
@onready var save_btn_hdr   = %SaveBtn
@onready var diary_btn_hdr  = %DiaryBtn
@onready var gallery_btn_hdr = %GalleryBtn
@onready var ending_btn_hdr = %EndingBtn
@onready var inventory_btn_hdr = %InventoryBtn

var header_ui: HeaderUI = HeaderUI.new()
var girls_ui: GirlsGridUI = GirlsGridUI.new()
var board_ui: CenterDashboardUI = CenterDashboardUI.new()
var loc_list_ui: LocationListUI = LocationListUI.new()
var gallery_ui: GalleryPopupUI = GalleryPopupUI.new()
var popup_mgr: PopupManager = PopupManager.new()
var hotspot_ui: HotspotExploreUI = HotspotExploreUI.new()
var score_reveal_ui = null

var _is_ui_dirty: bool = false

func _mark_ui_dirty():
    _is_ui_dirty = true

func _process(delta: float):
    if _is_ui_dirty:
        _is_ui_dirty = false
        update_ui()

func _ready():
    GameManager.state_updated.connect(_mark_ui_dirty)
    GameManager.show_toast.connect(_on_show_toast)
    GameManager.special_date_triggered.connect(_on_special_date)
    GameManager.initiative_updated.connect(func(): board_ui.show_center_info(self))  # ← 邀请变化时刷新手账
    dialogue_ui.event_finished.connect(_on_event_finished)
    dialogue_ui.ending_triggered.connect(func(eid: String):
        if eid != "":
            ending_screen.trigger_specific_ending(eid)
        else:
            ending_screen.trigger_ending()
        ending_screen.show()
    )
    _setup_header_buttons()
    header_ui.setup(date_lbl, time_lbl, stats_row, money_lbl)
    girls_ui.setup(girls_grid, char_profile_popup)
    board_ui.setup(dialogue_ui, location_explore_ui, hotspot_container, center_info, loc_bg, info_title, info_sub)
    board_ui.set_invite_callbacks(
        func(cid): _on_accept_invite(cid),
        func(cid): _on_decline_invite(cid)
    )
    board_ui.set_action_callbacks(
        func(): _show_stats_popup(),
        func(): _show_wardrobe_popup(),
        func(loc_id: String): _on_location_selected(loc_id)
    )
    loc_list_ui.setup(location_list, quick_list,
        func(loc_id): _on_location_selected(loc_id),
        func(): _on_skip_slot(),
        func(): SaveSystem.save_game()
    )
    gallery_ui.setup(self)
    popup_mgr.setup(self, func(): _mark_ui_dirty())
    hotspot_ui.setup(self, dialogue_ui, location_explore_ui, loc_bg, hotspot_container,
        func(): _mark_ui_dirty(),
        func(): board_ui.show_center_info(self)
    )
    update_ui()
    board_ui.show_center_info(self)

    # 初始化成绩查询 UI
    score_reveal_ui = preload("res://scripts/ScoreRevealUI.gd").new()
    add_child(score_reveal_ui)

    # 启动校园日常轻柔 BGM
    if is_instance_valid(AudioManager):
        AudioManager.play_bgm("bgm_peaceful_campus", 1.5)

func _input(event):
    # ESC 键唤起系统设置菜单
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        if get_node_or_null("SettingsPopupUI") == null and not dialogue_ui.visible:
            _show_settings_popup()
            return

    # ── 以下热键仅在 Debug 构建中生效，发布版自动剔除 ──────────
    if not OS.is_debug_build():
        return

    if not (event is InputEventKey and event.pressed):
        return

    # F7：跳跃到毕业典礼（大结局）
    if event.keycode == KEY_F7:
        GameManager.day = 570
        GameManager.day_of_week = 5
        GameManager.slot_index = 0
        GameManager.state_updated.emit()
        board_ui.show_center_info(self)
        update_ui()
        GameManager.show_toast.emit("🎓 [DEBUG] 时间穿梭：已跳转到初三毕业典礼！")
        _on_special_date("🎓 初三毕业典礼", "ending", "")

    # F6：强制扫描所有画廊解锁条件
    elif event.keycode == KEY_F6:
        GameManager._retroactive_gallery_check()
        GameManager.show_toast.emit("🖼️ [DEBUG] 画廊条件已重新扫描！")

    # F9：跳跃到初三下半期志愿填报日（第525天）
    elif event.keycode == KEY_F9:
        GameManager.day = 525
        GameManager.day_of_week = 1
        GameManager.slot_index = 0
        DataManager._load_data()
        GameManager.state_updated.emit()
        board_ui.show_center_info(self)
        update_ui()
        GameManager.show_toast.emit("🚀 [DEBUG] 已跳转到志愿填报日！请点击【教室】触发。")

    # F10：全属性满值 + 全角色好感拉满
    elif event.keycode == KEY_F10:
        for s in ["intellect", "art", "strength", "social", "charm"]:
            GameManager.add_stat(s, 100)
        for char_id in ["yutong", "jingjing", "wanqing", "xiaoxia", "yifei", "zicheng"]:
            GameManager.favorability[char_id] = 100
        GameManager._retroactive_gallery_check()
        GameManager.show_toast.emit("⚡ [DEBUG] 全属性已拉满，画廊已刷新！")
        update_ui()

func _setup_header_buttons():
    # 隐藏原始零散按钮，整合至“更多”菜单以节省屏幕空间，防止移动端显示溢出
    save_btn_hdr.hide()
    gallery_btn_hdr.hide()
    ending_btn_hdr.hide()
    
    # 创建“⚙️ 更多”按钮
    var more_btn = Button.new()
    more_btn.text = "⚙️ 更多"
    more_btn.name = "MoreBtn"
    more_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    save_btn_hdr.get_parent().add_child(more_btn)
    
    # 我们保留顶部最核心按钮：手账、背包、更多
    var defs = [
        [diary_btn_hdr,     Color(0.35, 0.28, 0.55), _show_diary_popup],
        [inventory_btn_hdr, Color(0.40, 0.50, 0.35), _show_inventory_popup],
        [more_btn,          Color(0.30, 0.32, 0.38), _show_more_popup],
    ]
    for d in defs:
        _style_header_btn(d[0], d[1])
        if d[0].pressed.is_connected(d[2]):
            d[0].pressed.disconnect(d[2])
        d[0].pressed.connect(d[2])


func _style_header_btn(btn: Button, accent: Color):
    ThemeUtils.style_accent_btn(btn, accent)

func _on_header_save():
    popup_mgr.show_save_load_popup(true)

func _on_header_ending():
    ending_screen.trigger_ending()
    ending_screen.show()

# ── 日记弹窗（委托给 PopupManager）────────────────────────────
func _show_diary_popup():
    popup_mgr.show_diary_popup()

# ── 背包弹窗（委托给 PopupManager）────────────────────────────
func _show_inventory_popup():
    popup_mgr.show_inventory_popup()

# ── 画廊系统（委托给 GalleryPopupUI）───────────────────────────
func _show_gallery_popup():
    gallery_ui.show_gallery_popup(func(title, builder): PopupManager.make_overlay_popup(self, title, builder))


# ── 西湖十景集章簿（board 入口，只读 book 模式）────────────────
func _show_stampbook_popup():
    var scr = load("res://scripts/StampBookUI.gd")
    if not scr: return
    # 记录探索层原可见性：从主界面打开时不应把探索层"凭空"显出来
    var was_explore_visible = location_explore_ui.visible
    location_explore_ui.hide()
    var inst = scr.new()
    inst.set_meta("mode", "book")
    add_child(inst)
    inst.closed.connect(func():
        if was_explore_visible:
            location_explore_ui.show()
        update_ui()
    )


# ── 西湖风物志图鉴（board 入口，只读）─────────────────────────
## DS-RN-04。与集章簿同构：运行时 new() 出子界面，不进 Autoload、不加 .tscn。
## ⚠️ 该面板**不写任何 flag** —— 授予统一由 CollectionManager.grant_fengwu() 负责。
func _show_fengwubook_popup():
    var scr = load("res://scripts/FengwuBookUI.gd")
    if not scr: return
    # 记录探索层原可见性：从主界面打开时不应把探索层"凭空"显出来
    var was_explore_visible = location_explore_ui.visible
    location_explore_ui.hide()
    var inst = scr.new()
    add_child(inst)
    inst.closed.connect(func():
        if was_explore_visible:
            location_explore_ui.show()
        update_ui()
    )


# ── 成就中心（board / 菜单入口，只读）─────────────────────────
func _show_achievement_popup():
    var scr = load("res://scripts/AchievementPopupUI.gd")
    if not scr: return
    var was_explore_visible = location_explore_ui.visible
    location_explore_ui.hide()
    var inst = scr.new()
    add_child(inst)
    inst.closed.connect(func():
        if was_explore_visible:
            location_explore_ui.show()
        update_ui()
    )


# ── 系统设置中心（board / 菜单 / Esc 入口）──────────────────────
func _show_settings_popup():
    var scr = load("res://scripts/SettingsPopupUI.gd")
    if not scr: return
    var was_explore_visible = location_explore_ui.visible
    location_explore_ui.hide()
    var inst = scr.new()
    add_child(inst)
    inst.closed.connect(func():
        if was_explore_visible:
            location_explore_ui.show()
        update_ui()
    )


# ── 通用全屏弹窗构造器（委托给 PopupManager 静态方法）────────────
func _make_overlay_popup(title: String, content_builder: Callable):
    PopupManager.make_overlay_popup(self, title, content_builder)


func _render_logs():
    for child in log_list.get_children(): child.queue_free()
    var recent = GameManager.diary.slice(-5)
    recent.reverse()
    for entry in recent:
        var lbl = Label.new()
        lbl.text = "[%s·%s] %s" % [entry.get("grade",""), entry.get("slot",""), entry.get("text","")]
        lbl.add_theme_font_size_override("font_size", 14)
        lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
        lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        log_list.add_child(lbl)


func update_ui():
    if not date_lbl: return
    header_ui.render_header()
    loc_list_ui.render_locations()   # 内部有 dirty 检测，slot/day/stress 不变时跳过重建
    girls_ui.update_girl_cards()     # 只更新数值，不重建节点
    _render_logs()

# ── 地点选择 → 路由到 HotspotExploreUI ──────────────────────
func _on_location_selected(loc_id: String):
    GameManager.current_location = loc_id  # 供穿搭地点好感加成使用
    center_info.hide()
    hotspot_container.show()
    if _check_cleaning_duty(): return
    if _check_dean_dorm_catch(loc_id): return
    if _try_memory_echo(loc_id): return    # step 0：命中则先播回响，播完自回调重入
    # step 0.5 · 西湖风物志「拾得」（DS-RN-04 / 决策 D-4）
    CollectionManager.pick_fengwu_pickup(loc_id)

    # ── 成就事件联动 ──
    if loc_id == "lakeside":
        AchievementManager.add_counter("visit_lakeside_count", 1)
        if GameManager.current_weather == "rainy":
            GameManager.flags["achv_rainy_walk"] = true
    elif loc_id == "classroom" and GameManager.slot_index == 0:
        GameManager.flags["achv_morning_study"] = true
    if int(GameManager.stats.get("stress", 0)) >= 90:
        GameManager.flags["achv_stress_over_90"] = true

    hotspot_ui.on_location_selected(loc_id)

## 值日生强制拦截：周五下午截留
func _check_cleaning_duty() -> bool:
    if GameManager.day % 7 == 5 and GameManager.slot_index == 2:
        var ev = DataManager.get_event_by_id("event_cleaning_duty")
        if not ev.is_empty():
            location_explore_ui.hide()
            dialogue_ui.show()
            dialogue_ui.start_event(ev)
            return true
    return false

## 教导主任宿管拦截：进宿舍前判定
func _check_dean_dorm_catch(loc_id: String) -> bool:
    if loc_id == "dorm" and GameManager.slot_index >= 3 and GameManager.stats.get("dean_suspicion", 0) > 50:
        if randf() < 0.4:  # 40% 概率触发包抄
            var ev = DataManager.get_event_by_id("dean_catch_dorm")
            if not ev.is_empty():
                location_explore_ui.hide()
                dialogue_ui.show()
                # 播完后重回宿舍场景
                dialogue_ui.event_finished.connect(
                    func(): _on_location_selected(loc_id), CONNECT_ONE_SHOT)
                dialogue_ui.start_event(ev)
                return true
    return false

## 情境回响 step 0（design/memory_echo_gdd.md §2.1 / §3.4 / §4.1）
## 命中 → 播放 flashback（不消耗时段），播完后重入 _on_location_selected 正常进地点。
## 返回 true 表示「本次已被回响接管」，调用方应立即 return。
func _try_memory_echo(loc_id: String) -> bool:
    var hit: Dictionary = CollectionManager.pick_memory_echo(loc_id)
    if hit.is_empty(): return false
    var vignette: Dictionary = CollectionManager.build_memory_echo_vignette(hit["sid"])
    if vignette.is_empty(): return false             # 数据异常兜底：静默放行，不阻断进地点
    CollectionManager.commit_memory_echo(hit["sid"]) # ← 必须在 start_event 之前写冷却（防重入）
    location_explore_ui.hide()
    dialogue_ui.show()
    # 一次性回调：回响播完 → 重走一遍进地点流程（此时冷却已写，pick 必返回 {}，无递归风险）
    # 信号顺序：_ready() L40 已先连 _on_event_finished（show_center_info + update_ui），
    # 本 lambda 后连 → 先恢复看板再重入探索层，最终 UI 落在探索层，无需额外干预。
    dialogue_ui.event_finished.connect(
        func(): _on_location_selected(loc_id), CONNECT_ONE_SHOT)
    dialogue_ui.start_event(vignette)
    return true

func _on_hotspot_clicked(loc_id: String, event_id: String):
    hotspot_ui.on_hotspot_clicked(loc_id, event_id)

# ── 邀请接受/拒绝（委托给 CenterDashboardUI）──────────────────
func _on_accept_invite(char_id: String):
    var loc_id = GameManager.accept_invite(char_id)
    board_ui.show_center_info(self)
    update_ui()
    if loc_id != "":
        _on_location_selected(loc_id)

func _on_decline_invite(char_id: String):
    GameManager.decline_invite(char_id)
    board_ui.show_center_info(self)
    update_ui()

func _on_skip_slot():
    GameManager.advance_time()
    board_ui.show_center_info(self)
    update_ui()

func _on_event_finished():
    # 西湖十景集章·路径 B 补偿（GDD §4.1）：
    # 浪漫事件终局 scene 经 setFlags 写入 stamp_*，在此补齐获得日并触发集满判定。
    # 幂等，O(10) 字典查询。
    CollectionManager._retroactive_stamp_check()
    board_ui.show_center_info(self)
    update_ui()

func _on_show_toast(message: String):
    GameManager.add_log(message)

func _on_special_date(label: String, effect: String, banner: String):
    GameManager.add_log("📅 " + label)
    if banner != "":
        GameManager.add_log("💬 " + banner)
    if effect == "ending":
        # 中考放榜，显示查分面板，关闭后再触发大结局
        # 先弹 5 道终极大考题
        var quiz_ui = preload("res://scripts/QuizUI.gd").new()
        add_child(quiz_ui)
        quiz_ui.start_quiz(["chinese", "math", "english", "science", "society"], func(correct_count):
            GameManager.quiz_bonus_score = correct_count * 5  # 本次成绩对1题加5分
            GameManager.calculate_exam_score()
            score_reveal_ui.show_result()
            if not score_reveal_ui.reveal_finished.is_connected(_on_score_reveal_finished):
                score_reveal_ui.reveal_finished.connect(_on_score_reveal_finished, CONNECT_ONE_SHOT)
        )
    elif effect == "exam":
        GameManager.flags["exam_week"] = true
        var quiz_ui = preload("res://scripts/QuizUI.gd").new()
        add_child(quiz_ui)
        quiz_ui.start_quiz(["chinese", "math", "english", "science", "society"], func(correct_count):
            var study = GameManager.stats.get("intellect", 0)
            var stress = GameManager.stats.get("stress", 0)
            var score = study * 1.2 - stress * 0.4 + (correct_count * 15)
            # 缩放为模拟总分 (满分可能600左右)
            var total_mock = min(600, int(score * 3.5))
            GameManager.stats["last_exam_total"] = total_mock
            
            GameManager.add_log("📝 考试结束，模拟总得分：%d" % total_mock)
            
            var ev = DataManager.get_event_by_id("event_ptm")
            if not ev.is_empty():
                location_explore_ui.hide()
                dialogue_ui.show()
                dialogue_ui.start_event(ev)
                
            GameManager.flags.erase("exam_week")
            GameManager.refresh_deskmate()
        )
    elif effect == "exam_sport":
        # 体能测试（Day 500）：根据 strength 属性决定体测成绩与加成
        var strength_val = GameManager.stats.get("strength", 0)
        var pe_score: int
        var pe_msg: String
        if strength_val >= 80:
            pe_score = 30
            pe_msg = "💪 体测超常发挥！满分体育 30 分，体能拉满！"
            GameManager.add_stat("charm", 2)   # 强健体魄带来额外魅力加成
        elif strength_val >= 60:
            pe_score = 24
            pe_msg = "🏃 体测成绩不错，体育 24 分，继续保持！"
        elif strength_val >= 40:
            pe_score = 18
            pe_msg = "😅 体测成绩一般，体育 18 分，还有提升空间。"
        else:
            pe_score = 10
            pe_msg = "😰 体测成绩较差，体育仅 10 分，平时要多锻炼！"
            GameManager.add_stat("stress", 5)  # 体测差劲带来压力
        # 写入最近考试结果的 pe 字段（供中考计算参考）
        GameManager.latest_exam_result["pe"] = pe_score
        GameManager.flags["pe_tested"] = true
        GameManager.add_log(pe_msg)
        GameManager.show_toast.emit(pe_msg)

    elif effect == "festival":
        # 节日触发：设置对应烹饪 flag，解锁限定食谱
        var festival_map: Dictionary = {
            "new_year":    "new_year_cooking",
            "dragon_boat": "dragon_boat_cooking",
            "mid_autumn":  "mid_autumn_cooking",
        }
        if festival_map.has(banner):
            var flag_key = festival_map[banner]
            if not GameManager.flags.has(flag_key):
                GameManager.flags[flag_key] = true
                CookingManager._check_recipe_unlocks()
                GameManager.show_toast.emit("🎉 %s！节日限定食谱已解锁，快去厨房烹饪吧！" % label)

        # P1 节日叙事启动（追加，不改上方烹饪解锁）
        var fest_narrative_map = {
            "new_year":    "fest_newyear",
            "dragon_boat": "fest_dragonboat",
            "mid_autumn":  "fest_midautumn",
            "teacher_day": "fest_teacherday",
            "spring_festival": "eco_lucky_money",
        }
        if fest_narrative_map.has(banner):
            var nev = DataManager.get_event_by_id(fest_narrative_map[banner])
            if not nev.is_empty():
                location_explore_ui.hide(); dialogue_ui.show(); dialogue_ui.start_event(nev)

    elif effect == "break" or effect == "free_day":
        # 长假开始：按 current_holiday 取对应 kickoff 事件强制启动
        # free_day（元旦 day31）时 current_holiday=="" → 不触发，符合预期
        var hol_type = GameManager.current_holiday
        if hol_type != "":
            var ev = DataManager.get_event_by_id("holiday_kickoff_" + hol_type)
            if not ev.is_empty():
                location_explore_ui.hide()
                dialogue_ui.show()
                dialogue_ui.start_event(ev)
                
    elif effect == "sports_meet":
        var ev = DataManager.get_event_by_id("event_sports_meet")
        if not ev.is_empty():
            location_explore_ui.hide()
            dialogue_ui.show()
            dialogue_ui.start_event(ev)
            
    elif effect == "class_election":
        var ev = DataManager.get_event_by_id("event_class_election")
        if not ev.is_empty():
            location_explore_ui.hide()
            dialogue_ui.show()
            dialogue_ui.start_event(ev)

    elif effect == "birthday_player":
        # 玩家生日：显示祝福 toast 并触发专属事件
        var ev = DataManager.get_event_by_id("event_birthday_player")
        if not ev.is_empty():
            location_explore_ui.hide()
            dialogue_ui.show()
            dialogue_ui.start_event(ev)

    elif effect == "birthday_char":
        # 角色生日：banner 为 char_id，触发对应角色生日事件
        var char_id = banner
        if char_id != "":
            var meta = GameManager.char_meta.get(char_id, {})
            var char_name = meta.get("name", char_id)
            var char_emoji = meta.get("emoji", "🎂")
            GameManager.show_toast.emit("%s %s 今天是你的生日！" % [char_emoji, char_name])
            var ev = DataManager.get_event_by_id("event_birthday_" + char_id)
            if not ev.is_empty():
                location_explore_ui.hide()
                dialogue_ui.show()
                dialogue_ui.start_event(ev)

    elif effect == "special":
        # banner 可能是提示文字（显示 toast）或事件 id（grad_ 前缀的毕业仪式事件）
        if banner.begins_with("grad_"):
            var ev = DataManager.get_event_by_id(banner)
            if not ev.is_empty():
                location_explore_ui.hide()
                dialogue_ui.show()
                dialogue_ui.start_event(ev)
        else:
            # 普通 special banner：弹出 toast 提示，玩家自行前往地点触发
            GameManager.show_toast.emit("✨ " + banner)

    elif effect == "opening":
        # 初一开学第一天（Day 1）：强制播放开学叙事
        # NG+ 周目用专属回响事件增强代入感
        var ng_count = GameManager.flags.get("ng_count", 0)
        var ev_id = "opening_ng_echo" if ng_count >= 1 else "opening_day1_morning"
        var ev = DataManager.get_event_by_id(ev_id)
        if not ev.is_empty():
            location_explore_ui.hide()
            dialogue_ui.show()
            dialogue_ui.start_event(ev)

    elif effect == "training_end":
        # 军训结束（Day 14）：联欢晚会，正式解锁常规校园探索
        var ev = DataManager.get_event_by_id("training_end_ceremony")
        if not ev.is_empty():
            location_explore_ui.hide()
            dialogue_ui.show()
            dialogue_ui.start_event(ev)
        GameManager.show_toast.emit("🎉 军训结束！从明天起，你可以自由探索西湖中学的每个角落了。")


func _on_score_reveal_finished():
    var ev = DataManager.get_event_by_id("event_grad_trip_start")
    if not ev.is_empty():
        location_explore_ui.hide()
        dialogue_ui.show()
        # 接管 event_finished ，在这个长番结算后呼出大结局
        dialogue_ui.event_finished.connect(
            func(): 
                dialogue_ui.hide()
                ending_screen.trigger_ending()
                ending_screen.show()
        , CONNECT_ONE_SHOT)
        dialogue_ui.start_event(ev)
    else:
        ending_screen.trigger_ending()
        ending_screen.show()

# ── 排行榜弹窗（委托给 PopupManager）──────────────────────────
func _show_leaderboard_popup():
    popup_mgr.show_leaderboard_popup()


func _show_season_popup():
    location_explore_ui.hide()
    dialogue_ui.hide()
    var season_script = load("res://scripts/SeasonUI.gd")
    if season_script:
        var season_ui_inst = season_script.new()
        add_child(season_ui_inst)
        season_ui_inst.closed.connect(func():
            location_explore_ui.show()
            update_ui()
        )

func _show_more_popup():
    _make_overlay_popup("⚙️ 更多菜单", func(content_vbox: VBoxContainer):
        var overlay = get_node_or_null("_OverlayPopup")
        
        var sub = Label.new()
        sub.text = "系统设置与收集进度管理"
        sub.add_theme_font_size_override("font_size", 12)
        sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
        content_vbox.add_child(sub)
        
        var spacer = Control.new()
        spacer.custom_minimum_size = Vector2(0, 10)
        content_vbox.add_child(spacer)
        
        var flow = HFlowContainer.new()
        flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        flow.add_theme_constant_override("h_separation", 16)
        flow.add_theme_constant_override("v_separation", 16)
        content_vbox.add_child(flow)
        
        var items = [
            {"text": "⚙️ 系统设置",   "color": Color(0.35, 0.45, 0.55), "fn": _show_settings_popup},
            {"text": "📊 角色状态",   "color": Color(0.35, 0.55, 0.80), "fn": _show_stats_popup},
            {"text": "👗 我的衣橱",   "color": Color(0.55, 0.30, 0.55), "fn": _show_wardrobe_popup},
            {"text": "💾 游戏存档",   "color": Color(0.30, 0.35, 0.55), "fn": _on_header_save},
            {"text": "🏅 青春赛季",   "color": Color(0.10, 0.55, 0.35), "fn": _show_season_popup},
            {"text": "🏆 全服学霸",   "color": Color(0.55, 0.45, 0.25), "fn": _show_leaderboard_popup},
            {"text": "🎖️ 成就中心",   "color": Color(0.85, 0.65, 0.20), "fn": _show_achievement_popup},
            {"text": "🖼️ 珍贵画廊",   "color": Color(0.28, 0.40, 0.55), "fn": _show_gallery_popup},
            {"text": "📖 集章簿",     "color": Color(0.30, 0.50, 0.45), "fn": _show_stampbook_popup},
            {"text": "🍃 风物志",     "color": Color(0.34, 0.46, 0.28), "fn": _show_fengwubook_popup},
            {"text": "🎓 往昔结局",   "color": Color(0.55, 0.28, 0.35), "fn": _on_header_ending},
            {"text": "💬 世界聊天",   "color": Color(0.12, 0.45, 0.70), "fn": _show_world_chat_popup},
            {"text": "🎏 社团",       "color": Color(0.45, 0.40, 0.65), "fn": _show_club_popup},
        ]
        
        for item in items:
            var btn = Button.new()
            btn.text = item["text"]
            btn.custom_minimum_size = Vector2(230, 70)
            btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            btn.add_theme_font_size_override("font_size", 16)
            
            # 按钮样式设计
            var s = StyleBoxFlat.new()
            s.bg_color = item["color"].darkened(0.4)
            s.border_width_left = 2; s.border_width_right = 2
            s.border_width_top = 2; s.border_width_bottom = 2
            s.border_color = item["color"].lightened(0.15)
            s.corner_radius_top_left = 12; s.corner_radius_top_right = 12
            s.corner_radius_bottom_left = 12; s.corner_radius_bottom_right = 12
            btn.add_theme_stylebox_override("normal", s)
            
            var h = s.duplicate()
            h.bg_color = item["color"].darkened(0.2)
            btn.add_theme_stylebox_override("hover", h)
            
            var p = s.duplicate()
            p.bg_color = item["color"].lightened(0.05)
            btn.add_theme_stylebox_override("pressed", p)
            
            btn.pressed.connect(func():
                if overlay:
                    overlay.queue_free()
                item["fn"].call()
            )
            flow.add_child(btn)
    )

# ── 社团面板（club_system_gdd MVP）───────────────────────────
## 纯只读状态展示：读 GameManager.flags 渲染「是否已入社 / 哪个社团 / 本周是否已参加」。
## ⚠️ 该面板**不写任何 flag** —— 入社只能经 club_join_hub 事件，参加只能经 club_weekly_* 事件，
##    本周重置只能经 DailyCycleManager._check_weekly_allowance 的周一钩子。
##    面板若代写 flag 会绕过「时间即代价」（支柱 A），属设计红线。
## 复用 _make_overlay_popup 容器，不新建场景文件、不进 Autoload。
const CLUB_NAMES := {
    "flag_club_literature": "📖 文学社",
    "flag_club_astronomy":  "🔭 天文社",
    "flag_club_broadcast":  "🎙️ 广播站",
    "flag_club_basketball": "🏀 篮球队",
    "flag_club_art":        "🎨 美术社",
}

## 面板内一行文本（避免在 lambda 内再嵌 lambda，保持 GDScript 解析简单可靠）
func _club_row(box: VBoxContainer, txt: String, size: int, col: Color) -> void:
    var l = Label.new()
    l.text = txt
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", col)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(l)

## 当前社团的中文显示名；未入社或数据异常时返回 ""
func _get_club_label() -> String:
    for flag_key in CLUB_NAMES:
        if GameManager.flags.has(flag_key):
            return CLUB_NAMES[flag_key]
    return ""

func _show_club_popup():
    _make_overlay_popup("🎏 我的社团", func(content_vbox: VBoxContainer):
        var joined: bool = GameManager.flags.has("flag_club_joined")

        var sub = Label.new()
        sub.text = "初中三年，只能认真参加一个社团。" if joined else "社团招新每年只有一次。"
        sub.add_theme_font_size_override("font_size", 12)
        sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
        content_vbox.add_child(sub)

        var spacer = Control.new()
        spacer.custom_minimum_size = Vector2(0, 10)
        content_vbox.add_child(spacer)

        if not joined:
            _club_row(content_vbox, "尚未加入任何社团", 20, Color(0.92, 0.90, 0.86))
            _club_row(content_vbox, "初一适应期后可加入社团。", 15, Color(1, 1, 1, 0.65))
            _club_row(content_vbox, "（放学后到教室看看，招新的摊子就支在走廊尽头。）", 14, Color(1, 1, 1, 0.45))
            return

        # 已入社：定位社团类型（承诺制，5 选 1，理论上唯一）
        var club_label := _get_club_label()
        if club_label == "": club_label = "未知社团"
        _club_row(content_vbox, club_label, 24, Color(0.72, 0.66, 0.92))
        _club_row(content_vbox, "状态：已入社（不可转社）", 15, Color(1, 1, 1, 0.65))

        var spacer2 = Control.new()
        spacer2.custom_minimum_size = Vector2(0, 8)
        content_vbox.add_child(spacer2)

        if GameManager.flags.has("flag_club_week_done"):
            _club_row(content_vbox, "✅ 本周社团活动：已参加", 18, Color(0.55, 0.80, 0.55))
            _club_row(content_vbox, "下周一恢复，可再参加一次。", 14, Color(1, 1, 1, 0.45))
        else:
            _club_row(content_vbox, "⏳ 本周社团活动：未参加", 18, Color(0.90, 0.75, 0.45))
            _club_row(content_vbox, "放学后前往社团活动地点即可参加（占用一个时段）。", 14, Color(1, 1, 1, 0.45))
    )

func _show_world_chat_popup():
    location_explore_ui.hide()
    dialogue_ui.hide()
    var chat_script = load("res://scripts/WorldChatUI.gd")
    if chat_script:
        var chat_ui_inst = chat_script.new()
        add_child(chat_ui_inst)
        chat_ui_inst.closed.connect(func():
            location_explore_ui.show()
            update_ui()
        )

# ── 角色状态总览弹窗 ─────────────────────────────────────────
func _show_stats_popup():
    var popup = CharacterStatsPopup.open(self)
    popup.closed.connect(func(): update_ui())

# ── 衣橱换装面板 ──────────────────────────────────────────────
func _show_wardrobe_popup():
    var popup = WardrobeUI.open(self)
    popup.closed.connect(func(): update_ui())
