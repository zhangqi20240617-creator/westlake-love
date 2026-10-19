## HotspotExploreUI.gd
## 热点探索 UI 代理类
## 负责在进入某地点后构建热点按钮（带 Anchor 定位 + 微动效），
## 以及处理热点点击后的各类子界面跳转（微信/商店/许愿/烹饪/普通事件）。

class_name HotspotExploreUI

# ── 依赖节点引用 ────────────────────────────────────────────
var _dialogue_ui:        Control
var _location_explore_ui: Control
var _loc_bg:             TextureRect
var _hotspot_container:  Control

# ── 回调引用（由 MainGame 注入）──────────────────────────────
var _host:               Control    # 用于 add_child
var _on_update_ui_cb:    Callable   # func()
var _on_board_refresh_cb: Callable  # func()  → board_ui.show_center_info(self)

# ── 初始化 ──────────────────────────────────────────────────
func setup(host: Control,
           dialogue_ui: Control,
           location_explore_ui: Control,
           loc_bg: TextureRect,
           hotspot_container: Control,
           on_update_ui: Callable,
           on_board_refresh: Callable) -> void:
    _host                = host
    _dialogue_ui         = dialogue_ui
    _location_explore_ui = location_explore_ui
    _loc_bg              = loc_bg
    _hotspot_container   = hotspot_container
    _on_update_ui_cb     = on_update_ui
    _on_board_refresh_cb = on_board_refresh

# ════════════════════════════════════════════════════════════
# ── 地点选中入口（含特殊事件优先级路由）────────────────────────
# ════════════════════════════════════════════════════════════
func on_location_selected(loc_id: String) -> void:
    SeasonManager.record_location_visit(loc_id)

    # 1. 优先检查特殊剧情事件（非重复主线/角色剧情，或高优强制事件）
    var ev = DataManager.get_available_event(loc_id)
    var is_special = not ev.is_empty() and (not ev.get("repeatable", false) or ev.get("priority", 0) >= 50)
    if is_special:
        _location_explore_ui.hide()
        _dialogue_ui.show()
        _dialogue_ui.start_event(ev)
        return

    # 2. 有热点 → 进入探索模式（含文化节等临时热点）
    var loc_data = GameManager.locations.get(loc_id, {})
    var hotspots = GameManager.get_location_hotspots(loc_id)
    if hotspots.size() > 0:
        enter_explore_mode(loc_id, loc_data, hotspots)
    else:
        # 无热点 → 直接随机事件搜索
        _location_explore_ui.hide()
        _dialogue_ui.show()
        _dialogue_ui.start_event_search(loc_id)

    # 3. NG+ 熟悉感台词：地点内有相关角色时触发
    _check_ng_familiarity_for_location(loc_id)


# ════════════════════════════════════════════════════════════
# ── 进入探索模式：清空旧热点 → 加载背景 → 重建热点按钮 ─────
# ════════════════════════════════════════════════════════════
## hotspots 参数：已合并临时热点的列表（by on_location_selected）；
## 为空时向后兼容，直接读 loc_data["hotspots"]
func enter_explore_mode(loc_id: String, loc_data: Dictionary,
        hotspots: Array = []) -> void:

    _dialogue_ui.hide()
    _location_explore_ui.show()

    # 加载背景图
    if loc_data.has("bg"):
        _loc_bg.texture = GameUtils.load_bg_texture(
            loc_data["bg"], GameManager.slot_index, GameManager.current_weather)
    else:
        _loc_bg.texture = null

    # 清空旧热点按钮
    for child in _hotspot_container.get_children():
        child.queue_free()

    # 合并临时热点（hotspots 由外部传入，已含文化节追加项）
    var spots = hotspots if not hotspots.is_empty() else loc_data.get("hotspots", [])

    # 构建新热点按钮
    for spot in spots:
        var btn = Button.new()
        btn.text = spot.get("label", "🔍 调查")
        btn.add_theme_font_size_override("font_size", 14)

        # 样式
        var s = StyleBoxFlat.new()
        s.bg_color = Color(0, 0, 0, 0.6)
        s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
        s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
        s.border_width_left  = 1; s.border_width_right  = 1
        s.border_width_top   = 1; s.border_width_bottom = 1
        s.border_color = Color(1, 1, 1, 0.5)
        s.content_margin_left  = 10; s.content_margin_right  = 10
        s.content_margin_top   = 5;  s.content_margin_bottom = 5
        btn.add_theme_stylebox_override("normal", s)
        var h = s.duplicate(); h.bg_color = Color(0.2, 0.2, 0.2, 0.8)
        btn.add_theme_stylebox_override("hover", h)

        btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

        # Anchor 定位（分辨率自适应，彻底避免节点隐藏时 size=0 导致定位失败）
        btn.anchor_left   = spot["pos"].x
        btn.anchor_right  = spot["pos"].x
        btn.anchor_top    = spot["pos"].y
        btn.anchor_bottom = spot["pos"].y
        btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
        btn.grow_vertical   = Control.GROW_DIRECTION_BOTH

        # 点击处理
        btn.pressed.connect(func(): on_hotspot_clicked(loc_id, spot.get("event_id", "")))

        # ── 呼吸微动效 ──────────────────────────────────────
        btn.resized.connect(func(): btn.pivot_offset = btn.size / 2)
        btn.mouse_entered.connect(func():
            var t = btn.create_tween().set_parallel(true)
            t.tween_property(btn, "scale",    Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_SINE)
            t.tween_property(btn, "modulate", Color(1.15, 1.15, 1.3),  0.15)
        )
        btn.mouse_exited.connect(func():
            var t = btn.create_tween().set_parallel(true)
            t.tween_property(btn, "scale",    Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)
            t.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0),  0.15)
        )

        _hotspot_container.add_child(btn)

