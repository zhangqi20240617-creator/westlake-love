## WardrobeShopUI.gd
## 限量/当季服装商店
## 展示限量及当季上架物品，含剩余库存、售罄提示

class_name WardrobeShopUI
extends Control

signal closed

static func open(parent: Control) -> WardrobeShopUI:
	var inst = WardrobeShopUI.new()
	parent.add_child(inst)
	inst._build_ui()
	return inst

var _scroll_vbox: VBoxContainer

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# 主卡片
	var card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(640, 680)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.08, 0.07, 0.12, 0.98)
	cs.border_width_left   = 2; cs.border_width_right  = 2
	cs.border_width_top    = 2; cs.border_width_bottom = 2
	cs.border_color = Color(0.70, 0.55, 0.15, 0.7)
	cs.corner_radius_top_left    = 18; cs.corner_radius_top_right    = 18
	cs.corner_radius_bottom_left = 18; cs.corner_radius_bottom_right = 18
	cs.content_margin_left = 24; cs.content_margin_right  = 24
	cs.content_margin_top  = 20; cs.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", cs)
	add_child(card)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	card.add_child(root_vbox)

	# 标题行
	var title_row = HBoxContainer.new()
	root_vbox.add_child(title_row)
	var title_lbl = Label.new()
	title_lbl.text = "🛍️ 西湖时尚集市"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var money_lbl = Label.new()
	money_lbl.text = "💰 %d" % GameManager.money
	money_lbl.add_theme_font_size_override("font_size", 16)
	money_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title_row.add_child(money_lbl)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_on_close)
	title_row.add_child(close_btn)

	# 副标题
	var sub = Label.new()
	sub.text = "今日精选 · 限量款售完即止，购入永久收藏"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.38))
	root_vbox.add_child(sub)

	root_vbox.add_child(HSeparator.new())

	# 商品滚动列表
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.add_theme_constant_override("separation", 12)
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_scroll_vbox)

	_build_shop_list(money_lbl)

	# 入场动画
	card.modulate.a = 0.0
	card.position.y += 20.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_property(card, "position:y", card.position.y - 20.0, 0.25).set_trans(Tween.TRANS_BACK)

func _build_shop_list(money_lbl: Label) -> void:
	for c in _scroll_vbox.get_children(): c.queue_free()

	# 当季过滤：限量款全显示；rare/common只展示当季或all
	var cur_season = GameManager.get_season()
	var shop_ids: Array = []
	for id in WardrobeManager.WARDROBE_DB.keys():
		var item = WardrobeManager.WARDROBE_DB[id]
		var rarity = item.get("rarity", "common")
		var season = item.get("season", "all")
		var price  = item.get("price", 0)
		if price == 0: continue   # 免费默认款不进商店
		# 限量款全年陈列
		if rarity == "limited":
			shop_ids.append(id)
			continue
		# 非限量：当季 or all 才显示
		if season == "all" or season == cur_season:
			shop_ids.append(id)

	if shop_ids.is_empty():
		var hint = Label.new()
		hint.text = "本季暂无上架商品，下个季节再来看看吧~"
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		_scroll_vbox.add_child(hint)
		return

	for id in shop_ids:
		_scroll_vbox.add_child(_build_shop_row(id, money_lbl))

