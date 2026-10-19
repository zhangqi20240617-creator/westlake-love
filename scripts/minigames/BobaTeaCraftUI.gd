# scripts/minigames/BobaTeaCraftUI.gd
class_name BobaTeaCraftUI
extends MiniGameBase

## ══════════════════════════════════════════════════════════════════
## BobaTeaCraftUI.gd — 校外饮品店·甜蜜奶茶调饮小游戏
## 机制核心：
## 1. 经典饮品配比制作（Recipe Crafting）：
##    - 顾客/同伴提出点单喜好（茶底 -> 甜度 -> 冰量 -> 招牌小料）
##    - 玩家在规定步骤内快速点击原料注入调饮杯
## 2. 疯狂雪克摇晃（Shake & Seal QTE）：
##    - 配比完成后，快速连击【摇晃雪克杯】完成乳化与封口
## 3. 属性深度联动：
##    - intellect (智力): 点单配方视觉高亮，降低配错率
##    - strength (体魄): 摇晃雪克杯效率飞升，手速充能翻倍
##    - 经济闭环: 兼职打工不仅赚取丰厚零花钱 (25~45元/杯)，还能增进同伴情谊！
## ══════════════════════════════════════════════════════════════════

enum State { ORDERING, MIXING, SHAKING, SERVING, SUMMARY }
var current_state: State = State.ORDERING

# ── 原料字典库 ─────────────────────────────────────────────────
const TEAS = ["锡兰红茶", "茉莉绿茶", "四季乌龙"]
const SUGARS = ["微糖(30%)", "半糖(50%)", "全糖(100%)"]
const ICES = ["少冰", "多冰", "去冰"]
const TOPPINGS = ["黑糖波霸", "爽滑布丁", "脆爽椰果"]

# ── 当前订单与步骤 ─────────────────────────────────────────────
var current_order := {}
var player_recipe := {}
var shake_progress: float = 0.0
var step_index: int = 0          # 0:选茶, 1:选糖, 2:选冰, 3:选小料

# ── UI 控件节点 ────────────────────────────────────────────────
var craft_panel: PanelContainer
var kitchen_view: Control
var order_ticket: PanelContainer
var order_lbl: Label
var cup_display: PanelContainer
var cup_contents_lbl: Label
var shake_bar: ProgressBar

var ingredients_vbox: VBoxContainer
var action_btn: Button
var status_lbl: Label
var perk_lbl: Label

func setup_game() -> void:
	game_id = "boba_craft"
	game_title = "兼职甜品店 · 甜蜜奶茶调饮"
	_title_lbl.text = "🧋 " + game_title

	_build_craft_ui()
	init_companion_dock(_content_root)

	_generate_companion_order()
	_update_hud_display()

func _generate_companion_order() -> void:
	# 根据同伴性格生成独特的喜好配方
	match companion_id:
		"jingjing":
			current_order = {"tea": "锡兰红茶", "sugar": "半糖(50%)", "ice": "多冰", "topping": "爽滑布丁"}
		"yutong":
			current_order = {"tea": "四季乌龙", "sugar": "微糖(30%)", "ice": "去冰", "topping": "黑糖波霸"}
		"wanqing":
			current_order = {"tea": "茉莉绿茶", "sugar": "微糖(30%)", "ice": "少冰", "topping": "脆爽椰果"}
		"xiaoxia":
			current_order = {"tea": "锡兰红茶", "sugar": "全糖(100%)", "ice": "多冰", "topping": "黑糖波霸"}
		_:
			current_order = {
				"tea": TEAS.pick_random(),
				"sugar": SUGARS.pick_random(),
				"ice": ICES.pick_random(),
				"topping": TOPPINGS.pick_random()
			}

	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")
	order_lbl.text = "【%s的点单】:\n茶底: %s\n甜度: %s | 冰量: %s\n小料: %s" % [
		c_name, current_order["tea"], current_order["sugar"], current_order["ice"], current_order["topping"]
	]
	say_companion_dialogue("“今天想喝一杯特调奶茶！我的要求都写在小票上了，看你手艺啦~”", "default")
	_show_step_buttons(0)

