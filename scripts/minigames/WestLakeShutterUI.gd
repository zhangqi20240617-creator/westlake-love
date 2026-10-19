# scripts/minigames/WestLakeShutterUI.gd
class_name WestLakeShutterUI
extends MiniGameBase

## ══════════════════════════════════════════════════════════════════
## WestLakeShutterUI.gd — 西湖湖畔·光影对焦抓拍小游戏
## 机制核心：
## 1. 移动取景框与光学景深对焦（Viewfinder & Focus）：
##    - 模拟手持相机晃动漂移，玩家控制取景框对准同伴
##    - 对焦环在特定焦距（深度）会由虚焦（红）变为完美锐化（荧光绿）
## 2. 捕捉绝美回眸瞬间（Shutter Timing）：
##    - 同伴在湖畔微风中会变换姿态（远眺 -> 挡风 -> 回眸笑颜）
##    - 在回眸笑容最灿烂且对焦锁定的瞬间按下快门！
## 3. 属性深度联动：
##    - art (艺术/审美): 拓宽构图与对焦黄金窗口 (+30%)，结算时提升艺术属性
##    - charm (魅力): 同伴神态更加灵动生动，极易拍出【MASTERPIECE 绝美拍立得】
##    - stress (压力): 湖畔光影摄影极大治愈心灵，压力直降 (-20)
## ══════════════════════════════════════════════════════════════════

enum State { IDLE, AIMING, FOCUSING, SHUTTER_RELEASED, RESULT }
var current_state: State = State.IDLE

# ── 取景与焦点参数 ─────────────────────────────────────────────
var cam_pos := Vector2(260.0, 150.0)
var target_char_pos := Vector2(260.0, 140.0)
var focus_depth: float = 0.0      # 0 ~ 100
var focus_dir: float = 1.0
var perfect_focus_zone := Vector2(45.0, 65.0)

# ── 同伴神态姿势 ───────────────────────────────────────────────
var pose_state: int = 0           # 0:背身眺望, 1:侧身撩发, 2:正面回眸笑颜
var pose_timer: float = 2.0

# ── 属性加成 ───────────────────────────────────────────────────
var stat_art_focus_bonus: float = 0.0
var stat_charm_boost: int = 0

# ── UI 控件节点 ────────────────────────────────────────────────
var camera_panel: PanelContainer
var lake_view: Control
var lake_bg: TextureRect
var subject_sprite: TextureRect
var viewfinder: Panel
var focus_ring: Control
var focus_bar: ProgressBar
var shutter_btn: Button
var status_lbl: Label
var perk_lbl: Label
var photo_result_overlay: PanelContainer

func setup_game() -> void:
	game_id = "lake_shutter"
	game_title = "西湖边 · 光影瞬间对焦抓拍"
	_title_lbl.text = "📷 " + game_title

	_calculate_stat_synergies()
	_build_shutter_ui()
	init_companion_dock(_content_root)

	_update_hud_display()
	_greet_companion()

func _calculate_stat_synergies() -> void:
	var art = float(GameManager.stats.get("art", 10))
	var charm = float(GameManager.stats.get("charm", 10))

	# 艺术：拓宽对焦完美区间
	stat_art_focus_bonus = clamp(art * 0.25, 0.0, 20.0)
	perfect_focus_zone = Vector2(50.0 - stat_art_focus_bonus * 0.5, 50.0 + stat_art_focus_bonus * 0.5)

	# 魅力：好感加成
	stat_charm_boost = int(clamp(charm * 0.08, 0.0, 6.0))

func _greet_companion() -> void:
	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")
	say_companion_dialogue("“西湖边的夕阳和波光真美……你拿相机对准我了吗？要拍得好看一点哦！”", "shy")

