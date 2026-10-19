extends Panel
# CookingUI.gd — 杭州美食烹饪界面（三标签：市场/菜谱/收集簿）

signal closed

var tab_index: int = 0  # 0=市场 1=菜谱 2=收集簿
var content_area: ScrollContainer
var content_vbox: VBoxContainer
var tab_btns: Array = []
var wallet_lbl: Label
var stats_lbl: Label
var _start_tab: int = 0

func _ready():
	anchor_left = 0.0; anchor_top = 0.0
	anchor_right = 1.0; anchor_bottom = 1.0
	offset_left = 0; offset_top = 0; offset_right = 0; offset_bottom = 0
	var barrier = ThemeUtils.create_style(Color(0, 0, 0, 0.65), 0)
	add_theme_stylebox_override("panel", barrier)

	var main = PanelContainer.new()
	main.custom_minimum_size = Vector2(760, 560)
	var ms = ThemeUtils.make_card_style(Color("#1a1a2e"), Color("#f472b6"), 16)
	ms.border_width_left = 2; ms.border_width_right = 2
	ms.border_width_top = 2; ms.border_width_bottom = 2
	main.add_theme_stylebox_override("panel", ms)
	main.anchor_left = 0.5; main.anchor_top = 0.5
	main.anchor_right = 0.5; main.anchor_bottom = 0.5
	main.offset_left = -380; main.offset_top = -280
	main.offset_right = 380; main.offset_bottom = 280
	add_child(main)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	main.add_child(vbox)

	# ── 标题栏 ──
	var hdr = HBoxContainer.new()
	hdr.custom_minimum_size = Vector2(0, 48)
	hdr.add_theme_constant_override("separation", 8)
	vbox.add_child(hdr)
	var sp0 = Control.new(); sp0.custom_minimum_size = Vector2(12, 0); hdr.add_child(sp0)
	var title = Label.new()
	title.text = "🍳 杭州美食坊"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f472b6"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_child(title)
	wallet_lbl = Label.new()
	wallet_lbl.add_theme_font_size_override("font_size", 18)
	wallet_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	wallet_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_child(wallet_lbl)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(44, 36)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_btn(close_btn, Color("#ef4444"), Color("#dc2626"))
	close_btn.pressed.connect(func(): closed.emit(); queue_free())
	hdr.add_child(close_btn)
	var sp1 = Control.new(); sp1.custom_minimum_size = Vector2(8, 0); hdr.add_child(sp1)

	# ── Tab 栏 ──
	var tab_bar = HBoxContainer.new()
	tab_bar.custom_minimum_size = Vector2(0, 44)
	tab_bar.add_theme_constant_override("separation", 6)
	vbox.add_child(tab_bar)
	var sp2 = Control.new(); sp2.custom_minimum_size = Vector2(8, 0); tab_bar.add_child(sp2)
	var tab_labels = ["🛒 食材市场", "📖 菜谱", "📦 收集簿"]
	for i in 3:
		var tb = Button.new()
		tb.text = tab_labels[i]
		tb.custom_minimum_size = Vector2(150, 40)
		tb.add_theme_font_size_override("font_size", 16)
		tb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab_btns.append(tb)
		var idx = i
		tb.pressed.connect(func(): _switch_tab(idx))
		tab_bar.add_child(tb)
	_refresh_tab_styles()

	# ── 内容区 ──
	content_area = ScrollContainer.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(content_area)
	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 10)
	content_area.add_child(content_vbox)

	# ── 底部状态栏 ──
	var footer = Panel.new()
	footer.custom_minimum_size = Vector2(0, 40)
	var fs = ThemeUtils.create_style(Color("#0f0f1e"), 14)
	footer.add_theme_stylebox_override("panel", fs)
	vbox.add_child(footer)
	stats_lbl = Label.new()
	stats_lbl.anchors_preset = Control.PRESET_FULL_RECT
	stats_lbl.offset_left = 14
	stats_lbl.add_theme_font_size_override("font_size", 15)
	stats_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	stats_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(stats_lbl)

	_start_tab = get_meta("start_tab", 0) if has_meta("start_tab") else 0
	_switch_tab(_start_tab)

