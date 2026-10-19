## CharacterStatsPopup.gd
## 角色状态总览弹窗
## 展示四大类数据：基础属性 / 分科复习 / 好感度 / 基本信息

class_name CharacterStatsPopup
extends Control

signal closed

# 角色元数据（图标、名称、颜色）
const CHAR_META = {
    "yutong":    {"label": "陈雨桐", "emoji": "💙", "color": Color(0.357, 0.624, 0.831)},
    "jingjing":  {"label": "叶菁菁", "emoji": "🌸", "color": Color(0.910, 0.490, 0.604)},
    "wanqing":   {"label": "苏晚晴", "emoji": "💜", "color": Color(0.655, 0.545, 0.980)},
    "xiaoxia":   {"label": "林小夏", "emoji": "💚", "color": Color(0.298, 0.686, 0.541)},
    "yifei":     {"label": "谢怡菲", "emoji": "🎵", "color": Color(0.940, 0.780, 0.470)},
    "zicheng":   {"label": "周子诚", "emoji": "⚽", "color": Color(0.500, 0.820, 0.700)},
    "jingjing_m":{"label": "叶明轩", "emoji": "👦", "color": Color(0.750, 0.650, 0.550)},
}

static func open(parent: Control) -> CharacterStatsPopup:
    var inst = CharacterStatsPopup.new()
    parent.add_child(inst)
    inst._build_ui()
    return inst

