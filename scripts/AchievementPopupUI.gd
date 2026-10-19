# scripts/AchievementPopupUI.gd
class_name AchievementPopupUI
extends Control

signal closed()

var _current_cat: String = "all"
var _filter_unlocked_only: bool = false

var _category_buttons: Dictionary = {}
var _progress_bar: ProgressBar
var _stats_lbl: Label
var _points_lbl: Label
var _cards_container: VBoxContainer
var _category_scroll: VBoxContainer

func _ready() -> void:
	z_index = 105
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("ui_popup")
	_build_ui()
	_refresh_display()

	if is_instance_valid(AchievementManager):
		AchievementManager.achievement_progress_updated.connect(_refresh_display)

func _build_ui() -> void:
	# 全屏暗黑高斯背景
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 0.85)
	bg.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_on_close_pressed()
	)
	add_child(bg)

	# 主面板容器
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 580)
	panel.set_anchors_preset(PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.13, 0.98)
	panel_style.border_color = Color(0.85, 0.70, 0.28, 0.6)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(main_vbox)

	# ── 顶部栏：标题、总点数与关闭按钮 ──
	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	main_vbox.add_child(top_bar)

	var title_lbl = Label.new()
	title_lbl.text = "🎖️  西湖成就中心"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78))
	top_bar.add_child(title_lbl)

	top_bar.add_spacer(false)

	_points_lbl = Label.new()
	_points_lbl.text = "成就点数：0 🎖️"
	_points_lbl.add_theme_font_size_override("font_size", 14)
	_points_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	top_bar.add_child(_points_lbl)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_on_close_pressed)
	top_bar.add_child(close_btn)

	# ── 进度总览栏 ──
	var prog_box = HBoxContainer.new()
	prog_box.add_theme_constant_override("separation", 16)
	main_vbox.add_child(prog_box)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 14)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.show_percentage = false
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.92, 0.75, 0.28)
	bar_fill.corner_radius_top_left = 6
	bar_fill.corner_radius_top_right = 6
	bar_fill.corner_radius_bottom_left = 6
	bar_fill.corner_radius_bottom_right = 6
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	prog_box.add_child(_progress_bar)

	_stats_lbl = Label.new()
	_stats_lbl.text = "0 / 0 (0%)"
	_stats_lbl.add_theme_font_size_override("font_size", 13)
	_stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	prog_box.add_child(_stats_lbl)

	var filter_btn = CheckBox.new()
	filter_btn.text = "仅看已达成"
	filter_btn.toggled.connect(func(toggled: bool):
		_filter_unlocked_only = toggled
		_refresh_display()
	)
	prog_box.add_child(filter_btn)

	var sep = HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.1)
	main_vbox.add_child(sep)

	# ── 下方主体：左侧分类列表 + 右侧成就卡片滚动区 ──
	var body_hbox = HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(body_hbox)

	# 左侧分类标签栏
	var cat_scroll = ScrollContainer.new()
	cat_scroll.custom_minimum_size = Vector2(190, 0)
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_hbox.add_child(cat_scroll)

	_category_scroll = VBoxContainer.new()
	_category_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_scroll.add_theme_constant_override("separation", 6)
	cat_scroll.add_child(_category_scroll)

	_build_category_buttons()

	# 右侧卡片滚动区
	var cards_scroll = ScrollContainer.new()
	cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_hbox.add_child(cards_scroll)

	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_container.add_theme_constant_override("separation", 8)
	cards_scroll.add_child(_cards_container)

func _build_category_buttons() -> void:
	for child in _category_scroll.get_children():
		child.queue_free()
	_category_buttons.clear()

	if not is_instance_valid(AchievementManager): return
	var cats = AchievementManager.get_categories()

	for cat in cats:
		var cid = cat["id"]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(175, 42)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "%s %s" % [cat["icon"], cat["name"]]
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func():
			if is_instance_valid(AudioManager):
				AudioManager.play_sfx("ui_click")
			_current_cat = cid
			_update_category_button_styles()
			_refresh_display()
		)
		_category_scroll.add_child(btn)
		_category_buttons[cid] = btn

	_update_category_button_styles()

