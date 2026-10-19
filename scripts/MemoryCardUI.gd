extends Control
class_name MemoryCardUI

## ══════════════════════════════════════════════════════════
## MemoryCardUI.gd  — 料理翻牌小游戏
## 嵌入 CookingUI._do_cook() 之前触发。
## 机制：n 对牌（n = 菜谱难度×2，最多6对），先展示1.5秒，翻背后配对。
## 结果 → 回调给 CookingUI 决定烹饪品质奖励。
##
## 使用方式：
##   var card_ui = MemoryCardUI.new()
##   card_ui.start_game(pair_count, emoji_list, cb)
##   parent.add_child(card_ui)
## 回调签名：cb.call(miss_count: int)
##   miss_count == 0    → 完美（bonus_dish 奖励）
##   miss_count <= 3    → 普通成功
##   miss_count >  3    → 烹饪失败（食材部分退还）
## ══════════════════════════════════════════════════════════

signal game_finished(miss_count: int)

const CARD_SIZE  := Vector2(90, 90)
const CARD_GAP   := 12
const PREVIEW_TIME := 1.5   # 开局展示时间（秒）
const FLIP_ANIM  := 0.25    # 翻牌动画时长（秒）

var _pair_count: int = 3
var _emoji_list: Array = []   # 牌图案（emoji字符串）
var _on_finish_cb: Callable

# ── 牌数据 ───────────────────────────────────────────────
# 每张牌：{index, value, matched, face_up, btn}
var _cards: Array = []
var _flipped: Array = []   # 当前翻开的两张（最多2）
var _miss_count: int = 0
var _matched_pairs: int = 0
var _lock: bool = false    # 动画期间锁操作

# ── UI 节点 ───────────────────────────────────────────────
var _bg: ColorRect
var _panel: Panel
var _title_lbl: Label
var _status_lbl: Label
var _grid: GridContainer

func _ready():
	z_index = 120
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_bg = ColorRect.new()
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 0.80)
	add_child(_bg)

	_panel = Panel.new()
	_panel.set_anchors_preset(PRESET_CENTER)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.09, 0.12, 0.20, 0.97)
	ps.corner_radius_top_left    = 20
	ps.corner_radius_top_right   = 20
	ps.corner_radius_bottom_left = 20
	ps.corner_radius_bottom_right = 20
	ps.border_width_left   = 2
	ps.border_width_right  = 2
	ps.border_width_top    = 2
	ps.border_width_bottom = 2
	ps.border_color = Color("f472b6")
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(side, 30)
	_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.text = "🃏 记住食材的摆放位置！"
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", Color("f472b6"))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_lbl)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 16)
	_status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_lbl)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	vbox.add_child(_grid)

# ══════════════════════════════════════════════════════════
# 公共入口
# ══════════════════════════════════════════════════════════
func start_game(pair_count: int, emoji_list: Array, cb: Callable) -> void:
	_pair_count  = clampi(pair_count, 2, 6)
	_emoji_list  = emoji_list
	_on_finish_cb = cb
	_miss_count  = 0
	_matched_pairs = 0
	_lock = false
	_flipped.clear()
	_cards.clear()

	# 自动调节面板尺寸
	var cols = 4 if _pair_count <= 4 else 6
	_grid.columns = cols
	var total_cards = _pair_count * 2
	var rows = ceili(float(total_cards) / cols)
	var pw = cols  * (CARD_SIZE.x + CARD_GAP) + 60
	var ph = rows  * (CARD_SIZE.y + CARD_GAP) + 160
	_panel.custom_minimum_size = Vector2(max(pw, 400), max(ph, 360))

	_build_grid()
	_status_lbl.text = "记住位置……（%.0f 秒后盖牌）" % PREVIEW_TIME
	show()

	# 预览阶段：所有牌正面朝上
	for card in _cards:
		card["face_up"] = true
		_update_card_face(card)

	await get_tree().create_timer(PREVIEW_TIME).timeout
	# 盖牌
	for card in _cards:
		card["face_up"] = false
		_update_card_face(card)
	_status_lbl.text = "翻开配对！失误 0 次"

