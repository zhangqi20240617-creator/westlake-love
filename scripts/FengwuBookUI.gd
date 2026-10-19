extends CanvasLayer
## FengwuBookUI — 西湖风物志图鉴（DS-RN-04）
##
## 入口：MainGame 更多菜单「🍃 风物志」→ MainGame._show_fengwubook_popup()
## 只读面板：展示 CollectionManager.FENGWU_ITEMS 全 24 格的点亮状态与随笔。
##
## 对外契约：
##   输入  无（不接受 set_meta，纯只读）
##   信号  signal closed
##
## ⚠️ 单向数据流：本面板**不写任何 flag**。
##    授予统一由 CollectionManager.grant_fengwu() 负责（拾得 / 购得 / 未来的手作）。
## ⚠️ 不进 Autoload、不新建 .tscn —— 由调用方 load(...).new() 后 add_child。

signal closed

var base_panel: PanelContainer
var _detail_title: Label
var _detail_body: Label
var _closing: bool = false

# ── 视觉常量（对齐 StampBookUI 既有配色，保持两本册子观感一致）──
const CELL_SIZE      := Vector2(122, 96)
const C_OWNED_BG     := Color(0.09, 0.14, 0.11, 1)
const C_OWNED_BORDER := Color(0.62, 0.80, 0.48)   # 草木绿
const C_LOCK_BG      := Color(0.05, 0.06, 0.10, 1)
const C_LOCK_BORDER  := Color(1, 1, 1, 0.10)
const C_TODO_BORDER  := Color(0.55, 0.48, 0.32)   # 手作预留槽：暗金虚位
const C_NAME_OWNED   := Color(0.90, 0.94, 0.86)
const C_NAME_LOCK    := Color(1, 1, 1, 0.25)

# ── 分类 / 软条件的展示映射（纯 UI 层，不参与任何判定）──────────
const CAT_EMOJI := {
    "味":   "🍶",
    "物":   "🏺",
    "草木": "🌿",
    "声景": "🔔",
}
const SEASON_LABEL := {
    "spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬",
}
const WEATHER_LABEL := {
    "sunny": "晴", "cloudy": "阴", "rainy": "雨", "snowy": "雪",
}
const SLOT_LABEL := {
    "morning": "清晨", "noon": "午间", "after": "放学后", "evening": "夜里",
}


