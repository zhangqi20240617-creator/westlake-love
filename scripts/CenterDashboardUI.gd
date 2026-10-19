# CenterDashboardUI.gd
class_name CenterDashboardUI
extends RefCounted

var dialogue_ui: Control
var location_explore_ui: Control
var hotspot_container: Control
var center_info: Control
var loc_bg: TextureRect
var info_title: Label
var info_sub: Label

const SLOT_ENV_TEXT = {
    "morning": "清晨的阳光微凉，新的一天开始了。",
    "noon":    "午休时间，空气里有淡淡的樟树叶味道。",
    "after":   "放学后的时间总是过得很快，夕阳很温柔。",
    "evening": "夜色渐深，整个城市慢慢安静下来。",
}

var _board_panel: PanelContainer = null
var _board_cache: Dictionary = {}
var _on_accept_invite_cb:  Callable
var _on_decline_invite_cb: Callable

# 快捷操作回调（由 MainGame 注入）
var _on_show_stats_cb:    Callable   # 打开角色属性面板
var _on_show_wardrobe_cb: Callable   # 打开衣橱换装
var _on_navigate_loc_cb:  Callable   # func(loc_id: String) → 跳转地点

## 注入邀请回调（在 MainGame._ready() 中调用）
func set_invite_callbacks(on_accept: Callable, on_decline: Callable) -> void:
    _on_accept_invite_cb  = on_accept
    _on_decline_invite_cb = on_decline


## 注入快捷操作回调（可选，在 MainGame._ready() 中调用）
func set_action_callbacks(
    on_stats: Callable,
    on_wardrobe: Callable,
    on_navigate: Callable
) -> void:
    _on_show_stats_cb    = on_stats
    _on_show_wardrobe_cb = on_wardrobe
    _on_navigate_loc_cb  = on_navigate

func setup(
    p_dialogue_ui: Control,
    p_location_explore_ui: Control,
    p_hotspot_container: Control,
    p_center_info: Control,
    p_loc_bg: TextureRect,
    p_info_title: Label,
    p_info_sub: Label
):
    dialogue_ui = p_dialogue_ui
    location_explore_ui = p_location_explore_ui
    hotspot_container = p_hotspot_container
    center_info = p_center_info
    loc_bg = p_loc_bg
    info_title = p_info_title
    info_sub = p_info_sub
    
    _init_board_panel()

