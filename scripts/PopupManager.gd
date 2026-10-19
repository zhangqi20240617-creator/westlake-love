## PopupManager.gd
## 弹窗管理代理类 + 通用弹窗构造静态工具
## 集中处理日记、背包、排行榜、存档/读档的弹窗内容渲染。
## 通用弹窗框架由 make_overlay_popup() 静态方法提供，可在任何节点上使用。

class_name PopupManager

# ── 宿主节点引用 ──────────────────────────────────────────────
var _host:            Control
var _on_update_ui_cb: Callable

# ── 初始化 ──────────────────────────────────────────────────
func setup(host: Control, on_update_ui_cb: Callable) -> void:
    _host            = host
    _on_update_ui_cb = on_update_ui_cb

# ════════════════════════════════════════════════════════════
# ── 通用全屏弹窗构造器（静态）────────────────────────────────
# ════════════════════════════════════════════════════════════
## 在 host 上创建标题 + 可滚动内容区的通用层叠弹窗。
## 会自动替换并清理已有名为 "_OverlayPopup" 的节点。
static func make_overlay_popup(host: Control, title: String,
        content_builder: Callable) -> void:
    var old = host.get_node_or_null("_OverlayPopup")
    if old: old.queue_free()

    var overlay = Control.new()
    overlay.name = "_OverlayPopup"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    host.add_child(overlay)

    var bg = ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0, 0, 0, 0.72)
    bg.mouse_filter = Control.MOUSE_FILTER_STOP
    bg.gui_input.connect(func(ev):
        if ev is InputEventMouseButton and ev.pressed: overlay.queue_free()
    )
    overlay.add_child(bg)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(560, 500)
    panel.layout_mode = 1
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
    panel.add_theme_stylebox_override("panel",
        ThemeUtils.create_style(Color(0.07, 0.08, 0.12, 0.98), 14, Color(1, 1, 1, 0.10), 1))
    overlay.add_child(panel)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left",   24)
    margin.add_theme_constant_override("margin_right",  24)
    margin.add_theme_constant_override("margin_top",    16)
    margin.add_theme_constant_override("margin_bottom", 16)
    panel.add_child(margin)

    var outer = VBoxContainer.new()
    outer.add_theme_constant_override("separation", 12)
    margin.add_child(outer)

    var title_row = HBoxContainer.new()
    outer.add_child(title_row)

    var title_lbl = Label.new()
    title_lbl.text = title
    title_lbl.add_theme_font_size_override("font_size", 22)
    title_lbl.add_theme_color_override("font_color", Color(0.94, 0.92, 0.88, 1))
    title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(title_lbl)

    var close_btn = Button.new()
    close_btn.text = "✕"
    close_btn.custom_minimum_size = Vector2(36, 36)
    close_btn.add_theme_font_size_override("font_size", 18)
    close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    close_btn.pressed.connect(func(): overlay.queue_free())
    title_row.add_child(close_btn)

    var sep = HSeparator.new()
    sep.modulate = Color(1, 1, 1, 0.1)
    outer.add_child(sep)

    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    outer.add_child(scroll)

    var content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    scroll.add_child(content)

    content_builder.call(content)

# ════════════════════════════════════════════════════════════

# ── 📔 日记弹窗 ──────────────────────────────────────────────
# ════════════════════════════════════════════════════════════
func show_diary_popup() -> void:
    PopupManager.make_overlay_popup(_host, "📔  我的日记", func(content_vbox: VBoxContainer):
        var diary = GameManager.diary.duplicate()
        diary.reverse()
        if diary.is_empty():
            var empty = Label.new()
            empty.text = "今天还没有记下任何事情..."
            empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
            empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            content_vbox.add_child(empty)
        for entry in diary:
            var row = VBoxContainer.new()
            row.add_theme_constant_override("separation", 2)

            var meta_lbl = Label.new()
            meta_lbl.text = "📅 第%d天 · %s%s · %s" % [
                entry.get("day", 0),
                entry.get("grade", ""),
                entry.get("grade", "").is_empty() and "上学期" or "",
                entry.get("slot", "")
            ]
            meta_lbl.add_theme_font_size_override("font_size", 10)
            meta_lbl.add_theme_color_override("font_color", Color(1, 0.84, 0.2, 0.7))

            var text_lbl = Label.new()
            text_lbl.text = entry.get("text", "")
            text_lbl.add_theme_font_size_override("font_size", 13)
            text_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.86, 0.9))
            text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

            var sep = HSeparator.new()
            sep.modulate = Color(1, 1, 1, 0.06)

            row.add_child(meta_lbl)
            row.add_child(text_lbl)
            row.add_child(sep)
            content_vbox.add_child(row)
    )

