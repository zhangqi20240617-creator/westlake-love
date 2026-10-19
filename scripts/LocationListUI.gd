## LocationListUI.gd
## 地点列表 & 快捷操作栏 代理类
## 负责渲染左侧 LocationList 网格与 QuickList 操作按钮，
## 从 MainGame.gd 解耦，保持与 GirlsGridUI / HeaderUI 一致的代理风格。

class_name LocationListUI

# ── 依赖节点引用 ────────────────────────────────────────────
var _location_list: Control   # GridContainer / VBoxContainer
var _quick_list:    Control   # HBoxContainer

# ── Dirty 检测缓存（避免每次 state_updated 都全量重建）────────
var _loc_last_slot:   int = -1
var _loc_last_day:    int = -1
var _loc_last_stress: int = -1

# ── 回调引用（由 MainGame 注入）──────────────────────────────
var _on_location_selected_cb: Callable   # func(loc_id: String)
var _on_skip_slot_cb:         Callable   # func()
var _on_save_cb:              Callable   # func()

# ────────────────────────────────────────────────────────────
func setup(location_list: Control, quick_list: Control,
           on_location_selected: Callable,
           on_skip_slot: Callable,
           on_save: Callable) -> void:
    _location_list          = location_list
    _quick_list             = quick_list
    _on_location_selected_cb = on_location_selected
    _on_skip_slot_cb         = on_skip_slot
    _on_save_cb              = on_save

# ── 主渲染入口（带 dirty 检测）──────────────────────────────
func render_locations() -> void:
    var cur_slot   = GameManager.slot_index
    var cur_day    = GameManager.day
    var cur_stress = GameManager.stats.get("stress", 0)

    var needs_rebuild = (
        cur_slot   != _loc_last_slot
        or cur_day != _loc_last_day
        or (cur_stress >= 80) != (_loc_last_stress >= 80)
    )

    if not needs_rebuild and _location_list.get_child_count() > 0:
        return   # 状态未变，跳过全量重建

    _loc_last_slot   = cur_slot
    _loc_last_day    = cur_day
    _loc_last_stress = cur_stress

    for child in _location_list.get_children(): child.queue_free()
    for child in _quick_list.get_children():    child.queue_free()

    # ── 快捷按钮区 ──────────────────────────────────────────
    var rest_btn = _make_quick_btn("🛌", "休息/跳过", false)
    rest_btn.pressed.connect(_on_skip_slot_cb)
    _quick_list.add_child(rest_btn)

    var save_btn = _make_quick_btn("💾", "存档", false)
    save_btn.pressed.connect(_on_save_cb)
    _quick_list.add_child(save_btn)

    # ── 地点卡片区 ──────────────────────────────────────────
    # 特殊日期：强制锁定单一地点（如毕业前夜只能去西湖边）
    var forced_loc = GameManager.get_forced_location_for_day()
    if forced_loc != "":
        var loc_data = GameManager.locations.get(forced_loc, {})
        if not loc_data.is_empty():
            # 氛围提示标签
            var hint = Label.new()
            hint.text = "🌙 今晚，只有一个地方值得去……"
            hint.add_theme_font_size_override("font_size", 13)
            hint.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0, 0.75))
            hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            _location_list.add_child(hint)
            # 单个地点卡
            var card = _make_loc_card(loc_data, forced_loc, false, false)
            card.pressed.connect(func(): _on_location_selected_cb.call(forced_loc))
            _location_list.add_child(card)
        return

    var available_locs = GameManager.get_available_locations()
    for entry in available_locs:
        var loc_id       = entry["id"]
        var is_avail     = entry["available"]
        var loc          = GameManager.locations[loc_id]
        var stress_blocked = cur_stress >= 80 and loc_id != "home"
        var locked       = not is_avail or stress_blocked

        var has_event = false
        if is_avail and not locked:
            var ev = DataManager.get_available_event(loc_id)
            has_event = not ev.is_empty() and not ev.get("repeatable", false)

        var card = _make_loc_card(loc, loc_id, locked, has_event)
        if not locked:
            card.pressed.connect(func(): _on_location_selected_cb.call(loc_id))
        _location_list.add_child(card)