func _switch_tab(idx: int):
	tab_index = idx
	_refresh_tab_styles()
	_rebuild_content()

func _refresh_tab_styles():
	for i in tab_btns.size():
		var active = i == tab_index
		_style_btn(tab_btns[i],
			Color("#f472b6") if active else Color("#334155"),
			Color("#db2777") if active else Color("#475569"))

func _rebuild_content():
	for c in content_vbox.get_children(): c.queue_free()
	wallet_lbl.text = "💰 %d  " % GameManager.money
	var s = CookingManager.get_collection_stats()
	stats_lbl.text = "%s %s · 经验 %d · 菜谱 %d/%d · 特产 %d/%d" % [
		s["cook_level_emoji"], s["cook_level"], s["cooking_exp"],
		s["recipes_unlocked"], s["recipes_total"],
		s["specialties_collected"], s["specialties_total"]
	]
	match tab_index:
		0: _build_market()
		1: _build_recipes()
		2: _build_collection()

# ══════════════════════════════════════════
# 标签 0：食材市场
# ══════════════════════════════════════════
func _build_market():
	var pad = _make_padded_vbox()
	var season = GameManager.get_season()

	# 按分类分组
	var categories: Dictionary = {}
	for item_id in CookingManager.SPECIALTY_DB.keys():
		var item = CookingManager.SPECIALTY_DB[item_id]
		var cat = item.get("category", "其他")
		if not categories.has(cat): categories[cat] = []
		categories[cat].append({"id": item_id, "data": item})

	for cat in categories.keys():
		var cat_lbl = Label.new()
		cat_lbl.text = "  ── %s ──" % cat
		cat_lbl.add_theme_font_size_override("font_size", 16)
		cat_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		pad.add_child(cat_lbl)

		for entry in categories[cat]:
			var item_id = entry["id"]
			var item    = entry["data"]
			var avail   = item.get("season", "all") == "all" or item.get("season") == season
			var owned   = CookingManager.collected_specialties.get(item_id, 0)

			var row = _make_card(Color("#1e293b") if avail else Color("#1a1a1a"), avail)
			var hb  = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			row.add_child(hb)

			var icon_lbl = Label.new()
			icon_lbl.text = item["icon"]
			icon_lbl.add_theme_font_size_override("font_size", 26)
			hb.add_child(icon_lbl)

			var tv = VBoxContainer.new()
			tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tv.add_theme_constant_override("separation", 2)
			hb.add_child(tv)

			var nl = Label.new()
			nl.text = item["name"] + ("  [季节限定]" if item.get("season","all") != "all" else "")
			nl.add_theme_font_size_override("font_size", 18)
			nl.add_theme_color_override("font_color", Color("#f8fafc") if avail else Color(1,1,1,0.3))
			tv.add_child(nl)

			var dl = Label.new()
			dl.text = item["desc"]
			dl.add_theme_font_size_override("font_size", 15)
			dl.add_theme_color_override("font_color", Color(1,1,1,0.5))
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tv.add_child(dl)

			var ol = Label.new()
			ol.text = "库存: %d" % owned
			ol.add_theme_font_size_override("font_size", 15)
			ol.add_theme_color_override("font_color", Color("#86efac") if owned > 0 else Color(1,1,1,0.3))
			ol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hb.add_child(ol)

			var pl = Label.new()
			pl.text = "💰%d" % item["price"]
			pl.add_theme_font_size_override("font_size", 16)
			pl.add_theme_color_override("font_color", Color("#fde047"))
			pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hb.add_child(pl)

			var buy = Button.new()
			buy.text = "购买" if avail else "缺货"
			buy.disabled = not avail or GameManager.money < item["price"]
			buy.custom_minimum_size = Vector2(70, 36)
			buy.add_theme_font_size_override("font_size", 14)
			buy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_style_btn(buy, Color("#0ea5e9"), Color("#0284c7"))
			var iid = item_id
			buy.pressed.connect(func():
				if CookingManager.buy_ingredient(iid): _rebuild_content()
			)
			hb.add_child(buy)
			pad.add_child(row)

