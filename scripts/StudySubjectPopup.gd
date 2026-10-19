## StudySubjectPopup.gd
## 分科复习选择弹窗 — 在教室/家中书桌触发学习热点时弹出
## 展示五科进度条，选科后消耗当前时段并调用 GameManager.add_subject_score()

class_name StudySubjectPopup
extends Control

signal closed

const SUBJECT_LIST = ["chinese", "math", "english", "science", "society"]
const BASE_GAIN_MIN = 5
const BASE_GAIN_MAX = 12

var _root: ColorRect
var _chosen: bool = false

# ── 静态工厂：在指定父节点打开弹窗 ─────────────────────────────
static func open(parent: Control) -> StudySubjectPopup:
	var inst = StudySubjectPopup.new()
	parent.add_child(inst)
	inst._build_ui()
	return inst

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 全屏半透明遮罩
	_root = ColorRect.new()
	_root.color = Color(0, 0, 0, 0.72)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 弹窗卡片（居中）
	var card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(480, 0)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.09, 0.14, 0.97)
	card_style.border_width_left   = 2; card_style.border_width_right  = 2
	card_style.border_width_top    = 2; card_style.border_width_bottom = 2
	card_style.border_color = Color(0.4, 0.6, 0.9, 0.5)
	card_style.corner_radius_top_left    = 16; card_style.corner_radius_top_right    = 16
	card_style.corner_radius_bottom_left = 16; card_style.corner_radius_bottom_right = 16
	card_style.content_margin_left = 24; card_style.content_margin_right  = 24
	card_style.content_margin_top  = 20; card_style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# 标题行
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)
	var title_lbl = Label.new()
	title_lbl.text = "📖 选择复习科目"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_on_close)
	title_row.add_child(close_btn)

	# 最弱科目提示
	var weakest = GameManager.get_weakest_subject()
	var wm = weakest.get("meta", {})
	var hint = Label.new()
	hint.text = "💡 建议优先：%s %s（当前 %d 分）" % [wm.get("emoji","📚"), wm.get("label",""), weakest.get("score",0)]
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 0.9))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	# 五科行
	var weakest_id = weakest.get("id", "")
	for subj in SUBJECT_LIST:
		var meta = GameManager.SUBJECT_META.get(subj, {})
		var cur  = GameManager.subject_scores.get(subj, 0)
		vbox.add_child(_build_subject_row(subj, meta, cur, subj == weakest_id))

	# 底部说明
	var foot = Label.new()
	foot.text = "选择后消耗当前时段，加分受智力属性影响"
	foot.add_theme_font_size_override("font_size", 11)
	foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(foot)

	# 入场动画
	card.modulate.a = 0.0
	card.position.y += 20.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_property(card, "position:y", card.position.y - 20.0, 0.25).set_trans(Tween.TRANS_BACK)

func _build_subject_row(subj: String, meta: Dictionary, cur_score: int, is_weakest: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# ── 奥赛专属 UI 缀名标记 (DS-RN-05c) ──
	var tag = ""
	if subj == "math":
		if GameManager.flags.has("flag_olympiad_gold"):
			tag = " 🏅保送金牌"
		elif GameManager.flags.has("flag_olympiad_dropped"):
			tag = " (已退赛)"
		elif GameManager.flags.has("flag_olympiad_joined"):
			tag = " 🏆奥赛集训区"

	# 名称标签
	var name_lbl = Label.new()
	name_lbl.text = "%s %s%s" % [meta.get("emoji","📚"), meta.get("label", subj), tag]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.custom_minimum_size = Vector2(90, 0)
	name_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.3) if is_weakest else Color(0.88, 0.88, 0.95))
	row.add_child(name_lbl)

	# 进度条
	var bar = ProgressBar.new()
	bar.min_value = 0; bar.max_value = 100; bar.value = cur_score
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 22)
	bar.show_percentage = false
	var bg_s = StyleBoxFlat.new()
	bg_s.bg_color = Color(0.15, 0.15, 0.2)
	bg_s.corner_radius_top_left    = 4; bg_s.corner_radius_top_right    = 4
	bg_s.corner_radius_bottom_left = 4; bg_s.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg_s)
	var fill_s = bg_s.duplicate()
	fill_s.bg_color = Color(1.0, 0.75, 0.2) if is_weakest else Color(0.35, 0.65, 0.9)
	bar.add_theme_stylebox_override("fill", fill_s)
	row.add_child(bar)

	# 分数标签
	var score_lbl = Label.new()
	score_lbl.text = "%d/100" % cur_score
	score_lbl.add_theme_font_size_override("font_size", 13)
	score_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	score_lbl.custom_minimum_size = Vector2(56, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score_lbl)

	# 复习按钮
	var btn = Button.new()
	btn.text = "⭐ 推荐" if is_weakest else "复习"
	btn.custom_minimum_size = Vector2(72, 0)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 13)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.88, 0.62, 0.12, 0.85) if is_weakest else Color(0.22, 0.42, 0.72, 0.75)
	bs.corner_radius_top_left    = 8; bs.corner_radius_top_right    = 8
	bs.corner_radius_bottom_left = 8; bs.corner_radius_bottom_right = 8
	bs.content_margin_left = 8; bs.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", bs)
	var bsh = bs.duplicate(); bsh.bg_color = bs.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", bsh)
	btn.pressed.connect(func(): _on_study_chosen(subj))
	row.add_child(btn)

	return row

func _on_study_chosen(subj: String) -> void:
	if _chosen: return
	_chosen = true
	# 加分（基础随机 + 智力加成）
	var intel   = GameManager.stats.get("intellect", 0)
	var int_bon = int(intel * 0.08)
	var gain    = randi_range(BASE_GAIN_MIN, BASE_GAIN_MAX) + int_bon
	GameManager.add_subject_score(subj, gain)
	# 推进时段（复习消耗一个时段）
	GameManager.advance_time()
	_on_close()

func _on_close() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		closed.emit()
		queue_free()
	)