# ── 快捷按钮工厂 ────────────────────────────────────────────
func _make_quick_btn(icon: String, label: String, _locked: bool) -> Button:
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(0, 40)

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.13, 0.15, 0.20, 1)
    style.corner_radius_top_left    = 6; style.corner_radius_top_right    = 6
    style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
    btn.add_theme_stylebox_override("normal", style)

    var hover = style.duplicate()
    hover.bg_color = Color(0.18, 0.20, 0.28, 1)
    btn.add_theme_stylebox_override("hover", hover)

    var hbox = HBoxContainer.new()
    hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.alignment    = BoxContainer.ALIGNMENT_CENTER
    hbox.add_theme_constant_override("separation", 8)

    var ico = Label.new()
    ico.text = icon
    ico.add_theme_font_size_override("font_size", 16)

    var lbl = Label.new()
    lbl.text = label
    lbl.add_theme_font_size_override("font_size", 13)
    lbl.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84, 0.85))

    hbox.add_child(ico)
    hbox.add_child(lbl)
    btn.add_child(hbox)
    return btn

# ── 地点卡片工厂 ────────────────────────────────────────────
func _make_loc_card(data: Dictionary, loc_id: String, locked: bool, has_event: bool) -> Button:
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(85, 78)
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.disabled = locked
    btn.clip_contents = true

    var bg_color = Color(0.10, 0.12, 0.17, 1) if not locked else Color(0.07, 0.08, 0.10, 1)
    var style = StyleBoxFlat.new()
    style.bg_color = bg_color
    style.corner_radius_top_left    = 8; style.corner_radius_top_right    = 8
    style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
    style.border_width_left  = 1; style.border_width_right  = 1
    style.border_width_top   = 1; style.border_width_bottom = 1
    style.border_color = Color(1, 1, 1, 0.06)
    btn.add_theme_stylebox_override("normal", style)

    if not locked:
        var hover = style.duplicate()
        hover.bg_color     = Color(0.15, 0.17, 0.25, 1)
        hover.border_color = Color(1, 1, 1, 0.15)
        btn.add_theme_stylebox_override("hover", hover)

    var vbox = VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.alignment    = BoxContainer.ALIGNMENT_CENTER

    # 图标行（含红点提示）
    var icon_row = HBoxContainer.new()
    icon_row.alignment    = BoxContainer.ALIGNMENT_CENTER
    icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var icon_lbl = Label.new()
    icon_lbl.text = data.get("icon", "📍")
    icon_lbl.add_theme_font_size_override("font_size", 22)
    icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon_lbl.modulate.a = 0.35 if locked else 1.0
    icon_row.add_child(icon_lbl)

    if has_event:
        var dot = Label.new()
        dot.text = "●"
        dot.add_theme_font_size_override("font_size", 8)
        dot.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
        icon_row.add_child(dot)

    var name_lbl = Label.new()
    name_lbl.text = data.get("name", "")
    name_lbl.add_theme_font_size_override("font_size", 15)
    name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_lbl.modulate.a = 0.4 if locked else 1.0

    var sub_lbl = Label.new()
    if locked:
        sub_lbl.text = "🔒 未开放"
        sub_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
    else:
        sub_lbl.text = data.get("sub", "")
        sub_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
    sub_lbl.add_theme_font_size_override("font_size", 12)
    sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    vbox.add_child(icon_row)
    vbox.add_child(name_lbl)
    vbox.add_child(sub_lbl)
    btn.add_child(vbox)

    # ── 邀请 badge：角色主动出现在此地点时，显示脉冲角标 ────
    var chars_here = GameManager.get_chars_at_location(loc_id)
    if not chars_here.is_empty():
        var badge = Label.new()
        badge.text = chars_here[0]["char_emoji"] + "!"
        badge.add_theme_font_size_override("font_size", 14)
        badge.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
        badge.position = Vector2(4, 4)
        badge.z_index  = 10
        btn.add_child(badge)

        # 金色发光边框
        var glow_style = style.duplicate()
        glow_style.border_color        = Color(1, 0.84, 0, 0.9)
        glow_style.border_width_left   = 2; glow_style.border_width_right  = 2
        glow_style.border_width_top    = 2; glow_style.border_width_bottom = 2
        btn.add_theme_stylebox_override("normal", glow_style)

    return btn

# ── 强制重置 dirty 标记（用于需要强刷的场合）────────────────
func force_rebuild() -> void:
    _loc_last_slot   = -1
    _loc_last_day    = -1
    _loc_last_stress = -1
