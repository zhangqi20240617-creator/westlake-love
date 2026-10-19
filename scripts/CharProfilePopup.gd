extends Control

# 人物档案弹窗 — 完全通过 GDScript 动态创建 UI

var _overlay: ColorRect
var _panel: PanelContainer
var _sprite_img: TextureRect
var _name_lbl: Label
var _tag_lbl: Label
var _intro_lbl: Label
var _aff_bar: ProgressBar
var _aff_val_lbl: Label
var _aff_desc_lbl: Label
var _rel_stage_lbl: Label
var _locs_hbox: HBoxContainer
var _tween: Tween

func _ready():
    _build_ui()
    hide()

func _build_ui():
    # 全屏半透明遮罩
    _overlay = ColorRect.new()
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _overlay.color = Color(0, 0, 0, 0.7)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.gui_input.connect(_on_overlay_clicked)
    add_child(_overlay)

    # 卡片面板
    _panel = PanelContainer.new()
    _panel.custom_minimum_size = Vector2(600, 420)
    _panel.layout_mode = 1
    _panel.set_anchors_preset(Control.PRESET_CENTER)
    _panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _panel.grow_vertical = Control.GROW_DIRECTION_BOTH

    var panel_style = StyleBoxFlat.new()
    panel_style.bg_color = Color(0.07, 0.08, 0.12, 0.98)
    panel_style.corner_radius_top_left = 16
    panel_style.corner_radius_top_right = 16
    panel_style.corner_radius_bottom_left = 16
    panel_style.corner_radius_bottom_right = 16
    panel_style.border_width_left = 1; panel_style.border_width_right = 1
    panel_style.border_width_top = 1; panel_style.border_width_bottom = 1
    panel_style.border_color = Color(1, 1, 1, 0.12)
    _panel.add_theme_stylebox_override("panel", panel_style)
    add_child(_panel)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    _panel.add_child(margin)

    # 主体水平布局
    var main_hbox = HBoxContainer.new()
    main_hbox.add_theme_constant_override("separation", 24)
    margin.add_child(main_hbox)

    # ── 左列：立绘 ──────────────────────────────────────────
    var left_vbox = VBoxContainer.new()
    left_vbox.custom_minimum_size = Vector2(180, 0)
    left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    left_vbox.add_theme_constant_override("separation", 10)
    main_hbox.add_child(left_vbox)

    # 立绘容器（带圆角背景）
    var sprite_bg = PanelContainer.new()
    sprite_bg.custom_minimum_size = Vector2(170, 240)
    var sprite_bg_style = StyleBoxFlat.new()
    sprite_bg_style.bg_color = Color(0.04, 0.05, 0.08, 1)
    sprite_bg_style.corner_radius_top_left = 10
    sprite_bg_style.corner_radius_top_right = 10
    sprite_bg_style.corner_radius_bottom_left = 10
    sprite_bg_style.corner_radius_bottom_right = 10
    sprite_bg.add_theme_stylebox_override("panel", sprite_bg_style)
    left_vbox.add_child(sprite_bg)

    _sprite_img = TextureRect.new()
    _sprite_img.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
    _sprite_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _sprite_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    sprite_bg.add_child(_sprite_img)

    # 光效条（角色主题色）
    var glow = ColorRect.new()
    glow.custom_minimum_size = Vector2(0, 3)
    glow.name = "GlowBar"
    left_vbox.add_child(glow)

    # ── 右列：信息 ──────────────────────────────────────────
    var right_vbox = VBoxContainer.new()
    right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_vbox.add_theme_constant_override("separation", 10)
    main_hbox.add_child(right_vbox)

    # 名字 + tag 行
    var name_row = HBoxContainer.new()
    name_row.add_theme_constant_override("separation", 10)
    right_vbox.add_child(name_row)

    _name_lbl = Label.new()
    _name_lbl.add_theme_font_size_override("font_size", 30)
    _name_lbl.add_theme_color_override("font_color", Color(0.94, 0.92, 0.88, 1))
    name_row.add_child(_name_lbl)

    _tag_lbl = Label.new()
    _tag_lbl.add_theme_font_size_override("font_size", 16)
    _tag_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
    _tag_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    name_row.add_child(_tag_lbl)

    # 分隔线
    var sep1 = HSeparator.new()
    sep1.modulate = Color(1, 1, 1, 0.1)
    right_vbox.add_child(sep1)

    # 介绍文字
    _intro_lbl = Label.new()
    _intro_lbl.add_theme_font_size_override("font_size", 17)
    _intro_lbl.add_theme_color_override("font_color", Color(0.85, 0.83, 0.80, 0.8))
    _intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    right_vbox.add_child(_intro_lbl)

    # 关系阶段
    _rel_stage_lbl = Label.new()
    _rel_stage_lbl.add_theme_font_size_override("font_size", 16)
    _rel_stage_lbl.add_theme_color_override("font_color", Color(1, 0.84, 0.2, 0.9))
    right_vbox.add_child(_rel_stage_lbl)

    # 好感度条
    var aff_lbl = Label.new()
    aff_lbl.text = "好感度"
    aff_lbl.add_theme_font_size_override("font_size", 15)
    aff_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
    right_vbox.add_child(aff_lbl)

    _aff_bar = ProgressBar.new()
    _aff_bar.custom_minimum_size = Vector2(0, 8)
    _aff_bar.show_percentage = false
    _aff_bar.value = 0
    _aff_bar.max_value = 100
    var bar_bg = StyleBoxFlat.new()
    bar_bg.bg_color = Color(1, 1, 1, 0.08)
    bar_bg.corner_radius_top_left = 4; bar_bg.corner_radius_top_right = 4
    bar_bg.corner_radius_bottom_left = 4; bar_bg.corner_radius_bottom_right = 4
    _aff_bar.add_theme_stylebox_override("background", bar_bg)
    right_vbox.add_child(_aff_bar)

    # 好感度数值
    var aff_row = HBoxContainer.new()
    right_vbox.add_child(aff_row)

    _aff_val_lbl = Label.new()
    _aff_val_lbl.add_theme_font_size_override("font_size", 16)
    _aff_val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    aff_row.add_child(_aff_val_lbl)

    _aff_desc_lbl = Label.new()
    _aff_desc_lbl.add_theme_font_size_override("font_size", 15)
    _aff_desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
    aff_row.add_child(_aff_desc_lbl)

    # 常见地点
    var loc_header = Label.new()
    loc_header.text = "常见地点"
    loc_header.add_theme_font_size_override("font_size", 15)
    loc_header.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
    right_vbox.add_child(loc_header)

    _locs_hbox = HBoxContainer.new()
    _locs_hbox.add_theme_constant_override("separation", 6)
    right_vbox.add_child(_locs_hbox)

    # 关闭按钮
    var close_btn = Button.new()
    close_btn.text = "关闭 ✕"
    close_btn.custom_minimum_size = Vector2(0, 42)
    close_btn.add_theme_font_size_override("font_size", 16)
    close_btn.pressed.connect(hide)
    right_vbox.add_child(close_btn)

