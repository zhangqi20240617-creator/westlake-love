# scripts/minigames/BadmintonRallyUI.gd
class_name BadmintonRallyUI
extends MiniGameBase

## ══════════════════════════════════════════════════════════════════
## BadmintonRallyUI.gd — 操场·双人羽毛球对击小游戏
## 机制核心：
## 1. 节奏击球与连击对打（Rally Combo）
## 2. 【凌空暴扣 SMASH!】绝杀机制（蓄力满格触发暴扣 QTE）
## 3. 同伴风格差分：
##    - 林小夏（体委）：超强扣杀球路，好胜心强，球速极快
##    - 叶菁菁（青梅）：轻柔喂球，默契度极高，适合长线连击
##    - 陈雨桐（班长）：严谨刁钻，追求边线落点
##    - 苏晚晴（文委）：体力较弱，球速轻缓，反差可爱
## 4. 角色 5 维属性深度联动：
##    - strength (体魄): 扣杀威力加成，结算时大幅提升体质 (strength +1~2)
##    - intellect (智力): 落点预判，击球甜区 (Sweet Spot) 判定窗口拓宽
##    - stress (压力): 挥洒汗水是最佳解压！连击越高减压越狠 (单局最高 -30)
##    - social / charm: 切磋羁绊加深，好感度增幅暴击
## ══════════════════════════════════════════════════════════════════

# ── 游戏状态 ───────────────────────────────────────────────────
enum State { IDLE, SERVING, BALL_TO_OPPONENT, BALL_TO_PLAYER, SMASH_READY, VICTORY, GAME_OVER }
var current_state: State = State.IDLE

# ── 对打与连击数据 ────────────────────────────────────────────
var rally_count: int = 0
var max_rally_record: int = 0
var smash_energy: float = 0.0     # 暴扣能量 0 ~ 100%
var total_smashes: int = 0
var target_max_rallies := 12      # 达成 12 拍即进入完美决胜

# ── 羽毛球物理与判定 ──────────────────────────────────────────
const COURT_TOP_Y := 65.0
const NET_Y := 160.0
const PLAYER_SWEET_Y := 250.0     # 最佳击球线
const COURT_BOTTOM_Y := 285.0

var ball_pos := Vector2(260.0, PLAYER_SWEET_Y)
var ball_start := Vector2.ZERO
var ball_target := Vector2.ZERO
var ball_progress: float = 0.0
var ball_duration: float = 1.0
var ball_tween: Tween = null

# ── 属性衍生加成 ──────────────────────────────────────────────
var stat_sweet_window_bonus: float = 0.0
var stat_smash_power_bonus: float = 0.0
var stat_stress_reduction_mult: float = 1.0

# ── UI 控件节点 ────────────────────────────────────────────────
var court_panel: PanelContainer
var court_view: Control
var net_line: Panel
var sweet_zone: Panel
var ball_node: Control
var ball_shadow: ColorRect
var opponent_avatar: PanelContainer
var opponent_avatar_lbl: Label
var rally_lbl: Label
var smash_bar: ProgressBar
var action_btn: Button
var status_lbl: Label
var perk_lbl: Label

func setup_game() -> void:
	game_id = "badminton_rally"
	game_title = "操场 · 双人羽毛球切磋"
	_title_lbl.text = "🏸 " + game_title

	_calculate_stat_synergies()
	_build_badminton_ui()
	init_companion_dock(_content_root)

	_update_hud_display()
	_greet_companion()

## 计算属性带来的运动加成
func _calculate_stat_synergies() -> void:
	var intellect = float(GameManager.stats.get("intellect", 10))
	var strength = float(GameManager.stats.get("strength", 10))
	var charm = float(GameManager.stats.get("charm", 10))
	var social = float(GameManager.stats.get("social", 10))

	# 智力：拓宽击球甜区
	stat_sweet_window_bonus = clamp(intellect * 0.15, 0.0, 20.0)
	# 体魄：增加扣杀充能效率
	stat_smash_power_bonus = clamp(strength * 0.25, 0.0, 30.0)
	# 社交与魅力：提升减压倍率与好感增幅
	stat_stress_reduction_mult = 1.0 + clamp((social + charm) * 0.003, 0.0, 0.4)

func _greet_companion() -> void:
	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "她")
	match companion_id:
		"xiaoxia":
			say_companion_dialogue("“来操场单挑羽毛球？我可不会手下留情哦，接招吧！”", "sport")
		"yutong":
			say_companion_dialogue("“偶尔运动一下对大脑也很有好处……请多指教！”", "study")
		"jingjing":
			say_companion_dialogue("“好呀！今天风很小，我们来试试看能连打多少拍！”", "casual")
		"wanqing":
			say_companion_dialogue("“我跑得不太快……你可要轻轻打给我哦。”", "shy")
		_:
			say_companion_dialogue("“夕阳下的球场真舒服！准备好发球了吗？”", "default")

