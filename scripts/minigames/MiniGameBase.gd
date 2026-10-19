# scripts/minigames/MiniGameBase.gd
class_name MiniGameBase
extends Control

## ══════════════════════════════════════════════════════════════════
## MiniGameBase.gd — 校园微游戏通用基类
## 职责：
## 1. 弹窗生命周期管理（淡入、淡出、暗色背景遮罩、退出与关闭回调）
## 2. 统一输出信号与结算（game_finished, closed）
## 3. 同伴陪伴系统（立绘展示、差分表情、动态对话气泡）
## 4. 防沉迷与保底机制（快速跳过/扫荡）
## ══════════════════════════════════════════════════════════════════

signal game_finished(result: Dictionary)
signal closed()

# ── 基础参数 ───────────────────────────────────────────────────
var game_id: String = "base_minigame"
var game_title: String = "小游戏"
var companion_id: String = ""       # 当前同行角色ID（如 yutong, jingjing）
var is_game_over: bool = false

# ── UI 结构引用 ────────────────────────────────────────────────
var _bg_overlay: ColorRect
var _main_panel: PanelContainer
var _header_bar: HBoxContainer
var _title_lbl: Label
var _content_root: Control
var _companion_container: PanelContainer
var _companion_sprite: TextureRect
var _companion_bubble: PanelContainer
var _bubble_lbl: Label
var _skip_btn: Button
var _exit_btn: Button

func _ready() -> void:
	z_index = 100
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_base_ui()
	_detect_initial_companion()
	setup_game()
	_play_enter_animation()

## 子类重写此函数进行具体的游戏初始化与节点搭建
func setup_game() -> void:
	pass

## 子类重写：执行一键快速跳过/结算
func execute_skip() -> void:
	pass

# ── 基础 UI 框架构建 ──────────────────────────────────────────
func _build_base_ui() -> void:
	# 全屏暗黑高斯遮罩
	_bg_overlay = ColorRect.new()
	_bg_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_bg_overlay.color = Color(0.04, 0.05, 0.09, 0.88)
	add_child(_bg_overlay)

	# 主游戏外壳窗口
	_main_panel = PanelContainer.new()
	_main_panel.set_anchors_preset(PRESET_FULL_RECT)
	_main_panel.offset_left = 30
	_main_panel.offset_top = 20
	_main_panel.offset_right = -30
	_main_panel.offset_bottom = -20

	var shell_style = ThemeUtils.create_style(
		Color(0.08, 0.10, 0.16, 0.96), 18,
		Color(0.35, 0.42, 0.65, 0.5), 2,
		-1, 16, 16, 12, 12
	)
	_main_panel.add_theme_stylebox_override("panel", shell_style)
	add_child(_main_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_main_panel.add_child(main_vbox)

	# 顶部标题与功能栏
	_header_bar = HBoxContainer.new()
	_header_bar.custom_minimum_size = Vector2(0, 42)
	main_vbox.add_child(_header_bar)

	_title_lbl = Label.new()
	_title_lbl.text = "🎮 " + game_title
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_bar.add_child(_title_lbl)

	# 快速跳过按钮
	_skip_btn = Button.new()
	_skip_btn.text = "⏩ 快速跳过"
	_skip_btn.custom_minimum_size = Vector2(100, 34)
	ThemeUtils.style_accent_btn(_skip_btn, Color(0.4, 0.5, 0.7), 6, 1)
	_skip_btn.pressed.connect(_on_skip_pressed)
	_header_bar.add_child(_skip_btn)

	# 退出关闭按钮
	_exit_btn = Button.new()
	_exit_btn.text = "✕ 退出"
	_exit_btn.custom_minimum_size = Vector2(80, 34)
	ThemeUtils.style_accent_btn(_exit_btn, Color(0.85, 0.35, 0.4), 6, 1)
	_exit_btn.pressed.connect(close_game)
	_header_bar.add_child(_exit_btn)

	# 中间主内容区域（左右或自适应）
	_content_root = HBoxContainer.new()
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 16)
	main_vbox.add_child(_content_root)

