# scripts/minigames/PaperSlipStealthUI.gd
class_name PaperSlipStealthUI
extends MiniGameBase

## ══════════════════════════════════════════════════════════════════
## PaperSlipStealthUI.gd — 课堂/自习·桌下传纸条潜行小游戏
## 机制核心：
## 1. 视线规避机制（Stealth & Vigilance）：
##    - 讲台老师/巡查主任处于三种状态：【板书沉浸】、【怀疑预警（黄标）】、【回头巡查（红眼）】
##    - 在安全期按住【蓄力弹射】，将折叠小纸条在桌下精准弹给同行同伴
## 2. 话题即时拼装（Topic Reply QTE）：
##    - 纸条到达后，弹出 3 个心动/幽默话题气泡，限时 5 秒选择回复
## 3. 属性深度联动：
##    - intellect (智力): 提升隐蔽技巧，降低被怀疑积累速度 (-30%)
##    - charm / social (魅力/社交): 话题心动暴击，同伴好感度翻倍
##    - stress (压力): 成功传递大幅减压 (-20)，但若被老师当场抓包则会被罚站检讨 (+压力、+教导主任怀疑度)
## ══════════════════════════════════════════════════════════════════

enum State { IDLE, CHARGING, SLIP_FLYING, TOPIC_CHOICE, BUSTED, SUCCESS }
var current_state: State = State.IDLE

# ── 老师状态机 ─────────────────────────────────────────────────
enum TeacherState { WRITING, SUSPICIOUS, WATCHING }
var teacher_state: TeacherState = TeacherState.WRITING
var teacher_timer: float = 3.0
var suspicion_gauge: float = 0.0   # 警戒槽 0 ~ 100%

# ── 蓄力与弹射 ─────────────────────────────────────────────────
var charge_power: float = 0.0
var is_charging: bool = false
const TARGET_DISTANCE := 360.0    # 距离同伴桌子的理论距离

# ── 属性加成 ───────────────────────────────────────────────────
var stat_stealth_bonus: float = 0.0
var stat_sweet_talk_bonus: int = 0

# ── UI 节点引用 ────────────────────────────────────────────────
var class_panel: PanelContainer
var room_view: Control
var teacher_box: PanelContainer
var teacher_lbl: Label
var eye_icon: Label
var alert_bar: ProgressBar

var player_desk: PanelContainer
var target_desk: PanelContainer
var paper_slip: Control
var charge_bar: ProgressBar

var action_btn: Button
var status_lbl: Label
var perk_lbl: Label
var topic_box: PanelContainer

# ── 纸条话题库 ─────────────────────────────────────────────────
const TOPIC_OPTIONS = [
	{
		"text": "“放学后一起去西湖边走走吗？”",
		"fav_type": "romantic",
		"bonus": 10,
		"reply": "“好呀！那下课在校门口等我，不许先溜！”"
	},
	{
		"text": "“刚才老师讲的那道压轴题，我有点没听懂……”",
		"fav_type": "study",
		"bonus": 8,
		"reply": "“嘻嘻，下课借我的笔记本给你看，上面记了步骤！”"
	},
	{
		"text": "“看窗外那只麻雀，长得好像教导主任哈哈哈。”",
		"fav_type": "funny",
		"bonus": 9,
		"reply": "“噗……你别逗我笑，被老师看见就惨啦！”"
	}
]

func setup_game() -> void:
	game_id = "paper_slip"
	game_title = "课堂自习 · 桌下传纸条"
	_title_lbl.text = "💌 " + game_title

	_calculate_stat_synergies()
	_build_stealth_ui()
	init_companion_dock(_content_root)

	_update_hud_display()
	_greet_companion()

func _calculate_stat_synergies() -> void:
	var intellect = float(GameManager.stats.get("intellect", 10))
	var charm = float(GameManager.stats.get("charm", 10))
	var social = float(GameManager.stats.get("social", 10))

	# 智力：提升潜行容错，降低被怀疑速率
	stat_stealth_bonus = clamp(intellect * 0.25, 0.0, 35.0)
	# 魅力与社交：话题好感加成
	stat_sweet_talk_bonus = int(clamp((charm + social) * 0.06, 0.0, 6.0))