func _init_board_panel():
    _board_cache.clear()

    var board = PanelContainer.new()
    board.name = "BoardPanel"
    board.custom_minimum_size = Vector2(680, 420)
    board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    board.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style = ThemeUtils.create_style(
        Color(0.06, 0.08, 0.14, 0.95), 16, Color(0.96, 0.47, 0.63, 0.6), 2, -1, 24, 24, 18, 18
    )
    board.add_theme_stylebox_override("panel", style)

    var outer_vbox = VBoxContainer.new()
    outer_vbox.add_theme_constant_override("separation", 10)
    board.add_child(outer_vbox)

    var header_hbox = HBoxContainer.new()
    outer_vbox.add_child(header_hbox)

    var title_lbl = Label.new()
    title_lbl.add_theme_font_size_override("font_size", 18)
    title_lbl.add_theme_color_override("font_color", Color("#f472b6"))
    header_hbox.add_child(title_lbl)
    _board_cache["title_lbl"] = title_lbl

    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_hbox.add_child(spacer)

    var sub_lbl = Label.new()
    sub_lbl.text = "「珍惜每一天，谱写属于你的西湖故事」"
    sub_lbl.add_theme_font_size_override("font_size", 14)
    sub_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.45))
    header_hbox.add_child(sub_lbl)

    outer_vbox.add_child(HSeparator.new())

    var main_hbox = HBoxContainer.new()
    main_hbox.add_theme_constant_override("separation", 20)
    outer_vbox.add_child(main_hbox)

    var left_vbox = VBoxContainer.new()
    left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_vbox.add_theme_constant_override("separation", 10)
    main_hbox.add_child(left_vbox)

    var date_card = PanelContainer.new()
    var d_style = ThemeUtils.create_style(Color(0.12, 0.15, 0.25, 0.6), 8, Color.TRANSPARENT, 0, -1, 12, 12, 8, 8)
    date_card.add_theme_stylebox_override("panel", d_style)
    left_vbox.add_child(date_card)

    var date_vbox = VBoxContainer.new()
    date_vbox.add_theme_constant_override("separation", 6)
    date_card.add_child(date_vbox)

    var cur_date_lbl = Label.new()
    cur_date_lbl.add_theme_font_size_override("font_size", 16)
    cur_date_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
    date_vbox.add_child(cur_date_lbl)
    _board_cache["cur_date_lbl"] = cur_date_lbl

    var season_lbl = Label.new()
    season_lbl.add_theme_font_size_override("font_size", 15)
    date_vbox.add_child(season_lbl)
    _board_cache["season_lbl"] = season_lbl

    var cur_time_lbl = Label.new()
    cur_time_lbl.add_theme_font_size_override("font_size", 14)
    cur_time_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
    date_vbox.add_child(cur_time_lbl)
    _board_cache["cur_time_lbl"] = cur_time_lbl

    var scene_desc_lbl = Label.new()
    scene_desc_lbl.add_theme_font_size_override("font_size", 13)
    scene_desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.38))
    scene_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    date_vbox.add_child(scene_desc_lbl)
    _board_cache["scene_desc_lbl"] = scene_desc_lbl

    var weather_effect_lbl = Label.new()
    weather_effect_lbl.add_theme_font_size_override("font_size", 14)
    weather_effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    date_vbox.add_child(weather_effect_lbl)
    _board_cache["weather_effect_lbl"] = weather_effect_lbl

    var fortune_card = VBoxContainer.new()
    fortune_card.add_theme_constant_override("separation", 4)
    left_vbox.add_child(fortune_card)

    var fortune_title_lbl = Label.new()
    fortune_title_lbl.text = "🔮 今日运势大吉度："
    fortune_title_lbl.add_theme_font_size_override("font_size", 14)
    fortune_title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
    fortune_card.add_child(fortune_title_lbl)

    var fortune_stars_lbl = Label.new()
    fortune_stars_lbl.add_theme_font_size_override("font_size", 16)
    fortune_stars_lbl.add_theme_color_override("font_color", Color("#34d399"))
    fortune_card.add_child(fortune_stars_lbl)
    _board_cache["fortune_stars_lbl"] = fortune_stars_lbl

    var fortune_desc_lbl = Label.new()
    fortune_desc_lbl.add_theme_font_size_override("font_size", 14)
    fortune_desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.75))
    fortune_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    fortune_card.add_child(fortune_desc_lbl)
    _board_cache["fortune_desc_lbl"] = fortune_desc_lbl

    main_hbox.add_child(VSeparator.new())

    var right_vbox = VBoxContainer.new()
    right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_vbox.add_theme_constant_override("separation", 8)
    main_hbox.add_child(right_vbox)

    # ── 倒计时 + 进度条 ──────────────────────────────────
    var exam_lbl = Label.new()
    exam_lbl.add_theme_font_size_override("font_size", 16)
    exam_lbl.add_theme_color_override("font_color", Color("#60a5fa"))
    right_vbox.add_child(exam_lbl)
    _board_cache["exam_lbl"] = exam_lbl

    var pb_bg = ThemeUtils.create_style(Color(0.1, 0.12, 0.18), 3)
    var pb_fg = ThemeUtils.create_style(Color(0.3, 0.6, 1.0), 3)
    var progress_bar = ProgressBar.new()
    progress_bar.custom_minimum_size = Vector2(0, 6)
    progress_bar.min_value = 0; progress_bar.max_value = 570
    progress_bar.show_percentage = false
    progress_bar.add_theme_stylebox_override("background", pb_bg)
    progress_bar.add_theme_stylebox_override("fill", pb_fg)
    right_vbox.add_child(progress_bar)
    _board_cache["progress_bar"] = progress_bar

    # ── 状态速览小标签栏 ─────────────────────────────────
    var status_strip = HBoxContainer.new()
    status_strip.add_theme_constant_override("separation", 8)
    right_vbox.add_child(status_strip)
    _board_cache["status_strip"] = status_strip

    # hw chip
    var hw_chip = Label.new()
    hw_chip.add_theme_font_size_override("font_size", 13)
    hw_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_strip.add_child(hw_chip)
    _board_cache["hw_chip"] = hw_chip

    # body chip
    var body_chip = Label.new()
    body_chip.add_theme_font_size_override("font_size", 13)
    body_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_strip.add_child(body_chip)
    _board_cache["body_chip"] = body_chip

    # money chip
    var money_chip = Label.new()
    money_chip.add_theme_font_size_override("font_size", 13)
    money_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_strip.add_child(money_chip)
    _board_cache["money_chip"] = money_chip

    # ── 好感瓶颈警告条 ────────────────────────────────────
    var bottleneck_lbl = Label.new()
    bottleneck_lbl.add_theme_font_size_override("font_size", 13)
    bottleneck_lbl.add_theme_color_override("font_color", Color("#f59e0b"))
    bottleneck_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    bottleneck_lbl.hide()
    right_vbox.add_child(bottleneck_lbl)
    _board_cache["bottleneck_lbl"] = bottleneck_lbl

    # ── 奥赛集训进度提示条 ─────────────────────────────────
    var olympiad_lbl = Label.new()
    olympiad_lbl.add_theme_font_size_override("font_size", 13)
    olympiad_lbl.add_theme_color_override("font_color", Color("#fcd34d"))
    olympiad_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    olympiad_lbl.hide()
    right_vbox.add_child(olympiad_lbl)
    _board_cache["olympiad_lbl"] = olympiad_lbl

    # ── 快捷操作区标题 ───────────────────────────────────
    var action_title = Label.new()
    action_title.text = "⚡ 今日快捷操作"
    action_title.add_theme_font_size_override("font_size", 14)
    action_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
    right_vbox.add_child(action_title)

    # ── 2列快捷按钮网格 ─────────────────────────────────
    var grid = GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_vbox.add_child(grid)
    _board_cache["action_grid"] = grid

    # 按钮定义（初始占位，数据在 show_center_info 动态填入）
    var btn_defs = [
        {"key": "btn_homework",  "icon": "📝", "label": "完成作业",   "base_color": Color(0.35, 0.55, 0.85)},
        {"key": "btn_relax",    "icon": "🏃", "label": "减压放松",   "base_color": Color(0.30, 0.65, 0.45)},
        {"key": "btn_shop",     "icon": "🛒", "label": "小卖部零食", "base_color": Color(0.60, 0.50, 0.25)},
        {"key": "btn_stats",    "icon": "📊", "label": "角色属性",   "base_color": Color(0.40, 0.38, 0.70)},
        {"key": "btn_wardrobe", "icon": "👗", "label": "今日穿搭",   "base_color": Color(0.65, 0.30, 0.55)},
        {"key": "btn_study",    "icon": "📚", "label": "自习学习",   "base_color": Color(0.30, 0.55, 0.55)},
    ]
    for def in btn_defs:
        var btn = _make_action_btn(def["icon"], def["label"], def["base_color"])
        grid.add_child(btn)
        _board_cache[def["key"]] = btn

    # ── 按钮点击连接（只连一次，lambda 运行时再取最新回调）──
    _board_cache["btn_homework"].pressed.connect(func():
        if _on_navigate_loc_cb.is_valid(): _on_navigate_loc_cb.call("home"))
    _board_cache["btn_relax"].pressed.connect(func():
        if _on_navigate_loc_cb.is_valid(): _on_navigate_loc_cb.call("playground"))
    _board_cache["btn_shop"].pressed.connect(func():
        if _on_navigate_loc_cb.is_valid(): _on_navigate_loc_cb.call("off_campus_shop"))
    _board_cache["btn_stats"].pressed.connect(func():
        if _on_show_stats_cb.is_valid(): _on_show_stats_cb.call())
    _board_cache["btn_wardrobe"].pressed.connect(func():
        if _on_show_wardrobe_cb.is_valid(): _on_show_wardrobe_cb.call())
    _board_cache["btn_study"].pressed.connect(func():
        if _on_navigate_loc_cb.is_valid(): _on_navigate_loc_cb.call("classroom"))

    _board_panel = board

