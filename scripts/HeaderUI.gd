# HeaderUI.gd
class_name HeaderUI
extends RefCounted

var date_lbl: Label
var time_lbl: Label
var stats_row: Control
var money_lbl: Label
var exam_lbl: Label  # 中考倒计时挂件（初三起显示，纯代码创建）

const _STAT_ORDER = ["intellect", "strength", "social", "art", "charm", "stress", "addict"]

const STAT_INFO = {
    "intellect": {"icon": "📚", "label": "学习", "color": Color(0.49, 0.78, 0.89)},
    "strength":  {"icon": "⚽", "label": "运动", "color": Color(0.50, 0.90, 0.71)},
    "social":    {"icon": "💬", "label": "社交", "color": Color(0.94, 0.78, 0.47)},
    "art":       {"icon": "🎨", "label": "艺术", "color": Color(0.78, 0.66, 0.88)},
    "charm":     {"icon": "✨", "label": "魅力", "color": Color(0.94, 0.60, 0.72)},
    "stress":    {"icon": "💢", "label": "压力", "color": Color(0.94, 0.44, 0.44)},
    "addict":    {"icon": "📱", "label": "网瘾", "color": Color(1.00, 0.55, 0.20)},
}

const SLOT_COLORS = {
    "morning": Color(1, 0.84, 0.2),
    "noon":    Color(1, 0.6, 0.2),
    "after":   Color(0.98, 0.55, 0.4),
    "evening": Color(0.6, 0.6, 1.0),
}

var _stat_bar_cache: Dictionary = {}

func setup(p_date_lbl: Label, p_time_lbl: Label, p_stats_row: Control, p_money_lbl: Label):
    date_lbl = p_date_lbl
    time_lbl = p_time_lbl
    stats_row = p_stats_row
    money_lbl = p_money_lbl
    
    _init_stat_bars()
    _init_exam_widget()

# ── 中考倒计时挂件：挂在顶栏 HBox 最右侧新增一列（避免撑高 Header）──
func _init_exam_widget():
    if not date_lbl: return
    var info_vbox = date_lbl.get_parent()
    if info_vbox == null: return
    var hbox = info_vbox.get_parent()
    if hbox == null: return
    exam_lbl = Label.new()
    exam_lbl.name = "ExamCountdownLbl"
    exam_lbl.add_theme_font_size_override("font_size", 12)
    exam_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    exam_lbl.visible = false
    hbox.add_child(exam_lbl)
    # 插到 MoneyLbl 之后（按钮组之前），而不是最右端
    if money_lbl and money_lbl.get_parent() == hbox:
        hbox.move_child(exam_lbl, money_lbl.get_index() + 1)

# ── 预建属性条节点 ──
func _init_stat_bars():
    _stat_bar_cache.clear()
    for child in stats_row.get_children():
        child.queue_free()
        
    for stat_name in _STAT_ORDER:
        var info = STAT_INFO[stat_name]

        var vbox = VBoxContainer.new()
        vbox.custom_minimum_size = Vector2(52, 0)
        vbox.alignment = BoxContainer.ALIGNMENT_CENTER

        # 图标 + 数值
        var top = HBoxContainer.new()
        top.alignment = BoxContainer.ALIGNMENT_CENTER
        top.add_theme_constant_override("separation", 3)

        var icon_lbl = Label.new()
        icon_lbl.text = info.icon
        icon_lbl.add_theme_font_size_override("font_size", 13)

        var val_lbl = Label.new()
        val_lbl.add_theme_font_size_override("font_size", 13)

        top.add_child(icon_lbl)
        top.add_child(val_lbl)

        # 进度条
        var bar = ProgressBar.new()
        bar.custom_minimum_size = Vector2(50, 5)
        bar.show_percentage = false
        bar.max_value = 100

        var fill_style = ThemeUtils.create_style(info.color, 2)
        bar.add_theme_stylebox_override("fill", fill_style)

        var bg_style = ThemeUtils.create_style(Color(1, 1, 1, 0.08), 2)
        bar.add_theme_stylebox_override("background", bg_style)

        vbox.add_child(top)
        vbox.add_child(bar)
        stats_row.add_child(vbox)

        _stat_bar_cache[stat_name] = {
            "vbox": vbox, "val_lbl": val_lbl, "bar": bar,
            "fill_style": fill_style
        }

# ── 顶部信息栏渲染 ──
func render_header():
    if not date_lbl: return
    
    var grade_info = GameManager.get_grade_info()
    var weeks = ["一", "二", "三", "四", "五", "六", "日"]
    var week_str = weeks[GameManager.day_of_week - 1]
    var day_in_sem = GameManager.get_day_in_sem()
    var is_weekend = GameManager.is_weekend()
    var slot_id = ["morning","noon","after","evening"][GameManager.slot_index]

    date_lbl.text = "%s%s · 第%d天 · 星期%s%s" % [
        grade_info.grade, grade_info.sem, day_in_sem, week_str,
        "  🎉" if is_weekend else ""
    ]
    var slot_color = SLOT_COLORS.get(slot_id, Color.WHITE)
    var weather_text = GameManager.WEATHER_NAMES.get(GameManager.current_weather, "☀️ 晴朗")
    time_lbl.text = "%s  %s" % [GameManager.get_time_label(), weather_text]
    time_lbl.add_theme_color_override("font_color", slot_color)

    # 只更新属性数值，不重建节点
    for stat_name in _STAT_ORDER:
        var cache = _stat_bar_cache.get(stat_name, {})
        if cache.is_empty(): continue
        var val = GameManager.stats.get(stat_name, 0)
        var base_color: Color = STAT_INFO[stat_name].color
        var color = base_color
        if stat_name == "stress" and val > 60:
            color = Color(1, 0.2, 0.2)
        elif stat_name == "addict" and val > 60:
            color = Color(0.95, 0.2, 0.1)

        cache["val_lbl"].text = str(val)
        cache["val_lbl"].add_theme_color_override("font_color", color)
        cache["bar"].value = val
        cache["fill_style"].bg_color = color

    money_lbl.text = "💰 " + str(GameManager.money)

    _render_exam_widget()

# ── 中考倒计时挂件渲染：初三（day>=361）起常驻显示差距 ──
func _render_exam_widget():
    if not exam_lbl: return
    if GameManager.day < ExamManager.PRESSURE_START_DAY:
        exam_lbl.visible = false
        return
    var info = ExamManager.get_target_gap()
    var sname = info.school.get("name", "高中") if info.school else "高中"
    var gap = int(info.gap)
    var days = int(info.days_left)
    if gap > 0:
        exam_lbl.text = "🎯 中考剩%d天\n预估%s · 距%s差%d" % [days, info.projected_range, sname, gap]
        # 差距越大越红：差 60 分以上深红，其余橙红
        if gap >= 60:
            exam_lbl.add_theme_color_override("font_color", Color(1.0, 0.30, 0.25))
        else:
            exam_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.30))
    else:
        exam_lbl.text = "🎯 中考剩%d天\n预估%s · 已过%s线 ✓" % [days, info.projected_range, sname]
        exam_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55))
        
    # 奥赛金牌保送覆盖
    if GameManager.flags.has("flag_olympiad_gold"):
        exam_lbl.text = "🎯 中考剩%d天\n🎓 提前批直通车 · 🥇 奥赛省第一已保送" % days
        exam_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
    elif GameManager.flags.has("flag_olympiad_joined") and not GameManager.flags.has("flag_olympiad_dropped"):
        exam_lbl.text += "\n🏆 [奥赛集训进行中]"
        
    exam_lbl.visible = true
