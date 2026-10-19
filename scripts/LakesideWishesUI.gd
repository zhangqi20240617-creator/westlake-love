extends CanvasLayer
## LakesideWishesUI — 西湖许愿花灯与漂流瓶 (移动端大字体优化版)

signal closed

var base_panel: PanelContainer
var tab_content: PanelContainer
var current_tab: int = 1 # 0: 放入, 1: 捞取, 2: 我的

func _ready():
    # 建立全屏半透明遮罩
    var mask = ColorRect.new()
    mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mask.color = Color(0, 0, 0, 0.6)
    add_child(mask)

    # ── 1. 主面板 ──
    # 为移动端加宽面板，占用更充足的屏幕空间，防止文字局促
    base_panel = PanelContainer.new()
    base_panel.custom_minimum_size = Vector2(820, 530)
    base_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    base_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    base_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    
    # 深色微透玻璃发光面板背景
    var sb = StyleBoxFlat.new()
    sb.bg_color = Color(0.06, 0.08, 0.15, 0.95)
    sb.corner_radius_top_left = 18
    sb.corner_radius_top_right = 18
    sb.corner_radius_bottom_left = 18
    sb.corner_radius_bottom_right = 18
    sb.shadow_color = Color(0, 0, 0, 0.6)
    sb.shadow_size = 18
    base_panel.add_theme_stylebox_override("panel", sb)
    add_child(base_panel)

    # 面板内边距 (增大移动端边缘空隙)
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 26)
    margin.add_theme_constant_override("margin_right", 26)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 24)
    base_panel.add_child(margin)

    var main_vbox = VBoxContainer.new()
    main_vbox.add_theme_constant_override("separation", 18)
    margin.add_child(main_vbox)

    # ── 2. 标题栏与关闭 ──
    var title_hbox = HBoxContainer.new()
    main_vbox.add_child(title_hbox)

    var title_lbl = Label.new()
    title_lbl.text = "🏮 西湖许愿花灯与漂流瓶"
    title_lbl.add_theme_font_size_override("font_size", 24) # 放大至24
    title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
    title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_hbox.add_child(title_lbl)

    # 增大关闭按钮的点击热区，方便手指点按
    var close_btn = Button.new()
    close_btn.text = "  ✕  "
    close_btn.flat = true
    close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    close_btn.add_theme_font_size_override("font_size", 24) # 放大至24
    close_btn.add_theme_color_override("font_color", Color(1,1,1,0.6))
    close_btn.pressed.connect(_on_close_pressed)
    title_hbox.add_child(close_btn)

    # ── 3. 顶部 Tabs 选项卡 (加高、字号放大，适配手指触控) ──
    var tabs_hbox = HBoxContainer.new()
    tabs_hbox.add_theme_constant_override("separation", 14)
    main_vbox.add_child(tabs_hbox)

    var tab_put = Button.new()
    tab_put.text = "🏮 放出许愿花灯"
    tab_put.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    tab_put.pressed.connect(func(): _switch_tab(0))
    tabs_hbox.add_child(tab_put)

    var tab_fetch = Button.new()
    tab_fetch.text = "🌊 捞取愿望花灯"
    tab_fetch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    tab_fetch.pressed.connect(func(): _switch_tab(1))
    tabs_hbox.add_child(tab_fetch)

    var tab_my = Button.new()
    tab_my.text = "✉️ 我的花灯与留言"
    tab_my.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    tab_my.pressed.connect(func(): _switch_tab(2))
    tabs_hbox.add_child(tab_my)

    # 移动端友好：按钮高度至少 44px
    for btn in [tab_put, tab_fetch, tab_my]:
        btn.add_theme_font_size_override("font_size", 17) # 放大至17
        btn.custom_minimum_size = Vector2(170, 44) # 高度调至44px，移动端标准触控高度
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.12, 0.16, 0.28, 0.8)
        style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
        style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
        btn.add_theme_stylebox_override("normal", style)

    # ── 4. 内容容器 ──
    tab_content = PanelContainer.new()
    tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var content_sb = StyleBoxFlat.new()
    content_sb.bg_color = Color(0, 0, 0, 0.25)
    content_sb.corner_radius_top_left = 10; content_sb.corner_radius_top_right = 10
    content_sb.corner_radius_bottom_left = 10; content_sb.corner_radius_bottom_right = 10
    tab_content.add_theme_stylebox_override("panel", content_sb)
    main_vbox.add_child(tab_content)

    # ── 5. 连接网络信号 ──
    NetworkManager.wishes_loaded.connect(_on_wishes_loaded)
    NetworkManager.wish_submitted.connect(_on_wish_submitted)
    NetworkManager.my_wishes_loaded.connect(_on_my_wishes_loaded)
    NetworkManager.wish_replied.connect(_on_wish_replied)

    # 默认切入捞取选项卡
    _switch_tab(1)

    # ── 6. 面板入场动画 ──
    base_panel.modulate.a = 0.0
    base_panel.scale = Vector2(0.94, 0.94)
    base_panel.pivot_offset = base_panel.custom_minimum_size / 2
    var t = create_tween().set_parallel(true)
    t.tween_property(base_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
    t.tween_property(base_panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_close_pressed():
    var t = create_tween().set_parallel(true)
    t.tween_property(base_panel, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
    t.tween_property(base_panel, "scale", Vector2(0.94, 0.94), 0.18).set_trans(Tween.TRANS_SINE)
    t.chain().tween_callback(func():
        closed.emit()
        queue_free()
    )

func _switch_tab(tab_idx: int):
    current_tab = tab_idx
    
    # 清空当前子项
    for child in tab_content.get_children():
        child.queue_free()

    # 构建对应子界面
    if tab_idx == 0:
        _build_put_tab()
    elif tab_idx == 1:
        _build_fetch_tab()
    elif tab_idx == 2:
        _build_my_tab()

# ───────────────── 1. 放出花灯 TAB ─────────────────
func _build_put_tab():
    var pad = MarginContainer.new()
    pad.add_theme_constant_override("margin_left", 40)
    pad.add_theme_constant_override("margin_right", 40)
    pad.add_theme_constant_override("margin_top", 24)
    pad.add_theme_constant_override("margin_bottom", 24)
    tab_content.add_child(pad)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 18)
    pad.add_child(vbox)

    var title = Label.new()
    title.text = "✍️ 写下心愿，系于花灯"
    title.add_theme_font_size_override("font_size", 20) # 放大至20
    title.add_theme_color_override("font_color", Color.WHITE)
    vbox.add_child(title)

    var desc = Label.new()
    desc.text = "微凉的晚风掠过西湖。写下这一刻你对未来的期盼，或者是对中考的自我打气……它将被水流带走，被另一位来到湖畔的同龄人捞起。"
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.add_theme_font_size_override("font_size", 16) # 放大至16
    desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
    vbox.add_child(desc)

    var text_edit = TextEdit.new()
    text_edit.placeholder_text = "在这里写下你的心愿（不超过 60 字）..."
    text_edit.custom_minimum_size = Vector2(0, 140)
    text_edit.add_theme_font_size_override("font_size", 17) # 放大至17
    var text_sb = StyleBoxFlat.new()
    text_sb.bg_color = Color(0.02, 0.03, 0.07, 0.8)
    text_sb.corner_radius_top_left = 10; text_sb.corner_radius_top_right = 10
    text_sb.corner_radius_bottom_left = 10; text_sb.corner_radius_bottom_right = 10
    text_sb.border_width_left = 1; text_sb.border_width_top = 1
    text_sb.border_width_right = 1; text_sb.border_width_bottom = 1
    text_sb.border_color = Color(0.2, 0.25, 0.4, 0.6)
    text_edit.add_theme_stylebox_override("normal", text_sb)
    text_edit.add_theme_stylebox_override("focus", text_sb)
    vbox.add_child(text_edit)

    var submit_btn = Button.new()
    submit_btn.text = "🏮 放出许愿花灯"
    submit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    submit_btn.custom_minimum_size = Vector2(200, 46) # 36 -> 46 (加高利于点击)
    submit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    submit_btn.add_theme_font_size_override("font_size", 17) # 放大至17
    
    var btn_sb = StyleBoxFlat.new()
    btn_sb.bg_color = Color(0.85, 0.4, 0.25, 1.0)
    btn_sb.corner_radius_top_left = 8; btn_sb.corner_radius_top_right = 8
    btn_sb.corner_radius_bottom_left = 8; btn_sb.corner_radius_bottom_right = 8
    submit_btn.add_theme_stylebox_override("normal", btn_sb)
    
    submit_btn.pressed.connect(func():
        var content = text_edit.text.strip_edges()
        if content.is_empty():
            _show_toast("写点内容再放入湖中吧！")
            return
        if content.length() > 60:
            _show_toast("花灯纸条字数上限为60字哦")
            return
        submit_btn.disabled = true
        submit_btn.text = "正在送入湖中..."
        NetworkManager.submit_wish(content)
    )
    vbox.add_child(submit_btn)

func _on_wish_submitted(success: bool, msg: String):
    if success:
        GameManager.flags["achv_wish_submitted"] = true
        if is_instance_valid(AchievementManager):
            AchievementManager.check_all()
    if current_tab == 0:
        _show_toast("✨ " + msg if success else "❌ " + msg)
        _switch_tab(2) # 自动切到“我的花灯”看一眼

# ───────────────── 2. 捞取花灯 TAB ─────────────────
var fetch_list_vbox: VBoxContainer

func _build_fetch_tab():
    var pad = MarginContainer.new()
    pad.add_theme_constant_override("margin_left", 20)
    pad.add_theme_constant_override("margin_right", 20)
    pad.add_theme_constant_override("margin_top", 16)
    pad.add_theme_constant_override("margin_bottom", 16)
    tab_content.add_child(pad)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 14)
    pad.add_child(vbox)

    var top_hbox = HBoxContainer.new()
    vbox.add_child(top_hbox)

    var desc = Label.new()
    desc.text = "🌊 湖面泛着柔光，点击右侧「打捞」来查看他人的心愿。"
    desc.add_theme_font_size_override("font_size", 13) # 11 -> 13
    desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
    desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_hbox.add_child(desc)

    var btn = Button.new()
    btn.text = "🌊 捞起花灯"
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    btn.add_theme_font_size_override("font_size", 13) # 11 -> 13
    btn.custom_minimum_size = Vector2(110, 40) # 移动端操作按钮
    var btn_sb = StyleBoxFlat.new()
    btn_sb.bg_color = Color(0.2, 0.45, 0.7, 1.0)
    btn_sb.corner_radius_top_left = 8; btn_sb.corner_radius_top_right = 8
    btn_sb.corner_radius_bottom_left = 8; btn_sb.corner_radius_bottom_right = 8
    btn.add_theme_stylebox_override("normal", btn_sb)
    btn.pressed.connect(func():
        for child in fetch_list_vbox.get_children():
            child.queue_free()
        var loading = Label.new()
        loading.text = "🌌 正在打捞西湖中的飘流花灯..."
        loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        loading.add_theme_font_size_override("font_size", 13)
        loading.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 0.6))
        fetch_list_vbox.add_child(loading)
        NetworkManager.get_random_wishes(3)
    )
    top_hbox.add_child(btn)

    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vbox.add_child(scroll)

    fetch_list_vbox = VBoxContainer.new()
    fetch_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fetch_list_vbox.add_theme_constant_override("separation", 14)
    scroll.add_child(fetch_list_vbox)

    # 默认自动打捞一次
    btn.pressed.emit()