func _build_ui() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

    # 全屏遮罩
    var overlay = ColorRect.new()
    overlay.color = Color(0, 0, 0, 0.78)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    overlay.gui_input.connect(func(ev):
        if ev is InputEventMouseButton and ev.pressed: _on_close()
    )

    # 主面板（带滚动）
    var scroll = ScrollContainer.new()
    scroll.set_anchors_preset(Control.PRESET_CENTER)
    scroll.custom_minimum_size = Vector2(640, 680)
    scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    scroll.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
    add_child(scroll)

    var card = PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var cs = StyleBoxFlat.new()
    cs.bg_color = Color(0.07, 0.08, 0.12, 0.98)
    cs.border_width_left   = 2; cs.border_width_right  = 2
    cs.border_width_top    = 2; cs.border_width_bottom = 2
    cs.border_color = Color(0.38, 0.55, 0.85, 0.55)
    cs.corner_radius_top_left    = 18; cs.corner_radius_top_right    = 18
    cs.corner_radius_bottom_left = 18; cs.corner_radius_bottom_right = 18
    cs.content_margin_left = 28; cs.content_margin_right  = 28
    cs.content_margin_top  = 22; cs.content_margin_bottom = 28
    card.add_theme_stylebox_override("panel", cs)
    scroll.add_child(card)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 20)
    card.add_child(vbox)

    # ── 标题行 ────────────────────────────────────────────────
    var title_row = HBoxContainer.new()
    vbox.add_child(title_row)
    var title_lbl = Label.new()
    title_lbl.text = "🧑‍🎓 角色状态总览"
    title_lbl.add_theme_font_size_override("font_size", 22)
    title_lbl.add_theme_color_override("font_color", Color(0.93, 0.91, 1.0))
    title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(title_lbl)
    var close_btn = Button.new()
    close_btn.text = "✕ 关闭"
    close_btn.flat = true
    close_btn.add_theme_font_size_override("font_size", 14)
    close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
    close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    close_btn.pressed.connect(_on_close)
    title_row.add_child(close_btn)

    # ── 基本信息行 ───────────────────────────────────────────
    var info_row = HBoxContainer.new()
    info_row.add_theme_constant_override("separation", 24)
    vbox.add_child(info_row)

    var grade_info = GameManager.get_grade_info()
    var weeks = ["一","二","三","四","五","六","日"]
    var week_str = weeks[GameManager.day_of_week - 1]
    var season_lbl_str = GameManager.get_season_label()

    var info_chips = [
        ["🎒 %s%s" % [grade_info.grade, grade_info.sem], Color(0.5, 0.8, 0.6)],
        ["📅 第%d天 · 星期%s" % [GameManager.day, week_str], Color(0.7, 0.7, 1.0)],
        ["💰 %d 元" % GameManager.money, Color(1.0, 0.85, 0.3)],
        [season_lbl_str, Color(0.9, 0.6, 0.9)],
    ]
    for chip in info_chips:
        var lbl = Label.new()
        lbl.text = chip[0]
        lbl.add_theme_font_size_override("font_size", 14)
        lbl.add_theme_color_override("font_color", chip[1])
        var sty = StyleBoxFlat.new()
        sty.bg_color = chip[1].darkened(0.72)
        sty.corner_radius_top_left    = 8; sty.corner_radius_top_right    = 8
        sty.corner_radius_bottom_left = 8; sty.corner_radius_bottom_right = 8
        sty.content_margin_left = 10; sty.content_margin_right = 10
        sty.content_margin_top  = 4;  sty.content_margin_bottom = 4
        lbl.add_theme_stylebox_override("normal", sty)
        info_row.add_child(lbl)

    vbox.add_child(_make_sep("💪 基础属性"))

    # ── 基础属性（双列布局）────────────────────────────────────
    const STAT_INFO_LOCAL = {
        "intellect": {"icon": "📚", "label": "学习力",  "color": Color(0.49, 0.78, 0.89)},
        "strength":  {"icon": "⚽", "label": "运动力",  "color": Color(0.50, 0.90, 0.71)},
        "social":    {"icon": "💬", "label": "社交力",  "color": Color(0.94, 0.78, 0.47)},
        "art":       {"icon": "🎨", "label": "艺术力",  "color": Color(0.78, 0.66, 0.88)},
        "charm":     {"icon": "✨", "label": "魅力值",  "color": Color(0.94, 0.60, 0.72)},
        "stress":    {"icon": "💢", "label": "压力值",  "color": Color(0.94, 0.44, 0.44)},
        "addict":    {"icon": "📱", "label": "网瘾值",  "color": Color(1.00, 0.55, 0.20)},
    }
    const STAT_ORDER = ["intellect", "strength", "social", "art", "charm", "stress", "addict"]

    var stat_grid = GridContainer.new()
    stat_grid.columns = 2
    stat_grid.add_theme_constant_override("h_separation", 16)
    stat_grid.add_theme_constant_override("v_separation", 10)
    vbox.add_child(stat_grid)

    for s in STAT_ORDER:
        var info = STAT_INFO_LOCAL[s]
        var val  = GameManager.stats.get(s, 0)
        var col  = info.color
        if (s == "stress" or s == "addict") and val > 60:
            col = Color(1.0, 0.25, 0.25)
        stat_grid.add_child(_make_stat_row(info.icon, info.label, val, 100, col))

    vbox.add_child(_make_sep("📖 分科复习进度"))

    # ── 分科复习 ─────────────────────────────────────────────
    const SUBJ_META = {
        "chinese": {"emoji": "📝", "label": "语文"},
        "math":    {"emoji": "🔢", "label": "数学"},
        "english": {"emoji": "🔤", "label": "英语"},
        "science": {"emoji": "🔬", "label": "理科"},
        "society": {"emoji": "🌏", "label": "道法"},
    }
    const SUBJ_ORDER = ["chinese", "math", "english", "science", "society"]

    var subj_grid = GridContainer.new()
    subj_grid.columns = 2
    subj_grid.add_theme_constant_override("h_separation", 16)
    subj_grid.add_theme_constant_override("v_separation", 10)
    vbox.add_child(subj_grid)

    var weakest_id = GameManager.get_weakest_subject().get("id", "")
    for s in SUBJ_ORDER:
        var sm  = SUBJ_META[s]
        var sc  = GameManager.subject_scores.get(s, 0)
        var col = Color(0.38, 0.65, 0.92) if s != weakest_id else Color(1.0, 0.75, 0.2)
        var lbl_text = "%s %s%s" % [sm.emoji, sm.label, " ⬅ 最弱" if s == weakest_id else ""]
        subj_grid.add_child(_make_stat_row(sm.emoji, sm.label + ("  ⬅ 最弱" if s == weakest_id else ""), sc, 100, col))

    vbox.add_child(_make_sep("💗 角色好感度"))

    # ── 好感度 ───────────────────────────────────────────────
    var fav_grid = GridContainer.new()
    fav_grid.columns = 2
    fav_grid.add_theme_constant_override("h_separation", 16)
    fav_grid.add_theme_constant_override("v_separation", 10)
    vbox.add_child(fav_grid)

    for char_id in GameManager.favorability.keys():
        var fav  = GameManager.favorability[char_id]
        if fav <= 0 and not CHAR_META.has(char_id): continue
        var meta = CHAR_META.get(char_id, {"label": char_id, "emoji": "💫", "color": Color(0.7, 0.7, 0.7)})
        var mood = GameManager.char_mood.get(char_id, "normal")
        var mood_icon = {"happy": "😊", "normal": "😐", "upset": "😒"}.get(mood, "😐")
        # 关系状态机：每个角色追加状态 chip，进度条颜色随状态 ramp
        var rel_disp = GameManager.get_rel_state_display(char_id)
        var rel_label = rel_disp.get("label", "")
        var rel_color = Color(rel_disp.get("color", "#9ca3af"))
        fav_grid.add_child(_make_stat_row(
            meta.emoji, "%s  %s ·[%s]" % [meta.label, mood_icon, rel_label], fav, 100, rel_color))

    # 入场动画
    scroll.modulate.a = 0.0
    scroll.position.y += 24.0
    var tw = scroll.create_tween().set_parallel(true)
    tw.tween_property(scroll, "modulate:a", 1.0, 0.28)
    tw.tween_property(scroll, "position:y", scroll.position.y - 24.0, 0.28).set_trans(Tween.TRANS_BACK)

