## GalleryPopupUI.gd
## 画廊弹窗 & 全屏浏览 代理类
## 负责渲染画廊卡片网格、全屏立绘/视频浏览，
## 从 MainGame.gd 解耦，保持架构统一。

class_name GalleryPopupUI

# ── 宿主节点引用（用于 add_child 等操作）────────────────────
var _host: Control

# ── 构造函数注入宿主节点 ─────────────────────────────────────
func setup(host: Control) -> void:
    _host = host

# ════════════════════════════════════════════════════════════
# ── 画廊弹窗入口 ─────────────────────────────────────────────
# ════════════════════════════════════════════════════════════
func show_gallery_popup(make_overlay_popup_cb: Callable) -> void:
    make_overlay_popup_cb.call("🖼  立绘画廊", func(content_vbox: VBoxContainer):
        # ── 收集进度条 ──────────────────────────────────────
        var prog = GameManager.get_gallery_progress()
        var prog_row = HBoxContainer.new()
        prog_row.add_theme_constant_override("separation", 10)

        var prog_lbl = Label.new()
        prog_lbl.text = "收集进度"
        prog_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
        prog_lbl.add_theme_font_size_override("font_size", 13)
        prog_row.add_child(prog_lbl)

        var prog_bar = ProgressBar.new()
        prog_bar.min_value = 0
        prog_bar.max_value = prog.total
        prog_bar.value     = prog.unlocked
        prog_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        prog_bar.custom_minimum_size   = Vector2(0, 18)
        prog_row.add_child(prog_bar)

        var prog_num = Label.new()
        prog_num.text = "%d / %d" % [prog.unlocked, prog.total]
        prog_num.add_theme_font_size_override("font_size", 13)
        prog_num.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
        prog_row.add_child(prog_num)

        content_vbox.add_child(prog_row)

        var sep = HSeparator.new()
        sep.modulate = Color(1, 1, 1, 0.1)
        content_vbox.add_child(sep)

        # ── 卡片网格 ────────────────────────────────────────
        var grid = GridContainer.new()
        grid.columns = 4
        grid.add_theme_constant_override("h_separation", 10)
        grid.add_theme_constant_override("v_separation", 10)
        grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content_vbox.add_child(grid)

        for item in GameManager.GALLERY_ITEMS:
            var is_unlocked = GameManager.is_gallery_unlocked(item)
            var char_id     = item.char
            var pose_id     = item.pose
            var meta        = GameManager.char_meta.get(char_id, {})
            var char_color  = Color(meta.get("color", "#888888"))

            # 外层容器
            var card = PanelContainer.new()
            card.custom_minimum_size    = Vector2(100, 150)
            card.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
            var card_style = StyleBoxFlat.new()
            card_style.bg_color = Color(0.05, 0.06, 0.10, 1)
            card_style.corner_radius_top_left    = 8; card_style.corner_radius_top_right    = 8
            card_style.corner_radius_bottom_left = 8; card_style.corner_radius_bottom_right = 8
            card_style.border_width_left  = 1; card_style.border_width_right  = 1
            card_style.border_width_top   = 1; card_style.border_width_bottom = 1
            card_style.border_color = char_color if is_unlocked else Color(1, 1, 1, 0.08)
            card_style.border_color.a = 0.5 if is_unlocked else 0.08
            card.add_theme_stylebox_override("panel", card_style)

            var vbox = VBoxContainer.new()
            vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
            vbox.add_theme_constant_override("separation", 0)
            card.add_child(vbox)

            # 图片区
            var img_area = Control.new()
            img_area.custom_minimum_size    = Vector2(0, 108)
            img_area.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
            img_area.size_flags_vertical    = Control.SIZE_EXPAND_FILL
            img_area.clip_contents = true
            vbox.add_child(img_area)

            if is_unlocked:
                var tex_rect = TextureRect.new()
                tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
                tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
                var png = "res://assets/sprites/%s/%s.png" % [char_id, pose_id]
                var jpg = "res://assets/sprites/%s/%s.jpg" % [char_id, pose_id]
                if ResourceLoader.exists(png):   tex_rect.texture = load(png)
                elif ResourceLoader.exists(jpg): tex_rect.texture = load(jpg)
                img_area.add_child(tex_rect)
            else:
                # 锁定状态
                var lock_bg = ColorRect.new()
                lock_bg.color = Color(0.03, 0.03, 0.05, 1)
                lock_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                img_area.add_child(lock_bg)

                var lock_lbl = Label.new()
                lock_lbl.text = "🔒"
                lock_lbl.add_theme_font_size_override("font_size", 28)
                lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                lock_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
                lock_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                img_area.add_child(lock_lbl)

            # 视频角标
            if is_unlocked and item.get("type", "") == "video":
                var badge = Label.new()
                badge.text = "▶"
                badge.add_theme_font_size_override("font_size", 14)
                badge.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
                badge.layout_mode        = 1
                badge.anchor_right       = 1.0
                badge.grow_horizontal    = Control.GROW_DIRECTION_BEGIN
                badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
                badge.custom_minimum_size  = Vector2(0, 24)
                img_area.add_child(badge)

            # 底部标签区
            var label_panel = PanelContainer.new()
            label_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            var lp_style = StyleBoxFlat.new()
            lp_style.bg_color = Color(0, 0, 0, 0.6)
            lp_style.corner_radius_bottom_left  = 7; lp_style.corner_radius_bottom_right = 7
            label_panel.add_theme_stylebox_override("panel", lp_style)
            vbox.add_child(label_panel)

            var inner_vbox = VBoxContainer.new()
            inner_vbox.add_theme_constant_override("separation", 1)
            label_panel.add_child(inner_vbox)

            var name_lbl = Label.new()
            name_lbl.text = item.label if is_unlocked else "???"
            name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            name_lbl.add_theme_font_size_override("font_size", 11)
            name_lbl.add_theme_color_override("font_color",
                char_color if is_unlocked else Color(1, 1, 1, 0.2))
            inner_vbox.add_child(name_lbl)

            if not is_unlocked:
                var hint_lbl = Label.new()
                hint_lbl.text = item.get("hint", "")
                hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                hint_lbl.add_theme_font_size_override("font_size", 9)
                hint_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
                hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                inner_vbox.add_child(hint_lbl)

            # 点击覆盖层（已解锁才可点击）
            if is_unlocked:
                var overlay_btn = Button.new()
                overlay_btn.flat = true
                overlay_btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
                overlay_btn.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
                overlay_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
                overlay_btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
                overlay_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                overlay_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
                var _char_id = char_id
                var _pose_id = pose_id
                var _label   = item.label
                var _bg      = item.get("bg", "")
                var _type    = item.get("type", "image")
                overlay_btn.pressed.connect(func():
                    show_gallery_fullscreen(_char_id, _pose_id, _label, _bg, _type)
                )
                card.add_child(overlay_btn)

            grid.add_child(card)
    )