func _on_wishes_loaded(data: Array):
    if current_tab != 1 or not is_instance_valid(fetch_list_vbox): return
    
    for child in fetch_list_vbox.get_children():
        child.queue_free()

    if data.is_empty():
        var empty = Label.new()
        empty.text = "湖面静悄悄的，什么都没有捞到。"
        empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty.add_theme_font_size_override("font_size", 13)
        empty.add_theme_color_override("font_color", Color(1,1,1,0.3))
        fetch_list_vbox.add_child(empty)
        return

    for item in data:
        var wish_id = item.get("id", "")
        var name = item.get("username", "无名氏")
        var school = item.get("school", "西湖中学")
        var content = item.get("content", "")
        var replies = item.get("replies", [])

        var card = PanelContainer.new()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var card_sb = StyleBoxFlat.new()
        card_sb.bg_color = Color(0.96, 0.84, 0.62, 0.14)
        card_sb.corner_radius_top_left = 12; card_sb.corner_radius_top_right = 12
        card_sb.corner_radius_bottom_left = 12; card_sb.corner_radius_bottom_right = 12
        card_sb.border_width_left = 5 # 强化左边粗边框
        card_sb.border_color = Color(1.0, 0.72, 0.35, 0.9)
        card.add_theme_stylebox_override("panel", card_sb)
        fetch_list_vbox.add_child(card)

        var margin = MarginContainer.new()
        margin.add_theme_constant_override("margin_left", 16)
        margin.add_theme_constant_override("margin_right", 16)
        margin.add_theme_constant_override("margin_top", 12)
        margin.add_theme_constant_override("margin_bottom", 14)
        card.add_child(margin)

        var card_vbox = VBoxContainer.new()
        card_vbox.add_theme_constant_override("separation", 10)
        margin.add_child(card_vbox)

        # 卡片头部
        var header = HBoxContainer.new()
        card_vbox.add_child(header)

        var author = Label.new()
        author.text = "👤 %s" % name
        author.add_theme_font_size_override("font_size", 14) # 11 -> 14
        author.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
        header.add_child(author)

        var school_lbl = Label.new()
        school_lbl.text = "（%s）" % school
        school_lbl.add_theme_font_size_override("font_size", 11) # 9 -> 11
        school_lbl.add_theme_color_override("font_color", Color(1,1,1,0.4))
        header.add_child(school_lbl)

        # 愿愿内容 (加粗加大)
        var content_lbl = Label.new()
        content_lbl.text = content
        content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        content_lbl.add_theme_font_size_override("font_size", 14) # 12 -> 14
        content_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
        card_vbox.add_child(content_lbl)

        # ── 已有留言展示区 ──
        var replies_box = VBoxContainer.new()
        replies_box.add_theme_constant_override("separation", 6)
        card_vbox.add_child(replies_box)

        for r in replies:
            var r_lbl = Label.new()
            r_lbl.text = "  💬 %s(%s): %s" % [r.get("username"), r.get("school"), r.get("content")]
            r_lbl.add_theme_font_size_override("font_size", 12) # 10 -> 12
            r_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92, 0.9))
            r_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            replies_box.add_child(r_lbl)

        # 底部大尺寸动作按钮栏 (40px 高度，移动端友好)
        var actions = HBoxContainer.new()
        actions.add_theme_constant_override("separation", 20)
        card_vbox.add_child(actions)

        var like_btn = Button.new()
        like_btn.text = "💖 送上祝福"
        like_btn.flat = true
        like_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        like_btn.add_theme_font_size_override("font_size", 12) # 10 -> 12
        like_btn.add_theme_color_override("font_color", Color(1, 0.65, 0.65))
        like_btn.custom_minimum_size = Vector2(0, 36)
        like_btn.pressed.connect(func():
            like_btn.text = "💖 已送出祝福"
            like_btn.disabled = true
            _show_toast("默默地为对方送出了美好祝福")
        )
        actions.add_child(like_btn)

        var reply_btn = Button.new()
        reply_btn.text = "💬 留言鼓励"
        reply_btn.flat = true
        reply_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        reply_btn.add_theme_font_size_override("font_size", 12) # 10 -> 12
        reply_btn.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
        reply_btn.custom_minimum_size = Vector2(0, 36)
        actions.add_child(reply_btn)

        # 展开的回复输入框 (高44px，移动触控舒适)
        var reply_input_box = HBoxContainer.new()
        reply_input_box.add_theme_constant_override("separation", 8)
        reply_input_box.hide()
        card_vbox.add_child(reply_input_box)

        var edit = LineEdit.new()
        edit.placeholder_text = "写句鼓励的话吧..."
        edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        edit.custom_minimum_size = Vector2(0, 42) # 42px 高度
        edit.add_theme_font_size_override("font_size", 13)
        reply_input_box.add_child(edit)

        var send = Button.new()
        send.text = " 发送 "
        send.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        send.custom_minimum_size = Vector2(80, 42)
        send.add_theme_font_size_override("font_size", 13)
        
        var send_sb = StyleBoxFlat.new()
        send_sb.bg_color = Color(0.2, 0.6, 0.4, 1.0)
        send_sb.corner_radius_top_left = 6; send_sb.corner_radius_top_right = 6
        send_sb.corner_radius_bottom_left = 6; send_sb.corner_radius_bottom_right = 6
        send.add_theme_stylebox_override("normal", send_sb)
        
        send.pressed.connect(func():
            var txt = edit.text.strip_edges()
            if txt.is_empty(): return
            send.disabled = true
            NetworkManager.reply_to_wish(wish_id, txt)
            
            # 客户端在本地先追加假回应
            var local_lbl = Label.new()
            local_lbl.text = "  💬 %s(%s): %s" % [GameManager.player_name, GameManager.school_name, txt]
            local_lbl.add_theme_font_size_override("font_size", 12)
            local_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92, 0.9))
            replies_box.add_child(local_lbl)
            
            reply_input_box.hide()
        )
        reply_input_box.add_child(send)

        reply_btn.pressed.connect(func():
            reply_input_box.visible = not reply_input_box.visible
            if reply_input_box.visible:
                edit.grab_focus()
        )