# ════════════════════════════════════════════════════════════
# ── 🎒 背包弹窗 ──────────────────────────────────────────────
# ════════════════════════════════════════════════════════════
func show_inventory_popup() -> void:
    PopupManager.make_overlay_popup(_host, "🎒  我的背包", func(content_vbox: VBoxContainer):
        var inv = GameManager.inventory
        if inv.is_empty():
            var empty = Label.new()
            empty.text = "背包空空如也..."
            empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
            empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            content_vbox.add_child(empty)
            return

        var grid = GridContainer.new()
        grid.columns = 2
        grid.add_theme_constant_override("h_separation", 12)
        grid.add_theme_constant_override("v_separation", 12)
        grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content_vbox.add_child(grid)

        for item_id in inv.keys():
            var count = inv[item_id]
            if count <= 0: continue
            var item_meta = GameManager.ITEM_DB.get(item_id, {})
            if item_meta.is_empty(): continue

            var card = PanelContainer.new()
            card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            var card_style = StyleBoxFlat.new()
            card_style.bg_color = Color(0.10, 0.12, 0.18, 1)
            card_style.corner_radius_top_left    = 6; card_style.corner_radius_top_right    = 6
            card_style.corner_radius_bottom_left = 6; card_style.corner_radius_bottom_right = 6
            card.add_theme_stylebox_override("panel", card_style)

            var margin = MarginContainer.new()
            margin.add_theme_constant_override("margin_left",   10)
            margin.add_theme_constant_override("margin_right",  10)
            margin.add_theme_constant_override("margin_top",    10)
            margin.add_theme_constant_override("margin_bottom", 10)
            card.add_child(margin)

            var hbox = HBoxContainer.new()
            hbox.add_theme_constant_override("separation", 12)
            margin.add_child(hbox)

            var icon_lbl = Label.new()
            icon_lbl.text = item_meta.get("icon", "📦")
            icon_lbl.add_theme_font_size_override("font_size", 32)
            icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            hbox.add_child(icon_lbl)

            var info_vbox = VBoxContainer.new()
            info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
            hbox.add_child(info_vbox)

            var name_row = HBoxContainer.new()
            var name_lbl = Label.new()
            name_lbl.text = item_meta.get("name", "未知物品")
            name_lbl.add_theme_font_size_override("font_size", 14)
            name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
            name_row.add_child(name_lbl)

            var count_lbl = Label.new()
            count_lbl.text = "x" + str(count)
            count_lbl.add_theme_font_size_override("font_size", 14)
            count_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
            count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            count_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
            name_row.add_child(count_lbl)
            info_vbox.add_child(name_row)

            var desc_lbl = Label.new()
            desc_lbl.text = item_meta.get("desc", "")
            desc_lbl.add_theme_font_size_override("font_size", 11)
            desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
            desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            desc_lbl.custom_minimum_size = Vector2(0, 20)
            info_vbox.add_child(desc_lbl)

            grid.add_child(card)
    )

