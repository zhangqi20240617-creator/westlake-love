extends Control
class_name QuizUI

## ══════════════════════════════════════════════════════════
## QuizUI.gd  — 速写填字模式（小游戏升级版）
## 特性：15秒计时 · 连击倍率（最高×2）· 三难度分级
##       边框发光特效（连击≥3）· 全对额外奖励
## ══════════════════════════════════════════════════════════

signal quiz_finished(correct_count: int, combo_max: int)

var current_questions: Array = []
var current_q_index: int = 0
var correct_count: int = 0
var combo: int = 0          # 连击数
var combo_max: int = 0      # 本场最高连击
var on_finish_callback: Callable

# ── 计时相关 ──────────────────────────────────────────────
const TIME_PER_QUESTION := 15.0   # 每题秒数
var _time_left: float = TIME_PER_QUESTION
var _timer_active: bool = false

# ── 难度参数 ──────────────────────────────────────────────
# 由外部调用 start_quiz() 时传入，默认 "normal"
# "easy":巩固 · "normal":提升 · "hard":冲刺
var _difficulty: String = "normal"
const DIFF_TIME = { "easy": 20.0, "normal": 15.0, "hard": 10.0 }
const DIFF_LABEL = { "easy": "巩固模式", "normal": "提升模式", "hard": "冲刺模式" }
const DIFF_COLOR = {
	"easy":   Color("86efac"),
	"normal": Color("fbbf24"),
	"hard":   Color("f87171")
}

# ── UI 节点 ───────────────────────────────────────────────
var bg_rect: ColorRect
var panel: Panel
var _border_glow: Panel    # 连击发光边框
var content_vbox: VBoxContainer
var header_lbl: Label
var diff_lbl: Label        # 难度标签
var question_lbl: Label
var options_container: VBoxContainer
var timer_bar: ProgressBar # 倒计时进度条
var timer_lbl: Label       # 秒数数字
var combo_lbl: Label       # 连击数显示
var result_overlay: Panel  # 答题后的结果浮层

func _ready():
	z_index = 100
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# ── 半透明背景 ───────────────────────────────────────
	bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	bg_rect.color = Color(0, 0, 0, 0.75)
	add_child(bg_rect)

	# ── 发光边框（连击时激活）────────────────────────────
	_border_glow = Panel.new()
	_border_glow.set_anchors_preset(PRESET_FULL_RECT)
	_border_glow.modulate = Color(1, 1, 1, 0)
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color(0, 0, 0, 0)
	glow_style.border_width_left   = 4
	glow_style.border_width_right  = 4
	glow_style.border_width_top    = 4
	glow_style.border_width_bottom = 4
	glow_style.border_color = Color("fbbf24")
	_border_glow.add_theme_stylebox_override("panel", glow_style)
	add_child(_border_glow)

	# ── 主面板 ───────────────────────────────────────────
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(820, 560)
	panel.set_anchors_preset(PRESET_CENTER)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.17, 0.97)
	style.corner_radius_top_left    = 18
	style.corner_radius_top_right   = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.4, 0.7)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   36)
	margin.add_theme_constant_override("margin_right",  36)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(content_vbox)

	# ── 顶栏：难度 + 连击 ────────────────────────────────
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	content_vbox.add_child(top_row)

	diff_lbl = Label.new()
	diff_lbl.add_theme_font_size_override("font_size", 15)
	diff_lbl.add_theme_color_override("font_color", Color("86efac"))
	top_row.add_child(diff_lbl)

	var sp_fill = Control.new()
	sp_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(sp_fill)

	combo_lbl = Label.new()
	combo_lbl.add_theme_font_size_override("font_size", 18)
	combo_lbl.add_theme_color_override("font_color", Color("fbbf24"))
	combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(combo_lbl)

	# ── 科目 + 题序标题 ──────────────────────────────────
	header_lbl = Label.new()
	header_lbl.add_theme_font_size_override("font_size", 17)
	header_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(header_lbl)

	# ── 倒计时进度条 ─────────────────────────────────────
	var timer_row = HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 8)
	content_vbox.add_child(timer_row)

	timer_lbl = Label.new()
	timer_lbl.add_theme_font_size_override("font_size", 16)
	timer_lbl.add_theme_color_override("font_color", Color("fbbf24"))
	timer_lbl.custom_minimum_size = Vector2(30, 0)
	timer_row.add_child(timer_lbl)

	timer_bar = ProgressBar.new()
	timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_bar.custom_minimum_size   = Vector2(0, 18)
	timer_bar.min_value = 0
	timer_bar.max_value = 100
	timer_bar.value     = 100
	timer_row.add_child(timer_bar)

	# ── 题目文字 ─────────────────────────────────────────
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(0, 6)
	content_vbox.add_child(sp1)

	question_lbl = Label.new()
	question_lbl.add_theme_font_size_override("font_size", 24)
	question_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(question_lbl)

	var sp2 = Control.new()
	sp2.custom_minimum_size = Vector2(0, 6)
	content_vbox.add_child(sp2)

	# ── 选项容器 ─────────────────────────────────────────
	options_container = VBoxContainer.new()
	options_container.add_theme_constant_override("separation", 10)
	content_vbox.add_child(options_container)

	hide()

