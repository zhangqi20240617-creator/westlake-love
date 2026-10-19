## WardrobeUI.gd
## 纸娃娃换装面板
## 左：6个装备槽（点击弹出该槽可穿列表）
## 右：物品网格（已拥有物品筛选）
## 顶：当前穿搭属性加成总览

class_name WardrobeUI
extends Control

signal closed

static func open(parent: Control) -> WardrobeUI:
    var inst = WardrobeUI.new()
    parent.add_child(inst)
    inst._build_ui()
    return inst

# ── 内部引用 ──────────────────────────────────────────────────
var _slot_btns: Dictionary = {}   # slot -> Button
var _item_grid: GridContainer
var _bonus_lbl: Label
var _filter_slot: String = ""     # "" = 全部，否则按槽筛选

func _build_ui() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

    # 全屏遮罩
    var overlay = ColorRect.new()
    overlay.color = Color(0, 0, 0, 0.80)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(overlay)

    # 主卡片
    var card = PanelContainer.new()
    card.set_anchors_preset(Control.PRESET_CENTER)
    card.custom_minimum_size = Vector2(760, 660)
    var cs = StyleBoxFlat.new()
    cs.bg_color = Color(0.07, 0.08, 0.13, 0.98)
    cs.border_width_left   = 2; cs.border_width_right  = 2
    cs.border_width_top    = 2; cs.border_width_bottom = 2
    cs.border_color = Color(0.42, 0.58, 0.90, 0.5)
    cs.corner_radius_top_left    = 18; cs.corner_radius_top_right    = 18
    cs.corner_radius_bottom_left = 18; cs.corner_radius_bottom_right = 18
    cs.content_margin_left = 24; cs.content_margin_right  = 24
    cs.content_margin_top  = 20; cs.content_margin_bottom = 24
    card.add_theme_stylebox_override("panel", cs)
    add_child(card)

    var root_vbox = VBoxContainer.new()
    root_vbox.add_theme_constant_override("separation", 16)
    card.add_child(root_vbox)

    # ── 标题行 ────────────────────────────────────────────────
    var title_row = HBoxContainer.new()
    root_vbox.add_child(title_row)
    var title_lbl = Label.new()
    title_lbl.text = "👗 我的衣橱"
    title_lbl.add_theme_font_size_override("font_size", 22)
    title_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 1.0))
    title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(title_lbl)

    # 去商店按钮
    var shop_btn = Button.new()
    shop_btn.text = "🛍️ 去商店"
    shop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    shop_btn.add_theme_font_size_override("font_size", 14)
    _style_btn(shop_btn, Color(0.6, 0.45, 0.15))
    shop_btn.pressed.connect(_open_shop)
    title_row.add_child(shop_btn)

    var close_btn = Button.new()
    close_btn.text = "✕"
    close_btn.flat = true
    close_btn.add_theme_font_size_override("font_size", 18)
    close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
    close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    close_btn.pressed.connect(_on_close)
    title_row.add_child(close_btn)

    # ── 属性加成总览条 ────────────────────────────────────────
    _bonus_lbl = Label.new()
    _bonus_lbl.add_theme_font_size_override("font_size", 14)
    _bonus_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.65))
    root_vbox.add_child(_bonus_lbl)
    _update_bonus_label()

    root_vbox.add_child(HSeparator.new())

    # ── 主体：左（纸娃娃槽）+ 右（物品列表）──────────────────
    var body_row = HBoxContainer.new()
    body_row.add_theme_constant_override("separation", 20)
    body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_vbox.add_child(body_row)

    # 左侧：装备槽面板
    var left_vbox = VBoxContainer.new()
    left_vbox.add_theme_constant_override("separation", 10)
    left_vbox.custom_minimum_size = Vector2(180, 0)
    body_row.add_child(left_vbox)

    var doll_lbl = Label.new()
    doll_lbl.text = "🧍 当前穿搭"
    doll_lbl.add_theme_font_size_override("font_size", 14)
    doll_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
    left_vbox.add_child(doll_lbl)

    for slot in WardrobeManager.SLOTS:
        var btn = _build_slot_btn(slot)
        left_vbox.add_child(btn)
        _slot_btns[slot] = btn

    # "脱下所有" 按钮
    var unequip_all_btn = Button.new()
    unequip_all_btn.text = "🗑️ 脱下所有"
    unequip_all_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    unequip_all_btn.add_theme_font_size_override("font_size", 12)
    _style_btn(unequip_all_btn, Color(0.5, 0.2, 0.2))
    unequip_all_btn.pressed.connect(func():
        for s in WardrobeManager.SLOTS:
            WardrobeManager.unequip(s)
        _refresh()
    )
    left_vbox.add_child(unequip_all_btn)

    body_row.add_child(VSeparator.new())

    # 右侧：物品筛选+网格
    var right_vbox = VBoxContainer.new()
    right_vbox.add_theme_constant_override("separation", 10)
    right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
    body_row.add_child(right_vbox)

    # 筛选按钮行
    var filter_row = HFlowContainer.new()
    filter_row.add_theme_constant_override("h_separation", 8)
    filter_row.add_theme_constant_override("v_separation", 6)
    right_vbox.add_child(filter_row)

    var all_filter = Button.new()
    all_filter.text = "🔍 全部"
    all_filter.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    all_filter.add_theme_font_size_override("font_size", 12)
    _style_btn(all_filter, Color(0.3, 0.3, 0.5))
    all_filter.pressed.connect(func(): _filter_slot = ""; _rebuild_grid())
    filter_row.add_child(all_filter)

    for slot in WardrobeManager.SLOTS:
        var fb = Button.new()
        fb.text = "%s %s" % [WardrobeManager.SLOT_EMOJIS[slot], WardrobeManager.SLOT_LABELS[slot]]
        fb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        fb.add_theme_font_size_override("font_size", 12)
        _style_btn(fb, Color(0.25, 0.35, 0.55))
        var s_capture = slot
        fb.pressed.connect(func(): _filter_slot = s_capture; _rebuild_grid())
        filter_row.add_child(fb)

    # 物品网格（带滚动）
    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_vbox.add_child(scroll)

    _item_grid = GridContainer.new()
    _item_grid.columns = 3
    _item_grid.add_theme_constant_override("h_separation", 10)
    _item_grid.add_theme_constant_override("v_separation", 10)
    _item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_item_grid)

    _rebuild_grid()

    # 监听状态变化
    WardrobeManager.item_equipped.connect(func(_a, _b): _refresh())
    WardrobeManager.item_unequipped.connect(func(_s): _refresh())

    # 入场动画
    card.modulate.a = 0.0
    card.position.y += 20.0
    var tw = card.create_tween().set_parallel(true)
    tw.tween_property(card, "modulate:a", 1.0, 0.25)
    tw.tween_property(card, "position:y", card.position.y - 20.0, 0.25).set_trans(Tween.TRANS_BACK)