# ── 搭建羽毛球场主结构 ────────────────────────────────────────
func _build_badminton_ui() -> void:
	court_panel = PanelContainer.new()
	court_panel.custom_minimum_size = Vector2(560, 0)
	court_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	court_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var outer_style = ThemeUtils.create_style(
		Color(0.08, 0.12, 0.16, 0.95), 16,
		Color(0.2, 0.7, 0.5, 0.7), 2,
		-1, 14, 14, 10, 10
	)
	court_panel.add_theme_stylebox_override("panel", outer_style)
	_content_root.add_child(court_panel)

	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 8)
	court_panel.add_child(v_box)

	# 1. 顶部运动天赋横幅
	perk_lbl = Label.new()
	var perk_list := []
	if stat_sweet_window_bonus > 0:
		perk_list.append("🧠智力甜区+%.0fpx" % stat_sweet_window_bonus)
	if stat_smash_power_bonus > 0:
		perk_list.append("💪体魄暴扣充能+%.0f%%" % stat_smash_power_bonus)
	if stat_stress_reduction_mult > 1.0:
		perk_list.append("💖运动减压×%.1f" % stat_stress_reduction_mult)

	perk_lbl.text = " [运动状态] " + (" · ".join(perk_list) if perk_list.size() > 0 else "精力充沛")
	perk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk_lbl.add_theme_font_size_override("font_size", 11)
	perk_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	v_box.add_child(perk_lbl)

	# 2. 塑胶球场视角 (PVC Court)
	court_view = Control.new()
	court_view.custom_minimum_size = Vector2(0, 310)
	court_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	court_view.clip_contents = true

	# 绿色塑胶地面
	var floor_bg = ColorRect.new()
	floor_bg.set_anchors_preset(PRESET_FULL_RECT)
	floor_bg.color = Color(0.12, 0.35, 0.25, 0.95)
	court_view.add_child(floor_bg)

	# 白边线与发球线
	var court_border = Panel.new()
	court_border.position = Vector2(60, 20)
	court_border.size = Vector2(440, 275)
	var border_style = ThemeUtils.create_style(Color.TRANSPARENT, 0, Color(0.9, 0.95, 0.9, 0.7), 2)
	court_border.add_theme_stylebox_override("panel", border_style)
	court_view.add_child(court_border)

	# 中间羽毛球网 (Net)
	net_line = Panel.new()
	net_line.position = Vector2(40, NET_Y - 4)
	net_line.size = Vector2(480, 8)
	var net_style = ThemeUtils.create_style(Color(0.95, 0.95, 0.95, 0.9), 2, Color(0.8, 0.3, 0.3), 1)
	net_line.add_theme_stylebox_override("panel", net_style)
	court_view.add_child(net_line)

	var net_lbl = Label.new()
	net_lbl.text = "─── 球网 NET ───"
	net_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	net_lbl.set_anchors_preset(PRESET_FULL_RECT)
	net_lbl.add_theme_font_size_override("font_size", 10)
	net_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	net_line.add_child(net_lbl)

	# 对方半场：同伴对拍位
	opponent_avatar = PanelContainer.new()
	opponent_avatar.position = Vector2(240, COURT_TOP_Y - 20)
	opponent_avatar.custom_minimum_size = Vector2(80, 36)
	var opp_style = ThemeUtils.create_style(Color(0.15, 0.2, 0.3, 0.9), 8, Color(0.9, 0.5, 0.7), 1)
	opponent_avatar.add_theme_stylebox_override("panel", opp_style)
	court_view.add_child(opponent_avatar)

	opponent_avatar_lbl = Label.new()
	opponent_avatar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_avatar_lbl.add_theme_font_size_override("font_size", 12)
	opponent_avatar_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
	opponent_avatar.add_child(opponent_avatar_lbl)

	# 我方半场：击球甜区（Sweet Spot Zone）
	sweet_zone = Panel.new()
	var sweet_h = 40.0 + stat_sweet_window_bonus
	sweet_zone.position = Vector2(80, PLAYER_SWEET_Y - sweet_h * 0.5)
	sweet_zone.size = Vector2(400, sweet_h)
	var sweet_style = ThemeUtils.create_style(Color(0.2, 0.6, 0.9, 0.22), 8, Color(0.3, 0.8, 1, 0.6), 2)
	sweet_zone.add_theme_stylebox_override("panel", sweet_style)
	court_view.add_child(sweet_zone)

	var sweet_lbl = Label.new()
	sweet_lbl.text = "🎯 最佳击球甜区 (SWEET SPOT)"
	sweet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sweet_lbl.set_anchors_preset(PRESET_FULL_RECT)
	sweet_lbl.add_theme_font_size_override("font_size", 11)
	sweet_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 0.7))
	sweet_zone.add_child(sweet_lbl)

	# 羽毛球与落点阴影
	ball_shadow = ColorRect.new()
	ball_shadow.custom_minimum_size = Vector2(16, 8)
	ball_shadow.color = Color(0, 0, 0, 0.35)
	court_view.add_child(ball_shadow)

	ball_node = Control.new()
	ball_node.custom_minimum_size = Vector2(24, 24)
	var ball_icon = Label.new()
	ball_icon.text = "🏸"
	ball_icon.add_theme_font_size_override("font_size", 22)
	ball_node.add_child(ball_icon)
	court_view.add_child(ball_node)

	v_box.add_child(court_view)

	# 3. 计分与 HUD 操控台
	var hud_panel = PanelContainer.new()
	var hud_style = ThemeUtils.create_style(Color(0.08, 0.1, 0.16, 0.95), 10, Color(0.2, 0.5, 0.4), 1)
	hud_panel.add_theme_stylebox_override("panel", hud_style)
	v_box.add_child(hud_panel)

	var hud_vbox = VBoxContainer.new()
	hud_vbox.add_theme_constant_override("separation", 6)
	hud_panel.add_child(hud_vbox)

	var info_row = HBoxContainer.new()
	rally_lbl = Label.new()
	rally_lbl.text = "🔥 当前连击: 0 拍"
	rally_lbl.add_theme_font_size_override("font_size", 15)
	rally_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	info_row.add_child(rally_lbl)

	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(sp)

	var energy_lbl = Label.new()
	energy_lbl.text = "⚡ 暴扣蓄力:"
	energy_lbl.add_theme_font_size_override("font_size", 13)
	energy_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 1))
	info_row.add_child(energy_lbl)

	smash_bar = ProgressBar.new()
	smash_bar.custom_minimum_size = Vector2(120, 16)
	smash_bar.max_value = 100
	smash_bar.show_percentage = true
	var s_style = ThemeUtils.create_style(Color(0.8, 0.3, 0.9), 4)
	smash_bar.add_theme_stylebox_override("fill", s_style)
	info_row.add_child(smash_bar)
	hud_vbox.add_child(info_row)

	status_lbl = Label.new()
	status_lbl.text = "点击【发球】开启对打，当球落入下方甜区时光速挥拍！"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	hud_vbox.add_child(status_lbl)

	# 核心动作按钮
	action_btn = Button.new()
	action_btn.text = "🏸 发球 START!"
	action_btn.custom_minimum_size = Vector2(0, 42)
	ThemeUtils.style_accent_btn(action_btn, Color(0.2, 0.65, 0.5), 8, 2)
	action_btn.pressed.connect(_on_action_pressed)
	hud_vbox.add_child(action_btn)

	_reset_ball_position()