# ── 根据游戏天数推算学期 ────────────────────────────────────
func _get_current_term() -> int:
	var d = GameManager.day
	if d <= 90:   return 1
	elif d <= 180: return 2
	elif d <= 270: return 3
	elif d <= 360: return 4
	elif d <= 450: return 5
	else:          return 6

# ── 自动根据 stress + day 推算难度 ────────────────────────
static func auto_difficulty() -> String:
	var stress = GameManager.stats.get("stress", 0)
	var d      = GameManager.day
	if d >= 450 or stress >= 60: return "hard"
	if d >= 270 or stress >= 30: return "normal"
	return "easy"

# ══════════════════════════════════════════════════════════
# 公共入口：可选传入 difficulty；不传时自动推算
# ══════════════════════════════════════════════════════════
func start_quiz(subjects: Array, cb: Callable, difficulty: String = ""):
	on_finish_callback = cb
	_difficulty = difficulty if difficulty != "" else auto_difficulty()
	_time_left = DIFF_TIME.get(_difficulty, 15.0)

	current_questions.clear()
	current_q_index = 0
	correct_count   = 0
	combo           = 0
	combo_max       = 0

	diff_lbl.text = "【%s】" % DIFF_LABEL.get(_difficulty, "提升模式")
	diff_lbl.add_theme_color_override("font_color", DIFF_COLOR.get(_difficulty, Color("fbbf24")))

	# 动态读题库
	var db = {}
	var f = FileAccess.open("res://scripts/questions.json", FileAccess.READ)
	if f:
		var text = f.get_as_text()
		var json = JSON.new()
		if json.parse(text) == OK:
			db = json.data

	var t = _get_current_term()
	for sub in subjects:
		if db.has(sub) and db[sub].size() > 0:
			var all_qs = db[sub]
			var valid_qs: Array = []
			for q in all_qs:
				var q_term = q.get("term", 0)
				if q_term == t or q_term == 0:
					valid_qs.append(q)
			if valid_qs.is_empty():
				valid_qs = all_qs
			valid_qs.shuffle()
			var selected = valid_qs[0]
			selected["sub_id"] = sub
			current_questions.append(selected)
		else:
			current_questions.append({
				"sub_id": sub, "question": "【题库缺失】当前科目的测试题。",
				"options": ["选我", "别选我", "也别选我", "跳过"], "correct": 0
			})

	if current_questions.is_empty():
		call_deferred("_finalize")
		return

	show()
	_show_current_question()

