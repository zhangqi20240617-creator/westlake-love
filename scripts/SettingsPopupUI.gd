# scripts/SettingsPopupUI.gd
class_name SettingsPopupUI
extends Control
## SettingsPopupUI.gd - 现代化全功能系统设置面板 (Settings Center UI)
## 包含音频调节、画面显示偏好、剧情文字播放速度设置与实时持久化。

signal closed()

var _current_tab: String = "audio" # "audio", "display", "gameplay"
var _tab_buttons: Dictionary = {}
var _content_container: VBoxContainer

# 音频控件
var _master_slider: HSlider
var _master_val_lbl: Label
var _bgm_slider: HSlider
var _bgm_val_lbl: Label
var _sfx_slider: HSlider
var _sfx_val_lbl: Label

# 临时设置缓存（用于实时预览和保存）
var _cur_master: float = 1.0
var _cur_bgm: float = 0.8
var _cur_sfx: float = 1.0
var _cur_window_mode: int = 0
var _cur_vsync: bool = true
var _cur_text_speed: int = 1
var _cur_auto_delay: float = 2.0
var _cur_skip_unread: bool = false

func _ready() -> void:
	z_index = 106
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("ui_popup")

	# 从 SettingsManager 同步当前参数
	if is_instance_valid(SettingsManager):
		_cur_master = SettingsManager.master_volume
		_cur_bgm = SettingsManager.bgm_volume
		_cur_sfx = SettingsManager.sfx_volume
		_cur_window_mode = SettingsManager.window_mode
		_cur_vsync = SettingsManager.vsync_enabled
		_cur_text_speed = SettingsManager.text_speed_idx
		_cur_auto_delay = SettingsManager.auto_delay
		_cur_skip_unread = SettingsManager.skip_unread

	_build_ui()
	_render_active_tab()

func _build_ui() -> void:
	# 暗黑毛玻璃遮罩
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 0.82)
	bg.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_on_close_pressed()
	)
	add_child(bg)

	# 核心面板卡片
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 500)
	panel.set_anchors_preset(PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.14, 0.98)
	panel_style.border_color = Color(0.85, 0.70, 0.28, 0.6)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(main_vbox)

	# 顶部标题与关闭按钮
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "⚙️ 系统设置"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	header_hbox.add_child(title_lbl)

	var title_spacer = Control.new()
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_spacer)

	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_on_close_pressed)
	ThemeUtils.style_accent_btn(close_btn, Color(0.4, 0.2, 0.2), 6, 1)
	header_hbox.add_child(close_btn)

	# Tab 导航栏
	var tab_hbox = HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tab_hbox)

	var tabs_def = [
		{"id": "audio", "name": "🔊 声音音效"},
		{"id": "display", "name": "🖥️ 显示偏好"},
		{"id": "gameplay", "name": "📖 文本剧情"}
	]

	for t in tabs_def:
		var tid = t["id"]
		var btn = Button.new()
		btn.text = t["name"]
		btn.custom_minimum_size = Vector2(130, 36)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func():
			if is_instance_valid(AudioManager):
				AudioManager.play_sfx("ui_click")
			_current_tab = tid
			_update_tab_styles()
			_render_active_tab()
		)
		tab_hbox.add_child(btn)
		_tab_buttons[tid] = btn

	_update_tab_styles()

	# 分隔线
	var hsep = HSeparator.new()
	main_vbox.add_child(hsep)

	# 内容面板容器
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("separation", 18)
	scroll.add_child(_content_container)

	# 底部按钮栏
	var footer_hbox = HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_END
	footer_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(footer_hbox)

	var save_btn = Button.new()
	save_btn.text = "💾 保存设置"
	save_btn.custom_minimum_size = Vector2(120, 38)
	ThemeUtils.style_accent_btn(save_btn, Color(0.25, 0.65, 0.45), 8, 2)
	save_btn.pressed.connect(_on_save_pressed)
	footer_hbox.add_child(save_btn)