func _ready():
    # 全屏半透明遮罩
    var mask = ColorRect.new()
    mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mask.color = Color(0, 0, 0, 0.6)
    add_child(mask)

    # ── 1. 主面板 ──
    base_panel = PanelContainer.new()
    base_panel.custom_minimum_size = Vector2(860, 590)
    base_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    base_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    base_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

    var sb = StyleBoxFlat.new()
    sb.bg_color = Color(0.06, 0.08, 0.15, 0.95)
    sb.corner_radius_top_left = 18
    sb.corner_radius_top_right = 18
    sb.corner_radius_bottom_left = 18
    sb.corner_radius_bottom_right = 18
    sb.shadow_color = Color(0, 0, 0, 0.6)
    sb.shadow_size = 18
    base_panel.add_theme_stylebox_override("panel", sb)
    add_child(base_panel)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 26)
    margin.add_theme_constant_override("margin_right", 26)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 24)
    base_panel.add_child(margin)

    var main_vbox = VBoxContainer.new()
    main_vbox.add_theme_constant_override("separation", 12)
    margin.add_child(main_vbox)

    # ── 2. 标题栏与关闭 ──
    var title_hbox = HBoxContainer.new()
    main_vbox.add_child(title_hbox)

    var title_lbl = Label.new()
    title_lbl.text = "🍃 西湖风物志"
    title_lbl.add_theme_font_size_override("font_size", 24)
    title_lbl.add_theme_color_override("font_color", C_OWNED_BORDER)
    title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_hbox.add_child(title_lbl)

    var close_btn = Button.new()
    close_btn.text = "  ✕  "
    close_btn.flat = true
    close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    close_btn.add_theme_font_size_override("font_size", 24)
    close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
    close_btn.pressed.connect(_on_close_pressed)
    title_hbox.add_child(close_btn)

    # ── 3. 进度条 ──
    var prog = CollectionManager.get_fengwu_progress()
    var reachable: int = CollectionManager.get_fengwu_reachable_total()

    var prog_hbox = HBoxContainer.new()
    prog_hbox.add_theme_constant_override("separation", 12)
    main_vbox.add_child(prog_hbox)

    var prog_tag = Label.new()
    prog_tag.text = "入册进度"
    prog_tag.add_theme_font_size_override("font_size", 14)
    prog_tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
    prog_hbox.add_child(prog_tag)

    var bar = ProgressBar.new()
    bar.max_value = prog["total"]
    bar.value = prog["unlocked"]
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 14)
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var bar_bg = StyleBoxFlat.new()
    bar_bg.bg_color = Color(0.03, 0.04, 0.08, 1)
    bar_bg.corner_radius_top_left = 7; bar_bg.corner_radius_top_right = 7
    bar_bg.corner_radius_bottom_left = 7; bar_bg.corner_radius_bottom_right = 7
    bar.add_theme_stylebox_override("background", bar_bg)
    var bar_fg = StyleBoxFlat.new()
    bar_fg.bg_color = C_OWNED_BORDER
    bar_fg.corner_radius_top_left = 7; bar_fg.corner_radius_top_right = 7
    bar_fg.corner_radius_bottom_left = 7; bar_fg.corner_radius_bottom_right = 7
    bar.add_theme_stylebox_override("fill", bar_fg)
    prog_hbox.add_child(bar)

    var prog_num = Label.new()
    prog_num.text = "%d / %d" % [prog["unlocked"], prog["total"]]
    prog_num.add_theme_font_size_override("font_size", 15)
    prog_num.add_theme_color_override("font_color", C_OWNED_BORDER)
    prog_hbox.add_child(prog_num)

    # 「本章可达」提示：手作未开放时明示上限，避免玩家把 18/24 误读为 bug
    if reachable < prog["total"]:
        var note = Label.new()
        note.text = "本章可达 %d 件；余下 %d 件为「手作」，将在后续章节开放。" % [
            reachable, prog["total"] - reachable]
        note.add_theme_font_size_override("font_size", 12)
        note.add_theme_color_override("font_color", Color(1, 0.85, 0.45, 0.75))
        main_vbox.add_child(note)

    # ── 4. 6 列 × 4 行风物网格 ──
    var grid = GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    main_vbox.add_child(grid)

    for fid in CollectionManager.FENGWU_ITEMS.keys():
        grid.add_child(_build_cell(str(fid)))

    # ── 5. 详情区 ──
    var detail_panel = PanelContainer.new()
    detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var detail_sb = StyleBoxFlat.new()
    detail_sb.bg_color = Color(0, 0, 0, 0.25)
    detail_sb.corner_radius_top_left = 10; detail_sb.corner_radius_top_right = 10
    detail_sb.corner_radius_bottom_left = 10; detail_sb.corner_radius_bottom_right = 10
    detail_panel.add_theme_stylebox_override("panel", detail_sb)
    main_vbox.add_child(detail_panel)

    var detail_pad = MarginContainer.new()
    detail_pad.add_theme_constant_override("margin_left", 16)
    detail_pad.add_theme_constant_override("margin_right", 16)
    detail_pad.add_theme_constant_override("margin_top", 10)
    detail_pad.add_theme_constant_override("margin_bottom", 10)
    detail_panel.add_child(detail_pad)

    var detail_scroll = ScrollContainer.new()
    detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    detail_pad.add_child(detail_scroll)

    var detail_vbox = VBoxContainer.new()
    detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail_vbox.add_theme_constant_override("separation", 6)
    detail_scroll.add_child(detail_vbox)

    _detail_title = Label.new()
    _detail_title.add_theme_font_size_override("font_size", 16)
    _detail_title.add_theme_color_override("font_color", C_OWNED_BORDER)
    _detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_vbox.add_child(_detail_title)

    _detail_body = Label.new()
    _detail_body.add_theme_font_size_override("font_size", 14)
    _detail_body.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
    _detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_vbox.add_child(_detail_body)

    _show_empty_detail()

    # ── 6. 入场动画 ──
    base_panel.modulate.a = 0.0
    base_panel.scale = Vector2(0.94, 0.94)
    base_panel.pivot_offset = base_panel.custom_minimum_size / 2
    var t = create_tween().set_parallel(true)
    t.tween_property(base_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
    t.tween_property(base_panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ── 单个风物格子 ────────────────────────────────────────────
func _build_cell(fid: String) -> Control:
    var data: Dictionary = CollectionManager.FENGWU_ITEMS[fid]
    var owned: bool = CollectionManager.is_fengwu_owned(fid)
    var obtain: String = str(data.get("obtain", ""))
    var is_todo: bool = obtain == "手作"          # 本章预留槽
    var bonus: bool = CollectionManager.is_fengwu_bonus_active(fid)

    var cell = Button.new()
    cell.custom_minimum_size = CELL_SIZE
    cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    cell.focus_mode = Control.FOCUS_NONE

    var s = StyleBoxFlat.new()
    s.bg_color = C_OWNED_BG if owned else C_LOCK_BG
    s.border_width_left = 1; s.border_width_right = 1
    s.border_width_top = 1; s.border_width_bottom = 1
    if owned:
        s.border_color = C_OWNED_BORDER
    elif is_todo:
        s.border_color = C_TODO_BORDER
    else:
        s.border_color = C_LOCK_BORDER
    s.corner_radius_top_left = 10; s.corner_radius_top_right = 10
    s.corner_radius_bottom_left = 10; s.corner_radius_bottom_right = 10
    cell.add_theme_stylebox_override("normal", s)
    var hs = s.duplicate()
    hs.bg_color = s.bg_color.lightened(0.10)
    cell.add_theme_stylebox_override("hover", hs)
    cell.add_theme_stylebox_override("pressed", hs)
    cell.add_theme_stylebox_override("focus", s)

    var vb = VBoxContainer.new()
    vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vb.alignment = BoxContainer.ALIGNMENT_CENTER
    vb.add_theme_constant_override("separation", 2)
    cell.add_child(vb)

    var emoji_lbl = Label.new()
    if owned:
        emoji_lbl.text = str(CAT_EMOJI.get(str(data.get("category", "")), "🍃"))
    else:
        emoji_lbl.text = "🔒" if is_todo else "？"
    emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    emoji_lbl.add_theme_font_size_override("font_size", 30)
    emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if not owned:
        emoji_lbl.modulate = Color(0.35, 0.35, 0.35)
    vb.add_child(emoji_lbl)

    var name_lbl = Label.new()
    # 未获得也显示名字（本作是"知道有什么、去凑齐"的收集观，不做全隐藏）
    # ⭐ = 当前季节/天气正对口，纯正反馈提示，不是门槛
    name_lbl.text = ("⭐ " + str(data.get("name", fid))) if (not owned and bonus) else str(data.get("name", fid))
    name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_lbl.add_theme_font_size_override("font_size", 13)
    name_lbl.add_theme_color_override("font_color", C_NAME_OWNED if owned else C_NAME_LOCK)
    name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(name_lbl)

    var sub_lbl = Label.new()
    if owned:
        var d: int = CollectionManager.get_fengwu_day(fid)
        sub_lbl.text = ("第 %d 天" % d) if d >= 0 else "第 ? 天"
    else:
        sub_lbl.text = "待开放" if is_todo else obtain
    sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub_lbl.add_theme_font_size_override("font_size", 11)
    sub_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45) if owned else Color(1, 1, 1, 0.18))
    sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(sub_lbl)

    cell.pressed.connect(func(): _on_cell_pressed(fid))
    return cell


