extends CanvasLayer
## StampBookUI — 西湖十景集章簿 / 集章打卡面板（DS-RN-03）
##
## 双模式（通过 set_meta("mode", ...) 注入，默认 "book"）：
##   "book"    主界面 board「📖 集章簿」入口 —— 只读查看全 10 景
##   "checkin" lakeside 热点「🏞️ 西湖十景·集章打卡」入口 —— 选一景盖章
##
## 对外契约：
##   输入  set_meta("mode", "book" | "checkin")
##   输出  var picked_sid: String   —— 仅 checkin 模式下非空，由 HotspotExploreUI 消费
##   信号  signal closed
##
## ⚠️ 单向数据流（GDD §6.5）：本面板**不写任何 flag**。
##    授予由 CollectionManager.grant_stamp() 在 HotspotExploreUI 侧统一负责。

signal closed

var picked_sid: String = ""

var _mode: String = "book"
var _checkin_locked: bool = false      # checkin 模式下当日已打卡
var base_panel: PanelContainer
var _detail_title: Label
var _detail_body: Label
var _closing: bool = false

# ── 视觉常量（对齐 LakesideWishesUI / GalleryPopupUI 既有配色）──
const CELL_SIZE      := Vector2(140, 100)
const C_OWNED_BG     := Color(0.10, 0.13, 0.20, 1)
const C_OWNED_BORDER := Color(0.95, 0.78, 0.35)   # 印泥金
const C_LOCK_BG      := Color(0.05, 0.06, 0.10, 1)
const C_LOCK_BORDER  := Color(1, 1, 1, 0.10)
const C_PICK_BORDER  := Color(0.45, 0.75, 0.95)   # 可点蓝
const C_NAME_OWNED   := Color(0.94, 0.90, 0.82)
const C_NAME_LOCK    := Color(1, 1, 1, 0.25)


func _ready():
    _mode = str(get_meta("mode", "book"))
    if _mode == "checkin":
        _checkin_locked = CollectionManager.is_stamp_checkin_used_today()

    # 全屏半透明遮罩
    var mask = ColorRect.new()
    mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mask.color = Color(0, 0, 0, 0.6)
    add_child(mask)

    # ── 1. 主面板 ──
    base_panel = PanelContainer.new()
    base_panel.custom_minimum_size = Vector2(820, 530)
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
    main_vbox.add_theme_constant_override("separation", 14)
    margin.add_child(main_vbox)

    # ── 2. 标题栏与关闭 ──
    var title_hbox = HBoxContainer.new()
    main_vbox.add_child(title_hbox)

    var title_lbl = Label.new()
    title_lbl.text = "📖 西湖十景集章簿" if _mode == "book" else "🏞️ 西湖十景·集章打卡"
    title_lbl.add_theme_font_size_override("font_size", 24)
    title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
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
    var prog = CollectionManager.get_stamp_progress()
    var prog_hbox = HBoxContainer.new()
    prog_hbox.add_theme_constant_override("separation", 12)
    main_vbox.add_child(prog_hbox)

    var prog_tag = Label.new()
    prog_tag.text = "收集进度"
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

    # ── 4. 5 列 × 2 行印章网格 ──
    var grid = GridContainer.new()
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    main_vbox.add_child(grid)

    for sid in _ordered_sids():
        grid.add_child(_build_cell(sid))

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


# ── 格子排序 ────────────────────────────────────────────────
## book 模式：严格保持注册表插入顺序（GDD §6.1）
## checkin 模式：⭐当季且未得的景置顶（GDD §2.4），其余保持注册表相对顺序（稳定排序）
func _ordered_sids() -> Array:
    var all_sids: Array = CollectionManager.WEST_LAKE_STAMP_SCENES.keys()
    if _mode != "checkin":
        return all_sids
    var top: Array = []
    var rest: Array = []
    for sid in all_sids:
        if not CollectionManager.is_stamp_owned(sid) and CollectionManager.is_stamp_bonus_active(sid):
            top.append(sid)
        else:
            rest.append(sid)
    return top + rest