func _update_hud_display() -> void:
	rally_lbl.text = "🔥 当前连击: %d 拍" % rally_count
	smash_bar.value = smash_energy
	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")
	opponent_avatar_lbl.text = "👤 %s" % c_name

func _reset_ball_position() -> void:
	ball_pos = Vector2(260.0, PLAYER_SWEET_Y)
	ball_node.position = ball_pos - Vector2(12, 12)
	ball_shadow.position = ball_pos - Vector2(8, 0)
	current_state = State.IDLE
	action_btn.text = "🏸 发球 SERVE!"
	ThemeUtils.style_accent_btn(action_btn, Color(0.2, 0.65, 0.5), 8, 2)

# ── 核心循环与击球判定 ────────────────────────────────────────
func _on_action_pressed() -> void:
	if current_state == State.IDLE or current_state == State.GAME_OVER:
		_start_serve()
	elif current_state == State.BALL_TO_PLAYER:
		_player_hit_ball()
	elif current_state == State.SMASH_READY:
		_execute_smash()

func _start_serve() -> void:
	rally_count = 0
	smash_energy = 0.0
	current_state = State.SERVING
	_update_hud_display()

	status_lbl.text = "我方发球！球越过球网！"
	action_btn.text = "👀 观察球路……"
	action_btn.disabled = true

	# 球从我方发向对方半场
	ball_start = ball_pos
	ball_target = Vector2(randf_range(160, 360), COURT_TOP_Y + 15)
	_fly_ball_to(ball_target, 0.9, func():
		_opponent_return_ball()
	)

