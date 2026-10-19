# scripts/AchievementBannerUI.gd
class_name AchievementBannerUI
extends CanvasLayer

signal banner_finished()

var _banner_panel: PanelContainer
var _tween: Tween

func show_banner(achv_data: Dictionary) -> void:
	layer = 120
	_build_ui(achv_data)
	_play_animation()

func _build_ui(data: Dictionary) -> void:
	var root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	_banner_panel = PanelContainer.new()
	_banner_panel.custom_minimum_size = Vector2(460, 72)
	_banner_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_panel.position = Vector2(640 - 230, -90)
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 尊贵原神金黑玻璃质感 StyleBox
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.96)
	style.border_color = Color(0.96, 0.78, 0.28, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.96, 0.78, 0.28, 0.25)
	style.shadow_size = 8
	_banner_panel.add_theme_stylebox_override("panel", style)
	root_ctrl.add_child(_banner_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_banner_panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# 左侧奖章图标
	var icon_box = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(48, 48)
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.18, 0.16, 0.10, 0.8)
	icon_style.border_color = Color(0.96, 0.78, 0.28, 0.8)
	icon_style.border_width_left = 1
	icon_style.border_width_top = 1
	icon_style.border_width_right = 1
	icon_style.border_width_bottom = 1
	icon_style.corner_radius_top_left = 24
	icon_style.corner_radius_top_right = 24
	icon_style.corner_radius_bottom_left = 24
	icon_style.corner_radius_bottom_right = 24
	icon_box.add_theme_stylebox_override("panel", icon_style)

	var icon_lbl = Label.new()
	icon_lbl.text = data.get("icon", "🏆")
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_box.add_child(icon_lbl)
	hbox.add_child(icon_box)

	# 中间文案
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	var header_row = HBoxContainer.new()
	text_vbox.add_child(header_row)

	var tag_lbl = Label.new()
	tag_lbl.text = "✨ 成就达成！"
	tag_lbl.add_theme_font_size_override("font_size", 11)
	tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35, 0.95))
	header_row.add_child(tag_lbl)

	var name_lbl = Label.new()
	name_lbl.text = "【%s】" % data.get("name", "新成就")
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	text_vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = data.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.75))
	desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_vbox.add_child(desc_lbl)

	# 右侧点数徽章
	var pts = data.get("points", 10)
	var pts_panel = PanelContainer.new()
	var pts_style = StyleBoxFlat.new()
	pts_style.bg_color = Color(0.35, 0.28, 0.08, 0.6)
	pts_style.border_color = Color(0.96, 0.78, 0.28, 0.5)
	pts_style.border_width_left = 1
	pts_style.border_width_top = 1
	pts_style.border_width_right = 1
	pts_style.border_width_bottom = 1
	pts_style.corner_radius_top_left = 6
	pts_style.corner_radius_top_right = 6
	pts_style.corner_radius_bottom_left = 6
	pts_style.corner_radius_bottom_right = 6
	pts_panel.add_theme_stylebox_override("panel", pts_style)

	var pts_margin = MarginContainer.new()
	pts_margin.add_theme_constant_override("margin_left", 8)
	pts_margin.add_theme_constant_override("margin_right", 8)
	pts_margin.add_theme_constant_override("margin_top", 4)
	pts_margin.add_theme_constant_override("margin_bottom", 4)
	pts_panel.add_child(pts_margin)

	var pts_lbl = Label.new()
	pts_lbl.text = "+%d 🎖️" % pts
	pts_lbl.add_theme_font_size_override("font_size", 13)
	pts_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	pts_margin.add_child(pts_lbl)
	hbox.add_child(pts_panel)

func _play_animation() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("achievement_unlock")
	_tween = create_tween()
	# 下滑出现 (带回弹感)
	_tween.tween_property(_banner_panel, "position:y", 24.0, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 悬停展示 3 秒
	_tween.tween_interval(3.0)
	# 上滑淡出收回
	_tween.tween_property(_banner_panel, "position:y", -90.0, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.finished.connect(func():
		banner_finished.emit()
		queue_free()
	)