# ════════════════════════════════════════════════════════════
# ── 🏆 排行榜弹窗 ────────────────────────────────────────────
# ════════════════════════════════════════════════════════════
func show_leaderboard_popup() -> void:
    PopupManager.make_overlay_popup(_host, "🏆  学霸排行榜 (全服)", func(content_vbox: VBoxContainer):
        var status_lbl = Label.new()
        status_lbl.text = "正在连接网络，拉取最新排行榜数据..."
        status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
        status_lbl.add_theme_font_size_override("font_size", 14)
        content_vbox.add_child(status_lbl)

        var list_vbox = VBoxContainer.new()
        list_vbox.add_theme_constant_override("separation", 10)
        content_vbox.add_child(list_vbox)

        # 首次加载：先上报分数，再拉取榜单
        var initial_callable = func(data: Array):
            _fill_leaderboard_data(data, list_vbox, status_lbl)
        NetworkManager.leaderboard_loaded.connect(initial_callable, CONNECT_ONE_SHOT)
        NetworkManager.submit_score(GameManager.stats.get("intellect", 10), func():
            NetworkManager.get_leaderboard()
        )

        var sep = HSeparator.new()
        sep.modulate = Color(1, 1, 1, 0.1)
        content_vbox.add_child(sep)

        var self_info = HBoxContainer.new()
        self_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content_vbox.add_child(self_info)

        var self_lbl = Label.new()
        self_lbl.text = "我的当前智力值: %d (已自动同步上报)" % GameManager.stats.get("intellect", 10)
        self_lbl.add_theme_font_size_override("font_size", 14)
        self_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
        self_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        self_info.add_child(self_lbl)

        var refresh_btn = Button.new()
        refresh_btn.text = "🔄 刷新"
        refresh_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        refresh_btn.custom_minimum_size = Vector2(90, 42)
        refresh_btn.add_theme_font_size_override("font_size", 13)
        refresh_btn.pressed.connect(func():
            for child in list_vbox.get_children(): child.queue_free()
            var loading = Label.new()
            loading.text = "正在重新拉取..."
            loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            loading.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
            loading.add_theme_font_size_override("font_size", 14)
            list_vbox.add_child(loading)

            var refresh_callable = func(newdata: Array):
                _fill_leaderboard_data(newdata, list_vbox, loading)
            NetworkManager.leaderboard_loaded.connect(refresh_callable, CONNECT_ONE_SHOT)
            NetworkManager.submit_score(GameManager.stats.get("intellect", 10), func():
                NetworkManager.get_leaderboard()
            )
        )
        self_info.add_child(refresh_btn)
    )

func _fill_leaderboard_data(data: Array, list_vbox: VBoxContainer, status_lbl: Label) -> void:
    if is_instance_valid(status_lbl):
        status_lbl.queue_free()

    for child in list_vbox.get_children():
        if child != status_lbl: child.queue_free()

    if data.is_empty():
        var empty = Label.new()
        empty.text = "暂无排行榜数据，服务器连接异常或尚未开榜。"
        empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 0.6))
        empty.add_theme_font_size_override("font_size", 14)
        list_vbox.add_child(empty)
        return

    for i in range(data.size()):
        var item     = data[i]
        var rank_num = i + 1
        var username = item.get("username", "神秘同学")
        var school   = item.get("school",   "西湖中学")
        var score    = item.get("intellect", 10)

        var row = PanelContainer.new()
        row.custom_minimum_size = Vector2(0, 54)
        var rs = StyleBoxFlat.new()
        rs.bg_color = Color(0.08, 0.10, 0.16)
        if username == GameManager.player_name:
            rs.bg_color      = Color(0.18, 0.16, 0.12)
            rs.border_width_left  = 1; rs.border_width_right  = 1
            rs.border_width_top   = 1; rs.border_width_bottom = 1
            rs.border_color  = Color(0.9, 0.7, 0.3, 0.7)
        rs.corner_radius_top_left    = 8; rs.corner_radius_top_right    = 8
        rs.corner_radius_bottom_left = 8; rs.corner_radius_bottom_right = 8
        row.add_theme_stylebox_override("panel", rs)

        var hbox = HBoxContainer.new()
        hbox.add_theme_constant_override("separation", 14)
        row.add_child(hbox)

        # 名次图标（前三金银铜）
        var rank_lbl = Label.new()
        rank_lbl.custom_minimum_size  = Vector2(50, 0)
        rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        rank_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
        rank_lbl.add_theme_font_size_override("font_size", 20)
        match rank_num:
            1: rank_lbl.text = "🥇"
            2: rank_lbl.text = "🥈"
            3: rank_lbl.text = "🥉"
            _:
                rank_lbl.text = "%d" % rank_num
                rank_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
        hbox.add_child(rank_lbl)

        var info = VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
        hbox.add_child(info)

        var name_lbl = Label.new()
        name_lbl.text = username
        name_lbl.add_theme_font_size_override("font_size", 15)
        name_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
        info.add_child(name_lbl)

        var school_lbl = Label.new()
        school_lbl.text = school
        school_lbl.add_theme_font_size_override("font_size", 11)
        school_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
        info.add_child(school_lbl)

        var score_lbl = Label.new()
        score_lbl.text = "📚 智力值: %d" % score
        score_lbl.add_theme_font_size_override("font_size", 15)
        score_lbl.add_theme_color_override("font_color",
            Color(0.4, 0.8, 1.0) if username != GameManager.player_name else Color(1.0, 0.8, 0.3))
        score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        hbox.add_child(score_lbl)

        var spacer = Control.new()
        spacer.custom_minimum_size = Vector2(10, 0)
        hbox.add_child(spacer)

        list_vbox.add_child(row)