func _build_grid():
	for c in _grid.get_children(): c.queue_free()
	_cards.clear()

	# 生成图案列表：每种图案×2
	var default_emojis = ["🍅","🥕","🥦","🌽","🍄","🧅","🥚","🍋","🫐","🍉","🌶️","🧄"]
	var emojis = _emoji_list if _emoji_list.size() >= _pair_count else default_emojis

	var values: Array = []
	for i in _pair_count:
		values.append(emojis[i % emojis.size()])
		values.append(emojis[i % emojis.size()])
	values.shuffle()

	for i in values.size():
		var card_data = {
			"index": i, "value": values[i],
			"matched": false, "face_up": false,
			"btn": null
		}

		var btn = Button.new()
		btn.custom_minimum_size = CARD_SIZE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# 背面样式
		_apply_card_style(btn, false, false, false)
		btn.pressed.connect(_on_card_clicked.bind(i))

		card_data["btn"] = btn
		_cards.append(card_data)
		_grid.add_child(btn)

func _apply_card_style(btn: Button, face_up: bool, matched: bool, hover: bool):
	var s = StyleBoxFlat.new()
	s.corner_radius_top_left    = 10
	s.corner_radius_top_right   = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	if matched:
		s.bg_color = Color(0.15, 0.55, 0.25)
		s.border_color = Color("86efac")
	elif face_up:
		s.bg_color = Color(0.20, 0.28, 0.48) if not hover else Color(0.28, 0.38, 0.60)
		s.border_color = Color("60a5fa")
	else:
		s.bg_color = Color(0.25, 0.18, 0.38) if not hover else Color(0.32, 0.24, 0.48)
		s.border_color = Color("a78bfa")
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal",   s)
	btn.add_theme_stylebox_override("disabled", s.duplicate())
	var hs = s.duplicate(); hs.bg_color = s.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hs)

func _update_card_face(card: Dictionary):
	var btn: Button = card["btn"]
	if not is_instance_valid(btn): return
	if card["matched"]:
		btn.text = card["value"]
		btn.add_theme_font_size_override("font_size", 36)
		btn.disabled = true
		_apply_card_style(btn, true, true, false)
	elif card["face_up"]:
		btn.text = card["value"]
		btn.add_theme_font_size_override("font_size", 36)
		btn.disabled = false
		_apply_card_style(btn, true, false, false)
	else:
		btn.text = "?"
		btn.add_theme_font_size_override("font_size", 28)
		btn.disabled = false
		_apply_card_style(btn, false, false, false)

# ── 牌点击处理 ────────────────────────────────────────────
func _on_card_clicked(idx: int):
	if _lock: return
	var card = _cards[idx]
	if card["matched"] or card["face_up"]: return
	if _flipped.size() >= 2: return

	# 翻开
	card["face_up"] = true
	_update_card_face(card)
	_flipped.append(idx)

	if _flipped.size() == 2:
		_lock = true
		await get_tree().create_timer(0.6).timeout
		_check_pair()

func _check_pair():
	var i0 = _flipped[0]
	var i1 = _flipped[1]
	_flipped.clear()

	var c0 = _cards[i0]
	var c1 = _cards[i1]

	if c0["value"] == c1["value"]:
		# 配对成功
		c0["matched"] = true
		c1["matched"] = true
		_update_card_face(c0)
		_update_card_face(c1)
		_matched_pairs += 1
		GameManager.show_toast.emit("✅ 配对！%s" % c0["value"])
		_status_lbl.text = "失误 %d 次 · 已配对 %d/%d" % [_miss_count, _matched_pairs, _pair_count]

		if _matched_pairs >= _pair_count:
			await get_tree().create_timer(0.5).timeout
			_finish()
			return
	else:
		# 配对失败：短暂显示后盖回
		_miss_count += 1
		_status_lbl.text = "失误 %d 次 · 已配对 %d/%d" % [_miss_count, _matched_pairs, _pair_count]
		await get_tree().create_timer(0.7).timeout
		c0["face_up"] = false
		c1["face_up"] = false
		_update_card_face(c0)
		_update_card_face(c1)

	_lock = false

func _finish():
	_lock = true
	var result_text: String
	if _miss_count == 0:
		result_text = "🏆 完美！食材摆放零失误，料理品质大幅提升！"
	elif _miss_count <= 3:
		result_text = "😊 不错！失误 %d 次，料理正常完成。" % _miss_count
	else:
		result_text = "😅 失误 %d 次，部分食材浪费了……" % _miss_count

	_status_lbl.text = result_text
	_status_lbl.add_theme_color_override("font_color",
		Color("fbbf24") if _miss_count == 0 else Color("86efac") if _miss_count <= 3 else Color("f87171"))

	await get_tree().create_timer(1.8).timeout
	hide()
	queue_free()
	game_finished.emit(_miss_count)
	if _on_finish_cb.is_valid():
		_on_finish_cb.call(_miss_count)