# ── 搭建摄影界面 ──────────────────────────────────────────────
func _build_shutter_ui() -> void:
	camera_panel = PanelContainer.new()
	camera_panel.custom_minimum_size = Vector2(560, 0)
	camera_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var c_style = ThemeUtils.create_style(
		Color(0.08, 0.1, 0.14, 0.96), 16,
		Color(0.3, 0.6, 0.85, 0.7), 2,
		-1, 14, 14, 10, 10
	)
	camera_panel.add_theme_stylebox_override("panel", c_style)
	_content_root.add_child(camera_panel)

	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 8)
	camera_panel.add_child(v_box)

	# 1. 审美天赋
	perk_lbl = Label.new()
	var perks := []
	if stat_art_focus_bonus > 0:
		perks.append("🎨审美景深: 黄金对焦容错+%.0f%%" % stat_art_focus_bonus)
	if stat_charm_boost > 0:
		perks.append("💖心动定格: 摄影好感+%d" % stat_charm_boost)
	perk_lbl.text = " [光影天赋] " + (" · ".join(perks) if perks.size() > 0 else "自然抓拍")
	perk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk_lbl.add_theme_font_size_override("font_size", 11)
	perk_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1))
	v_box.add_child(perk_lbl)

	# 2. 相机单反取景器视窗
	lake_view = Control.new()
	lake_view.custom_minimum_size = Vector2(0, 300)
	lake_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lake_view.clip_contents = true

	# 西湖背景底图
	lake_bg = TextureRect.new()
	lake_bg.set_anchors_preset(PRESET_FULL_RECT)
	lake_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lake_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/backgrounds/lakeside_after_sunny.jpg"):
		lake_bg.texture = load("res://assets/backgrounds/lakeside_after_sunny.jpg")
	elif ResourceLoader.exists("res://assets/backgrounds/lakeside.jpg"):
		lake_bg.texture = load("res://assets/backgrounds/lakeside.jpg")
	lake_view.add_child(lake_bg)

	# 画面中央同伴立绘模特
	subject_sprite = TextureRect.new()
	subject_sprite.position = Vector2(190, 40)
	subject_sprite.custom_minimum_size = Vector2(180, 260)
	subject_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	subject_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lake_view.add_child(subject_sprite)
	_update_model_sprite("casual")

	# 单反取景框十字辅助线与对焦框 (Viewfinder)
	viewfinder = Panel.new()
	viewfinder.position = cam_pos - Vector2(80, 80)
	viewfinder.size = Vector2(160, 160)
	var vf_style = ThemeUtils.create_style(Color.TRANSPARENT, 8, Color(1, 0.9, 0.4, 0.8), 2)
	viewfinder.add_theme_stylebox_override("panel", vf_style)
	lake_view.add_child(viewfinder)

	# 对焦环指示圆圈
	focus_ring = Control.new()
	focus_ring.position = Vector2(80, 80)
	var ring_lbl = Label.new()
	ring_lbl.text = "◎"
	ring_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring_lbl.add_theme_font_size_override("font_size", 24)
	ring_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	focus_ring.add_child(ring_lbl)
	viewfinder.add_child(focus_ring)

	v_box.add_child(lake_view)

	# 3. 操作与对焦指示条
	var ctrl_panel = PanelContainer.new()
	var ctrl_style = ThemeUtils.create_style(Color(0.08, 0.10, 0.16, 0.95), 10, Color(0.3, 0.35, 0.5), 1)
	ctrl_panel.add_theme_stylebox_override("panel", ctrl_style)
	v_box.add_child(ctrl_panel)

	var ctrl_vbox = VBoxContainer.new()
	ctrl_vbox.add_theme_constant_override("separation", 6)
	ctrl_panel.add_child(ctrl_vbox)

	var hud_row = HBoxContainer.new()
	var f_title = Label.new()
	f_title.text = "🔍 光学对焦景深 (Focus):"
	f_title.add_theme_font_size_override("font_size", 12)
	f_title.add_theme_color_override("font_color", Color(0.5, 0.85, 1))
	hud_row.add_child(f_title)

	focus_bar = ProgressBar.new()
	focus_bar.custom_minimum_size = Vector2(160, 14)
	focus_bar.max_value = 100
	focus_bar.show_percentage = false
	var fb_style = ThemeUtils.create_style(Color(0.2, 0.8, 0.6), 3)
	focus_bar.add_theme_stylebox_override("fill", fb_style)
	hud_row.add_child(focus_bar)
	ctrl_vbox.add_child(hud_row)

	status_lbl = Label.new()
	status_lbl.text = "景深对焦游标往返移动，看准【变绿 + 回眸微笑】的瞬间按下快门！"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	ctrl_vbox.add_child(status_lbl)

	shutter_btn = Button.new()
	shutter_btn.text = "📸 按下快门 SHUTTER!"
	shutter_btn.custom_minimum_size = Vector2(0, 42)
	ThemeUtils.style_accent_btn(shutter_btn, Color(0.2, 0.65, 0.9), 8, 2)
	shutter_btn.pressed.connect(_on_shutter_pressed)
	ctrl_vbox.add_child(shutter_btn)

	current_state = State.AIMING

func _update_hud_display() -> void:
	focus_bar.value = focus_depth

func _update_model_sprite(emotion: String) -> void:
	var path_candidates = [
		"res://assets/sprites/%s/%s.png" % [companion_id, emotion],
		"res://assets/sprites/%s/shy.png" % companion_id,
		"res://assets/sprites/%s/casual.png" % companion_id,
		"res://assets/sprites/%s/default.png" % companion_id,
	]
	var tex: Texture2D = null
	for p in path_candidates:
		if ResourceLoader.exists(p):
			tex = load(p)
			if tex: break
	if tex:
		subject_sprite.texture = tex

# ── 对焦游标与神态状态机 ──────────────────────────────────────
func _process(delta: float) -> void:
	if current_state != State.AIMING:
		return

	# 1. 自动景深对焦往返游标
	focus_depth += focus_dir * delta * 70.0
	if focus_depth >= 100.0:
		focus_depth = 100.0
		focus_dir = -1.0
	elif focus_depth <= 0.0:
		focus_depth = 0.0
		focus_dir = 1.0
	focus_bar.value = focus_depth

	# 判断当前是否处于完美焦点区
	var is_in_focus = (focus_depth >= perfect_focus_zone.x and focus_depth <= perfect_focus_zone.y)
	var ring_lbl = focus_ring.get_child(0) as Label
	if is_in_focus:
		ring_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		ring_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	# 2. 同伴神态变换（每 1.8 秒切换神态）
	pose_timer -= delta
	if pose_timer <= 0:
		pose_timer = randf_range(1.6, 2.4)
		pose_state = (pose_state + 1) % 3
		match pose_state:
			0:
				_update_model_sprite("default")
				status_lbl.text = "同伴正迎着湖风远眺断桥……等待抓拍时机"
			1:
				_update_model_sprite("casual")
				status_lbl.text = "同伴转过侧脸撩起发丝……即将回眸！"
			2:
				_update_model_sprite("shy")
				status_lbl.text = "✨ 回眸笑颜瞬间！完美神态已就位，快按快门！"
				say_companion_dialogue("“看这边！笑一个~”", "shy")