# ── 搭建制作台 UI ─────────────────────────────────────────────
func _build_craft_ui() -> void:
	craft_panel = PanelContainer.new()
	craft_panel.custom_minimum_size = Vector2(560, 0)
	craft_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var c_style = ThemeUtils.create_style(
		Color(0.12, 0.13, 0.2, 0.96), 16,
		Color(0.95, 0.65, 0.35, 0.7), 2,
		-1, 14, 14, 10, 10
	)
	craft_panel.add_theme_stylebox_override("panel", c_style)
	_content_root.add_child(craft_panel)

	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 8)
	craft_panel.add_child(v_box)

	# 1. 顶部天赋
	perk_lbl = Label.new()
	var intellect = GameManager.stats.get("intellect", 10)
	var strength = GameManager.stats.get("strength", 10)
	perk_lbl.text = " [调饮天赋] 🧠智力记忆准确 · 💪体魄摇晃提速+%.0f%%" % clamp(strength * 0.3, 0, 30)
	perk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk_lbl.add_theme_font_size_override("font_size", 11)
	perk_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	v_box.add_child(perk_lbl)

	# 2. 制作吧台展区
	kitchen_view = Control.new()
	kitchen_view.custom_minimum_size = Vector2(0, 300)
	kitchen_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kitchen_view.clip_contents = true

	var bar_bg = ColorRect.new()
	bar_bg.set_anchors_preset(PRESET_FULL_RECT)
	bar_bg.color = Color(0.14, 0.16, 0.22, 0.95)
	kitchen_view.add_child(bar_bg)

	# 左侧点单小票 (Order Ticket)
	order_ticket = PanelContainer.new()
	order_ticket.position = Vector2(25, 20)
	order_ticket.custom_minimum_size = Vector2(220, 120)
	var ticket_style = ThemeUtils.create_style(Color(0.96, 0.95, 0.9, 0.95), 8, Color(0.8, 0.5, 0.3), 2, -1, 10, 10, 8, 8)
	order_ticket.add_theme_stylebox_override("panel", ticket_style)
	kitchen_view.add_child(order_ticket)

	order_lbl = Label.new()
	order_lbl.add_theme_font_size_override("font_size", 13)
	order_lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	order_ticket.add_child(order_lbl)

	# 中间雪克杯制作展示
	cup_display = PanelContainer.new()
	cup_display.position = Vector2(280, 20)
	cup_display.custom_minimum_size = Vector2(230, 120)
	var cup_style = ThemeUtils.create_style(Color(0.2, 0.25, 0.35, 0.9), 8, Color(0.4, 0.7, 0.9), 2, -1, 10, 10, 8, 8)
	cup_display.add_theme_stylebox_override("panel", cup_style)
	kitchen_view.add_child(cup_display)

	cup_contents_lbl = Label.new()
	cup_contents_lbl.text = "【当前配方】:\n杯中尚空，请选择原料注入……"
	cup_contents_lbl.add_theme_font_size_override("font_size", 13)
	cup_contents_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	cup_display.add_child(cup_contents_lbl)

	# 下方原料选择与摇晃容器
	ingredients_vbox = VBoxContainer.new()
	ingredients_vbox.position = Vector2(25, 160)
	ingredients_vbox.size = Vector2(490, 130)
	ingredients_vbox.add_theme_constant_override("separation", 6)
	kitchen_view.add_child(ingredients_vbox)

	v_box.add_child(kitchen_view)

	# 3. 底部状态与操作
	var ctrl_panel = PanelContainer.new()
	var ctrl_style = ThemeUtils.create_style(Color(0.08, 0.10, 0.16, 0.95), 10, Color(0.3, 0.35, 0.5), 1)
	ctrl_panel.add_theme_stylebox_override("panel", ctrl_style)
	v_box.add_child(ctrl_panel)

	var ctrl_vbox = VBoxContainer.new()
	ctrl_vbox.add_theme_constant_override("separation", 6)
	ctrl_panel.add_child(ctrl_vbox)

	var hud_row = HBoxContainer.new()
	var s_title = Label.new()
	s_title.text = "🌪️ 摇晃乳化度 (Shake):"
	s_title.add_theme_font_size_override("font_size", 12)
	s_title.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	hud_row.add_child(s_title)

	shake_bar = ProgressBar.new()
	shake_bar.custom_minimum_size = Vector2(180, 14)
	shake_bar.max_value = 100
	shake_bar.show_percentage = true
	var sb_style = ThemeUtils.create_style(Color(0.95, 0.5, 0.2), 3)
	shake_bar.add_theme_stylebox_override("fill", sb_style)
	hud_row.add_child(shake_bar)
	ctrl_vbox.add_child(hud_row)

	status_lbl = Label.new()
	status_lbl.text = "按照小票点单要求，第一步：选择合适的茶底！"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	ctrl_vbox.add_child(status_lbl)