func _greet_companion() -> void:
	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")
	say_companion_dialogue("“嘘……小心讲台上的老师！趁他写黑板时再扔给我！”", "shy")

# ── UI 布局搭建 ──────────────────────────────────────────────
func _build_stealth_ui() -> void:
	class_panel = PanelContainer.new()
	class_panel.custom_minimum_size = Vector2(560, 0)
	class_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var outer_style = ThemeUtils.create_style(
		Color(0.10, 0.12, 0.18, 0.96), 16,
		Color(0.85, 0.5, 0.65, 0.7), 2,
		-1, 14, 14, 10, 10
	)
	class_panel.add_theme_stylebox_override("panel", outer_style)
	_content_root.add_child(class_panel)

	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 8)
	class_panel.add_child(v_box)

	# 1. 顶部潜行天赋
	perk_lbl = Label.new()
	var perks := []
	if stat_stealth_bonus > 0:
		perks.append("🧠隐蔽手法: 警戒积累-%.0f%%" % stat_stealth_bonus)
	if stat_sweet_talk_bonus > 0:
		perks.append("💖心动话术: 好感+%d" % stat_sweet_talk_bonus)
	perk_lbl.text = " [摸鱼天赋] " + (" · ".join(perks) if perks.size() > 0 else "小心翼翼")
	perk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk_lbl.add_theme_font_size_override("font_size", 11)
	perk_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
	v_box.add_child(perk_lbl)

	# 2. 教室俯瞰与视角展区
	room_view = Control.new()
	room_view.custom_minimum_size = Vector2(0, 300)
	room_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_view.clip_contents = true

	var floor_bg = ColorRect.new()
	floor_bg.set_anchors_preset(PRESET_FULL_RECT)
	floor_bg.color = Color(0.12, 0.14, 0.20, 0.95)
	room_view.add_child(floor_bg)

	# 讲台与老师巡视区
	var podium = Panel.new()
	podium.position = Vector2(180, 15)
	podium.size = Vector2(200, 50)
	var p_style = ThemeUtils.create_style(Color(0.2, 0.15, 0.12), 8, Color(0.6, 0.45, 0.3), 2)
	podium.add_theme_stylebox_override("panel", p_style)
	room_view.add_child(podium)

	teacher_box = PanelContainer.new()
	teacher_box.position = Vector2(230, 20)
	teacher_box.custom_minimum_size = Vector2(100, 36)
	var t_style = ThemeUtils.create_style(Color(0.15, 0.2, 0.3), 8)
	teacher_box.add_theme_stylebox_override("panel", t_style)
	room_view.add_child(teacher_box)

	var t_hbox = HBoxContainer.new()
	t_hbox.add_theme_constant_override("separation", 4)
	eye_icon = Label.new()
	eye_icon.text = "📝"
	eye_icon.add_theme_font_size_override("font_size", 16)
	t_hbox.add_child(eye_icon)

	teacher_lbl = Label.new()
	teacher_lbl.text = "背身写板书"
	teacher_lbl.add_theme_font_size_override("font_size", 12)
	teacher_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	t_hbox.add_child(teacher_lbl)
	teacher_box.add_child(t_hbox)

	# 课桌布局：左侧玩家课桌，右侧同伴课桌
	player_desk = PanelContainer.new()
	player_desk.position = Vector2(60, 180)
	player_desk.size = Vector2(90, 70)
	var desk_style = ThemeUtils.create_style(Color(0.25, 0.18, 0.12), 6, Color(0.5, 0.35, 0.2), 2)
	player_desk.add_theme_stylebox_override("panel", desk_style)
	room_view.add_child(player_desk)

	var p_lbl = Label.new()
	p_lbl.text = "你的课桌\n🎒 [我方]"
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.set_anchors_preset(PRESET_FULL_RECT)
	p_lbl.add_theme_font_size_override("font_size", 11)
	p_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	player_desk.add_child(p_lbl)

	target_desk = PanelContainer.new()
	target_desk.position = Vector2(410, 180)
	target_desk.size = Vector2(90, 70)
	var t_desk_style = ThemeUtils.create_style(Color(0.25, 0.18, 0.12), 6, Color(0.9, 0.45, 0.65), 2)
	target_desk.add_theme_stylebox_override("panel", t_desk_style)
	room_view.add_child(target_desk)

	var t_target_lbl = Label.new()
	t_target_lbl.text = "同伴课桌\n💌 [目标]"
	t_target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_target_lbl.set_anchors_preset(PRESET_FULL_RECT)
	t_target_lbl.add_theme_font_size_override("font_size", 11)
	t_target_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.9))
	target_desk.add_child(t_target_lbl)

	# 折叠小纸条 (Paper Slip)
	paper_slip = Control.new()
	paper_slip.position = Vector2(110, 205)
	var slip_icon = Label.new()
	slip_icon.text = "✉️"
	slip_icon.add_theme_font_size_override("font_size", 22)
	paper_slip.add_child(slip_icon)
	room_view.add_child(paper_slip)

	# 话题选择浮层 (初始隐藏)
	topic_box = PanelContainer.new()
	topic_box.position = Vector2(80, 100)
	topic_box.custom_minimum_size = Vector2(400, 150)
	var topic_style = ThemeUtils.create_style(
		Color(0.08, 0.1, 0.16, 0.98), 12,
		Color(0.96, 0.5, 0.7, 0.9), 2,
		-1, 14, 14, 12, 12
	)
	topic_box.add_theme_stylebox_override("panel", topic_style)
	topic_box.visible = false
	room_view.add_child(topic_box)

	v_box.add_child(room_view)

	# 3. 操控与警报栏
	var ctrl_panel = PanelContainer.new()
	var ctrl_style = ThemeUtils.create_style(Color(0.08, 0.10, 0.16, 0.95), 10, Color(0.3, 0.35, 0.5), 1)
	ctrl_panel.add_theme_stylebox_override("panel", ctrl_style)
	v_box.add_child(ctrl_panel)

	var ctrl_vbox = VBoxContainer.new()
	ctrl_vbox.add_theme_constant_override("separation", 6)
	ctrl_panel.add_child(ctrl_vbox)

	var hud_row = HBoxContainer.new()
	var alert_title = Label.new()
	alert_title.text = "🚨 巡查警戒度:"
	alert_title.add_theme_font_size_override("font_size", 12)
	alert_title.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	hud_row.add_child(alert_title)

	alert_bar = ProgressBar.new()
	alert_bar.custom_minimum_size = Vector2(100, 14)
	alert_bar.max_value = 100
	alert_bar.show_percentage = true
	var a_style = ThemeUtils.create_style(Color(0.9, 0.25, 0.3), 3)
	alert_bar.add_theme_stylebox_override("fill", a_style)
	hud_row.add_child(alert_bar)

	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_row.add_child(sp)

	var charge_title = Label.new()
	charge_title.text = "🎯 弹射蓄力:"
	charge_title.add_theme_font_size_override("font_size", 12)
	charge_title.add_theme_color_override("font_color", Color(0.3, 0.8, 1))
	hud_row.add_child(charge_title)

	charge_bar = ProgressBar.new()
	charge_bar.custom_minimum_size = Vector2(100, 14)
	charge_bar.max_value = 100
	charge_bar.show_percentage = true
	var c_style = ThemeUtils.create_style(Color(0.2, 0.7, 0.9), 3)
	charge_bar.add_theme_stylebox_override("fill", c_style)
	hud_row.add_child(charge_bar)
	ctrl_vbox.add_child(hud_row)

	status_lbl = Label.new()
	status_lbl.text = "趁老师背身写板书，按住【蓄力】对准力度松开弹射！"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	ctrl_vbox.add_child(status_lbl)

	action_btn = Button.new()
	action_btn.text = "🎯 按住蓄力弹射 (HOLD)"
	action_btn.custom_minimum_size = Vector2(0, 42)
	ThemeUtils.style_accent_btn(action_btn, Color(0.85, 0.35, 0.6), 8, 2)
	action_btn.button_down.connect(_on_action_down)
	action_btn.button_up.connect(_on_action_up)
	ctrl_vbox.add_child(action_btn)