func show_center_info(main_game_ref: Node):
    dialogue_ui.hide()
    location_explore_ui.show()
    hotspot_container.hide()
    center_info.show()
    center_info.move_to_front()

    if ResourceLoader.exists("res://assets/backgrounds/home.png"):
        loc_bg.texture = load("res://assets/backgrounds/home.png")
    else:
        loc_bg.texture = null

    info_title.text = ""
    info_sub.text   = ""

    if _board_panel and not _board_panel.is_inside_tree():
        center_info.add_child(_board_panel)

    var grade_info   = GameManager.get_grade_info()
    var slots        = ["morning","noon","after","evening"]
    var slot_id      = slots[GameManager.slot_index] if GameManager.slot_index < slots.size() else "morning"
    var season_scene = GameManager.get_west_lake_scene()
    var weather_text = GameManager.WEATHER_NAMES.get(GameManager.current_weather, "☀️ 晴朗")

    _board_cache["title_lbl"].text      = "🌸 %s的青春规划手账" % GameManager.player_name
    _board_cache["cur_date_lbl"].text   = "📅 %s · 第%d天" % [grade_info.grade + grade_info.sem, GameManager.get_day_in_sem()]
    _board_cache["cur_time_lbl"].text   = "时段: %s  ·  %s" % [SLOT_ENV_TEXT.get(slot_id, "清晨"), weather_text]
    _board_cache["scene_desc_lbl"].text = season_scene.get("desc", "")

    var season_color_map = {"spring": Color("#f9a8d4"), "summer": Color("#6ee7b7"),
                            "autumn": Color("#fcd34d"), "winter": Color("#bae6fd")}
    _board_cache["season_lbl"].text = "%s %s  |  今日西湖：%s" % [
        season_scene.get("emoji", "🌸"), GameManager.get_season_label(), season_scene.get("name", "苏堤春晓")]
    _board_cache["season_lbl"].add_theme_color_override("font_color",
        season_color_map.get(GameManager.get_season(), Color("#f9a8d4")))

    var weather_effect = GameManager.get_weather_effect_desc()
    var wl: Label = _board_cache["weather_effect_lbl"]
    wl.text = weather_effect
    if weather_effect != "":
        var wc_map = {"sunny": Color("#fde68a"), "cloudy": Color("#c4b5fd"),
                      "rainy": Color("#93c5fd"),  "snowy":  Color("#e0f2fe")}
        wl.add_theme_color_override("font_color", wc_map.get(GameManager.current_weather, Color("#fde68a")))

    var fortune_stars_count = GameManager.get_daily_fortune()
    var star_map = {1: "★☆☆☆☆", 2: "★★☆☆☆", 3: "★★★☆☆", 4: "★★★★☆", 5: "★★★★★"}
    var fortune_color_map = {1: Color("#94a3b8"), 2: Color("#94a3b8"), 3: Color("#34d399"),
                             4: Color("#34d399"), 5: Color("#fbbf24")}
    var fl: Label = _board_cache["fortune_stars_lbl"]
    fl.text = "🍀 气运指数: " + star_map.get(fortune_stars_count, "★★★")
    fl.add_theme_color_override("font_color", fortune_color_map.get(fortune_stars_count, Color("#34d399")))

    var fortune_quotes = {
        1: "背运。这种日子适合宅在家顺着写作业，少出门闯祉。",
        2: "不太顺。现实一点，多写作业少接近别人，等等更好的时机。",
        3: "平平。适合在小卖部买瓶冰红茶，没准能喝到“再来一瓶”哦。",
        4: "吉利。正适合去西湖边放个花灯，没准能捐到别人留下的小秘密。",
        5: "大吉！今日与人互动好感加抡10%，先去找你心中想见的人吧！"
    }
    _board_cache["fortune_desc_lbl"].text = fortune_quotes.get(fortune_stars_count, "")

    var days_left = 570 - GameManager.day
    _board_cache["exam_lbl"].text = ("🎓 冲刺终章 · 中考结算时刻！" if days_left <= 0
        else "🎓 中考倒计时: ⏳ %d 天" % days_left)
    _board_cache["progress_bar"].value = GameManager.day

    # ── 状态速览小标签 ─────────────────────────────────────
    var stress = GameManager.get_stat("stress")
    var addict = GameManager.get_stat("addict")

    var hw_c: Label = _board_cache["hw_chip"]
    match GameManager.hw_status:
        1:  hw_c.text = "📝作业未完"; hw_c.add_theme_color_override("font_color", Color("#f87171"))
        2:  hw_c.text = "✅作业已交"; hw_c.add_theme_color_override("font_color", Color("#34d399"))
        _:  hw_c.text = "📝今日无课"; hw_c.add_theme_color_override("font_color", Color(1,1,1,0.45))

    var bc: Label = _board_cache["body_chip"]
    if stress >= 60:
        bc.text = "💥压力过高"; bc.add_theme_color_override("font_color", Color("#fb923c"))
    elif addict >= 60:
        bc.text = "📱网瘾警告"; bc.add_theme_color_override("font_color", Color("#fb923c"))
    else:
        bc.text = "🍃身心良好"; bc.add_theme_color_override("font_color", Color("#60a5fa"))

    var mc: Label = _board_cache["money_chip"]
    if GameManager.money < 20:
        mc.text = "👛%d元(拮据)" % GameManager.money
        mc.add_theme_color_override("font_color", Color("#f87171"))
    else:
        mc.text = "👛%d元" % GameManager.money
        mc.add_theme_color_override("font_color", Color(1,1,1,0.55))

    # ── 好感瓶颈锁提示 ──────────────────────────────────────
    var bl: Label = _board_cache["bottleneck_lbl"]
    var bn = GameManager.get_active_bottleneck()
    if not bn.is_empty():
        bl.text = "🔒 [%s] 关系瓶颈！需：%s" % [bn.get("char_name",""), bn.get("desc","")]
        bl.show()
    else:
        bl.hide()

    # ── 奥赛集训进度提示 ──────────────────────────────────────
    var olyl: Label = _board_cache["olympiad_lbl"]
    var flags = GameManager.flags
    if flags.has("flag_olympiad_gold"):
        olyl.text = "🏅 【金牌保送】已斩获省奥赛第一名，西湖二中录取直通车！"
        olyl.show()
    elif flags.has("flag_olympiad_dropped"):
        olyl.text = "🗑️ 【已退赛】你放弃了省奥赛之路，回归常规中考体系。"
        olyl.show()
    elif flags.has("flag_olympiad_joined"):
        var stage = "等待集训开始"
        if flags.has("flag_olympiad_city_done"): stage = "冲刺省决赛"
        elif flags.has("flag_olympiad_training_done"): stage = "等待初赛开考"
        elif flags.has("flag_olympiad_training_2"): stage = "魔鬼集训第三期"
        elif flags.has("flag_olympiad_training_1"): stage = "魔鬼集训第二期"
        else: stage = "魔鬼集训第一期"
        
        var o_color = Color("#fcd34d")
        if flags.has("flag_olympiad_training_done"): o_color = Color("#10b981") # 绿色代表集训完成
        olyl.add_theme_color_override("font_color", o_color)
        olyl.text = "🏆 【奥赛征途】当前阶段: %s （注意调节极高压力）" % stage
        olyl.show()
    else:
        olyl.hide()

    # ── 动态更新快捷按钮状态 ────────────────────────────────
    _refresh_action_buttons(stress, addict)

    if main_game_ref.has_method("_render_invite_panel"):
        main_game_ref._render_invite_panel(center_info)
    else:
        # 使用新的内聚方法（当 _on_accept_invite_cb / _on_decline_invite_cb 已注入时）
        if _on_accept_invite_cb.is_valid() and _on_decline_invite_cb.is_valid():
            render_invite_panel(center_info, _on_accept_invite_cb, _on_decline_invite_cb)