# ── 显示当前题目并重置计时 ────────────────────────────────
func _show_current_question():
	for c in options_container.get_children():
		c.queue_free()

	var q_data = current_questions[current_q_index]
	var meta     = GameManager.SUBJECT_META.get(q_data["sub_id"], {})
	var sub_name = meta.get("label", q_data["sub_id"])
	var q_total  = current_questions.size()

	header_lbl.text = "【%s】 速写填字 (%d/%d)" % [sub_name, current_q_index + 1, q_total]
	question_lbl.text = q_data["question"]
	_update_combo_label()

	# 重置计时
	_time_left    = DIFF_TIME.get(_difficulty, 15.0)
	_timer_active = true
	_update_timer_bar()

	# 构建选项按钮
	var idx = 0
	for opt_text in q_data["options"]:
		var btn = Button.new()
		btn.text = opt_text
		btn.custom_minimum_size = Vector2(540, 58)
		btn.add_theme_font_size_override("font_size", 18)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.18, 0.22, 0.33)
		s.corner_radius_top_left    = 8
		s.corner_radius_top_right   = 8
		s.corner_radius_bottom_left = 8
		s.corner_radius_bottom_right = 8
		s.border_width_left   = 1
		s.border_width_right  = 1
		s.border_width_top    = 1
		s.border_width_bottom = 1
		s.border_color = Color(0.35, 0.45, 0.65, 0.8)
		btn.add_theme_stylebox_override("normal",   s)
		btn.add_theme_stylebox_override("hover",    _hover_style())
		btn.add_theme_stylebox_override("pressed",  s.duplicate())
		btn.add_theme_stylebox_override("disabled", s.duplicate())

		btn.pressed.connect(_on_option_selected.bind(btn, idx, q_data["correct"]))
		options_container.add_child(btn)
		idx += 1

func _hover_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.32, 0.48)
	s.corner_radius_top_left    = 8
	s.corner_radius_top_right   = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	return s

# ── 帧更新：处理计时器 ────────────────────────────────────
func _process(delta: float):
	if not _timer_active or not visible:
		return
	_time_left -= delta
	_update_timer_bar()
	if _time_left <= 0.0:
		_timer_active = false
		_on_timeout()

func _update_timer_bar():
	var total = DIFF_TIME.get(_difficulty, 15.0)
	var pct   = clampf(_time_left / total * 100.0, 0, 100)
	timer_bar.value = pct
	timer_lbl.text  = "%d" % int(ceil(_time_left))
	# 时间不足 30% 时进度条变红
	if pct <= 30:
		timer_lbl.add_theme_color_override("font_color", Color("f87171"))
	else:
		timer_lbl.add_theme_color_override("font_color", Color("fbbf24"))

func _on_timeout():
	# 超时视为答错
	for c in options_container.get_children():
		c.disabled = true
	# 高亮正确答案
	var q_data       = current_questions[current_q_index]
	var correct_idx  = q_data["correct"]
	var correct_btn  = options_container.get_child(correct_idx)
	var rs = correct_btn.get_theme_stylebox("disabled").duplicate()
	rs.bg_color = Color(0.2, 0.7, 0.3)
	correct_btn.add_theme_stylebox_override("disabled", rs)
	GameManager.show_toast.emit("⏰ 时间到！答案是第 %d 项" % (correct_idx + 1))
	combo = 0
	_update_combo_label()
	_flash_glow(false)
	await get_tree().create_timer(1.4).timeout
	_advance_question()

# ── 玩家选择答案 ─────────────────────────────────────────
func _on_option_selected(btn: Button, selected_idx: int, correct_idx: int):
	if not _timer_active: return
	_timer_active = false

	for c in options_container.get_children():
		c.disabled = true

	var s = btn.get_theme_stylebox("disabled").duplicate()
	if selected_idx == correct_idx:
		s.bg_color = Color(0.15, 0.65, 0.28)
		btn.add_theme_stylebox_override("disabled", s)
		correct_count += 1
		combo         += 1
		if combo > combo_max:
			combo_max = combo
		_update_combo_label()
		_flash_glow(true)

		# 连击提示
		if combo == 3:
			GameManager.show_toast.emit("🔥 3连击！×1.5 加成！")
		elif combo == 5:
			GameManager.show_toast.emit("⚡ 5连击！×2.0 满倍！")
		elif combo >= 8:
			GameManager.show_toast.emit("💥 连击 %d！！" % combo)
		else:
			GameManager.show_toast.emit("✅ 答对！连击 %d" % combo)
	else:
		var right_btn = options_container.get_child(correct_idx)
		var rs = right_btn.get_theme_stylebox("disabled").duplicate()
		rs.bg_color = Color(0.15, 0.65, 0.28)
		right_btn.add_theme_stylebox_override("disabled", rs)
		s.bg_color = Color(0.75, 0.18, 0.18)
		btn.add_theme_stylebox_override("disabled", s)
		GameManager.show_toast.emit("❌ 答错了……连击中断")
		combo = 0
		_update_combo_label()
		_flash_glow(false)

	await get_tree().create_timer(1.2).timeout
	_advance_question()