# ════════════════════════════════════════════════════════════
# ── 热点点击路由 ─────────────────────────────────────────────
# ════════════════════════════════════════════════════════════
func on_hotspot_clicked(loc_id: String, event_id: String) -> void:
    # ── 特殊子界面跳转 ──────────────────────────────────────
    match event_id:
        "phone_wechat":
            _open_sub_ui("res://scripts/WeChatUI.gd", func(inst): pass)
            return
        "shop_ui":
            _open_sub_ui("res://scripts/ShopUI.gd", func(inst): pass)
            return
        "lakeside_wishes":
            _open_sub_ui("res://scripts/LakesideWishesUI.gd", func(inst): pass)
            return
        "claw_machine":
            _open_sub_ui("res://scripts/minigames/ClawMachineUI.gd",
                func(inst): pass,
                func():
                    _location_explore_ui.show()
                    _on_update_ui_cb.call()
                    _on_board_refresh_cb.call()
            )
            return
        "badminton_rally":
            _open_sub_ui("res://scripts/minigames/BadmintonRallyUI.gd",
                func(inst): pass,
                func():
                    _location_explore_ui.show()
                    _on_update_ui_cb.call()
                    _on_board_refresh_cb.call()
            )
            return
        "paper_slip":
            _open_sub_ui("res://scripts/minigames/PaperSlipStealthUI.gd",
                func(inst): pass,
                func():
                    _location_explore_ui.show()
                    _on_update_ui_cb.call()
                    _on_board_refresh_cb.call()
            )
            return
        "lake_shutter":
            _open_sub_ui("res://scripts/minigames/WestLakeShutterUI.gd",
                func(inst): pass,
                func():
                    _location_explore_ui.show()
                    _on_update_ui_cb.call()
                    _on_board_refresh_cb.call()
            )
            return
        "boba_craft":
            _open_sub_ui("res://scripts/minigames/BobaTeaCraftUI.gd",
                func(inst): pass,
                func():
                    _location_explore_ui.show()
                    _on_update_ui_cb.call()
                    _on_board_refresh_cb.call()
            )
            return
        "west_lake_stamp":
            _open_west_lake_stamp_checkin()
            return
        "cooking_market", "cooking_ui":
            _open_sub_ui("res://scripts/CookingUI.gd",
                func(inst): inst.set_meta("start_tab", 0 if event_id == "cooking_market" else 1),
                func():
                    _location_explore_ui.show()
                    _on_update_ui_cb.call()
                    _on_board_refresh_cb.call()
            )
            return
        "class_study", "home_study":
            # 分科复习弹窗：选科目 → 加分 → 推进时段
            _location_explore_ui.hide()
            var popup = StudySubjectPopup.open(_host)
            popup.closed.connect(func():
                _location_explore_ui.show()
                _on_update_ui_cb.call()
                _on_board_refresh_cb.call()
            )
            return
        "cultural_festival":
            # 文化节专属：使用通用随机事件搜索（事件库中需有 tag=cultural_festival 的事件）
            # 暂无专属事件时 fallback 到 random_event
            _location_explore_ui.hide()
            _dialogue_ui.show()
            var cf_ev = DataManager.get_event_by_id("cultural_festival")
            if not cf_ev.is_empty():
                cf_ev = cf_ev.duplicate(true)
                cf_ev["location"] = loc_id
                _dialogue_ui.start_event(cf_ev)
            else:
                _dialogue_ui.start_event_search(loc_id)
            return

    # ── 普通热点：展示对话 ──────────────────────────────────
    if _check_dean_dating_catch(loc_id, event_id): return
    
    _location_explore_ui.hide()
    _dialogue_ui.show()

    if event_id == "random_event":
        _dialogue_ui.start_event_search(loc_id)
        return

    var ev = DataManager.get_event_by_id(event_id)
    if not ev.is_empty():
        var ev_copy = ev.duplicate(true)
        ev_copy["location"] = loc_id
        _dialogue_ui.start_event(ev_copy)
    else:
        # Fallback：无事件时的默认提示
        _dialogue_ui.start_event({
            "id":       "generic_hotspot",
            "location": loc_id,
            "scenes":   [{"speaker": null, "text": "你查看了这里，但似乎没什么特别的发生。"}]
        })