# ── 显示指定角色档案 ──────────────────────────────────────────
func show_char(char_id: String):
    var meta = GameManager.char_meta.get(char_id, {})
    if meta.is_empty(): return

    var char_data = DataManager.get_character(char_id)
    var aff = GameManager.favorability.get(char_id, 0)
    var char_color = Color(meta.get("color", "#aaaaaa"))

    # 角色名 + tag
    _name_lbl.text = meta.get("name", char_id)
    _tag_lbl.text = meta.get("tag", "")
    _tag_lbl.add_theme_color_override("font_color", char_color)

    # 介绍
    _intro_lbl.text = char_data.get("intro", meta.get("intro", "暂无介绍。"))

    # 立绘
    _sprite_img.texture = null
    var png_path = "res://assets/sprites/%s/default.png" % char_id
    var jpg_path = "res://assets/sprites/%s/default.jpg" % char_id
    if ResourceLoader.exists(png_path):
        _sprite_img.texture = load(png_path)
    elif ResourceLoader.exists(jpg_path):
        _sprite_img.texture = load(jpg_path)

    # 光效条颜色
    var glow_bar = _panel.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/GlowBar")
    if not glow_bar:
        var left_vbox = _panel.find_child("GlowBar", true, false)
        if left_vbox:
            left_vbox.color = char_color
    var glow = find_child("GlowBar", true, false)
    if glow: glow.color = char_color

    # 好感度进度条（带动画）
    _aff_bar.value = 0
    var fill_style = StyleBoxFlat.new()
    fill_style.bg_color = char_color
    fill_style.corner_radius_top_left = 4; fill_style.corner_radius_top_right = 4
    fill_style.corner_radius_bottom_left = 4; fill_style.corner_radius_bottom_right = 4
    _aff_bar.add_theme_stylebox_override("fill", fill_style)

    var hearts = "💖" if aff >= 80 else ("❤️" if aff >= 50 else ("🩷" if aff >= 25 else "🤍"))
    _aff_val_lbl.text = "%s  %d / 100" % [hearts, aff]
    _aff_val_lbl.add_theme_color_override("font_color", char_color)

    var rel_stage = "陌路人"
    if aff >= 100: rel_stage = "永恒的羁绊 ✨"
    elif aff >= 80: rel_stage = "心有灵犀 💖"
    elif aff >= 50: rel_stage = "无话不谈 ❤️"
    elif aff >= 25: rel_stage = "渐渐熟络 🩷"
    elif aff > 0:   rel_stage = "初次相识 🤍"
    _rel_stage_lbl.text = "当前关系：" + rel_stage
    _aff_desc_lbl.text = "上次互动：第%s天" % str(GameManager.flags.get("last_interact_" + char_id, "?"))

    # 常见地点
    for child in _locs_hbox.get_children(): child.queue_free()
    var char_locs = char_data.get("locations", [])
    for loc_id in char_locs:
        var loc = GameManager.locations.get(loc_id, {})
        if loc.is_empty(): continue
        var tag = Button.new()
        tag.text = loc.get("icon","📍") + " " + loc.get("name", loc_id)
        tag.disabled = true
        tag.add_theme_font_size_override("font_size", 15)
        var tag_style = StyleBoxFlat.new()
        tag_style.bg_color = char_color.darkened(0.5)
        tag_style.border_width_left = 1; tag_style.border_width_right = 1
        tag_style.border_width_top = 1; tag_style.border_width_bottom = 1
        tag_style.border_color = char_color
        tag_style.corner_radius_top_left = 4; tag_style.corner_radius_top_right = 4
        tag_style.corner_radius_bottom_left = 4; tag_style.corner_radius_bottom_right = 4
        tag.add_theme_stylebox_override("disabled", tag_style)
        _locs_hbox.add_child(tag)

    show()

    # 好感度条动画
    if _tween: _tween.kill()
    _tween = create_tween()
    _tween.tween_property(_aff_bar, "value", aff, 0.6).set_ease(Tween.EASE_OUT)

func _on_overlay_clicked(event: InputEvent):
    if event is InputEventMouseButton and event.pressed:
        hide()