func _update_tab_styles() -> void:
	for tid in _tab_buttons.keys():
		var btn: Button = _tab_buttons[tid]
		var is_active = (tid == _current_tab)
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6

		if is_active:
			style.bg_color = Color(0.85, 0.70, 0.28, 0.3)
			style.border_color = Color(0.96, 0.82, 0.36)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		else:
			style.bg_color = Color(0.12, 0.14, 0.20, 0.6)
			style.border_color = Color(1, 1, 1, 0.08)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			btn.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _render_active_tab() -> void:
	for c in _content_container.get_children():
		c.queue_free()

	match _current_tab:
		"audio":
			_render_audio_settings()
		"display":
			_render_display_settings()
		"gameplay":
			_render_gameplay_settings()

# ── 声音设置页面 ──────────────────────────────────────────────
func _render_audio_settings() -> void:
	# 主音量
	_build_volume_row("全局主音量 (Master)", _cur_master, func(val):
		_cur_master = val
		if is_instance_valid(AudioManager):
			AudioManager.set_master_volume(val)
	)

	# 背景音乐音量
	_build_volume_row("背景音乐 (BGM)", _cur_bgm, func(val):
		_cur_bgm = val
		if is_instance_valid(AudioManager):
			AudioManager.set_bgm_volume(val)
	)

	# 游戏音效音量
	_build_volume_row("音效声音 (SFX)", _cur_sfx, func(val):
		_cur_sfx = val
		if is_instance_valid(AudioManager):
			AudioManager.set_sfx_volume(val)
	, true)

func _build_volume_row(label_text: String, initial_val: float, on_change: Callable, is_sfx: bool = false) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_content_container.add_child(row)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)

	var slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_val
	row.add_child(slider)

	var val_lbl = Label.new()
	val_lbl.custom_minimum_size = Vector2(50, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.text = "%d%%" % int(initial_val * 100)
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float):
		val_lbl.text = "%d%%" % int(v * 100)
		on_change.call(v)
		if is_sfx and is_instance_valid(AudioManager):
			AudioManager.play_sfx("ui_click")
	)

# ── 显示设置页面 ──────────────────────────────────────────────
func _render_display_settings() -> void:
	# 窗口模式
	var win_row = HBoxContainer.new()
	win_row.add_theme_constant_override("separation", 16)
	_content_container.add_child(win_row)

	var win_lbl = Label.new()
	win_lbl.text = "屏幕显示模式"
	win_lbl.custom_minimum_size = Vector2(200, 0)
	win_lbl.add_theme_font_size_override("font_size", 14)
	win_row.add_child(win_lbl)

	var mode_btn_group = HBoxContainer.new()
	mode_btn_group.add_theme_constant_override("separation", 8)
	win_row.add_child(mode_btn_group)

	var modes = [
		{"idx": 0, "name": "🪟 窗口化 (1280x720)"},
		{"idx": 1, "name": "🖥️ 独占全屏"}
	]
	for m in modes:
		var btn = Button.new()
		btn.text = m["name"]
		btn.custom_minimum_size = Vector2(160, 36)
		var is_cur = (_cur_window_mode == m["idx"])
		ThemeUtils.style_accent_btn(btn, Color(0.2, 0.45, 0.7) if is_cur else Color(0.18, 0.20, 0.28), 6, 1)
		btn.pressed.connect(func():
			if is_instance_valid(AudioManager):
				AudioManager.play_sfx("ui_click")
			_cur_window_mode = m["idx"]
			_render_active_tab()
		)
		mode_btn_group.add_child(btn)

	# 垂直同步
	var vsync_row = HBoxContainer.new()
	vsync_row.add_theme_constant_override("separation", 16)
	_content_container.add_child(vsync_row)

	var vsync_lbl = Label.new()
	vsync_lbl.text = "垂直同步 (VSync)"
	vsync_lbl.custom_minimum_size = Vector2(200, 0)
	vsync_lbl.add_theme_font_size_override("font_size", 14)
	vsync_row.add_child(vsync_lbl)

	var check = CheckBox.new()
	check.text = "开启垂直同步（防画面撕裂，稳定帧率）"
	check.button_pressed = _cur_vsync
	check.toggled.connect(func(pressed):
		if is_instance_valid(AudioManager):
			AudioManager.play_sfx("ui_click")
		_cur_vsync = pressed
	)
	vsync_row.add_child(check)