# ── 步骤流转与按钮生成 ────────────────────────────────────────
func _show_step_buttons(step: int) -> void:
	step_index = step
	for child in ingredients_vbox.get_children():
		child.queue_free()

	var options := []
	var step_title := ""

	match step:
		0:
			step_title = "第一步：选择萃取茶底"
			options = TEAS
		1:
			step_title = "第二步：选择甜度配比"
			options = SUGARS
		2:
			step_title = "第三步：选择冰量温度"
			options = ICES
		3:
			step_title = "第四步：添加灵魂小料"
			options = TOPPINGS

	var title_lbl = Label.new()
	title_lbl.text = "👉 " + step_title
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	ingredients_vbox.add_child(title_lbl)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	for opt in options:
		var btn = Button.new()
		btn.text = opt
		btn.custom_minimum_size = Vector2(140, 36)
		ThemeUtils.style_accent_btn(btn, Color(0.3, 0.45, 0.7), 6, 1)
		btn.pressed.connect(func():
			_select_ingredient(step, opt)
		)
		hbox.add_child(btn)
	ingredients_vbox.add_child(hbox)

func _select_ingredient(step: int, val: String) -> void:
	match step:
		0: player_recipe["tea"] = val
		1: player_recipe["sugar"] = val
		2: player_recipe["ice"] = val
		3: player_recipe["topping"] = val

	cup_contents_lbl.text = "【当前配方】:\n茶底: %s\n甜度: %s | 冰量: %s\n小料: %s" % [
		player_recipe.get("tea", "-"),
		player_recipe.get("sugar", "-"),
		player_recipe.get("ice", "-"),
		player_recipe.get("topping", "-")
	]

	if step < 3:
		_show_step_buttons(step + 1)
	else:
		_enter_shaking_phase()

# ── 摇晃雪克杯阶段 ────────────────────────────────────────────
func _enter_shaking_phase() -> void:
	current_state = State.SHAKING
	for child in ingredients_vbox.get_children():
		child.queue_free()

	status_lbl.text = "配方已就位！疯狂连续点击【🌪️ 摇晃雪克杯】完成乳化出杯！"
	status_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))

	action_btn = Button.new()
	action_btn.text = "🌪️ 摇晃雪克杯 SHAKE!"
	action_btn.custom_minimum_size = Vector2(0, 44)
	ThemeUtils.style_accent_btn(action_btn, Color(0.95, 0.45, 0.2), 8, 2)
	action_btn.pressed.connect(_on_shake_clicked)
	ingredients_vbox.add_child(action_btn)