func _update_hud_display() -> void:
	alert_bar.value = suspicion_gauge
	charge_bar.value = charge_power

# ── 老师状态机循环 ────────────────────────────────────────────
func _process(delta: float) -> void:
	if current_state == State.BUSTED or current_state == State.SUCCESS:
		return

	# 老师巡视轮换
	teacher_timer -= delta
	if teacher_timer <= 0:
		_cycle_teacher_state()

	# 蓄力中
	if is_charging:
		charge_power = min(100.0, charge_power + delta * 90.0)
		charge_bar.value = charge_power
		# 老师回头时若正在蓄力，警戒值光速暴增
		if teacher_state == TeacherState.WATCHING:
			var gain = (65.0 - stat_stealth_bonus) * delta
			suspicion_gauge += max(15.0, gain)
			alert_bar.value = suspicion_gauge
			if suspicion_gauge >= 100.0:
				_busted_by_teacher()

func _cycle_teacher_state() -> void:
	match teacher_state:
		TeacherState.WRITING:
			# 沉浸写板书 -> 进入怀疑预警
			teacher_state = TeacherState.SUSPICIOUS
			teacher_timer = randf_range(1.2, 1.8)
			eye_icon.text = "❓"
			teacher_lbl.text = "讲台停顿起疑"
			teacher_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
			status_lbl.text = "⚠️ 老师停笔起疑了！准备停手！"
		TeacherState.SUSPICIOUS:
			# 起疑 -> 猛回头巡查
			teacher_state = TeacherState.WATCHING
			teacher_timer = randf_range(1.5, 2.4)
			eye_icon.text = "👀"
			teacher_lbl.text = "回头锐利巡视！"
			teacher_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			status_lbl.text = "🚨 老师回头了！绝对不要乱动！"
			say_companion_dialogue("“快低头看书！别动别动！”", "shy")
		TeacherState.WATCHING:
			# 巡视完毕 -> 恢复写板书
			teacher_state = TeacherState.WRITING
			teacher_timer = randf_range(2.8, 4.2)
			eye_icon.text = "📝"
			teacher_lbl.text = "背身写板书"
			teacher_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
			status_lbl.text = "老师转身板书！安全时机，快蓄力传纸条！"
			suspicion_gauge = max(0.0, suspicion_gauge - 20.0)
			alert_bar.value = suspicion_gauge