## 对手同伴回球
func _opponent_return_ball() -> void:
	current_state = State.BALL_TO_PLAYER
	action_btn.disabled = false

	# 检查是否蓄力满格进入暴扣局
	if smash_energy >= 100.0:
		current_state = State.SMASH_READY
		action_btn.text = "⚡ 凌空暴扣 SMASH!"
		ThemeUtils.style_accent_btn(action_btn, Color(0.95, 0.25, 0.35), 8, 2)
		status_lbl.text = "对方回出高远球！暴扣绝杀时机已到！快按【凌空暴扣】！"
		status_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		say_companion_dialogue("“哇！球挑高了！好机会，扣下来！”", "shy")

		ball_start = ball_pos
		ball_target = Vector2(260.0, PLAYER_SWEET_Y)
		_fly_ball_to(ball_target, 1.4, func():
			# 暴扣超时未打出算漏球
			if current_state == State.SMASH_READY:
				_miss_ball("错失扣杀良机，羽毛球落地了！")
		)
		return

	action_btn.text = "🏸 挥拍抽击 HIT!"
	ThemeUtils.style_accent_btn(action_btn, Color(0.25, 0.55, 0.9), 8, 2)
	status_lbl.text = "球飞向我方！看准落入甜区时挥拍！"

	# 根据同伴性格决定回球速度与难度
	var opp_speed := 0.95
	match companion_id:
		"xiaoxia": opp_speed = 0.72   # 体委球速极快
		"yutong": opp_speed = 0.82   # 班长落点偏刁
		"wanqing": opp_speed = 1.10  # 文委球速舒缓
		"jingjing": opp_speed = 0.90 # 青梅喂球适中

	# 随着连击增多，球速逐步加快
	opp_speed = max(0.65, opp_speed - rally_count * 0.02)

	var target_x = randf_range(130, 390)
	ball_start = ball_pos
	ball_target = Vector2(target_x, PLAYER_SWEET_Y + 10)

	_fly_ball_to(ball_target, opp_speed, func():
		# 球若触底还未挥拍则判 MISS
		if current_state == State.BALL_TO_PLAYER:
			_miss_ball("挥拍太迟，羽毛球掉落在地了！")
	)

## 玩家挥拍判定
func _player_hit_ball() -> void:
	if current_state != State.BALL_TO_PLAYER:
		return

	if ball_tween and ball_tween.is_valid():
		ball_tween.kill()

	var current_y = ball_node.position.y
	var dy = abs(current_y - PLAYER_SWEET_Y)

	# 智力拓宽甜区
	var sweet_limit = 22.0 + stat_sweet_window_bonus

	if dy <= sweet_limit:
		# 完美抽击
		rally_count += 1
		max_rally_record = max(max_rally_record, rally_count)
		var gain = (30.0 + stat_smash_power_bonus)
		smash_energy = clamp(smash_energy + gain, 0.0, 100.0)
		_update_hud_display()

		status_lbl.text = "🎯 完美击球 (PERFECT)！球速极快，连击 %d 拍！" % rally_count
		status_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		say_companion_dialogue("“好球！抽得漂亮，看我接住！”", "default")
		_hit_success(0.75)
	elif dy <= sweet_limit + 35.0:
		# 普通击球
		rally_count += 1
		max_rally_record = max(max_rally_record, rally_count)
		smash_energy = clamp(smash_energy + 15.0, 0.0, 100.0)
		_update_hud_display()

		status_lbl.text = "👍 普通回球 (GOOD)！保持连击 %d 拍！" % rally_count
		status_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
		_hit_success(0.9)
	else:
		# 时机严重偏差
		_miss_ball("时机严重偏差，打出界外了！")

func _hit_success(return_duration: float) -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("badminton_hit", 0.08)
	current_state = State.BALL_TO_OPPONENT
	action_btn.disabled = true
	action_btn.text = "👀 观察球路……"

	# 回球给对手
	var target_x = randf_range(160, 360)
	ball_start = ball_pos
	ball_target = Vector2(target_x, COURT_TOP_Y + 15)
	_fly_ball_to(ball_target, return_duration, func():
		_opponent_return_ball()
	)