# ── 按下快门判定 ──────────────────────────────────────────────
func _on_shutter_pressed() -> void:
	if current_state != State.AIMING:
		return
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("camera_shutter")
	current_state = State.SHUTTER_RELEASED
	shutter_btn.disabled = true

	# 白光闪光灯过曝特效
	_flash_camera()

	# 判定综合得分：对焦精度 + 神态契合度
	var is_in_focus = (focus_depth >= perfect_focus_zone.x and focus_depth <= perfect_focus_zone.y)
	var is_perfect_pose = (pose_state == 2)

	if is_in_focus and is_perfect_pose:
		_on_photo_masterpiece()
	elif is_in_focus or is_perfect_pose:
		_on_photo_good()
	else:
		_on_photo_blurry()

func _flash_camera() -> void:
	var flash = ColorRect.new()
	flash.set_anchors_preset(PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.95)
	lake_view.add_child(flash)

	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.25)
	tw.finished.connect(func(): flash.queue_free())

func _on_photo_masterpiece() -> void:
	status_lbl.text = "🌟 MASTERPIECE！湖畔光影绝美神作！"
	status_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))

	var favor_boost = 14 + stat_charm_boost
	GameManager.add_favor(companion_id, favor_boost)
	GameManager.add_stat("stress", -22)
	GameManager.add_stat("art", 1)      # 提升艺术属性

	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")
	say_companion_dialogue("“天哪！这张照片把我拍得也太好看了吧……！我要存进手机当壁纸！”", "shy")
	GameManager.show_toast.emit("📸 拍出绝美湖畔大片！%s 好感大涨 +%d，艺术 +1！" % [c_name, favor_boost])

	# ── 成就系统联动 ──
	GameManager.flags["achv_shutter_perfect"] = true
	var p_streak = int(GameManager.flags.get("achv_cnt_shutter_perfect_streak", 0)) + 1
	GameManager.flags["achv_cnt_shutter_perfect_streak"] = p_streak
	if p_streak >= 3:
		GameManager.flags["achv_shutter_perfect_triple"] = true
	if is_instance_valid(AchievementManager):
		AchievementManager.check_all()

	_reset_camera_action()

func _on_photo_good() -> void:
	GameManager.flags["achv_cnt_shutter_perfect_streak"] = 0
	status_lbl.text = "👍 NICE SHOT！抓拍到了自然好看的瞬间！"
	status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1))

	var favor_boost = 8 + stat_charm_boost
	GameManager.add_favor(companion_id, favor_boost)
	GameManager.add_stat("stress", -15)

	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")
	say_companion_dialogue("“挺自然的抓拍！西湖的阳光正好照在脸上呢~”", "happy")
	GameManager.show_toast.emit("📸 照片定格成功！%s 好感 +%d！" % [c_name, favor_boost])

	_reset_camera_action()

func _on_photo_blurry() -> void:
	GameManager.flags["achv_cnt_shutter_perfect_streak"] = 0
	# 意外成就：抓拍了个寂寞
	GameManager.flags["achv_shutter_ghost"] = true
	if is_instance_valid(AchievementManager):
		AchievementManager.check_all()

	status_lbl.text = "⚠️ 拍虚脱焦了！画面有点模糊……"
	status_lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.5))

	GameManager.add_stat("stress", -10)
	say_companion_dialogue("“噗……这张好像正好闭眼了，糊成一片啦，再拍一张嘛！”", "default")

	_reset_camera_action()

func _reset_camera_action() -> void:
	shutter_btn.disabled = false
	shutter_btn.text = "🔄 再拍一张 (RETAKE)"
	shutter_btn.pressed.disconnect(_on_shutter_pressed)
	shutter_btn.pressed.connect(func():
		current_state = State.AIMING
		shutter_btn.text = "📸 按下快门 SHUTTER!"
		shutter_btn.pressed.disconnect(shutter_btn.pressed.get_connections()[0].callable)
		shutter_btn.pressed.connect(_on_shutter_pressed)
	)

func execute_skip() -> void:
	var art = GameManager.stats.get("art", 10)
	var favor_boost = 10 + stat_charm_boost
	GameManager.add_favor(companion_id, favor_boost)
	GameManager.add_stat("stress", -18)
	GameManager.show_toast.emit("湖畔快速合影留念成功！好感度 +%d！" % favor_boost)
	say_companion_dialogue("“湖边的合影真好看！今天太开心啦！”", "happy")