# ── 弹射手感判定 ──────────────────────────────────────────────
func _on_action_down() -> void:
	if current_state != State.IDLE:
		return
	is_charging = true
	charge_power = 0.0

func _on_action_up() -> void:
	if not is_charging:
		return
	is_charging = false

	# 检查时机
	if teacher_state == TeacherState.WATCHING:
		_busted_by_teacher()
		return

	# 判定蓄力精度 (70% ~ 90% 为最佳弹射力度)
	current_state = State.SLIP_FLYING
	action_btn.disabled = true
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("paper_rustle")

	var tw = create_tween()
	var target_x = 420.0
	if charge_power < 50.0:
		# 力度太小：掉在半路走廊
		target_x = 240.0
		tw.tween_property(paper_slip, "position", Vector2(target_x, 230), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.finished.connect(func():
			_slip_dropped_short()
		)
	elif charge_power > 95.0:
		# 力度太大：飞过头砸在窗户上
		target_x = 520.0
		tw.tween_property(paper_slip, "position", Vector2(target_x, 170), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.finished.connect(func():
			_busted_by_teacher("大力出奇迹，纸条直接飞到窗台被老师听到了！")
		)
	else:
		# 完美命中同伴课桌！
		tw.tween_property(paper_slip, "position", Vector2(target_x, 195), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.finished.connect(func():
			_on_slip_received()
		)

func _slip_dropped_short() -> void:
	status_lbl.text = "力度太小！纸条卡在过道正中间……趁老师没回头赶紧捡！"
	status_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	suspicion_gauge = min(100.0, suspicion_gauge + 35.0)
	alert_bar.value = suspicion_gauge

	# ── 意外成就：同学，你纸条掉了 ──
	GameManager.flags["achv_slip_hallway"] = true
	if is_instance_valid(AchievementManager):
		AchievementManager.check_all()

	var tw = create_tween()
	tw.tween_interval(1.0)
	tw.finished.connect(func():
		paper_slip.position = Vector2(110, 205)
		current_state = State.IDLE
		action_btn.disabled = false
	)

func _on_slip_received() -> void:
	current_state = State.TOPIC_CHOICE
	say_companion_dialogue("“接到了接到了！写了什么呀？”", "shy")
	_show_topic_choices()

## 弹出纸条回复选择支
func _show_topic_choices() -> void:
	for child in topic_box.get_children():
		child.queue_free()

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	topic_box.add_child(v)

	var title = Label.new()
	title.text = "💌 纸条传达！选择你想对她说的话："
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	v.add_child(title)

	for top in TOPIC_OPTIONS:
		var btn = Button.new()
		btn.text = top["text"]
		btn.custom_minimum_size = Vector2(0, 32)
		ThemeUtils.style_accent_btn(btn, Color(0.3, 0.45, 0.7), 6, 1)
		btn.pressed.connect(func():
			_select_topic(top)
		)
		v.add_child(btn)

	topic_box.visible = true

func _select_topic(top: Dictionary) -> void:
	topic_box.visible = false
	current_state = State.SUCCESS

	var total_favor = top["bonus"] + stat_sweet_talk_bonus
	GameManager.add_favor(companion_id, total_favor)
	GameManager.add_stat("stress", -20) # 课上刺激摸鱼大幅减压

	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")

	say_companion_dialogue(top["reply"], "shy")
	status_lbl.text = "🎉 纸条传情成功！%s 的好感度 +%d，压力 -20！" % [c_name, total_favor]
	status_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	GameManager.show_toast.emit("💌 纸条交流顺利！%s 好感提升 +%d！" % [c_name, total_favor])

	# ── 成就系统联动 ──
	if suspicion_gauge <= 5.0:
		GameManager.flags["achv_stealth_perfect"] = true
	if suspicion_gauge <= 0.01:
		GameManager.flags["achv_paper_silent"] = true
	if is_instance_valid(AchievementManager):
		AchievementManager.check_all()

	action_btn.disabled = false
	action_btn.text = "🔄 再传一张 (RETRY)"
	action_btn.button_down.disconnect(_on_action_down)
	action_btn.button_up.disconnect(_on_action_up)
	action_btn.pressed.connect(func():
		paper_slip.position = Vector2(110, 205)
		current_state = State.IDLE
		action_btn.text = "🎯 按住蓄力弹射 (HOLD)"
		action_btn.pressed.disconnect(action_btn.pressed.get_connections()[0].callable)
		action_btn.button_down.connect(_on_action_down)
		action_btn.button_up.connect(_on_action_up)
	)

func _busted_by_teacher(custom_msg: String = "") -> void:
	current_state = State.BUSTED
	is_charging = false
	status_lbl.text = "🚨 " + (custom_msg if custom_msg != "" else "被老师抓个正着！纸条被没收！")
	status_lbl.add_theme_color_override("font_color", Color(1, 0.25, 0.25))

	GameManager.add_stat("stress", 15)
	GameManager.add_stat("dean_suspicion", 10)
	say_companion_dialogue("“糟了糟了……下课要被叫去办公室了！”", "shy")
	GameManager.show_toast.emit("😱 课堂传纸条被当场逮住！压力 +15，引起老师注意！")

	action_btn.disabled = false
	action_btn.text = "低头认错，整理心情"
	action_btn.pressed.connect(func():
		close_game()
	)

func execute_skip() -> void:
	var intellect = GameManager.stats.get("intellect", 10)
	var total_favor = 8 + stat_sweet_talk_bonus
	GameManager.add_favor(companion_id, total_favor)
	GameManager.add_stat("stress", -15)
	GameManager.show_toast.emit("隐蔽传纸条成功！好感度 +%d！" % total_favor)
	say_companion_dialogue("“嘻嘻，小纸条我收好啦！”", "happy")