# ── 装备槽按钮 ────────────────────────────────────────────────
func _build_slot_btn(slot: String) -> Button:
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(0, 48)
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    btn.add_theme_font_size_override("font_size", 14)
    btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _update_slot_btn(btn, slot)
    btn.pressed.connect(func(): _on_slot_clicked(slot))
    return btn

func _update_slot_btn(btn: Button, slot: String) -> void:
    var eq_id = WardrobeManager.equipped.get(slot, "")
    if eq_id != "":
        var item = WardrobeManager.WARDROBE_DB.get(eq_id, {})
        btn.text = "%s  %s" % [item.get("emoji", "❓"), item.get("name", eq_id)]
        _style_btn(btn, WardrobeManager.RARITY_COLORS.get(item.get("rarity","common"), Color(0.4,0.4,0.4)))
    else:
        btn.text = "%s  [空] %s" % [WardrobeManager.SLOT_EMOJIS[slot], WardrobeManager.SLOT_LABELS[slot]]
        var empty_s = StyleBoxFlat.new()
        empty_s.bg_color = Color(0.15, 0.15, 0.22)
        empty_s.border_width_left   = 1; empty_s.border_width_right  = 1
        empty_s.border_width_top    = 1; empty_s.border_width_bottom = 1
        empty_s.border_color = Color(0.4, 0.4, 0.55, 0.5)
        empty_s.corner_radius_top_left    = 8; empty_s.corner_radius_top_right    = 8
        empty_s.corner_radius_bottom_left = 8; empty_s.corner_radius_bottom_right = 8
        btn.add_theme_stylebox_override("normal", empty_s)

func _on_slot_clicked(slot: String) -> void:
    # 如果当前槽有装备 → 直接卸下
    if WardrobeManager.equipped.has(slot):
        WardrobeManager.unequip(slot)
    else:
        # 筛选该槽，方便玩家选择
        _filter_slot = slot
        _rebuild_grid()

# ── 物品网格 ──────────────────────────────────────────────────
func _rebuild_grid() -> void:
    for c in _item_grid.get_children(): c.queue_free()

    var display_list: Array = []
    for id in WardrobeManager.owned_items:
        if not WardrobeManager.WARDROBE_DB.has(id): continue
        var item = WardrobeManager.WARDROBE_DB[id]
        if _filter_slot != "" and item["category"] != _filter_slot: continue
        display_list.append(id)

    if display_list.is_empty():
        var hint = Label.new()
        hint.text = "暂无该类物品，去商店逛逛吧~"
        hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
        hint.add_theme_font_size_override("font_size", 13)
        _item_grid.add_child(hint)
        return

    for id in display_list:
        _item_grid.add_child(_build_item_card(id))

