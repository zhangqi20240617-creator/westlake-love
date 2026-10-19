# GirlsGridUI.gd
class_name GirlsGridUI
extends RefCounted

var girls_grid: Control
var char_profile_popup: Control
var _girl_card_cache: Dictionary = {}

func setup(p_girls_grid: Control, p_char_profile_popup: Control):
    girls_grid = p_girls_grid
    char_profile_popup = p_char_profile_popup
    
    init_girl_cards()

func init_girl_cards():
    _girl_card_cache.clear()
    for child in girls_grid.get_children():
        child.queue_free()

    var female_chars = ["yutong", "jingjing", "wanqing", "xiaoxia", "keke"]
    var male_chars   = ["yifei", "zicheng", "beichen", "jingjing_m", "zijun"]
    var target_ids   = female_chars if GameManager.gender == "male" else male_chars

    for char_id in target_ids:
        var meta = GameManager.char_meta.get(char_id, {})
        if meta.is_empty(): continue
        var char_color = Color(meta.get("color", "#aaaaaa"))
        var is_locked  = GameManager.day < meta.get("unlockDay", 1)
        var aff        = GameManager.favorability.get(char_id, 0)

        var entry = _build_girl_card(char_id, meta, char_color, is_locked, aff)
        _girl_card_cache[char_id] = entry
        girls_grid.add_child(entry["card"])

# 构建单张角色卡片，返回带节点引用的缓存字典
func _build_girl_card(char_id: String, meta: Dictionary, char_color: Color,
                       is_locked: bool, aff: int) -> Dictionary:
    # 描边与底色
    var card_style = ThemeUtils.create_style(
        Color(0.09, 0.10, 0.14, 1),
        6,
        char_color if not is_locked else Color(1, 1, 1, 0.06),
        1
    )
    card_style.border_color.a = 0.25 if not is_locked else 0.06

    var card = PanelContainer.new()
    card.add_theme_stylebox_override("panel", card_style)

    var inner = VBoxContainer.new()
    inner.add_theme_constant_override("separation", 4)

    # 头部
    var header_hbox = HBoxContainer.new()
    header_hbox.add_theme_constant_override("separation", 6)

    var emoji_lbl = Label.new()
    emoji_lbl.text = "🔒" if is_locked else meta.get("emoji", "?")
    emoji_lbl.add_theme_font_size_override("font_size", 18)

    var name_tag_vbox = VBoxContainer.new()
    name_tag_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_tag_vbox.add_theme_constant_override("separation", 1)

    var name_lbl = Label.new()
    name_lbl.text = "???" if is_locked else meta.get("name", char_id)
    name_lbl.add_theme_font_size_override("font_size", 16)
    name_lbl.add_theme_color_override("font_color",
        Color(1, 1, 1, 0.3) if is_locked else Color(0.94, 0.92, 0.88, 1))

    var tag_lbl = Label.new()
    tag_lbl.text = meta.get("tag", "")
    tag_lbl.add_theme_font_size_override("font_size", 13)
    tag_lbl.add_theme_color_override("font_color",
        Color(1, 1, 1, 0.2) if is_locked else char_color)

    name_tag_vbox.add_child(name_lbl)
    name_tag_vbox.add_child(tag_lbl)
    header_hbox.add_child(emoji_lbl)
    header_hbox.add_child(name_tag_vbox)
    inner.add_child(header_hbox)

    var bar: ProgressBar = null
    var heart_lbl: Label = null

    if not is_locked:
        # 好感度条
        var fill = ThemeUtils.create_style(char_color, 2)

        bar = ProgressBar.new()
        bar.custom_minimum_size = Vector2(0, 5)
        bar.show_percentage = false
        bar.max_value = 100
        bar.value = aff
        bar.add_theme_stylebox_override("fill", fill)

        var bg_s = ThemeUtils.create_style(Color(1, 1, 1, 0.07), 2)
        bar.add_theme_stylebox_override("background", bg_s)

        var hearts = "💖" if aff >= 80 else ("❤️" if aff >= 50 else ("🩷" if aff >= 25 else "🤍"))
        heart_lbl = Label.new()
        heart_lbl.text = hearts + " " + str(aff)
        heart_lbl.add_theme_font_size_override("font_size", 13)
        heart_lbl.add_theme_color_override("font_color", char_color)

        var max_lbl = Label.new()
        max_lbl.text = "/100"
        max_lbl.add_theme_font_size_override("font_size", 13)
        max_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
        max_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        var aff_row = HBoxContainer.new()
        aff_row.add_child(heart_lbl)
        aff_row.add_child(max_lbl)

        inner.add_child(bar)
        inner.add_child(aff_row)

        var click_hint = Label.new()
        click_hint.text = "点击查看档案 ›"
        click_hint.add_theme_font_size_override("font_size", 12)
        click_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.2))
        click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        inner.add_child(click_hint)

        card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        card.mouse_filter = Control.MOUSE_FILTER_STOP
        var cid = char_id
        card.gui_input.connect(func(ev: InputEvent):
            if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
                char_profile_popup.show_char(cid)
        )
    else:
        var hint = Label.new()
        hint.text = "尚未相遇"
        hint.add_theme_font_size_override("font_size", 13)
        hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.2))
        inner.add_child(hint)

    card.add_child(inner)
    return {"card": card, "bar": bar, "heart_lbl": heart_lbl,
            "card_style": card_style, "was_locked": is_locked, "meta": meta, "char_color": char_color}

# 轻量更新：只改数值和颜色，锁定状态变化时重建该卡片
func update_girl_cards():
    for char_id in _girl_card_cache.keys():
        var entry    = _girl_card_cache[char_id]
        var meta     = entry["meta"]
        var is_locked = GameManager.day < meta.get("unlockDay", 1)
        var was_locked = entry["was_locked"]
        var aff      = GameManager.favorability.get(char_id, 0)
        var char_color: Color = entry["char_color"]

        # 锁定状态变化（解锁新角色）→ 重建该卡片
        if is_locked != was_locked:
            var old_card: Node = entry["card"]
            var idx = old_card.get_index()
            old_card.queue_free()
            var new_entry = _build_girl_card(char_id, meta, char_color, is_locked, aff)
            _girl_card_cache[char_id] = new_entry
            girls_grid.add_child(new_entry["card"])
            girls_grid.move_child(new_entry["card"], idx)
            continue

        # 已解锁：只更新进度条和心形文字
        if not is_locked and entry["bar"] != null:
            entry["bar"].value = aff
            var hearts = "💖" if aff >= 80 else ("❤️" if aff >= 50 else ("🩷" if aff >= 25 else "🤍"))
            entry["heart_lbl"].text = hearts + " " + str(aff)
            # 更新描边颜色（好感≥80 时加深）
            entry["card_style"].border_color = char_color
            entry["card_style"].border_color.a = 0.25