func _update_category_button_styles() -> void:
	for cid in _category_buttons.keys():
		var btn: Button = _category_buttons[cid]
		var is_active = (cid == _current_cat)

		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8

		if is_active:
			style.bg_color = Color(0.35, 0.28, 0.12, 0.9)
			style.border_color = Color(0.96, 0.78, 0.28, 0.9)
			style.border_width_left = 2
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
		else:
			style.bg_color = Color(0.12, 0.13, 0.18, 0.6)
			style.border_color = Color(1, 1, 1, 0.06)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _refresh_display() -> void:
	if not is_instance_valid(AchievementManager): return

	# 1. 刷新统计数据
	var global_stats = AchievementManager.get_stats()
	var cat_stats = AchievementManager.get_category_stats(_current_cat)

	_points_lbl.text = "成就点数：%d 🎖️" % global_stats["unlocked_points"]
	_progress_bar.max_value = cat_stats["total_count"]
	_progress_bar.value = cat_stats["unlocked_count"]
	_stats_lbl.text = "已达成：%d / %d (%.1f%%)" % [
		cat_stats["unlocked_count"], cat_stats["total_count"], cat_stats["percent"]
	]

	# 2. 刷新左侧分类按钮徽标文字
	for cid in _category_buttons.keys():
		var btn: Button = _category_buttons[cid]
		var cs = AchievementManager.get_category_stats(cid)
		var meta = AchievementManager.CATEGORY_META.get(cid, {})
		btn.text = "%s %s (%d/%d)" % [meta.get("icon", "⭐"), meta.get("name", cid), cs["unlocked_count"], cs["total_count"]]

	# 3. 渲染右侧卡片
	for c in _cards_container.get_children():
		c.queue_free()

	var list = AchievementManager.get_achievements_by_category(_current_cat)
	if list.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "暂无相关成就"
		empty_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
		_cards_container.add_child(empty_lbl)
		return

	for achv in list:
		var aid = achv["id"]
		var is_done = AchievementManager.is_unlocked(aid)
		if _filter_unlocked_only and not is_done:
			continue

		var card = _create_achievement_card(achv, is_done)
		_cards_container.add_child(card)

func _create_achievement_card(data: Dictionary, is_done: bool) -> Control:
	var aid = data["id"]
	var is_hidden = data.get("hidden", false) and not is_done

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10

	if is_done:
		style.bg_color = Color(0.12, 0.11, 0.16, 0.95)
		style.border_color = Color(0.96, 0.78, 0.28, 0.7)
		style.border_width_left = 2
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	elif is_hidden:
		style.bg_color = Color(0.08, 0.07, 0.12, 0.75)
		style.border_color = Color(0.40, 0.35, 0.55, 0.35)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	else:
		style.bg_color = Color(0.09, 0.10, 0.14, 0.8)
		style.border_color = Color(0.25, 0.28, 0.35, 0.35)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1

	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# 左侧图标徽章
	var icon_box = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(46, 46)
	var icon_style = StyleBoxFlat.new()
	icon_style.corner_radius_top_left = 23
	icon_style.corner_radius_top_right = 23
	icon_style.corner_radius_bottom_left = 23
	icon_style.corner_radius_bottom_right = 23

	if is_done:
		icon_style.bg_color = Color(0.35, 0.25, 0.08, 0.8)
		icon_style.border_color = Color(0.96, 0.78, 0.28, 0.8)
		icon_style.border_width_left = 1
		icon_style.border_width_top = 1
		icon_style.border_width_right = 1
		icon_style.border_width_bottom = 1
	else:
		icon_style.bg_color = Color(0.12, 0.13, 0.18, 0.7)
		icon_style.border_color = Color(1, 1, 1, 0.08)
		icon_style.border_width_left = 1
		icon_style.border_width_top = 1
		icon_style.border_width_right = 1
		icon_style.border_width_bottom = 1

	icon_box.add_theme_stylebox_override("panel", icon_style)

	var icon_lbl = Label.new()
	if is_done:
		icon_lbl.text = data.get("icon", "🏆")
	elif is_hidden:
		icon_lbl.text = "❓"
	else:
		icon_lbl.text = data.get("icon", "🔒")
		icon_lbl.modulate = Color(0.7, 0.7, 0.7, 0.6)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_box.add_child(icon_lbl)
	hbox.add_child(icon_box)

	# 中间文字描述
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	var name_lbl = Label.new()
	if is_hidden:
		name_lbl.text = "？？？"
		name_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.75))
	else:
		name_lbl.text = data.get("name", "未命名成就")
		if is_done:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.80))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.78, 0.80, 0.85))
	name_lbl.add_theme_font_size_override("font_size", 15)
	text_vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	if is_hidden:
		desc_lbl.text = "西湖与校园漫步时的意外惊喜，或许某次奇遇就能解开封印..."
		desc_lbl.add_theme_color_override("font_color", Color(0.48, 0.45, 0.58))
	else:
		desc_lbl.text = data.get("desc", "")
		if is_done:
			desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88, 0.85))
		else:
			desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_vbox.add_child(desc_lbl)

	# 右侧状态徽章与点数
	var right_vbox = VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.custom_minimum_size = Vector2(90, 0)
	hbox.add_child(right_vbox)

	var pts = data.get("points", 10)
	var pts_lbl = Label.new()
	pts_lbl.text = "+%d 🎖️" % pts
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts_lbl.add_theme_font_size_override("font_size", 13)
	if is_done:
		pts_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	else:
		pts_lbl.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58))
	right_vbox.add_child(pts_lbl)

	var status_lbl = Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 11)
	if is_done:
		var day = AchievementManager.get_unlock_day(aid)
		if day > 0:
			status_lbl.text = "第 %d 天达成" % day
		else:
			status_lbl.text = "已达成"
		status_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55))
	elif is_hidden:
		status_lbl.text = "隐藏成就"
		status_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.85))
	else:
		status_lbl.text = "未达成"
		status_lbl.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55))
	right_vbox.add_child(status_lbl)

	return card

func _on_close_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("ui_click")
	closed.emit()
	queue_free()