# ════════════════════════════════════════════════════════════
# ── 💾 存档/读档弹窗 ──────────────────────────────────────────
# ════════════════════════════════════════════════════════════
func show_save_load_popup(is_saving: bool) -> void:
    var title = "💾  选择存档槽" if is_saving else "📂  读取存档"
    PopupManager.make_overlay_popup(_host, title, func(content_vbox: VBoxContainer):
        for slot in range(3):
            var meta     = SaveSystem.get_slot_meta(slot)
            var is_empty = meta.is_empty()

            var item_hbox = HBoxContainer.new()
            item_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            item_hbox.add_theme_constant_override("separation", 8)
            content_vbox.add_child(item_hbox)

            var row = Button.new()
            row.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
            row.custom_minimum_size    = Vector2(0, 56)
            row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

            var rs = StyleBoxFlat.new()
            rs.bg_color = Color(0.08, 0.10, 0.16)
            rs.corner_radius_top_left    = 8; rs.corner_radius_top_right    = 8
            rs.corner_radius_bottom_left = 8; rs.corner_radius_bottom_right = 8
            rs.border_width_left  = 1; rs.border_width_right  = 1
            rs.border_width_top   = 1; rs.border_width_bottom = 1
            rs.border_color = Color(0.3, 0.5, 0.8, 0.4)
            row.add_theme_stylebox_override("normal", rs)
            var rh = rs.duplicate(); rh.bg_color = Color(0.14, 0.17, 0.26)
            row.add_theme_stylebox_override("hover", rh)

            var hbox = HBoxContainer.new()
            hbox.anchors_preset = Control.PRESET_FULL_RECT
            hbox.add_theme_constant_override("separation", 12)
            row.add_child(hbox)

            var slot_icon = Label.new()
            slot_icon.text = "💾 Slot %d" % (slot + 1)
            slot_icon.add_theme_font_size_override("font_size", 13)
            slot_icon.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
            slot_icon.custom_minimum_size = Vector2(70, 0)
            slot_icon.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
            hbox.add_child(slot_icon)

            var info = VBoxContainer.new()
            info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            info.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
            hbox.add_child(info)

            var name_row = Label.new()
            if is_empty:
                name_row.text = "【空档】"
                name_row.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
            else:
                name_row.text = "%s  ·  第%d天" % [meta.player_name, meta.day]
                name_row.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
            name_row.add_theme_font_size_override("font_size", 13)
            info.add_child(name_row)

            if not is_empty:
                var time_lbl2 = Label.new()
                time_lbl2.text = meta.saved_at
                time_lbl2.add_theme_font_size_override("font_size", 10)
                time_lbl2.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
                info.add_child(time_lbl2)

            var s = slot
            row.pressed.connect(func():
                var popup = _host.get_node_or_null("_OverlayPopup")
                if popup: popup.queue_free()
                if is_saving:
                    if SaveSystem.save_game(s):
                        GameManager.add_log("💾 存档成功 (Slot %d)" % (s + 1))
                        GameManager.show_toast.emit("💾 已保存到 Slot %d" % (s + 1))
                else:
                    if SaveSystem.load_game(s):
                        GameManager.add_log("📂 读档成功 (Slot %d)" % (s + 1))
                        GameManager.show_toast.emit("📂 已读取 Slot %d" % (s + 1))
                        _on_update_ui_cb.call()
                    else:
                        # S3：按 SaveSystem 返回的错误码给出准确原因，
                        # 不再把「存档损坏 / 版本过新」一律误报成「没有存档」。
                        var err = SaveSystem.get_last_load_error()
                        GameManager.show_toast.emit("⚠️ Slot %d：%s" % [s + 1, err.get("msg", "读取失败")])
            )
            item_hbox.add_child(row)

            # ── 云端同步按钮 ──
            var cloud_btn = Button.new()
            cloud_btn.custom_minimum_size = Vector2(88, 56)
            cloud_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            var cs = StyleBoxFlat.new()
            cs.bg_color = Color(0.12, 0.15, 0.22) if is_saving else Color(0.1, 0.18, 0.15)
            cs.border_width_left  = 1; cs.border_width_right  = 1
            cs.border_width_top   = 1; cs.border_width_bottom = 1
            cs.border_color = Color(0.4, 0.7, 0.9, 0.4) if is_saving else Color(0.4, 0.9, 0.6, 0.4)
            cs.corner_radius_top_left    = 8; cs.corner_radius_top_right    = 8
            cs.corner_radius_bottom_left = 8; cs.corner_radius_bottom_right = 8
            cloud_btn.add_theme_stylebox_override("normal", cs)
            var ch = cs.duplicate(); ch.bg_color = cs.bg_color.lightened(0.1)
            cloud_btn.add_theme_stylebox_override("hover", ch)

            cloud_btn.text = "☁️ 上传云" if is_saving else "☁️ 云恢复"
            cloud_btn.add_theme_font_size_override("font_size", 11)
            cloud_btn.add_theme_color_override("font_color",
                Color(0.6, 0.85, 1.0) if is_saving else Color(0.5, 0.95, 0.7))

            cloud_btn.pressed.connect(func():
                var popup = _host.get_node_or_null("_OverlayPopup")
                if is_saving:
                    if is_empty:
                        GameManager.show_toast.emit("❌ 本地该槽位为空，请先存档再上传云端")
                        return
                    cloud_btn.disabled = true
                    cloud_btn.text = "上传中..."
                    var callable = func(success: bool, msg: String):
                        if popup: popup.queue_free()
                        GameManager.show_toast.emit(msg)
                    NetworkManager.cloud_save_uploaded.connect(callable, CONNECT_ONE_SHOT)
                    NetworkManager.upload_cloud_save(s)
                else:
                    cloud_btn.disabled = true
                    cloud_btn.text = "下载中..."
                    var callable = func(success: bool, d: Dictionary):
                        if popup: popup.queue_free()
                        if success:
                            if SaveSystem.load_from_dict(d):
                                GameManager.add_log("☁️ 云端存档读取成功")
                                GameManager.show_toast.emit("☁️ 云端存档已成功同步至本地！")
                                _on_update_ui_cb.call()
                        else:
                            GameManager.show_toast.emit("⚠️ 云端 Slot %d 没有存档或下载失败" % (s + 1))
                    NetworkManager.cloud_save_downloaded.connect(callable, CONNECT_ONE_SHOT)
                    NetworkManager.download_cloud_save(s)
            )
            item_hbox.add_child(cloud_btn)

        # 存档界面额外显示「读档」入口
        if is_saving:
            var load_btn = Button.new()
            load_btn.text = "📂  切换到「读档」"
            load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            load_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            var ls = StyleBoxFlat.new()
            ls.bg_color = Color(0.05, 0.12, 0.08)
            ls.corner_radius_top_left    = 8; ls.corner_radius_top_right    = 8
            ls.corner_radius_bottom_left = 8; ls.corner_radius_bottom_right = 8
            load_btn.add_theme_stylebox_override("normal", ls)
            load_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
            load_btn.pressed.connect(func():
                var popup = _host.get_node_or_null("_OverlayPopup")
                if popup: popup.queue_free()
                show_save_load_popup(false)
            )
            content_vbox.add_child(load_btn)
    )