# ══════════════════════════════════════════
# 标签 1：菜谱
# ══════════════════════════════════════════
func _build_recipes():
	var pad = _make_padded_vbox()

	for recipe_id in CookingManager.RECIPE_DB.keys():
		var recipe   = CookingManager.RECIPE_DB[recipe_id]
		var unlocked = recipe_id in CookingManager.unlocked_recipes
		var cooked   = CookingManager.cooked_dishes.get(recipe_id, {})
		var cookable = CookingManager.can_cook(recipe_id)
		var missing  = CookingManager.get_missing_ingredients(recipe_id)
		var diff_str = ["★☆☆", "★★☆", "★★★"][recipe.get("difficulty", 1) - 1]

		var card_col = Color("#16213e") if unlocked else Color("#111111")
		var card = _make_card(card_col, unlocked)
		var cv = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)

		# 菜谱标题行
		var title_row = HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		cv.add_child(title_row)

		var icon_l = Label.new()
		icon_l.text = recipe["icon"] if unlocked else "🔒"
		icon_l.add_theme_font_size_override("font_size", 28)
		title_row.add_child(icon_l)

		var tv2 = VBoxContainer.new()
		tv2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv2.add_theme_constant_override("separation", 2)
		title_row.add_child(tv2)

		var name_l = Label.new()
		name_l.text = (recipe["name"] if unlocked else "???  待解锁") + "  " + diff_str
		name_l.add_theme_font_size_override("font_size", 19)
		name_l.add_theme_color_override("font_color", Color("#f472b6") if unlocked else Color(1,1,1,0.3))
		tv2.add_child(name_l)

		if unlocked:
			var desc_l = Label.new()
			desc_l.text = recipe["desc"]
			desc_l.add_theme_font_size_override("font_size", 15)
			desc_l.add_theme_color_override("font_color", Color(1,1,1,0.55))
			desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tv2.add_child(desc_l)

		# 食材需求行
		if unlocked:
			var ing_row = HBoxContainer.new()
			ing_row.add_theme_constant_override("separation", 6)
			cv.add_child(ing_row)
			var ing_lbl = Label.new()
			ing_lbl.text = "食材："
			ing_lbl.add_theme_font_size_override("font_size", 15)
			ing_lbl.add_theme_color_override("font_color", Color(1,1,1,0.4))
			ing_row.add_child(ing_lbl)
			for ing_id in recipe["ingredients"].keys():
				var ing_data = CookingManager.SPECIALTY_DB.get(ing_id, {})
				var have = CookingManager.collected_specialties.get(ing_id, 0)
				var need = recipe["ingredients"][ing_id]
				var il2  = Label.new()
				il2.text = "%s %s(%d/%d)" % [ing_data.get("icon","📦"), ing_data.get("name", ing_id), have, need]
				il2.add_theme_font_size_override("font_size", 15)
				il2.add_theme_color_override("font_color", Color("#86efac") if have >= need else Color("#f87171"))
				ing_row.add_child(il2)

		# 烹饪次数 & 最佳品质
		if unlocked and not cooked.is_empty():
			var hist_l = Label.new()
			hist_l.text = "已烹饪 %d 次 · 最佳: %s" % [cooked.get("count",0), recipe["quality_desc"][cooked.get("best_quality",0)]]
			hist_l.add_theme_font_size_override("font_size", 15)
			hist_l.add_theme_color_override("font_color", Color("#fbbf24"))
			cv.add_child(hist_l)

		# 典故
		if unlocked and recipe.get("lore", "") != "":
			var lore_l = Label.new()
			lore_l.text = "📜 " + recipe["lore"]
			lore_l.add_theme_font_size_override("font_size", 14)
			lore_l.add_theme_color_override("font_color", Color(1,1,1,0.3))
			lore_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(lore_l)

		# 烹饪按钮
		if unlocked:
			var cook_btn = Button.new()
			cook_btn.text = "🍳 开始烹饪" if cookable else ("缺少: " + _missing_text(missing))
			cook_btn.disabled = not cookable
			cook_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			cook_btn.custom_minimum_size = Vector2(0, 40)
			cook_btn.add_theme_font_size_override("font_size", 15)
			_style_btn(cook_btn, Color("#16a34a"), Color("#15803d"))
			var rid = recipe_id
			cook_btn.pressed.connect(func(): _do_cook(rid))
			cv.add_child(cook_btn)

		pad.add_child(card)