# ════════════════════════════════════════════════════════════
# ── 全屏立绘/视频浏览 ────────────────────────────────────────
# ════════════════════════════════════════════════════════════
func show_gallery_fullscreen(char_id: String, pose_id: String,
        label_text: String, bg_path: String = "", item_type: String = "image") -> void:

    var old = _host.get_node_or_null("_GalleryFullscreen")
    if old: old.queue_free()

    var fs = Control.new()
    fs.name = "_GalleryFullscreen"
    fs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _host.add_child(fs)

    var char_meta  = GameManager.char_meta.get(char_id, {})
    var char_color = Color(char_meta.get("color", "#5b9fd4")) if not char_meta.is_empty() else Color(0.35, 0.55, 0.85)

    # 深色底层背景
    var bg_rect2 = ColorRect.new()
    bg_rect2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg_rect2.color        = Color(0.03, 0.03, 0.06, 1.0)
    bg_rect2.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fs.add_child(bg_rect2)

    # 场景背景图
    if bg_path != "" and ResourceLoader.exists(bg_path):
        var scene_bg = TextureRect.new()
        scene_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        scene_bg.texture      = load(bg_path)
        scene_bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
        scene_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        scene_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        fs.add_child(scene_bg)

    # 暗化遮罩
    var dim = ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color        = Color(0, 0, 0, 0.45)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fs.add_child(dim)

    # 底部渐变暗角
    var grad_tex  = GradientTexture2D.new()
    var grad      = Gradient.new()
    grad.set_color(0, Color(0, 0, 0, 0.0))
    grad.set_color(1, Color(0, 0, 0, 0.7))
    grad.set_offset(0, 0.0); grad.set_offset(1, 1.0)
    grad_tex.gradient  = grad
    grad_tex.fill      = GradientTexture2D.FILL_LINEAR
    grad_tex.fill_from = Vector2(0.5, 0.5)
    grad_tex.fill_to   = Vector2(0.5, 1.0)
    var vignette = TextureRect.new()
    vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vignette.texture      = grad_tex
    vignette.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
    vignette.stretch_mode = TextureRect.STRETCH_SCALE
    vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fs.add_child(vignette)

    # 主内容：视频 或 静态立绘
    if item_type == "video":
        var ogv_path = "res://assets/sprites/%s/%s.ogv" % [char_id, pose_id]
        if ResourceLoader.exists(ogv_path):
            var vsp = VideoStreamPlayer.new()
            vsp.stream = load(ogv_path)
            vsp.loop   = true
            vsp.expand = true
            vsp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            vsp.mouse_filter = Control.MOUSE_FILTER_IGNORE
            fs.add_child(vsp)
            vsp.play()
            vsp.modulate.a = 0.0
            var tw = _host.create_tween()
            tw.tween_property(vsp, "modulate:a", 1.0, 0.4)
    else:
        var tex_rect = TextureRect.new()
        tex_rect.layout_mode  = 1
        tex_rect.anchor_left  = 0.25; tex_rect.anchor_right  = 0.75
        tex_rect.anchor_top   = 0.0;  tex_rect.anchor_bottom = 1.0
        tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
        tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var png = "res://assets/sprites/%s/%s.png" % [char_id, pose_id]
        var jpg = "res://assets/sprites/%s/%s.jpg" % [char_id, pose_id]
        if ResourceLoader.exists(png):   tex_rect.texture = load(png)
        elif ResourceLoader.exists(jpg): tex_rect.texture = load(jpg)
        fs.add_child(tex_rect)

    # 底部立绘标签
    var label = Label.new()
    label.text         = label_text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.layout_mode  = 1
    label.anchor_top   = 1.0; label.anchor_bottom = 1.0
    label.anchor_left  = 0.0; label.anchor_right  = 1.0
    label.offset_top   = -50.0; label.offset_bottom = -10.0
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 20)
    label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
    fs.add_child(label)

    # 点击关闭提示
    var close_hint = Label.new()
    close_hint.text         = "点击任意处返回"
    close_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    close_hint.layout_mode  = 1
    close_hint.anchor_top   = 1.0; close_hint.anchor_bottom = 1.0
    close_hint.anchor_left  = 0.0; close_hint.anchor_right  = 1.0
    close_hint.offset_top   = -25.0; close_hint.offset_bottom = -5.0
    close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    close_hint.add_theme_font_size_override("font_size", 12)
    close_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
    fs.add_child(close_hint)

    # 全屏透明捕获层
    var click_capture = ColorRect.new()
    click_capture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    click_capture.color        = Color(0, 0, 0, 0)
    click_capture.mouse_filter = Control.MOUSE_FILTER_STOP
    click_capture.gui_input.connect(func(ev):
        if ev is InputEventMouseButton and ev.pressed:
            fs.queue_free()
    )
    fs.add_child(click_capture)