# ════════════════════════════════════════════════════════════
# ── ⚡ 快捷操作按钮工厂 ────────────────────────────────────
# ════════════════════════════════════════════════════════════

## 创建一个带 icon+label 的快捷操作按钮（基础样式）
func _make_action_btn(icon: String, label: String, base_color: Color) -> Button:
    var btn = Button.new()
    btn.text = "%s %s" % [icon, label]
    btn.add_theme_font_size_override("font_size", 12)
    btn.custom_minimum_size = Vector2(0, 38)
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    _apply_btn_style(btn, base_color, false)
    return btn

## 统一应用按钮样式（alert=true 时显示醒目高亮边框）
func _apply_btn_style(btn: Button, base_color: Color, alert: bool) -> void:
    var s = StyleBoxFlat.new()
    s.bg_color = base_color.darkened(0.42)
    s.border_width_left   = 2; s.border_width_right  = 2
    s.border_width_top    = 2; s.border_width_bottom  = 2
    s.border_color = base_color.lightened(0.15) if not alert else Color(1.0, 0.35, 0.25, 1.0)
    s.corner_radius_top_left    = 10; s.corner_radius_top_right    = 10
    s.corner_radius_bottom_left = 10; s.corner_radius_bottom_right = 10
    s.content_margin_left = 8; s.content_margin_right  = 8
    s.content_margin_top  = 6; s.content_margin_bottom = 6
    btn.add_theme_stylebox_override("normal", s)
    var h = s.duplicate()
    h.bg_color = base_color.darkened(0.20)
    h.border_color = base_color.lightened(0.35) if not alert else Color(1.0, 0.5, 0.3, 1.0)
    btn.add_theme_stylebox_override("hover", h)
    var p = s.duplicate()
    p.bg_color = base_color.lightened(0.05)
    btn.add_theme_stylebox_override("pressed", p)
    if alert:
        btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6))
    else:
        btn.remove_theme_color_override("font_color")