func _missing_text(missing: Array) -> String:
	var parts = []
	for m in missing: parts.append(m["name"])
	return "、".join(parts)

func _do_cook(recipe_id: String):
	var result = CookingManager.cook_dish(recipe_id)
	if not result["success"]:
		GameManager.show_toast.emit("❌ " + result.get("reason", "烹饪失败"))
		return
	var q_colors = [Color("#94a3b8"), Color("#86efac"), Color("#fbbf24")]
	var q_icons  = ["😅", "😊", "🤩"]
	GameManager.show_toast.emit("%s %s 品质：%s" % [q_icons[result["quality"]], result["dish_name"], result["quality_text"]])
	_rebuild_content()

# ══════════════════════════════════════════
# 标签 2：收集簿
# ══════════════════════════════════════════
func _build_collection():
	var pad = _make_padded_vbox()
	var s   = CookingManager.get_collection_stats()

	# 厨师等级卡
	var level_card = _make_card(Color("#1e1b4b"), true)
	var lc_vb = VBoxContainer.new(); lc_vb.add_theme_constant_override("separation", 4)
	level_card.add_child(lc_vb)
	var ll = Label.new()
	ll.text = "%s 厨师等级：%s" % [s["cook_level_emoji"], s["cook_level"]]
	ll.add_theme_font_size_override("font_size", 20)
	ll.add_theme_color_override("font_color", Color("#a78bfa"))
	lc_vb.add_child(ll)
	var el = Label.new()
	el.text = "烹饪经验: %d  |  下一级需: %d  |  已烹饪菜品: %d 种" % [s["cooking_exp"], s["next_level_exp"], s["dishes_cooked"]]
	el.add_theme_font_size_override("font_size", 16)
	el.add_theme_color_override("font_color", Color(1,1,1,0.6))
	lc_vb.add_child(el)
	pad.add_child(level_card)

	# 进度条
	var prog_card = _make_card(Color("#0f172a"), true)
	var pc_vb = VBoxContainer.new(); pc_vb.add_theme_constant_override("separation", 6)
	prog_card.add_child(pc_vb)
	_add_progress_row(pc_vb, "🍳 菜谱解锁", s["recipes_unlocked"], s["recipes_total"], Color("#f472b6"))
	_add_progress_row(pc_vb, "📦 特产收集", s["specialties_collected"], s["specialties_total"], Color("#fbbf24"))
	pad.add_child(prog_card)

	# 已烹饪记录
	var cook_lbl = Label.new()
	cook_lbl.text = "  ── 烹饪记录 ──"
	cook_lbl.add_theme_font_size_override("font_size", 16)
	cook_lbl.add_theme_color_override("font_color", Color(1,1,1,0.4))
	pad.add_child(cook_lbl)

	if CookingManager.cooked_dishes.is_empty():
		var nl2 = Label.new()
		nl2.text = "还没有烹饪过任何菜品，去菜谱标签开始吧！"
		nl2.add_theme_font_size_override("font_size", 16)
		nl2.add_theme_color_override("font_color", Color(1,1,1,0.3))
		nl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl2.custom_minimum_size = Vector2(0, 60)
		pad.add_child(nl2)
	else:
		for recipe_id in CookingManager.cooked_dishes.keys():
			var recipe = CookingManager.RECIPE_DB.get(recipe_id, {})
			var cd     = CookingManager.cooked_dishes[recipe_id]
			var bq     = cd.get("best_quality", 0)
			var row    = _make_card(Color("#1e293b"), true)
			var rh     = HBoxContainer.new()
			rh.add_theme_constant_override("separation", 10)
			row.add_child(rh)
			var ri = Label.new(); ri.text = recipe.get("icon","🍽"); ri.add_theme_font_size_override("font_size", 26); rh.add_child(ri)
			var rv = VBoxContainer.new(); rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rh.add_child(rv)
			var rn = Label.new(); rn.text = recipe.get("name","?"); rn.add_theme_font_size_override("font_size", 18); rn.add_theme_color_override("font_color", Color("#f8fafc")); rv.add_child(rn)
			var rb = Label.new(); rb.text = "最佳: %s" % recipe.get("quality_desc",["","",""])[bq]; rb.add_theme_font_size_override("font_size", 15); rb.add_theme_color_override("font_color", Color("#fbbf24")); rv.add_child(rb)
			var rc2 = Label.new(); rc2.text = "共烹饪 %d 次" % cd.get("count",0); rc2.add_theme_font_size_override("font_size", 15); rc2.add_theme_color_override("font_color", Color(1,1,1,0.4)); rc2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; rh.add_child(rc2)
			pad.add_child(row)