# ── 同伴系统（Companion Dock）─────────────────────────────────
## 初始化右侧/左侧同伴面板
func init_companion_dock(parent_container: Control) -> void:
	_companion_container = PanelContainer.new()
	_companion_container.custom_minimum_size = Vector2(280, 0)
	_companion_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var dock_style = ThemeUtils.create_style(
		Color(0.06, 0.08, 0.13, 0.85), 14,
		Color(0.96, 0.47, 0.63, 0.3), 1,
		-1, 12, 12, 10, 10
	)
	_companion_container.add_theme_stylebox_override("panel", dock_style)
	parent_container.add_child(_companion_container)

	var dock_vbox = VBoxContainer.new()
	dock_vbox.add_theme_constant_override("separation", 8)
	_companion_container.add_child(dock_vbox)

	# 同伴选择切换区
	var switch_hbox = HBoxContainer.new()
	var tag_lbl = Label.new()
	tag_lbl.text = "同行好友"
	tag_lbl.add_theme_font_size_override("font_size", 14)
	tag_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	switch_hbox.add_child(tag_lbl)

	var switch_btn = Button.new()
	switch_btn.text = "🔄 换人"
	switch_btn.custom_minimum_size = Vector2(60, 24)
	ThemeUtils.style_accent_btn(switch_btn, Color(0.45, 0.4, 0.6), 4, 1)
	switch_btn.pressed.connect(_cycle_companion)
	switch_hbox.add_child(switch_btn)
	dock_vbox.add_child(switch_hbox)

	# 气泡对话框
	_companion_bubble = PanelContainer.new()
	_companion_bubble.custom_minimum_size = Vector2(0, 60)
	var bubble_style = ThemeUtils.create_style(
		Color(0.14, 0.16, 0.24, 0.95), 10,
		Color(0.96, 0.6, 0.75, 0.6), 1,
		-1, 10, 10, 8, 8
	)
	_companion_bubble.add_theme_stylebox_override("panel", bubble_style)
	dock_vbox.add_child(_companion_bubble)

	_bubble_lbl = Label.new()
	_bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_lbl.add_theme_font_size_override("font_size", 13)
	_bubble_lbl.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	_bubble_lbl.text = "“一起试试看吧！”"
	_companion_bubble.add_child(_bubble_lbl)

	# 同伴立绘贴图
	_companion_sprite = TextureRect.new()
	_companion_sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_companion_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_companion_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dock_vbox.add_child(_companion_sprite)

	update_companion_display()

## 自动探测当前最合适同伴（好感最高、或当前地点相关的角色）
func _detect_initial_companion() -> void:
	if companion_id != "":
		return
	# 优先寻找好感度最高的角色
	var best_cid := ""
	var best_aff := -1
	for cid in GameManager.char_meta.keys():
		var aff = GameManager.favorability.get(cid, 0)
		if aff > best_aff:
			best_aff = aff
			best_cid = cid
	companion_id = best_cid if best_cid != "" else "jingjing"

## 切换同伴
func _cycle_companion() -> void:
	var keys = GameManager.char_meta.keys()
	if keys.is_empty():
		return
	var idx = keys.find(companion_id)
	idx = (idx + 1) % keys.size()
	companion_id = keys[idx]
	update_companion_display()
	say_companion_dialogue("换我来陪你啦！准备好了吗？", "default")

## 更新同伴立绘与展示
func update_companion_display(emotion: String = "default") -> void:
	if not is_instance_valid(_companion_sprite):
		return
	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")

	# 尝试加载对应立绘
	var path_candidates = [
		"res://assets/sprites/%s/%s.png" % [companion_id, emotion],
		"res://assets/sprites/%s/casual.png" % companion_id,
		"res://assets/sprites/%s/default.png" % companion_id,
	]
	var tex: Texture2D = null
	for p in path_candidates:
		if ResourceLoader.exists(p):
			tex = load(p)
			if tex: break

	if tex:
		_companion_sprite.texture = tex
		_companion_sprite.visible = true
	else:
		_companion_sprite.visible = false

## 同伴说话气泡
func say_companion_dialogue(text: String, emotion: String = "default") -> void:
	if not is_instance_valid(_bubble_lbl):
		return
	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")
	_bubble_lbl.text = "【%s】：“%s”" % [c_name, text]
	update_companion_display(emotion)

	# 气泡弹出轻微微动效
	if is_instance_valid(_companion_bubble):
		var tw = create_tween()
		_companion_bubble.scale = Vector2(0.96, 0.96)
		tw.tween_property(_companion_bubble, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── 结算与奖励分发 ────────────────────────────────────────────
func apply_rewards(rewards: Dictionary) -> void:
	# 1. 属性变更 (stress, intellect 等)
	if rewards.has("stats"):
		for st in rewards["stats"]:
			GameManager.add_stat(st, rewards["stats"][st])

	# 2. 金钱收益或消耗
	if rewards.has("money"):
		GameManager.add_stat("money", rewards["money"])

	# 3. 好感度加成
	if rewards.has("favor") and companion_id != "":
		var amt = int(rewards["favor"])
		GameManager.add_favor(companion_id, amt)

	# 4. 获得物品
	if rewards.has("items"):
		for itm in rewards["items"]:
			CollectionManager.add_item(itm, 1)

	# 5. 获得成就 / 标志位
	if rewards.has("flags"):
		for flg in rewards["flags"]:
			GameManager.flags[flg] = true

# ── 通用入场与关闭 ────────────────────────────────────────────
func _play_enter_animation() -> void:
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)

func _on_skip_pressed() -> void:
	execute_skip()

func close_game() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.finished.connect(func():
		closed.emit()
		queue_free()
	)