## 返回目标地点当前不可用的原因标签（供显示在按钮文字上）
func _loc_unavail_reason(loc_id: String) -> String:
    var loc = GameManager.locations.get(loc_id, {})
    if loc.is_empty(): return "未开放"
    if loc.get("weekendOnly", false) and not GameManager.is_weekend():
        return "仅周末"
    if loc.get("workdayOnly", false) and GameManager.is_weekend():
        return "仅工作日"
    var slot_abbr = {"morning": "上午", "noon": "中午", "after": "放学后", "evening": "晚上"}
    var allowed = []
    for s in loc.get("slots", []):
        allowed.append(slot_abbr.get(s, s))
    return "|".join(allowed)

## 根据当前游戏状态刷新六个快捷按钮的样式和提示词（信号已在 _init_board_panel 一次性连接）
func _refresh_action_buttons(stress: int, addict: int) -> void:
    # ── 获取当前可用地点集合（尊重时段/周末限制）──────────────────
    var avail_set: Dictionary = {}
    for entry in GameManager.get_available_locations():
        if entry["available"]:
            avail_set[entry["id"]] = true

    # ── 📝 完成作业 ──────────────────────────────────────
    var hw_btn: Button = _board_cache.get("btn_homework")
    if hw_btn:
        var hw_alert = (GameManager.hw_status == 1)
        var home_avail = avail_set.has("home")
        _apply_btn_style(hw_btn, Color(0.35, 0.55, 0.85), hw_alert)
        hw_btn.disabled = (GameManager.hw_status == 2) or not home_avail
        match GameManager.hw_status:
            1: hw_btn.text = "📝 去写作业！" if home_avail else "📝 去写作业(%s)" % _loc_unavail_reason("home")
            2: hw_btn.text = "✅ 作业已完成"
            _: hw_btn.text = "📝 完成作业" if home_avail else "📝 卧室(%s)" % _loc_unavail_reason("home")

    # ── 🏃 减压放松 ──────────────────────────────────────
    var relax_btn: Button = _board_cache.get("btn_relax")
    if relax_btn:
        var relax_alert = (stress >= 60 or addict >= 60)
        var relax_avail = avail_set.has("playground")
        _apply_btn_style(relax_btn, Color(0.30, 0.65, 0.45), relax_alert and relax_avail)
        relax_btn.disabled = not relax_avail
        if not relax_avail:
            relax_btn.text = "🏃 操场(%s)" % _loc_unavail_reason("playground")
        elif stress >= 60:
            relax_btn.text = "🏃 去减压！(压力高)"
        elif addict >= 60:
            relax_btn.text = "🏃 去运动！(网瘾重)"
        else:
            relax_btn.text = "🏃 减压放松"

    # ── 🛒 小卖部零食 ──────────────────────────────────────
    var shop_btn: Button = _board_cache.get("btn_shop")
    if shop_btn:
        var money_alert = (GameManager.money < 20)
        var shop_avail = avail_set.has("off_campus_shop")
        _apply_btn_style(shop_btn, Color(0.60, 0.50, 0.25), false)
        shop_btn.disabled = not shop_avail
        if not shop_avail:
            shop_btn.text = "🛒 小卖部(%s)" % _loc_unavail_reason("off_campus_shop")
        elif money_alert:
            shop_btn.text = "🛒 零花钱不足"
        else:
            shop_btn.text = "🛒 小卖部零食"

    # ── 📊 角色属性 ──────────────────────────────────────
    var stats_btn: Button = _board_cache.get("btn_stats")
    if stats_btn:
        _apply_btn_style(stats_btn, Color(0.40, 0.38, 0.70), false)
        stats_btn.text = "📊 角色属性"
        stats_btn.disabled = false

    # ── 👗 今日穿搭 ──────────────────────────────────────
    var wardrobe_btn: Button = _board_cache.get("btn_wardrobe")
    if wardrobe_btn:
        _apply_btn_style(wardrobe_btn, Color(0.65, 0.30, 0.55), false)
        wardrobe_btn.text = "👗 今日穿搭"
        wardrobe_btn.disabled = false

    # ── 📚 自习学习 ──────────────────────────────────────
    var study_btn: Button = _board_cache.get("btn_study")
    if study_btn:
        var study_avail = avail_set.has("classroom")
        _apply_btn_style(study_btn, Color(0.30, 0.55, 0.55), false)
        study_btn.disabled = not study_avail
        study_btn.text = "📚 自习学习" if study_avail else "📚 教室(%s)" % _loc_unavail_reason("classroom")