# ── 单个印章格子 ────────────────────────────────────────────
func _build_cell(sid: String) -> Control:
    var data: Dictionary = CollectionManager.WEST_LAKE_STAMP_SCENES[sid]
    var owned: bool = CollectionManager.is_stamp_owned(sid)
    var bonus: bool = CollectionManager.is_stamp_bonus_active(sid)
    # checkin 模式：未得且当日未打卡 → 可选；其余灰显
    var selectable: bool = (_mode == "checkin") and (not owned) and (not _checkin_locked)
    # 亮显条件：book 模式看是否已得；checkin 模式看是否可选
    var lit: bool = owned if _mode == "book" else selectable

    var cell = Button.new()
    cell.custom_minimum_size = CELL_SIZE
    cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    cell.focus_mode = Control.FOCUS_NONE

    var s = StyleBoxFlat.new()
    s.bg_color = C_OWNED_BG if lit else C_LOCK_BG
    s.border_width_left = 1; s.border_width_right = 1
    s.border_width_top = 1; s.border_width_bottom = 1
    if selectable:
        s.border_color = C_PICK_BORDER
    elif owned:
        s.border_color = C_OWNED_BORDER
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
    emoji_lbl.text = str(data.get("emoji", "🏞️"))
    emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    emoji_lbl.add_theme_font_size_override("font_size", 34)
    emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if not lit:
        emoji_lbl.modulate = Color(0.35, 0.35, 0.35)
    vb.add_child(emoji_lbl)

    var name_lbl = Label.new()
    # checkin 模式下当季景挂 ⭐ 徽标（纯正反馈，非门槛）
    name_lbl.text = ("⭐ " + str(data.get("name", sid))) if (selectable and bonus) else str(data.get("name", sid))
    name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_lbl.add_theme_font_size_override("font_size", 14)
    name_lbl.add_theme_color_override("font_color", C_NAME_OWNED if lit else C_NAME_LOCK)
    name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(name_lbl)

    var day_lbl = Label.new()
    if owned:
        var d: int = CollectionManager.get_stamp_day(sid)
        day_lbl.text = ("第 %d 天" % d) if d >= 0 else "第 ? 天"
    else:
        day_lbl.text = "——"
    day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    day_lbl.add_theme_font_size_override("font_size", 12)
    day_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45) if lit else Color(1, 1, 1, 0.18))
    day_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(day_lbl)

    cell.pressed.connect(func(): _on_cell_pressed(sid, owned, selectable))
    return cell


func _on_cell_pressed(sid: String, owned: bool, selectable: bool):
    if _closing: return
    if _mode == "checkin":
        if selectable:
            # 唯一输出：交由 HotspotExploreUI 读取后调用 grant_stamp + 播放 vignette
            picked_sid = sid
            _on_close_pressed()
            return
        if _checkin_locked:
            _detail_title.text = "🕗 今天已经在西湖集过章啦"
            _detail_body.text = "今天已经在湖边盖过一枚印了，明天再来。（现在可以随便翻翻集章簿）"
            return
        # 已得
        _fill_detail(sid)
        return

    # book 模式
    if owned:
        _fill_detail(sid)
    else:
        var data: Dictionary = CollectionManager.WEST_LAKE_STAMP_SCENES[sid]
        _detail_title.text = "%s %s  ·  未获得" % [data.get("emoji", ""), data.get("name", sid)]
        _detail_body.text = "还没去过这里。去西湖边打卡吧——「🏞️ 西湖十景·集章打卡」。"


func _fill_detail(sid: String):
    var data: Dictionary = CollectionManager.WEST_LAKE_STAMP_SCENES[sid]
    var d: int = CollectionManager.get_stamp_day(sid)
    _detail_title.text = "%s %s  ·  %s" % [
        data.get("emoji", ""), data.get("name", sid), CollectionManager.format_stamp_day(d)]
    var parts := PackedStringArray([str(data.get("summary", ""))])
    for line in data.get("lines", []):
        parts.append(str(line))
    _detail_body.text = "\n".join(parts)


func _show_empty_detail():
    if _mode == "checkin" and _checkin_locked:
        _detail_title.text = "🕗 今天已经在西湖集过章啦"
        _detail_body.text = "今天已经在湖边盖过一枚印了，明天再来。"
    elif _mode == "checkin":
        _detail_title.text = "选一处景，去盖一枚印"
        _detail_body.text = "点亮的景可以打卡（消耗 1 个时段）。⭐ 是当季推荐——不是门槛，任何季节都能盖任何一枚。不想盖就直接关掉，不花时间。"
    else:
        _detail_title.text = "点一枚印看看"
        _detail_body.text = "已集得的印章会亮起金边。点开可以重读那天的文字与日期。"


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