func _build_shop_row(item_id: String, money_lbl: Label) -> PanelContainer:
	var item     = WardrobeManager.WARDROBE_DB[item_id]
	var rarity   = item.get("rarity", "common")
	var r_color  = WardrobeManager.RARITY_COLORS.get(rarity, Color(0.6,0.6,0.6))
	var is_owned = item_id in WardrobeManager.owned_items
	var sold_out = WardrobeManager.is_sold_out(item_id)
	var stock    = item.get("stock", -1)
	var cur_stock = WardrobeManager.item_stock.get(item_id, stock)

	var panel = PanelContainer.new()
	var ps = StyleBoxFlat.new()
	ps.bg_color = r_color.darkened(0.75) if not is_owned else Color(0.12, 0.18, 0.12)
	ps.border_width_left   = 2; ps.border_width_right  = 2
	ps.border_width_top    = 2; ps.border_width_bottom = 2
	ps.border_color = r_color.lightened(0.1) if not is_owned else Color(0.3, 0.6, 0.3)
	ps.corner_radius_top_left    = 12; ps.corner_radius_top_right    = 12
	ps.corner_radius_bottom_left = 12; ps.corner_radius_bottom_right = 12
	ps.content_margin_left = 14; ps.content_margin_right  = 14
	ps.content_margin_top  = 12; ps.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", ps)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	# 图标
	var icon_lbl = Label.new()
	icon_lbl.text = item.get("emoji", "❓")
	icon_lbl.add_theme_font_size_override("font_size", 36)
	icon_lbl.custom_minimum_size = Vector2(50, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(icon_lbl)

	# 信息列
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	# 名称 + 稀有度
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info.add_child(name_row)
	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", r_color.lightened(0.25))
	name_row.add_child(name_lbl)
	var rarity_tag = Label.new()
	rarity_tag.text = "【%s】" % WardrobeManager.RARITY_LABELS.get(rarity, "普通")
	rarity_tag.add_theme_font_size_override("font_size", 12)
	rarity_tag.add_theme_color_override("font_color", r_color)
	name_row.add_child(rarity_tag)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	# 属性加成行
	var bonus_parts: Array = []
	var stat_icons = {"charm":"✨","social":"💬","art":"🎨","strength":"⚽","intellect":"📚"}
	for stat in item.get("stat_bonus", {}).keys():
		bonus_parts.append("%s+%d" % [stat_icons.get(stat,""), item["stat_bonus"][stat]])
	if not bonus_parts.is_empty():
		var bl = Label.new()
		bl.text = "加成：" + "  ".join(bonus_parts)
		bl.add_theme_font_size_override("font_size", 12)
		bl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.5))
		info.add_child(bl)

	# 库存行
	if stock > 0:
		var stock_lbl = Label.new()
		var remain = cur_stock if cur_stock >= 0 else stock
		stock_lbl.text = "剩余库存：%d 件" % remain if not sold_out else "已售罄"
		stock_lbl.add_theme_font_size_override("font_size", 12)
		stock_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.4, 0.3) if sold_out else Color(1.0, 0.85, 0.3))
		info.add_child(stock_lbl)

	# 右侧：价格 + 购买按钮
	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	right_col.custom_minimum_size = Vector2(90, 0)
	row.add_child(right_col)

	var price_lbl = Label.new()
	price_lbl.text = "💰 %d" % item.get("price", 0)
	price_lbl.add_theme_font_size_override("font_size", 15)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(price_lbl)

	var buy_btn = Button.new()
	buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_btn.add_theme_font_size_override("font_size", 13)
	buy_btn.custom_minimum_size = Vector2(86, 0)

	if is_owned:
		buy_btn.text = "✅ 已拥有"
		buy_btn.disabled = true
		_style_shop_btn(buy_btn, Color(0.25, 0.45, 0.25))
	elif sold_out:
		buy_btn.text = "🚫 已售罄"
		buy_btn.disabled = true
		_style_shop_btn(buy_btn, Color(0.35, 0.2, 0.2))
	else:
		buy_btn.text = "🛍️ 购买"
		_style_shop_btn(buy_btn, Color(0.55, 0.40, 0.10))
		buy_btn.pressed.connect(func(): _on_buy(item_id, money_lbl))

	right_col.add_child(buy_btn)
	return panel

func _on_buy(item_id: String, money_lbl: Label) -> void:
	var result = WardrobeManager.buy_item(item_id)
	if result["success"]:
		money_lbl.text = "💰 %d" % GameManager.money
		_build_shop_list(money_lbl)   # 刷新列表
	else:
		GameManager.show_toast.emit("❌ " + result.get("reason", "购买失败"))

func _style_shop_btn(btn: Button, color: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left    = 8; s.corner_radius_top_right    = 8
	s.corner_radius_bottom_left = 8; s.corner_radius_bottom_right = 8
	s.content_margin_left = 8; s.content_margin_right = 8
	s.content_margin_top  = 5; s.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate(); h.bg_color = color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", h)
	var d = s.duplicate(); d.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("disabled", d)

func _on_close() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func(): closed.emit(); queue_free())