# ════════════════════════════════════════════════════════════
# ── 💌 邀请面板（内聚至 Dashboard）────────────────────────────
# ════════════════════════════════════════════════════════════

## 渲染待处理邀请卡到 parent 容器。
## on_accept_cb: func(char_id: String) → 应调用 accept_invite 并刷新 UI
## on_decline_cb: func(char_id: String) → 应调用 decline_invite 并刷新 UI
func render_invite_panel(parent: Control,
        on_accept_cb: Callable, on_decline_cb: Callable) -> void:
    # 清除旧邀请面板（避免重复追加）
    for child in parent.get_children():
        if child.name.begins_with("InvitePanel"):
            parent.remove_child(child)
            child.queue_free()

    var invites = GameManager.get_pending_invites()
    if invites.is_empty(): return

    var invite_panel = VBoxContainer.new()
    invite_panel.name = "InvitePanel"
    invite_panel.add_theme_constant_override("separation", 8)
    invite_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    invite_panel.custom_minimum_size   = Vector2(680, 0)

    var hdr = Label.new()
    hdr.text = "💌  待处理邀请"
    hdr.add_theme_font_size_override("font_size", 14)
    hdr.add_theme_color_override("font_color", Color(1, 0.84, 0.2, 0.8))
    invite_panel.add_child(hdr)

    for inv in invites:
        var char_color = Color(inv["char_color"])

        var card = PanelContainer.new()
        var cs = StyleBoxFlat.new()
        cs.bg_color    = Color(char_color.r, char_color.g, char_color.b, 0.10)
        cs.border_color = Color(char_color.r, char_color.g, char_color.b, 0.55)
        cs.border_width_left   = 2; cs.border_width_right   = 2
        cs.border_width_top    = 2; cs.border_width_bottom  = 2
        cs.corner_radius_top_left    = 10; cs.corner_radius_top_right    = 10
        cs.corner_radius_bottom_left = 10; cs.corner_radius_bottom_right = 10
        cs.content_margin_left = 14; cs.content_margin_right  = 14
        cs.content_margin_top  = 10; cs.content_margin_bottom = 10
        card.add_theme_stylebox_override("panel", cs)

        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 12)
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        card.add_child(row)

        # 角色 emoji
        var emoji_lbl = Label.new()
        emoji_lbl.text = inv["char_emoji"]
        emoji_lbl.add_theme_font_size_override("font_size", 24)
        row.add_child(emoji_lbl)

        # 邀请文字
        var txt_vbox = VBoxContainer.new()
        txt_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        txt_vbox.add_theme_constant_override("separation", 2)
        row.add_child(txt_vbox)

        var name_lbl = Label.new()
        name_lbl.text = "%s · %s" % [inv["char_name"], inv["loc_name"]]
        name_lbl.add_theme_font_size_override("font_size", 15)
        name_lbl.add_theme_color_override("font_color", char_color)
        txt_vbox.add_child(name_lbl)

        var desc_lbl = Label.new()
        desc_lbl.text = inv.get("invite_text", "")
        desc_lbl.add_theme_font_size_override("font_size", 13)
        desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
        desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        txt_vbox.add_child(desc_lbl)

        # 接受按钮
        var accept_btn = Button.new()
        accept_btn.text = "✅ 接受"
        accept_btn.add_theme_font_size_override("font_size", 14)
        accept_btn.custom_minimum_size = Vector2(80, 38)
        accept_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        var as_ = StyleBoxFlat.new()
        as_.bg_color = Color(0.1, 0.55, 0.3, 0.9)
        as_.corner_radius_top_left    = 8; as_.corner_radius_top_right    = 8
        as_.corner_radius_bottom_left = 8; as_.corner_radius_bottom_right = 8
        as_.content_margin_left = 8; as_.content_margin_right = 8
        as_.content_margin_top  = 4; as_.content_margin_bottom = 4
        accept_btn.add_theme_stylebox_override("normal", as_)
        var ah_ = as_.duplicate(); ah_.bg_color = Color(0.15, 0.7, 0.4, 1.0)
        accept_btn.add_theme_stylebox_override("hover", ah_)
        var cid = inv["char_id"]
        accept_btn.pressed.connect(func(): on_accept_cb.call(cid))
        row.add_child(accept_btn)

        # 婉拒按钮
        var decline_btn = Button.new()
        decline_btn.text = "🙅 婉拒"
        decline_btn.add_theme_font_size_override("font_size", 14)
        decline_btn.custom_minimum_size = Vector2(80, 38)
        decline_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        var ds_ = StyleBoxFlat.new()
        ds_.bg_color = Color(0.4, 0.15, 0.15, 0.7)
        ds_.corner_radius_top_left    = 8; ds_.corner_radius_top_right    = 8
        ds_.corner_radius_bottom_left = 8; ds_.corner_radius_bottom_right = 8
        ds_.content_margin_left = 8; ds_.content_margin_right = 8
        ds_.content_margin_top  = 4; ds_.content_margin_bottom = 4
        decline_btn.add_theme_stylebox_override("normal", ds_)
        var dh_ = ds_.duplicate(); dh_.bg_color = Color(0.6, 0.2, 0.2, 0.9)
        decline_btn.add_theme_stylebox_override("hover", dh_)
        decline_btn.pressed.connect(func(): on_decline_cb.call(cid))
        row.add_child(decline_btn)

        invite_panel.add_child(card)

    parent.add_child(invite_panel)