# ── 工具函数：带标题的分隔条 ────────────────────────────────
func _make_sep(title: String) -> HBoxContainer:
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)

    var lbl = Label.new()
    lbl.text = title
    lbl.add_theme_font_size_override("font_size", 15)
    lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))

    var line = HSeparator.new()
    line.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    row.add_child(lbl)
    row.add_child(line)
    return row

# ── 工具函数：单行属性条 ─────────────────────────────────────
func _make_stat_row(icon: String, label_text: String, val: int, max_val: int, color: Color) -> HBoxContainer:
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)

    # 图标+名称
    var name_lbl = Label.new()
    name_lbl.text = label_text
    name_lbl.add_theme_font_size_override("font_size", 14)
    name_lbl.custom_minimum_size = Vector2(140, 0)
    name_lbl.add_theme_color_override("font_color", color.lightened(0.2))
    row.add_child(name_lbl)

    # 进度条
    var bar = ProgressBar.new()
    bar.min_value = 0; bar.max_value = max_val; bar.value = val
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.custom_minimum_size = Vector2(0, 20)
    bar.show_percentage = false

    var bg = StyleBoxFlat.new()
    bg.bg_color = Color(0.15, 0.15, 0.22)
    bg.corner_radius_top_left    = 5; bg.corner_radius_top_right    = 5
    bg.corner_radius_bottom_left = 5; bg.corner_radius_bottom_right = 5
    bar.add_theme_stylebox_override("background", bg)

    var fill = bg.duplicate()
    fill.bg_color = color
    bar.add_theme_stylebox_override("fill", fill)
    row.add_child(bar)

    # 数值标签
    var val_lbl = Label.new()
    val_lbl.text = "%d" % val
    val_lbl.add_theme_font_size_override("font_size", 14)
    val_lbl.add_theme_color_override("font_color", color)
    val_lbl.custom_minimum_size = Vector2(36, 0)
    val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(val_lbl)

    return row

func _on_close() -> void:
    var tw = create_tween()
    tw.tween_property(self, "modulate:a", 0.0, 0.18)
    tw.tween_callback(func():
        closed.emit()
        queue_free()
    )