## 执行凌空暴扣（绝杀）
func _execute_smash() -> void:
	if current_state != State.SMASH_READY:
		return
	if ball_tween and ball_tween.is_valid():
		ball_tween.kill()

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("badminton_hit", 0.15)

	total_smashes += 1
	smash_energy = 0.0
	rally_count += 1
	max_rally_record = max(max_rally_record, rally_count)
	_update_hud_display()

	status_lbl.text = "💥 绝杀暴扣 (SMASH)！雷霆一击，直接得分！"
	status_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.4))
	say_companion_dialogue("“哇啊啊——！这球太帅了，完全接不到！”", "shy")

	# 画面暴扣震动
	_shake_court()

	# 球以超高速度砸向对方底线
	ball_start = ball_pos
	ball_target = Vector2(randf_range(180, 340), COURT_TOP_Y - 10)
	_fly_ball_to(ball_target, 0.35, func():
		_on_round_victory()
	)

## 漏球或出界
func _miss_ball(reason: String) -> void:
	current_state = State.GAME_OVER
	if randf() < 0.35:
		reason = "大力出奇迹，羽毛球高高飞起卡在操场大树上了！"
		GameManager.flags["achv_badminton_tree"] = true
	status_lbl.text = "❌ " + reason
	status_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	say_companion_dialogue("“哎呀擦网了……不过刚才几个来回打得超尽兴的！”", "default")
	_settle_badminton_game()

func _on_round_victory() -> void:
	current_state = State.VICTORY
	status_lbl.text = "🏆 完美暴扣得分！对手被彻底征服！"
	_settle_badminton_game()

# ── 结算与奖励分发 ────────────────────────────────────────────
func _settle_badminton_game() -> void:
	action_btn.text = "🔄 再来一局 (RETRY)"
	action_btn.disabled = false
	ThemeUtils.style_accent_btn(action_btn, Color(0.2, 0.65, 0.5), 8, 2)

	# 属性计算：
	# 1. 压力削减：每拍 -2，暴扣额外 -10，社交/魅力加成
	var stress_cut = int((rally_count * 2.2 + total_smashes * 10) * stat_stress_reduction_mult)
	stress_cut = clamp(stress_cut, 8, 32)
	GameManager.add_stat("stress", -stress_cut)

	# 2. 体魄提升：连击 >= 6 拍体魄 +1，暴扣成功再 +1
	var str_gain = 0
	if rally_count >= 6:
		str_gain += 1
	if total_smashes >= 1:
		str_gain += 1
	if str_gain > 0:
		GameManager.add_stat("strength", str_gain)

	# 3. 好感度增长：随连击数与暴扣加成
	var favor_boost = clamp(int(rally_count * 0.8) + total_smashes * 4, 3, 14)
	GameManager.add_favor(companion_id, favor_boost)

	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")

	GameManager.show_toast.emit(
		"🏸 切磋结束！对打 %d 拍，压力 -%d，%s 好感 +%d%s" % [
			rally_count, stress_cut, c_name, favor_boost,
			("，体魄 +%d！" % str_gain) if str_gain > 0 else "！"
		]
	)

	# ── 成就系统联动 ──
	if max_rally_record >= 10:
		GameManager.flags["achv_badminton_rally_10"] = true
	if max_rally_record >= 50:
		GameManager.flags["achv_badminton_50"] = true
	if is_instance_valid(AchievementManager):
		AchievementManager.check_all()

# ── 物理抛物线飞行实现 ────────────────────────────────────────
func _fly_ball_to(target_pos: Vector2, duration: float, on_finished: Callable) -> void:
	ball_tween = create_tween().set_parallel(true)
	# X 轴平滑平移
	ball_tween.tween_property(ball_node, "position:x", target_pos.x - 12, duration).set_trans(Tween.TRANS_LINEAR)
	ball_tween.tween_property(ball_shadow, "position:x", target_pos.x - 8, duration).set_trans(Tween.TRANS_LINEAR)

	# Y 轴位移
	ball_tween.tween_property(ball_node, "position:y", target_pos.y - 12, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ball_tween.tween_property(ball_shadow, "position:y", target_pos.y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	ball_tween.finished.connect(func():
		ball_pos = target_pos
		on_finished.call()
	)

func _shake_court() -> void:
	if is_instance_valid(court_view):
		var tw = create_tween()
		court_view.position.y += 6
		tw.tween_property(court_view, "position:y", court_view.position.y - 6, 0.15).set_trans(Tween.TRANS_BOUNCE)

# ── 快速跳过（Anti-Grind）─────────────────────────────────────
func execute_skip() -> void:
	var strength = GameManager.stats.get("strength", 10)
	var simulated_rallies = clamp(6 + int(strength * 0.15), 6, 14)
	rally_count = simulated_rallies
	total_smashes = 1 if strength >= 30 else 0
	_settle_badminton_game()
	say_companion_dialogue("“今天球感太好啦！出了一身汗，整个人都轻松了！”", "happy")