# ── 工具函数 ──────────────────────────────────────────────────
func _make_padded_vbox() -> VBoxContainer:
	var pad_c = MarginContainer.new()
	pad_c.add_theme_constant_override("margin_left", 14)
	pad_c.add_theme_constant_override("margin_right", 14)
	pad_c.add_theme_constant_override("margin_top", 10)
	pad_c.add_theme_constant_override("margin_bottom", 10)
	content_vbox.add_child(pad_c)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pad_c.add_child(vb)
	return vb

func _make_card(bg: Color, active: bool) -> PanelContainer:
	var pc = PanelContainer.new()
	var bc = Color(1,1,1,0.08) if not active else Color(1,1,1,0.15)
	var s = ThemeUtils.create_style(bg, 10, bc, 1, -1, 12, 12, 10, 10)
	pc.add_theme_stylebox_override("panel", s)
	return pc

func _style_btn(btn: Button, col: Color, hover: Color):
	var s = ThemeUtils.create_style(col, 8, Color.TRANSPARENT, 0, -1, 10, 10, 4, 4)
	btn.add_theme_stylebox_override("normal", s)
	var h = ThemeUtils.create_style(hover, 8, Color.TRANSPARENT, 0, -1, 10, 10, 4, 4)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	var d = ThemeUtils.create_style(Color(col, 0.3), 8, Color.TRANSPARENT, 0, -1, 10, 10, 4, 4)
	btn.add_theme_stylebox_override("disabled", d)

func _add_progress_row(parent: VBoxContainer, label: String, cur: int, total: int, col: Color):
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); parent.add_child(row)
	var l = Label.new(); l.text = label; l.add_theme_font_size_override("font_size", 16); l.add_theme_color_override("font_color", Color(1,1,1,0.7)); l.custom_minimum_size = Vector2(130,0); row.add_child(l)
	var bar = ProgressBar.new(); bar.value = (float(cur)/float(total)*100) if total>0 else 0; bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.custom_minimum_size = Vector2(0,22); row.add_child(bar)
	var pl2 = Label.new(); pl2.text = "%d/%d" % [cur, total]; pl2.add_theme_font_size_override("font_size", 15); pl2.add_theme_color_override("font_color", col); row.add_child(pl2)