func _on_wish_replied(success: bool, msg: String):
    _show_toast(msg)

# ───────────────── 3. 我的花灯 TAB ─────────────────
var my_list_vbox: VBoxContainer

func _build_my_tab():
    var pad = MarginContainer.new()
    pad.add_theme_constant_override("margin_left", 20)
    pad.add_theme_constant_override("margin_right", 20)
    pad.add_theme_constant_override("margin_top", 16)
    pad.add_theme_constant_override("margin_bottom", 16)
    tab_content.add_child(pad)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 14)
    pad.add_child(vbox)

    var title_lbl = Label.new()
    title_lbl.text = "✉️ 我放入西湖的花灯留言簿（可随时查看是谁给我留言了）"
    title_lbl.add_theme_font_size_override("font_size", 14) # 12 -> 14
    title_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
    vbox.add_child(title_lbl)

    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vbox.add_child(scroll)

    my_list_vbox = VBoxContainer.new()
    my_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    my_list_vbox.add_theme_constant_override("separation", 16)
    scroll.add_child(my_list_vbox)

    var loading = Label.new()
    loading.text = "正在拉取你在西湖放飞的所有花灯..."
    loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading.add_theme_font_size_override("font_size", 13) # 11 -> 13
    loading.add_theme_color_override("font_color", Color(1,1,1,0.3))
    my_list_vbox.add_child(loading)

    # 异步拉取
    NetworkManager.get_my_wishes()