func _on_cell_pressed(fid: String):
    if _closing: return
    var data: Dictionary = CollectionManager.FENGWU_ITEMS[fid]
    var owned: bool = CollectionManager.is_fengwu_owned(fid)
    var cat: String = str(data.get("category", ""))
    var cat_icon: String = str(CAT_EMOJI.get(cat, "🍃"))
    var nm: String = str(data.get("name", fid))

    if owned:
        var d: int = CollectionManager.get_fengwu_day(fid)
        _detail_title.text = "%s %s · %s  ·  %s" % [
            cat_icon, nm, cat, CollectionManager.format_fengwu_day(d)]
        _detail_body.text = str(data.get("hint", ""))
        return

    _detail_title.text = "%s %s · %s  ·  未入册" % [cat_icon, nm, cat]
    _detail_body.text = _obtain_tip(fid, data)


## 未入册条目的获取提示（纯展示，措辞须与判定实现一致：loc 硬、其余软）
func _obtain_tip(fid: String, data: Dictionary) -> String:
    match str(data.get("obtain", "")):
        "拾得":
            var loc_id: String = str(data.get("loc", ""))
            var loc_name: String = str(GameManager.locations.get(loc_id, {}).get("name", loc_id))
            var soft := PackedStringArray()
            var s: String = str(data.get("season", ""))
            var w: String = str(data.get("weather", ""))
            var sl: String = str(data.get("slot", ""))
            if s != "":  soft.append(str(SEASON_LABEL.get(s, s)) + "天")
            if w != "":  soft.append(str(WEATHER_LABEL.get(w, w)) + "天")
            if sl != "": soft.append(str(SLOT_LABEL.get(sl, sl)))
            var tip := "去「%s」多走走，说不定就遇上了。" % loc_name
            if soft.size() > 0:
                tip += "\n%s时更容易碰到——只是更容易，任何时候都可能遇上。" % "、".join(soft)
            tip += "\n（每天最多拾得一件）"
            return tip
        "购得":
            var price: int = int(GameManager.ITEM_DB.get(fid, {}).get("price", 0))
            return "小卖部 / 市集的货架上有。\n价格 💰 %d —— 买下即自动入册。" % price
        "手作":
            return "在家备一份手作礼物，加一点材料费，就能做出来。\n" + str(data.get("hint", ""))
    return ""


func _show_empty_detail():
    var prog = CollectionManager.get_fengwu_progress()
    _detail_title.text = "点一格看看"
    _detail_body.text = "一味、一物、一草木、一声景——把杭州拆成 %d 件小东西，慢慢攒。\n已入册的会亮起绿边，点开可以重读那天的随笔。" % prog["total"]


func _on_close_pressed():
    if _closing: return
    _closing = true
    var t = create_tween().set_parallel(true)
    t.tween_property(base_panel, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
    t.tween_property(base_panel, "scale", Vector2(0.94, 0.94), 0.18).set_trans(Tween.TRANS_SINE)
    t.chain().tween_callback(func():
        closed.emit()
        queue_free()
    )
