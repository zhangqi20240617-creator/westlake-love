extends Panel
# ShopUI.gd - 🏪 校外小卖部互动商店界面 (Interactive Shop System Overlay)

signal closed

var shop_panel: PanelContainer
var item_list_container: VBoxContainer
var wallet_lbl: Label

func _ready():
    # ── 全屏黑色半透明遮罩 ──
    anchor_left = 0.0
    anchor_top = 0.0
    anchor_right = 1.0
    anchor_bottom = 1.0
    offset_left = 0
    offset_top = 0
    offset_right = 0
    offset_bottom = 0

    var barrier = ThemeUtils.create_style(Color(0, 0, 0, 0.6), 0)
    add_theme_stylebox_override("panel", barrier)
    
    # ── 商店主体面板 ──
    shop_panel = PanelContainer.new()
    shop_panel.custom_minimum_size = Vector2(700, 520)
    
    var panel_style = ThemeUtils.make_card_style(Color("#1e293b"), Color("#38bdf8"), 18)
    panel_style.border_width_left = 2; panel_style.border_width_right = 2
    panel_style.border_width_top = 2; panel_style.border_width_bottom = 2
    panel_style.shadow_color = Color(0, 0, 0, 0.4)
    panel_style.shadow_size = 15
    shop_panel.add_theme_stylebox_override("panel", panel_style)
    
    # 居中定位
    shop_panel.anchor_left = 0.5
    shop_panel.anchor_top = 0.5
    shop_panel.anchor_right = 0.5
    shop_panel.anchor_bottom = 0.5
    shop_panel.offset_left = -350
    shop_panel.offset_top = -260
    shop_panel.offset_right = 350
    shop_panel.offset_bottom = 260
    add_child(shop_panel)
    
    # 内部垂直排版
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 12)
    shop_panel.add_child(vbox)
    
    # ── 1. 顶部标题栏 ──
    var header = HBoxContainer.new()
    header.custom_minimum_size = Vector2(0, 45)
    vbox.add_child(header)
    
    var spacer_l = Control.new()
    spacer_l.custom_minimum_size = Vector2(10, 0)
    header.add_child(spacer_l)
    
    var title_lbl = Label.new()
    title_lbl.text = "🏪 校外小卖部 (挑选物品)"
    title_lbl.add_theme_color_override("font_color", Color("#f8fafc"))
    title_lbl.add_theme_font_size_override("font_size", 22)
    title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_lbl)
    
    # 关闭按钮
    var close_btn = Button.new()
    close_btn.text = " ✕ 返回 "
    close_btn.custom_minimum_size = Vector2(90, 36)
    close_btn.add_theme_font_size_override("font_size", 15)
    close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    
    var close_style = ThemeUtils.create_style(Color("#ef4444"), 8, Color.TRANSPARENT, 0, -1, 12, 12, -1, -1)
    close_btn.add_theme_stylebox_override("normal", close_style)
    var close_hover = ThemeUtils.create_style(Color("#dc2626"), 8, Color.TRANSPARENT, 0, -1, 12, 12, -1, -1)
    close_btn.add_theme_stylebox_override("hover", close_hover)
    close_btn.add_theme_stylebox_override("pressed", close_hover)
    
    close_btn.pressed.connect(_on_close_pressed)
    header.add_child(close_btn)
    
    var spacer_r = Control.new()
    spacer_r.custom_minimum_size = Vector2(10, 0)
    header.add_child(spacer_r)
    
    # ── 2. 商品列表滚动区域 ──
    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vbox.add_child(scroll)
    
    # 内层垂直网格
    item_list_container = VBoxContainer.new()
    item_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    item_list_container.add_theme_constant_override("separation", 10)
    scroll.add_child(item_list_container)
    
    # ── 3. 底部金钱栏 ──
    var footer = Panel.new()
    footer.custom_minimum_size = Vector2(0, 48)
    var footer_style = ThemeUtils.create_style(Color("#0f172a"), 16)
    footer.add_theme_stylebox_override("panel", footer_style)
    vbox.add_child(footer)
    
    wallet_lbl = Label.new()
    wallet_lbl.text = " 零花钱: 💰 100"
    wallet_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    wallet_lbl.anchors_preset = Control.PRESET_LEFT_WIDE
    wallet_lbl.offset_left = 16
    wallet_lbl.add_theme_color_override("font_color", Color("#fbbf24")) # 黄色高亮
    wallet_lbl.add_theme_font_size_override("font_size", 18)
    footer.add_child(wallet_lbl)
    
    var desc_lbl = Label.new()
    desc_lbl.text = "小卖部蹭网不耗费时间，购买物品为零时延。  "
    desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    desc_lbl.anchors_preset = Control.PRESET_RIGHT_WIDE
    desc_lbl.offset_right = -16
    desc_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
    desc_lbl.add_theme_font_size_override("font_size", 15)
    footer.add_child(desc_lbl)

    # 填充商品
    update_shop_list()