# ── 剧情与文本设置页面 ────────────────────────────────────────
func _render_gameplay_settings() -> void:
	# 文字播放速度
	var spd_row = HBoxContainer.new()
	spd_row.add_theme_constant_override("separation", 16)
	_content_container.add_child(spd_row)

	var spd_lbl = Label.new()
	spd_lbl.text = "对话打字速度"
	spd_lbl.custom_minimum_size = Vector2(200, 0)
	spd_lbl.add_theme_font_size_override("font_size", 14)
	spd_row.add_child(spd_lbl)

	var spd_btn_group = HBoxContainer.new()
	spd_btn_group.add_theme_constant_override("separation", 8)
	spd_row.add_child(spd_btn_group)

	var speeds = [
		{"idx": 0, "name": "慢速"},
		{"idx": 1, "name": "标准"},
		{"idx": 2, "name": "极速"},
		{"idx": 3, "name": "瞬间显示"}
	]
	for s in speeds:
		var btn = Button.new()
		btn.text = s["name"]
		btn.custom_minimum_size = Vector2(80, 36)
		var is_cur = (_cur_text_speed == s["idx"])
		ThemeUtils.style_accent_btn(btn, Color(0.85, 0.65, 0.25) if is_cur else Color(0.18, 0.20, 0.28), 6, 1)
		btn.pressed.connect(func():
			if is_instance_valid(AudioManager):
				AudioManager.play_sfx("ui_click")
			_cur_text_speed = s["idx"]
			_render_active_tab()
		)
		spd_btn_group.add_child(btn)

	# 自动播放等待时长
	var auto_row = HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 16)
	_content_container.add_child(auto_row)

	var auto_lbl = Label.new()
	auto_lbl.text = "自动播放等待时间"
	auto_lbl.custom_minimum_size = Vector2(200, 0)
	auto_lbl.add_theme_font_size_override("font_size", 14)
	auto_row.add_child(auto_lbl)

	var auto_slider = HSlider.new()
	auto_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_slider.min_value = 0.5
	auto_slider.max_value = 4.0
	auto_slider.step = 0.5
	auto_slider.value = _cur_auto_delay
	auto_row.add_child(auto_slider)

	var auto_val_lbl = Label.new()
	auto_val_lbl.custom_minimum_size = Vector2(50, 0)
	auto_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	auto_val_lbl.text = "%.1f秒" % _cur_auto_delay
	auto_row.add_child(auto_val_lbl)

	auto_slider.value_changed.connect(func(v: float):
		auto_val_lbl.text = "%.1f秒" % v
		_cur_auto_delay = v
	)

	# 快进未读文本
	var skip_row = HBoxContainer.new()
	skip_row.add_theme_constant_override("separation", 16)
	_content_container.add_child(skip_row)

	var skip_lbl = Label.new()
	skip_lbl.text = "快进未读剧情"
	skip_lbl.custom_minimum_size = Vector2(200, 0)
	skip_lbl.add_theme_font_size_override("font_size", 14)
	skip_row.add_child(skip_lbl)

	var skip_check = CheckBox.new()
	skip_check.text = "开启（允许快进未阅读过的新剧情）"
	skip_check.button_pressed = _cur_skip_unread
	skip_check.toggled.connect(func(pressed):
		if is_instance_valid(AudioManager):
			AudioManager.play_sfx("ui_click")
		_cur_skip_unread = pressed
	)
	skip_row.add_child(skip_check)

func _on_save_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("ui_click")

	if is_instance_valid(SettingsManager):
		SettingsManager.set_audio_volumes(_cur_master, _cur_bgm, _cur_sfx)
		SettingsManager.set_display_config(_cur_window_mode, _cur_vsync)
		SettingsManager.set_gameplay_config(_cur_text_speed, _cur_auto_delay, _cur_skip_unread)

	if is_instance_valid(GameManager):
		GameManager.show_toast.emit("⚙️ 设置已成功保存！")

	closed.emit()
	queue_free()

func _on_close_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("ui_click")
	closed.emit()
	queue_free()