func _build_item_card(item_id: String) -> PanelContainer:
    var item    = WardrobeManager.WARDROBE_DB[item_id]
    var slot    = item["category"]
    var rarity  = item.get("rarity", "common")
    var r_color = WardrobeManager.RARITY_COLORS.get(rarity, Color(0.6,0.6,0.6))
    var is_equipped = WardrobeManager.equipped.get(slot, "") == item_id

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(0, 90)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var ps = StyleBoxFlat.new()
    ps.bg_color = r_color.darkened(0.72) if not is_equipped else r_color.darkened(0.45)
    ps.border_width_left   = 2; ps.border_width_right  = 2
    ps.border_width_top    = 2; ps.border_width_bottom = 2
    ps.border_color = r_color.lightened(0.1) if not is_equipped else r_color.lightened(0.4)
    ps.corner_radius_top_left    = 10; ps.corner_radius_top_right    = 10
    ps.corner_radius_bottom_left = 10; ps.corner_radius_bottom_right = 10
    ps.content_margin_left = 10; ps.content_margin_right  = 10
    ps.content_margin_top  = 8;  ps.content_margin_bottom = 8
    panel.add_theme_stylebox_override("panel", ps)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    panel.add_child(vbox)

    # 图标行
    var icon_row = HBoxContainer.new()
    vbox.add_child(icon_row)
    var icon_lbl = Label.new()
    icon_lbl.text = item.get("emoji", "❓")
    icon_lbl.add_theme_font_size_override("font_size", 28)
    icon_row.add_child(icon_lbl)

    var info_vbox = VBoxContainer.new()
    info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info_vbox.add_theme_constant_override("separation", 2)
    icon_row.add_child(info_vbox)

    var name_lbl = Label.new()
    name_lbl.text = item["name"]
    name_lbl.add_theme_font_size_override("font_size", 13)
    name_lbl.add_theme_color_override("font_color", r_color.lightened(0.3))
    name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    info_vbox.add_child(name_lbl)

    var rarity_lbl = Label.new()
    rarity_lbl.text = WardrobeManager.RARITY_LABELS.get(rarity, "普通")
    rarity_lbl.add_theme_font_size_override("font_size", 11)
    rarity_lbl.add_theme_color_override("font_color", r_color)
    info_vbox.add_child(rarity_lbl)

    # 属性加成（+N 显示）
    var bonus_parts: Array = []
    for stat in item.get("stat_bonus", {}).keys():
        var v = item["stat_bonus"][stat]
        var stat_icons = {"charm":"✨","social":"💬","art":"🎨","strength":"⚽","intellect":"📚"}
        bonus_parts.append("%s+%d" % [stat_icons.get(stat,""), v])
    if not bonus_parts.is_empty():
        var bonus_lbl = Label.new()
        bonus_lbl.text = "  ".join(bonus_parts)
        bonus_lbl.add_theme_font_size_override("font_size", 11)
        bonus_lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.6))
        vbox.add_child(bonus_lbl)

    # 装备/卸下按钮
    var eq_btn = Button.new()
    eq_btn.text = "✅ 已装备（点击卸下）" if is_equipped else "装备"
    eq_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    eq_btn.add_theme_font_size_override("font_size", 12)
    _style_btn(eq_btn, Color(0.2, 0.5, 0.2) if is_equipped else Color(0.25, 0.40, 0.65))
    eq_btn.pressed.connect(func():
        if is_equipped:
            WardrobeManager.unequip(slot)
        else:
            WardrobeManager.equip(item_id)
        _rebuild_grid()
    )
    vbox.add_child(eq_btn)

    return panel

# ── 刷新整体 ─────────────────────────────────────────────────
func _refresh() -> void:
    _update_bonus_label()
    for slot in _slot_btns.keys():
        _update_slot_btn(_slot_btns[slot], slot)
    _rebuild_grid()

# ── 属性加成总览 ─────────────────────────────────────────────
func _update_bonus_label() -> void:
    var bonus = WardrobeManager.get_active_bonus()
    if bonus.is_empty():
        _bonus_lbl.text = "💡 当前穿搭无属性加成 — 装备服饰后加成会显示在这里"
        return
    var stat_labels = {"charm":"✨魅力","social":"💬社交","art":"🎨艺术",
                        "strength":"⚽运动","intellect":"📚学习"}
    var parts: Array = []
    for stat in bonus.keys():
        var v = bonus[stat]
        parts.append("%s +%d" % [stat_labels.get(stat, stat), v])
    _bonus_lbl.text = "✨ 穿搭加成：" + "  ".join(parts)

# ── 打开商店 ─────────────────────────────────────────────────
func _open_shop() -> void:
    var shop = WardrobeShopUI.open(get_parent())
    shop.closed.connect(func(): _refresh())

func _style_btn(btn: Button, color: Color) -> void:
    var s = StyleBoxFlat.new()
    s.bg_color = color.darkened(0.4)
    s.corner_radius_top_left    = 8; s.corner_radius_top_right    = 8
    s.corner_radius_bottom_left = 8; s.corner_radius_bottom_right = 8
    s.border_width_left   = 1; s.border_width_right  = 1
    s.border_width_top    = 1; s.border_width_bottom = 1
    s.border_color = color.lightened(0.15)
    s.content_margin_left = 10; s.content_margin_right = 10
    s.content_margin_top  = 5;  s.content_margin_bottom = 5
    btn.add_theme_stylebox_override("normal", s)
    var h = s.duplicate(); h.bg_color = color.darkened(0.2)
    btn.add_theme_stylebox_override("hover", h)

func _on_close() -> void:
    var tw = create_tween()
    tw.tween_property(self, "modulate:a", 0.0, 0.18)
    tw.tween_callback(func(): closed.emit(); queue_free())