# 更新商品列表
func update_shop_list():
    # 清空列表
    for child in item_list_container.get_children():
        child.queue_free()
        
    # 钱包余额
    wallet_lbl.text = " 当前钱包余额: 💰 %d" % GameManager.money
    
    var db = GameManager.ITEM_DB
    for item_id in db.keys():
        var item = db[item_id]
        if item.get("category", "") == "doll":
            continue
        var name_str = item.get("name", "未知")
        var icon_str = item.get("icon", "📦")
        var desc_str = item.get("desc", "无描述")
        var price = item.get("price", 0)
        var owned = GameManager.inventory.get(item_id, 0)
        
        # 单行 HBoxContainer
        var row = PanelContainer.new()
        var row_style = ThemeUtils.create_style(Color("#334155", 0.4), 8, Color("#475569"), 1, -1, 12, 12, 8, 8)
        row.add_theme_stylebox_override("panel", row_style)
        item_list_container.add_child(row)
        
        var hbox = HBoxContainer.new()
        hbox.add_theme_constant_override("separation", 12)
        row.add_child(hbox)
        
        # 图标
        var icon_lbl = Label.new()
        icon_lbl.text = icon_str
        icon_lbl.add_theme_font_size_override("font_size", 28)
        icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        hbox.add_child(icon_lbl)
        
        # 文字区域 (名称 + 描述)
        var text_vbox = VBoxContainer.new()
        text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        text_vbox.add_theme_constant_override("separation", 2)
        hbox.add_child(text_vbox)
        
        var name_lbl = Label.new()
        name_lbl.text = name_str
        name_lbl.add_theme_color_override("font_color", Color("#f8fafc"))
        name_lbl.add_theme_font_size_override("font_size", 18)
        text_vbox.add_child(name_lbl)
        
        var detail_lbl = Label.new()
        detail_lbl.text = desc_str
        detail_lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
        detail_lbl.add_theme_font_size_override("font_size", 15)
        detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        text_vbox.add_child(detail_lbl)
        
        # 拥有数量
        var owned_lbl = Label.new()
        owned_lbl.text = "已拥有: %d" % owned
        owned_lbl.add_theme_color_override("font_color", Color("#94a3b8") if owned == 0 else Color("#86efac"))
        owned_lbl.add_theme_font_size_override("font_size", 15)
        owned_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        hbox.add_child(owned_lbl)
        
        # 价格标签
        var price_lbl = Label.new()
        price_lbl.text = "💰 %d" % price
        price_lbl.add_theme_color_override("font_color", Color("#fde047"))
        price_lbl.add_theme_font_size_override("font_size", 16)
        price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        hbox.add_child(price_lbl)
        
        # 购买按钮
        var buy_btn = Button.new()
        buy_btn.text = "购买"
        buy_btn.custom_minimum_size = Vector2(72, 36)
        buy_btn.add_theme_font_size_override("font_size", 15)
        buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        
        var buy_style = ThemeUtils.create_style(Color("#0ea5e9"), 6)
        buy_btn.add_theme_stylebox_override("normal", buy_style)
        
        var buy_hover = ThemeUtils.create_style(Color("#0284c7"), 6)
        buy_btn.add_theme_stylebox_override("hover", buy_hover)
        buy_btn.add_theme_stylebox_override("pressed", buy_hover)
        
        # 钱不够时禁用
        if GameManager.money < price:
            buy_btn.disabled = true
            buy_btn.add_theme_color_override("font_disabled_color", Color("#64748b"))
            var dis_style = ThemeUtils.create_style(Color("#1e293b"), 6)
            buy_btn.add_theme_stylebox_override("disabled", dis_style)
            
        buy_btn.pressed.connect(func(): _on_buy_pressed(item_id, price))
        hbox.add_child(buy_btn)

func _on_buy_pressed(item_id: String, price: int):
    if GameManager.money >= price:
        GameManager.money -= price
        GameManager.add_item(item_id, 1)
        # ── 成就统计 ──
        if is_instance_valid(AchievementManager):
            AchievementManager.add_counter("shop_buy_count", 1)
            if AchievementManager.get_counter("shop_buy_count") >= 5:
                GameManager.flags["achv_snack_spree"] = true
                AchievementManager.check_all()

        # 播放购买成功动效
        var tween = create_tween()
        tween.tween_property(shop_panel, "scale", Vector2(1.02, 1.02), 0.08)
        tween.tween_property(shop_panel, "scale", Vector2(1.0, 1.0), 0.08)
        update_shop_list()
    else:
        GameManager.show_toast.emit("❌ 零花钱不足！")

func _on_close_pressed():
    closed.emit()
    queue_free()