func _on_shake_clicked() -> void:
	if current_state != State.SHAKING:
		return

	# 体魄加速摇晃
	var strength = GameManager.stats.get("strength", 10)
	var boost = 18.0 + (strength * 0.3)
	shake_progress = min(100.0, shake_progress + boost)
	shake_bar.value = shake_progress

	# 晃动动画
	var tw = create_tween()
	cup_display.position.x += 6
	tw.tween_property(cup_display, "position:x", cup_display.position.x - 6, 0.08)

	if shake_progress >= 100.0:
		_serve_drink()

# ── 出杯封口与品尝 ────────────────────────────────────────────
func _serve_drink() -> void:
	current_state = State.SERVING
	action_btn.disabled = true

	# 判定配比准确度
	var is_tea_ok = (player_recipe["tea"] == current_order["tea"])
	var is_sugar_ok = (player_recipe["sugar"] == current_order["sugar"])
	var is_ice_ok = (player_recipe["ice"] == current_order["ice"])
	var is_topping_ok = (player_recipe["topping"] == current_order["topping"])

	var correct_count = (1 if is_tea_ok else 0) + (1 if is_sugar_ok else 0) + (1 if is_ice_ok else 0) + (1 if is_topping_ok else 0)

	var meta = GameManager.char_meta.get(companion_id, {})
	var c_name = meta.get("name", "同伴")

	if correct_count == 4:
		# 完美制作
		status_lbl.text = "🌟 PERFECT CRAFT！特调绝配！完美满足顾客口味！"
		status_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.4))

		GameManager.add_stat("money", 45) # 兼职高薪
		GameManager.add_favor(companion_id, 12)
		GameManager.add_stat("stress", -18)

		say_companion_dialogue("“哇！第一口喝下去太幸福了，甜度和冰量完全是我最喜欢的！好棒的调饮师！”", "shy")
		GameManager.show_toast.emit("🧋 奶茶调制完美！兼职薪水 +45元，%s 好感 +12！" % c_name)
	elif correct_count >= 2:
		status_lbl.text = "👍 NICE DRINK！味道很不错，基本符合要求！"
		status_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))

		GameManager.add_stat("money", 30)
		GameManager.add_favor(companion_id, 7)
		GameManager.add_stat("stress", -10)

		say_companion_dialogue("“好喝！虽然有点小出入，但这个味道我也挺喜欢的呢~”", "happy")
		GameManager.show_toast.emit("🧋 奶茶出品成功！兼职薪水 +30元，%s 好感 +7！" % c_name)
	else:
		status_lbl.text = "⚠️ 配料弄混了……糖度和茶底搞错了！"
		status_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4))

		GameManager.add_stat("money", 15)
		# 意外成就：这杯奶茶能防身
		GameManager.flags["achv_boba_explosive"] = true
		say_companion_dialogue("“噗……咳咳，好像太甜了一点，不过心意我领啦！”", "default")
		GameManager.show_toast.emit("兼职出品失误，仅获基础工钱 15元。")

	if correct_count >= 2:
		GameManager.flags["achv_boba_crafted"] = true
	if correct_count == 4:
		GameManager.flags["achv_boba_perfect"] = true
		GameManager.flags["achv_boba_3star_all"] = true
	if is_instance_valid(AchievementManager):
		AchievementManager.check_all()

	_reset_kitchen_action()

func _reset_kitchen_action() -> void:
	action_btn.disabled = false
	action_btn.text = "🔄 再做一杯 (NEXT ORDER)"
	action_btn.pressed.disconnect(_on_shake_clicked)
	action_btn.pressed.connect(func():
		shake_progress = 0.0
		shake_bar.value = 0
		player_recipe = {}
		current_state = State.ORDERING
		_generate_companion_order()
	)

func execute_skip() -> void:
	GameManager.add_stat("money", 35)
	GameManager.add_favor(companion_id, 8)
	GameManager.add_stat("stress", -12)
	GameManager.show_toast.emit("快速调制优质奶茶！获得兼职薪水 35元！")
	say_companion_dialogue("“特调奶茶好好喝！辛苦啦~”", "happy")
