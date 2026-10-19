extends Control
# WorldChatUI.gd — 青春世界聊天室面板

signal closed

var list_container: VBoxContainer = null
var input_field: LineEdit = null
var send_btn: Button = null
var poll_timer: Timer = null

func _ready():
	# 铺满屏幕
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 半透明背景遮罩
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close()
	)
	add_child(bg)
	
	# 主面板
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 680)
	panel.layout_mode = 1
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var ps = ThemeUtils.create_style(Color(0.08, 0.10, 0.15, 0.98), 16, Color(1, 1, 1, 0.12), 1)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)
	
	# 边距
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	
	# 垂直布局
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	
	# 标题栏
	var header = HBoxContainer.new()
	layout.add_child(header)
	
	var title_lbl = Label.new()
	title_lbl.text = "💬 青春世界聊天室"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88, 1))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.custom_minimum_size = Vector2(36, 36)
	_style_close_btn(close_btn)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)
	
	# 分割线
	var sep = HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.1)
	layout.add_child(sep)
	
	# 聊天消息可滚动列表
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	
	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 10)
	scroll.add_child(list_container)
	
	# 底部发送栏
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)
	
	input_field = LineEdit.new()
	input_field.placeholder_text = "和大家聊聊天吧，探讨下烹饪配方..."
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.custom_minimum_size = Vector2(0, 46)
	input_field.add_theme_font_size_override("font_size", 18)
	_style_input_field(input_field)
	input_field.text_submitted.connect(func(_t): _send_message())
	footer.add_child(input_field)
	
	send_btn = Button.new()
	send_btn.text = "发送 🚀"
	send_btn.custom_minimum_size = Vector2(100, 46)
	send_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	send_btn.add_theme_font_size_override("font_size", 18)
	_style_send_btn(send_btn)
	send_btn.pressed.connect(_send_message)
	footer.add_child(send_btn)
	
	# 连接信号与初始化
	NetworkManager.world_chat_loaded.connect(_on_chat_loaded)
	NetworkManager.world_chat_sent.connect(_on_chat_sent)
	
	# 首次获取聊天数据
	NetworkManager.get_world_chat_history()
	
	# 定时轮询器（每 3 秒刷新一次）
	poll_timer = Timer.new()
	poll_timer.wait_time = 3.0
	poll_timer.autostart = true
	poll_timer.timeout.connect(func():
		NetworkManager.get_world_chat_history()
	)
	add_child(poll_timer)

func _close():
	closed.emit()
	queue_free()

func _send_message():
	var text = input_field.text.strip_edges()
	if text.is_empty():
		return
	
	input_field.editable = false
	send_btn.disabled = true
	NetworkManager.send_world_chat_message(text)

func _on_chat_sent(success: bool, msg: String):
	input_field.editable = true
	send_btn.disabled = false
	if success:
		input_field.text = ""
		NetworkManager.get_world_chat_history()
	else:
		GameManager.show_toast.emit(msg)

func _on_chat_loaded(messages: Array):
	# 记下当前的滚动条位置或滚动到底部
	var scroll = list_container.get_parent() as ScrollContainer
	var scroll_at_bottom = scroll.scroll_vertical >= scroll.get_v_scroll_bar().max_value - scroll.size.y - 20
	
	# 清空现有子项
	for child in list_container.get_children():
		child.queue_free()
	
	if messages.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "暂无聊天消息..."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
		list_container.add_child(empty_lbl)
		return
	
	for msg in messages:
		var item_panel = PanelContainer.new()
		var is_system = msg.get("username") == "系统向导"
		
		# 样式包
		var ips: StyleBoxFlat
		if is_system:
			ips = ThemeUtils.create_style(Color(0.12, 0.18, 0.15, 0.5), 8, Color(0.2, 0.8, 0.4, 0.8), 0, -1, 12, 12, 8, 8)
			ips.border_width_left = 3
		else:
			ips = ThemeUtils.create_style(Color(1, 1, 1, 0.03), 8, Color.TRANSPARENT, 0, -1, 12, 12, 8, 8)
		item_panel.add_theme_stylebox_override("panel", ips)
		list_container.add_child(item_panel)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		item_panel.add_child(vbox)
		
		# 首行：[称号] 名字 · 学校
		var first_row = HBoxContainer.new()
		first_row.add_theme_constant_override("separation", 6)
		vbox.add_child(first_row)
		
		# 称号徽章 (如果有)
		var title_str = msg.get("title", "")
		if not title_str.is_empty():
			var title_lbl = Label.new()
			title_lbl.text = " %s " % title_str
			title_lbl.add_theme_font_size_override("font_size", 13)
			title_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
			
			var badge_style = ThemeUtils.create_style(Color(0.95, 0.75, 0.2, 1), 4)
			title_lbl.add_theme_stylebox_override("normal", badge_style)
			first_row.add_child(title_lbl)
		
		# 名字
		var name_lbl = Label.new()
		name_lbl.text = msg.get("username", "未知同学")
		name_lbl.add_theme_font_size_override("font_size", 16)
		if is_system:
			name_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4, 1))
		else:
			# 如果是自己，高亮黄色
			if msg.get("username") == GameManager.player_name:
				name_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
			else:
				name_lbl.add_theme_color_override("font_color", Color(0.4, 0.75, 0.95, 1))
		first_row.add_child(name_lbl)
		
		# 学校
		var school_lbl = Label.new()
		school_lbl.text = "（%s）" % msg.get("school", "西湖中学")
		school_lbl.add_theme_font_size_override("font_size", 14)
		school_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		first_row.add_child(school_lbl)
		
		# 内容行
		var content_lbl = Label.new()
		content_lbl.text = msg.get("content", "")
		content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_lbl.add_theme_font_size_override("font_size", 17)
		if is_system:
			content_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.9, 1))
		else:
			content_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.86, 0.9))
		vbox.add_child(content_lbl)

	# 异步滚动到底部
	if scroll_at_bottom or messages.size() <= 2:
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _style_close_btn(btn: Button):
	var s = ThemeUtils.create_style(Color(0.3, 0.15, 0.15, 0.6), 6)
	btn.add_theme_stylebox_override("normal", s)
	var h = ThemeUtils.create_style(Color(0.5, 0.2, 0.2, 0.8), 6)
	btn.add_theme_stylebox_override("hover", h)

func _style_input_field(le: LineEdit):
	var s = ThemeUtils.create_style(Color(0, 0, 0, 0.25), 8, Color(1, 1, 1, 0.15), 1, -1, 12, 12, -1, -1)
	le.add_theme_stylebox_override("normal", s)
	le.add_theme_stylebox_override("focus", s)

func _style_send_btn(btn: Button):
	var s = ThemeUtils.create_style(Color(0.12, 0.45, 0.70, 0.8), 8)
	btn.add_theme_stylebox_override("normal", s)
	var h = ThemeUtils.create_style(Color(0.15, 0.55, 0.85, 1), 8)
	btn.add_theme_stylebox_override("hover", h)