func _on_my_wishes_loaded(data: Array):
    if current_tab != 2 or not is_instance_valid(my_list_vbox): return

    for child in my_list_vbox.get_children():
        child.queue_free()

    if data.is_empty():
        var empty = Label.new()
        empty.text = "你在西湖里还没有放出过花灯。\n快去左侧「放入花灯」写下你的第一个中考期许吧！"
        empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        empty.add_theme_font_size_override("font_size", 13) # 11 -> 13
        empty.add_theme_color_override("font_color", Color(1,1,1,0.3))
        my_list_vbox.add_child(empty)
        return

    for wish in data:
        var content = wish.get("content", "")
        var replies = wish.get("replies", [])

        var wish_box = VBoxContainer.new()
        wish_box.add_theme_constant_override("separation", 10)
        my_list_vbox.add_child(wish_box)

        # 玩家自己的花灯卡片
        var card = PanelContainer.new()
        var card_sb = StyleBoxFlat.new()
        card_sb.bg_color = Color(0.85, 0.45, 0.3, 0.16) # 温馨橘红
        card_sb.corner_radius_top_left = 12; card_sb.corner_radius_top_right = 12
        card_sb.corner_radius_bottom_left = 12; card_sb.corner_radius_bottom_right = 12
        card_sb.border_width_left = 4
        card_sb.border_color = Color(0.9, 0.5, 0.3, 0.8)
        card.add_theme_stylebox_override("panel", card_sb)
        wish_box.add_child(card)

        var card_pad = MarginContainer.new()
        card_pad.add_theme_constant_override("margin_left", 16)
        card_pad.add_theme_constant_override("margin_right", 16)
        card_pad.add_theme_constant_override("margin_top", 12)
        card_pad.add_theme_constant_override("margin_bottom", 12)
        card.add_child(card_pad)

        var card_inner = VBoxContainer.new()
        card_inner.add_theme_constant_override("separation", 6)
        card_pad.add_child(card_inner)

        var my_tag = Label.new()
        my_tag.text = "🏮 我的许愿花灯："
        my_tag.add_theme_font_size_override("font_size", 12) # 10 -> 12
        my_tag.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
        card_inner.add_child(my_tag)

        var content_lbl = Label.new()
        content_lbl.text = content
        content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        content_lbl.add_theme_font_size_override("font_size", 14) # 12 -> 14
        content_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
        card_inner.add_child(content_lbl)

        # ── 重点：他人回复列表展现 ──
        var replies_container = VBoxContainer.new()
        replies_container.add_theme_constant_override("separation", 8)
        # 明显的层级缩进
        var reply_margin = MarginContainer.new()
        reply_margin.add_theme_constant_override("margin_left", 28)
        reply_margin.add_child(replies_container)
        wish_box.add_child(reply_margin)

        if replies.is_empty():
            var no_reply = Label.new()
            no_reply.text = " 📪 湖面上静悄悄的，花灯还在静静漂流..."
            no_reply.add_theme_font_size_override("font_size", 12)
            no_reply.add_theme_color_override("font_color", Color(1,1,1,0.3))
            replies_container.add_child(no_reply)
        else:
            for reply in replies:
                var r_name = reply.get("username", "无名氏")
                var r_school = reply.get("school", "西湖中学")
                var r_text = reply.get("content", "")

                var reply_panel = PanelContainer.new()
                var reply_sb = StyleBoxFlat.new()
                reply_sb.bg_color = Color(0.12, 0.22, 0.35, 0.65)
                reply_sb.corner_radius_top_left = 10; reply_sb.corner_radius_top_right = 10
                reply_sb.corner_radius_bottom_left = 10; reply_sb.corner_radius_bottom_right = 10
                reply_sb.border_width_left = 3
                reply_sb.border_color = Color(0.3, 0.6, 0.9, 0.8)
                reply_panel.add_theme_stylebox_override("panel", reply_sb)
                replies_container.add_child(reply_panel)

                var rep_pad = MarginContainer.new()
                rep_pad.add_theme_constant_override("margin_left", 14)
                rep_pad.add_theme_constant_override("margin_right", 14)
                rep_pad.add_theme_constant_override("margin_top", 10)
                rep_pad.add_theme_constant_override("margin_bottom", 10)
                reply_panel.add_child(rep_pad)

                var rep_vbox = VBoxContainer.new()
                rep_vbox.add_theme_constant_override("separation", 6)
                rep_pad.add_child(rep_vbox)

                var rep_header = HBoxContainer.new()
                rep_vbox.add_child(rep_header)

                var who = Label.new()
                who.text = "✉️ 来自「%s」的留言：" % r_name
                who.add_theme_font_size_override("font_size", 13) # 10 -> 13 (留言名字放大)
                
                # 对专属角色名字高亮，从 GameManager.char_meta 中查找匹配的主题颜色
                var matched_char_id = ""
                for cid in GameManager.char_meta.keys():
                    if GameManager.char_meta[cid].get("name", "") == r_name:
                        matched_char_id = cid
                        break
                
                if matched_char_id != "":
                    var meta = GameManager.char_meta[matched_char_id]
                    who.add_theme_color_override("font_color", Color(meta.get("color", "#ffffff")))
                else:
                    who.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
                rep_header.add_child(who)

                var sch = Label.new()
                sch.text = "(%s)" % r_school
                sch.add_theme_font_size_override("font_size", 10) # 8 -> 10
                sch.add_theme_color_override("font_color", Color(1,1,1,0.3))
                rep_header.add_child(sch)

                # 详细回复正文 (大字体)
                var msg_lbl = Label.new()
                msg_lbl.text = r_text
                msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                msg_lbl.add_theme_font_size_override("font_size", 13) # 11 -> 13
                msg_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
                rep_vbox.add_child(msg_lbl)

        # 分隔线
        var sep = HSeparator.new()
        sep.modulate = Color(1,1,1,0.08)
        my_list_vbox.add_child(sep)

# ───────────────── 辅助浮动 Toast (大字体) ─────────────────
func _show_toast(msg: String):
    var toast = PanelContainer.new()
    var ts = StyleBoxFlat.new()
    ts.bg_color = Color(0, 0, 0, 0.88)
    ts.corner_radius_top_left = 10; ts.corner_radius_top_right = 10
    ts.corner_radius_bottom_left = 10; ts.corner_radius_bottom_right = 10
    toast.add_theme_stylebox_override("panel", ts)
    
    var lbl = Label.new()
    lbl.text = msg
    lbl.add_theme_font_size_override("font_size", 13) # 11 -> 13
    lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
    toast.add_child(lbl)
    
    add_child(toast)
    toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    toast.offset_bottom = -50 # 底部空开更多空间
    toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
    toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    
    toast.modulate.a = 0.0
    var tw = create_tween()
    tw.tween_property(toast, "modulate:a", 1.0, 0.2)
    tw.tween_interval(2.5)
    tw.tween_property(toast, "modulate:a", 0.0, 0.3)
    tw.tween_callback(toast.queue_free)