func _advance_question():
	current_q_index += 1
	if current_q_index < current_questions.size():
		_show_current_question()
	else:
		_finalize()

# ── 连击标签更新 ─────────────────────────────────────────
func _update_combo_label():
	if combo <= 0:
		combo_lbl.text = ""
		return
	var mult  = _get_combo_mult()
	var stars = "🔥" if combo >= 5 else ("✨" if combo >= 3 else "⚡")
	combo_lbl.text = "%s 连击 %d  ×%.1f" % [stars, combo, mult]

# 连击倍率：3+ → ×1.5，5+ → ×2.0（用于结算奖励提示）
func _get_combo_mult() -> float:
	if combo >= 5: return 2.0
	if combo >= 3: return 1.5
	return 1.0

# ── 连击发光效果 ─────────────────────────────────────────
func _flash_glow(is_correct: bool):
	if is_correct and combo >= 3:
		var glow_col = Color("fbbf24") if combo < 5 else Color("f87171")
		var gs = _border_glow.get_theme_stylebox("panel").duplicate()
		gs.border_color = glow_col
		_border_glow.add_theme_stylebox_override("panel", gs)
		var t = _border_glow.create_tween()
		t.tween_property(_border_glow, "modulate", Color(1, 1, 1, 0.85), 0.15)
		t.tween_property(_border_glow, "modulate", Color(1, 1, 1, 0.0),  0.5)
	else:
		_border_glow.modulate = Color(1, 1, 1, 0)

# ── 结算 ─────────────────────────────────────────────────
func _finalize():
	_timer_active = false
	hide()
	queue_free()

	var total = current_questions.size()
	var reward_stress = 0
	var quiz_bonus    = 0

	# ── 全对奖励 ──────────────────────────────────────────
	if correct_count == total and total > 0:
		reward_stress = -3
		quiz_bonus    = 10 * total   # 额外答题奖励分
		GameManager.stats["stress"] = clampi(GameManager.stats["stress"] + reward_stress, 0, 100)
		GameManager.quiz_bonus_score += quiz_bonus
		GameManager.show_toast.emit("🏆 全对！压力 -3，中考预估+%d！" % quiz_bonus)
	elif correct_count >= ceili(total * 0.8):
		quiz_bonus = 5 * correct_count
		GameManager.quiz_bonus_score += quiz_bonus
		GameManager.show_toast.emit("😊 答对 %d/%d，预估+%d" % [correct_count, total, quiz_bonus])
	else:
		GameManager.show_toast.emit("😅 答对 %d/%d，继续加油！" % [correct_count, total])

	# 最高连击奖励（不受科目限制）
	if combo_max >= 5:
		GameManager.stats["social"] = clampi(GameManager.stats.get("social", 0) + 1, 0, 100)
		GameManager.show_toast.emit("⚡ 最高 %d 连击！社交 +1" % combo_max)

	# ── 成就系统联动 ──
	if is_instance_valid(AchievementManager):
		if correct_count > 0:
			AchievementManager.add_counter("quiz_correct_count", correct_count)
		if correct_count == total and total > 0:
			GameManager.flags["achv_quiz_perfect_first"] = true
		if combo_max >= 5:
			GameManager.flags["achv_quiz_combo_5"] = true
		AchievementManager.check_all()

	quiz_finished.emit(correct_count, combo_max)
	if on_finish_callback:
		on_finish_callback.call(correct_count)