# ── 西湖十景集章打卡（GDD §2.3）───────────────────────────────
## 打开面板本身免费（玩家可进去看看还差哪几景就退出，不消耗时段）；
## 真正选中某景才 grant_stamp() + 播放 vignette，由 DialogueUI 自然 advance_time()。
func _open_west_lake_stamp_checkin() -> void:
    var holder := {}   # 借字典跨闭包捕获面板实例（实例由 _open_sub_ui 内部 new 出）

    var pre_cb := func(inst):
        inst.set_meta("mode", "checkin")
        holder["ui"] = inst

    var close_cb := func():
        var sid := ""
        var ui = holder.get("ui", null)
        if is_instance_valid(ui):
            sid = str(ui.picked_sid)
        var vignette: Dictionary = {}
        if sid != "":
            # 授予与演出分离：flag / day / 集满判定原子发生在 CollectionManager
            CollectionManager.grant_stamp(sid, true)
            vignette = CollectionManager.build_stamp_vignette(sid)
        if vignette.is_empty():
            # 空手退出（或数据异常兜底）：恢复探索层，不消耗时段
            _location_explore_ui.show()
            _on_update_ui_cb.call()
            _on_board_refresh_cb.call()
            return
        _location_explore_ui.hide()
        _dialogue_ui.show()
        _dialogue_ui.start_event(vignette)

    _open_sub_ui("res://scripts/StampBookUI.gd", pre_cb, close_cb)

# ── 通用子 UI 打开器──────────────────────────────────────────
## 隐藏探索层 → new 实例 → pre_add_cb → add_child
## on_close_cb: 可选。传入时使用自定义关闭回调；不传入时使用默认恢复逻辑
## （默认：show location_explore_ui + update_ui）
func _open_sub_ui(script_path: String, pre_add_cb: Callable,
        on_close_cb: Callable = Callable()) -> void:
    _location_explore_ui.hide()
    _dialogue_ui.hide()
    var scr = load(script_path)
    if not scr: return
    var inst = scr.new()
    pre_add_cb.call(inst)
    _host.add_child(inst)
    # 优先使用调用方传入的自定义回调，否则使用默认展示逻辑
    if on_close_cb.is_valid():
        inst.closed.connect(on_close_cb)
    else:
        inst.closed.connect(func():
            _location_explore_ui.show()
            _on_update_ui_cb.call()
        )

# ── NG+ 熟悉感检测（进入地点时触发，对地点相关角色做一次性检测）──
func _check_ng_familiarity_for_location(loc_id: String) -> void:
    # 根据地点找相关角色（简单映射）
    var loc_char_map = {
        "classroom":    ["yutong", "wanqing"],
        "library":      ["yutong", "wanqing"],
        "playground":   ["xiaoxia", "zicheng"],
        "community":    ["jingjing", "jingjing_m"],
        "lakeside":     ["yutong", "jingjing", "wanqing"],
        "music_room":   ["yifei"],
        "school_gate":  ["jingjing", "xiaoxia"],
    }
    var chars: Array = loc_char_map.get(loc_id, [])
    for char_id in chars:
        var line = GameManager.get_ng_familiarity_line(char_id)
        if line != "":
            var meta = GameManager.char_meta.get(char_id, {})
            var emoji = meta.get("emoji", "💫")
            GameManager.show_toast.emit("%s %s" % [emoji, line])
            break  # 每次进入地点只触发一个角色，避免刷屏

# ── 教导主任早恋抓包（点击约会热点时概率拦截）──────────────────────
func _check_dean_dating_catch(loc_id: String, event_id: String) -> bool:
    if loc_id == "playground" or loc_id == "corridor":
        if GameManager.stats.get("dean_suspicion", 0) > 50 and randf() < 0.3:
            var ev = DataManager.get_event_by_id("dean_catch_dating")
            if not ev.is_empty():
                _location_explore_ui.hide()
                _dialogue_ui.show()
                _dialogue_ui.start_event(ev)
                return true
    return false
