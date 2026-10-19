extends Control

# UI 引用
@onready var bg_rect = $BG
@onready var name_label = $Box/NameTag/NameLabel
@onready var text_label = $Box/TextLabel
@onready var next_icon = $Box/NextIcon
@onready var choice_overlay = $ChoiceOverlay
@onready var choice_container = $ChoiceOverlay/VBoxContainer
@onready var sprite_left = $Sprites/Left
@onready var sprite_center = $Sprites/Center
@onready var sprite_right = $Sprites/Right
@onready var sprite_video = $Sprites/CenterVideo  # 视频立绘播放器


# 信号
signal event_started
signal event_finished
signal ending_triggered(ending_id: String)

# 对话状态
var current_event: Dictionary
var scene_index: int = 0
var is_typing: bool = false
var text_speed: float = 0.03
var _just_opened: bool = false # 防止打开瞬间误触跳过
var _should_skip_to_next_day: bool = false

# ── 打字机效果（_process 驱动，避免每字符创建 Timer）──
var _typing_full_text: String = ""
var _typing_index: int = 0
var _typing_elapsed: float = 0.0
var _next_icon_tween: Tween = null

# 资源路径存在性缓存，避免重复的文件系统 I/O 检查
var _path_exists_cache: Dictionary = {}

func _check_resource_exists(path: String) -> bool:
    if _path_exists_cache.has(path):
        return _path_exists_cache[path]
    var exists = ResourceLoader.exists(path)
    _path_exists_cache[path] = exists
    return exists


# ── 送礼系统 UI 变量 ──
var gift_btn: Button
var gift_overlay: ColorRect
var gift_vbox: VBoxContainer

func _ready():
    # 动态创建送礼按钮
    gift_btn = Button.new()
    gift_btn.text = "🎁 送礼"
    gift_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    gift_btn.custom_minimum_size = Vector2(80, 32)
    
    var s = StyleBoxFlat.new()
    s.bg_color = Color("#ec4899") # 粉色送礼
    s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
    s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
    s.content_margin_left = 10; s.content_margin_right = 10
    gift_btn.add_theme_stylebox_override("normal", s)
    var h = s.duplicate()
    h.bg_color = Color("#db2777")
    gift_btn.add_theme_stylebox_override("hover", h)
    gift_btn.add_theme_stylebox_override("pressed", h)
    
    # 定位在对话框 Box 右上角
    gift_btn.anchor_left = 1.0
    gift_btn.anchor_right = 1.0
    gift_btn.anchor_top = 0.0
    gift_btn.anchor_bottom = 0.0
    gift_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    gift_btn.offset_left = -100
    gift_btn.offset_top = -15
    gift_btn.offset_right = -20
    gift_btn.offset_bottom = 17
    
    $Box.add_child(gift_btn)
    gift_btn.pressed.connect(_on_gift_pressed)
    gift_btn.hide()
    
    _setup_gift_overlay()

# ── 启动对话 ────────────────────────────────────────────────
func start_event_search(loc_id: String):
    var ev = DataManager.get_available_event(loc_id)
    if not ev.is_empty():
        start_event(ev)
    else:
        var loc_data = GameManager.locations.get(loc_id, {})
        var loc_name = loc_data.get("name", "此处")
        var fallback_ev = {
            "id": "generic_" + loc_id,
            "location": loc_id,
            "scenes": [
                {"speaker": null, "text": "你在" + loc_name + "待了一会儿，这里显得很平静。"},
                {"speaker": null, "text": "稍微整理了一下心情，时间悄悄流逝了。"}
            ]
        }
        start_event(fallback_ev)

func start_event(event_data: Dictionary):
    if not event_data.has("scenes"):
        print("错误: 事件数据中缺少 scenes 字段")
        return
    current_event = event_data
    scene_index = 0
    _just_opened = true
    _should_skip_to_next_day = false
    var loc_id = event_data.get("location", "")
    if loc_id == null: loc_id = ""   # JSON null 防御
    # 加载背景图（默认按地点）
    _load_background(loc_id)
    # 事件级 bg 覆盖：若事件自带 bg（长假 CG 等），优先切换背景层
    var ev_bg = event_data.get("bg", "")
    if ev_bg != null and ev_bg != "":
        var tex = GameUtils.load_bg_texture(ev_bg, GameManager.slot_index, GameManager.current_weather)
        if tex != null:
            bg_rect.texture = tex
    # 事件级 addItem：事件自带 addItem 时直接入背包（如手作可赠物品）
    var ev_add_item = event_data.get("addItem", "")
    if ev_add_item != null and ev_add_item != "":
        CollectionManager.add_item(ev_add_item, 1)

    # 应用地点基础属性增益
    _apply_location_gains(loc_id)
    show()
    event_started.emit()
    play_current_scene()
    get_tree().create_timer(0.1).timeout.connect(func(): _just_opened = false)


func _load_background(loc_id: String):
    bg_rect.texture = null
    if loc_id == "": return
    
    var loc_data = GameManager.locations.get(loc_id, {})
    var base_bg_path = loc_data.get("bg", "")
    bg_rect.texture = GameUtils.load_bg_texture(base_bg_path, GameManager.slot_index, GameManager.current_weather)


func _apply_location_gains(loc_id: String):
    if loc_id == "": return
    var msgs = DataManager.apply_location_gains(loc_id)
    if msgs.size() > 0:
        GameManager.add_log("✨ " + ", ".join(msgs))
    # 天气加成提示（若当前天气对该地点有加成，弹出提示）
    var w = GameManager.current_weather
    var is_outdoor = loc_id in ["lakeside", "playground", "school_gate", "community", "amusement_park"]
    if (w == "rainy" or w == "snowy") and not is_outdoor:
        GameManager.show_toast.emit("🌧️ 烟雨加持！室内学习效率提升中…")
    elif w == "sunny" and is_outdoor:
        GameManager.show_toast.emit("☀️ 晴天加持！户外活动收益翻倍！")
    elif w == "snowy" and loc_id == "lakeside":
        GameManager.show_toast.emit("❄️ 漫天飞雪·断桥残雪之境！留意西湖边的特殊事件…")


func play_current_scene():
    next_icon.hide()
    if not current_event.has("scenes") or scene_index >= current_event.scenes.size():
        finish_event()
        return
    
    var scene = current_event.scenes[scene_index]
    
    if scene.get("skipToNextDay", false):
        _should_skip_to_next_day = true
    
    # 处理角色名字
    var char_id = scene.get("speaker", null)
    if char_id == "player":
        name_label.text = GameManager.player_name
    elif char_id and char_id != "":
        var char_data = DataManager.get_character(char_id)
        name_label.text = char_data.get("name", char_id) if not char_data.is_empty() else char_id
    else:
        name_label.text = ""
    
    # 处理文本占位符
    var final_text = scene.get("text", "")
    final_text = final_text.replace("{schoolName}", GameManager.school_name)
    final_text = final_text.replace("{playerName}", GameManager.player_name)
    type_text(final_text)
    
    # 检查是否有选项
    if scene.has("choices"):
        show_choices(scene.choices)
    else:
        choice_container.get_parent().hide()
        
    # 判定送礼按钮显隐
    if scene.has("choices") or char_id == null or str(char_id) == "" or char_id == "player" or char_id == "narrator" or not GameManager.char_meta.has(char_id):
        gift_btn.hide()
    else:
        gift_btn.show()
    
    # 渲染立绘
    update_sprites(scene)
    
    # 场景级别 setFlags（数组）→ 同步到画廊解锁
    # 与选项级 L474-477 的写法对称；纯新增分支，既有 setFlag 路径不动
    if scene.has("setFlags"):
        for f in scene["setFlags"]:
            GameManager.set_flag(f, true)
            GameManager.unlock_gallery(f)

    # 场景级别 setFlag → 同步到画廊解锁
    if scene.has("setFlag"):
        GameManager.set_flag(scene["setFlag"], true)
        GameManager.unlock_gallery(scene["setFlag"])

    # 场景级别 addItem → 直接入背包（如 int_craft_make 手作礼物）
    if scene.has("addItem") and scene["addItem"] != null and scene["addItem"] != "":
        CollectionManager.add_item(scene["addItem"], 1)

    # 场景级别 removeItem → 直接扣背包（DS-RN-04b：fw_craft_* 消耗 handmade_gift）
    # 对称于上方 addItem。DataManager 的 requireItem 只校验不消耗（L245-250），
    # 所以「消耗一个手作礼物」必须由本分支在场景级显式完成，
    # 否则 1 个 handmade_gift 可解锁全部 6 条手作事件。
    if scene.has("removeItem") and scene["removeItem"] != null and scene["removeItem"] != "":
        CollectionManager.remove_item(scene["removeItem"], 1)

    # 场景级别 grantFengwu → 风物志入册（DS-RN-04b：手作产物的**唯一**授予通道）
    # ⚠️ 手作产物走纯 flag、不进 ITEM_DB（D-2），因此：
    #    · 绝不可改用 addItem —— add_item 对非 ITEM_DB 物品会访问
    #      ITEM_DB[item_id].name 而崩溃（CollectionManager L11-20）。
    #    · 也不可改用 setFlag —— setFlag 只写 flag，不触发集满判定 / 入册 toast。
    #    grant_fengwu() 内部已做幂等 + toast + 24 件集满判定（CollectionManager L570-582）。
    if scene.has("grantFengwu") and scene["grantFengwu"] != null and scene["grantFengwu"] != "":
        CollectionManager.grant_fengwu(scene["grantFengwu"])
    
    # 看到某个 pose 时，自动解锁对应画廊 flag
    var pose = scene.get("pose", "")
    var speaker = scene.get("speaker", "")
    if pose != "" and speaker != "" and speaker != "player" and speaker != null:
        var auto_flag = "seen_%s_%s" % [speaker, pose]
        GameManager.unlock_gallery(auto_flag)

# 渲染立绘逻辑（优先检测 .ogv 视频立绘）
func update_sprites(scene: Dictionary):
    sprite_left.texture = null
    sprite_right.texture = null
    
    var char_id = scene.get("speaker", current_event.get("charId", ""))
    var pose = scene.get("pose", "default")
    
    # 如果没有说话人或是旁白，直接清除立绘并返回
    if char_id == null or str(char_id) == "" or char_id == "narrator":
        sprite_center.texture = null
        sprite_center.hide()
        sprite_video.stop()
        sprite_video.hide()
        sprite_center.set_meta("sprite_key", "")
        return
        
    var char_id_str = str(char_id).to_lower()
    var pose_str = str(pose).to_lower()
    var target_key = char_id_str + "_" + pose_str

    if sprite_center.has_meta("sprite_key") and sprite_center.get_meta("sprite_key") == target_key:
        return
    sprite_center.set_meta("sprite_key", target_key)

    
    var base_path = "res://assets/sprites/" + char_id_str + "/" + pose_str
    var ogv_path = base_path + ".ogv"
    var png_path = base_path + ".png"
    var jpg_path = base_path + ".jpg"
    
    # ── 优先：视频立绘 ──────────────────────────────
    if _check_resource_exists(ogv_path):
        sprite_center.hide()
        
        # 已经在播同一个视频则跳过重载
        var current_stream = sprite_video.stream
        var need_reload = true
        if current_stream != null:
            var current_path = current_stream.resource_path
            if current_path == ogv_path:
                need_reload = false
        
        if need_reload:
            sprite_video.stream = load(ogv_path)
            sprite_video.loop = true
            sprite_video.show()
            sprite_video.play()
            # 淡入动画
            sprite_video.modulate.a = 0.0
            var t = create_tween()
            t.tween_property(sprite_video, "modulate:a", 1.0, 0.3)
        else:
            sprite_video.show()
        return
    
    # ── 回退：静态立绘 ─────────────────────────────
    sprite_video.stop()
    sprite_video.hide()
    sprite_center.show()
    
    var tex = null
    if _check_resource_exists(png_path):
        tex = load(png_path)
    elif _check_resource_exists(jpg_path):
        tex = load(jpg_path)
    
    if tex:
        var is_new_tex = sprite_center.texture != tex
        sprite_center.texture = tex
        
        # 立绘淡入与纵向滑入动画
        if is_new_tex:
            sprite_center.modulate.a = 0.0
            
            var base_y = 0.0
            if not sprite_center.has_meta("orig_y"):
                sprite_center.set_meta("orig_y", sprite_center.position.y)
                base_y = sprite_center.position.y
            else:
                base_y = sprite_center.get_meta("orig_y")
                
            sprite_center.position.y = base_y + 15.0
            var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            t.tween_property(sprite_center, "modulate:a", 1.0, 0.25)
            t.tween_property(sprite_center, "position:y", base_y, 0.25)
    else:
        sprite_center.texture = null
        sprite_center.hide()
        print("警告: 找不到立绘 ", base_path)

# 打字机效果（同步启动，由 _process 驱动字符逐一显示）
func type_text(full_text: String):
    if _next_icon_tween:
        _next_icon_tween.kill()
        _next_icon_tween = null

    if is_instance_valid(SettingsManager):
        match SettingsManager.text_speed_idx:
            0: text_speed = 0.06
            1: text_speed = 0.03
            2: text_speed = 0.012
            3: text_speed = 0.0001

    text_label.text = ""
    _typing_full_text = full_text
    _typing_index = 0
    _typing_elapsed = 0.0
    is_typing = true
    next_icon.hide()

func _process(delta: float):
    if _typing_full_text == "" or not visible:
        return
    _typing_elapsed += delta
    while _typing_elapsed >= text_speed and _typing_index < _typing_full_text.length():
        _typing_elapsed -= text_speed
        _typing_index += 1
        text_label.text = _typing_full_text.substr(0, _typing_index)
    if _typing_index >= _typing_full_text.length():
        _on_typing_finished()

func _on_typing_finished():
    _typing_full_text = ""
    _typing_elapsed = 0.0
    is_typing = false
    next_icon.show()
    if _next_icon_tween:
        _next_icon_tween.kill()
    _next_icon_tween = create_tween().set_loops()
    _next_icon_tween.tween_property(next_icon, "modulate:a", 0.3, 0.6)
    _next_icon_tween.tween_property(next_icon, "modulate:a", 1.0, 0.6)

# 显示选项
func show_choices(choices: Array):
    choice_container.get_parent().show()
    
    # 渐入选择面板，带来流畅舒缓的视觉反馈
    choice_overlay.modulate.a = 0.0
    var overlay_tween = create_tween()
    overlay_tween.tween_property(choice_overlay, "modulate:a", 1.0, 0.2)
    
    for child in choice_container.get_children():
        child.queue_free()

    var index = 0
    for c in choices:
        # 过滤：条件缺失时不显示该选项
        if c.has("requireFlags"):
            var has_all = true
            var match_any = c.get("requireFlagsMatchAny", false)
            var has_any = false
            for f in c["requireFlags"]:
                if GameManager.flags.has(f):
                    has_any = true
                else:
                    has_all = false
            if match_any and c["requireFlags"].size() > 0 and not has_any:
                continue
            elif not match_any and not has_all:
                continue
                
        if c.has("excludeFlags"):
            var excluded = false
            for f in c["excludeFlags"]:
                if GameManager.flags.has(f):
                    excluded = true
                    break
            if excluded:
                continue
                
        # 过滤：临时标志位 blockIfTempFlag
        if c.has("blockIfTempFlag") and GameManager.has_temp_flag(c["blockIfTempFlag"]):
            continue
            
        # 过滤：属性条件 (requireStats / excludeStats)
        var stat_ok = true
        if c.has("requireStats"):
            for k in c["requireStats"].keys():
                var val = int(c["requireStats"][k])
                if k == "money":
                    if GameManager.money < val: stat_ok = false; break
                elif GameManager.stats.get(k, 0) < val:
                    stat_ok = false
                    break
        if not stat_ok: continue
            
        # 过滤：好感条件 (requireFav)
        var fav_ok = true
        if c.has("requireFav"):
            for char_id in c["requireFav"]:
                if GameManager.favorability.get(char_id, 0) < int(c["requireFav"][char_id]):
                    fav_ok = false
                    break
        if not fav_ok: continue
            
        if c.has("excludeStats"):
            var stat_failed = false
            for k in c["excludeStats"].keys():
                var val = int(c["excludeStats"][k])
                if GameManager.stats.get(k, 0) >= val:
                    stat_failed = true
                    break
            if stat_failed: continue
            
        # 过滤：conditionType hw_pending — 仅当有作业未完成，或处于放学后/晚上时段才显示
        if c.get("conditionType", "") == "hw_pending":
            var hw = GameManager.hw_status
            var slot = ["morning", "noon", "after", "evening"][GameManager.slot_index] if GameManager.slot_index < 4 else "morning"
            var is_school_time = slot in ["after", "evening"]
            if hw == 0 and not is_school_time:
                continue  # 没有作业且不是适合做作业的时段，隐藏作业选项
        var btn = Button.new()
        # 过滤：金钱不足时置灰并禁用
        var req_money = int(c.get("reqMoney", 0))
        var req_item = c.get("reqItem", "")
        var req_item_amt = int(c.get("reqItemAmt", 1))
        
        if req_money > 0 and GameManager.money < req_money:
            btn.text = c.text + " [💰不足]"
            btn.disabled = true
        elif req_item != "" and not GameManager.has_item(req_item, req_item_amt):
            var item_name = GameManager.ITEM_DB.get(req_item, {}).get("name", "未知物品")
            var amt_str = (" x%d" % req_item_amt) if req_item_amt > 1 else ""
            btn.text = c.text + " [需要:" + item_name + amt_str + "]"
            btn.disabled = true
        else:
            btn.text = c.text
            btn.pressed.connect(_on_choice_selected.bind(c))
            
        choice_container.add_child(btn)
        
        # 级联淡入效果：每个选项以阶梯式顺序渐现，质感拉满
        btn.modulate.a = 0.0
        var btn_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        btn_tween.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(index * 0.05)
        
        _setup_choice_button_hover(btn)
        index += 1

func _setup_choice_button_hover(btn: Button):
    btn.mouse_entered.connect(func():
        btn.pivot_offset = btn.size / 2.0
        var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1)
        tween.tween_property(btn, "modulate", Color(1.1, 1.1, 1.15), 0.1)
    )
    btn.mouse_exited.connect(func():
        btn.pivot_offset = btn.size / 2.0
        var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
        tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 0.15)
    )

func _on_choice_selected(choice_data: Dictionary):
    if choice_data.get("skipToNextDay", false):
        _should_skip_to_next_day = true

    # 0. 扣除金钱（如果有要求且没有被 statDelta 重复扣除）
    if choice_data.has("reqMoney"):
        var req = int(choice_data["reqMoney"])
        var has_money_delta = false
        for key in ["statsDelta", "statDelta"]:
            if choice_data.has(key) and choice_data[key].has("money"):
                has_money_delta = true
                break
        
        # 如果是概率事件且包含 money 变更，也视为已有 delta
        if choice_data.has("probNext"):
            var prob = choice_data["probNext"]
            if prob.get("successStat", {}).has("money") or prob.get("failStat", {}).has("money"):
                has_money_delta = true
                
        if not has_money_delta:
            GameManager.add_stat("money", -req)

    # 1. 属性变动
    if choice_data.has("statsDelta"):
        var delta = choice_data["statsDelta"]
        for stat_key in delta.keys():
            GameManager.add_stat(stat_key, int(delta[stat_key]))
    if choice_data.has("statDelta"):
        var delta = choice_data["statDelta"]
        for stat_key in delta.keys():
            GameManager.add_stat(stat_key, int(delta[stat_key]))

    # 1.5 概率判定逻辑 (probNext)
    var has_prob_jump = false
    var prob_jump_target = -1
    if choice_data.has("probNext"):
        has_prob_jump = true
        var prob = choice_data["probNext"]
        var chance = float(prob.get("chance", 0.5))
        var rolled = randf()
        var delta = {}
        
        if rolled <= chance:
            # 成功
            prob_jump_target = int(prob.get("successNext", -1))
            delta = prob.get("successStat", {})
            GameManager.show_toast.emit("🎲 概率判定：成功！")
        else:
            # 失败
            prob_jump_target = int(prob.get("failNext", -1))
            delta = prob.get("failStat", {})
            GameManager.show_toast.emit("🎲 概率判定：失败...")
            
        for stat_key in delta.keys():
            GameManager.add_stat(stat_key, int(delta[stat_key]))

    # 2. 好感度变动
    if choice_data.has("affDelta"):
        GameManager.add_favor(current_event.get("charId", ""), int(choice_data.affDelta))
    elif choice_data.has("favors"):
        for char_id_key in choice_data["favors"].keys():
            GameManager.add_favor(char_id_key, int(choice_data["favors"][char_id_key]))

    # 3. Flag
    # 关系状态机：选项级冷战触发 / 挽回（在 Flag 之前处理，确保 relCold 后 flag 仍生效）
    var _rel_char = current_event.get("charId", "")
    if _rel_char != "":
        if choice_data.get("relCold", false):
            RelationshipManager.enter_cold_war(_rel_char)
        if choice_data.get("relRecover", false):
            RelationshipManager.recover_from_cold(_rel_char)

    if choice_data.has("setFlags"):
        for f in choice_data["setFlags"]: GameManager.set_flag(f, true)
    if choice_data.has("setFlag"):
        GameManager.set_flag(choice_data["setFlag"], true)
    if choice_data.has("clearFlag"):
        GameManager.set_flag(choice_data["clearFlag"], false)

    # 4. TempFlag (每个时段重置)
    if choice_data.has("setTempFlag"):
        GameManager.set_temp_flag(choice_data["setTempFlag"])

    # 5. 作业状态
    if choice_data.has("setHwStatus"):
        GameManager.hw_status = int(choice_data["setHwStatus"])
    if choice_data.get("resetHwStatus", false):
        GameManager.reset_hw_status(choice_data.get("resetHwNeglect", false))
    if choice_data.get("incHwNeglect", false):
        GameManager.hw_neglect_count += 1
        
    # 6. 物品系统
    if choice_data.has("giveItem"):
        var items = choice_data["giveItem"] if typeof(choice_data["giveItem"]) == TYPE_ARRAY else [choice_data["giveItem"]]
        for itm in items:
            GameManager.add_item(itm)
    if choice_data.has("takeItem"):
        var items = choice_data["takeItem"] if typeof(choice_data["takeItem"]) == TYPE_ARRAY else [choice_data["takeItem"]]
        for itm in items:
            GameManager.remove_item(itm)

    # 跳转或结束志愿填报
    if choice_data.has("setTargetSchool"):
        GameManager.set_target_high_school(choice_data["setTargetSchool"])

    # 6. 结局触发
    if choice_data.get("isEndTrigger", false):
        var eid = choice_data.get("ending", "")
        ending_triggered.emit(eid)

    # 7. 跳转
    if has_prob_jump:
        if prob_jump_target == 99:
            finish_event()
        elif prob_jump_target >= 0:
            scene_index = prob_jump_target
            play_current_scene()
        else:
            finish_event()
    else:
        var nxt = int(choice_data.get("next", -1))
        if nxt == 99:
            finish_event()
        elif nxt >= 0:
            scene_index = nxt
            play_current_scene()
        else:
            finish_event()

func finish_event():
    var ev_id = current_event.get("id", "")
    if ev_id != "" and not current_event.get("repeatable", false):
        GameManager.set_flag(ev_id, true)
    var char_id = current_event.get("charId", "")
    if char_id == null: char_id = ""   # JSON null 防御
    if char_id != "":
        # 记录最后互动日期（防止冷落惩罚）
        # ENG-08：此处刻意只写 int day —— 消费方 DailyCycleManager L118/L155 以
        # `last_day is int` 取值做冷落/冷战计时，写 bool 会污染类型且立即被覆盖。
        GameManager.flags["last_interact_" + char_id] = GameManager.day
        var char_name = GameManager.char_meta.get(char_id, {}).get("name", char_id)
        GameManager.add_diary_entry("和%s聊了聊" % char_name)

    # ── 成就系统联动：猫咪互动事件计数 ──
    if (ev_id.begins_with("int_pet_") or ev_id.find("cat") != -1 or ev_id.find("orange") != -1) and is_instance_valid(AchievementManager):
        AchievementManager.add_counter("cat_pet_count", 1)
        AchievementManager.add_counter("campus_cat_feeds", 1)
        AchievementManager.check_all()

    # 关系状态机：事件级冷战触发 / 挽回（无选项事件完成即生效）
    if char_id != "":
        if current_event.get("relCold", false):
            RelationshipManager.enter_cold_war(char_id)
        if current_event.get("relRecover", false):
            RelationshipManager.recover_from_cold(char_id)

    hide()
    
    if _should_skip_to_next_day or current_event.get("skipToNextDay", false):
        GameManager.slot_index = 0
        GameManager.day += 1
        GameManager.day_of_week = ((GameManager.day - 1) % 7) + 1
        # 长假状态同步重建（与 advance_time 同款守卫，避免通宵跳日后冷战误触发）
        DailyCycleManager._update_current_holiday()
        GameManager.temp_flags.clear()
        GameManager._check_daily_decay()
        GameManager._check_special_date()
        GameManager._check_weekly_allowance()
        GameManager.add_log("🌙 通宵未归，时间来到了第二天清晨...")
    # 事件级 noTimeCost（记忆回响 DS-RN-02 §3.4）：玩家未主动请求的被动演出不收取时段。
    # current_event 在 start_event() L108 已整份保存，此处可直接读取该字段。
    # 纯新增分支：不带该键的既有事件走原 else 语义，零回归面。
    elif not current_event.get("noTimeCost", false):
        GameManager.advance_time()
        
    event_finished.emit()

# ── 输入监听 ────────────────────────────────────────────────
func _input(event):
    if not visible or _just_opened: return
    if choice_container.get_parent().visible: return
    if gift_overlay and gift_overlay.visible: return
    
    # 如果点击在送礼按钮上，则不在此处拦截，交给按钮自身处理
    if event is InputEventMouseButton and event.pressed:
        if gift_btn and gift_btn.visible and gift_btn.get_global_rect().has_point(event.global_position):
            return
            
    if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
        get_viewport().set_input_as_handled()
        if is_typing:
            # 立即显示全文（跳过打字动画）
            if _typing_full_text != "":
                text_label.text = _typing_full_text
            _typing_full_text = ""
            _typing_index = 0
            _on_typing_finished()
        else:
            _advance_scene()

func _advance_scene():
    var cur_scene = current_event.scenes[scene_index]

    # 处理 logicType：条件跳转（作业检查等）
    if cur_scene.has("logicType"):
        var targets = cur_scene.get("logicTargets", {})
        var jump_to = -1
        if cur_scene["logicType"] == "hw_check":
            var hw = GameManager.hw_status
            var neg = GameManager.hw_neglect_count
            if hw == 1 and neg >= 2:
                jump_to = int(targets.get("hw_3rd_miss", 5))
            elif hw == 2:
                jump_to = int(targets.get("hw_good", 2))
            elif hw == 3:
                jump_to = int(targets.get("hw_sloppy", 3))
            else:
                jump_to = int(targets.get("hw_missing", 4))
                
        elif cur_scene["logicType"] == "quiz_homework":
            var quiz_ui = preload("res://scripts/QuizUI.gd").new()
            var parent = get_parent()
            parent.add_child(quiz_ui)
            
            var target_sub = GameManager.current_hw_subject
            if target_sub == "":
                target_sub = ["chinese", "math", "english", "science", "society"][randi() % 5]
            
            quiz_ui.start_quiz([target_sub], func(correct_count):
                if correct_count > 0:
                    GameManager.hw_status = 2
                    GameManager.add_stat("intellect", 3)
                    GameManager.add_stat("stress", 5)
                    var em = get_tree().root.get_node_or_null("Main/ExamManager")
                    if em and em.has_method("add_subject_score"): em.add_subject_score(target_sub, 3)
                else:
                    GameManager.hw_status = 3
                    GameManager.add_stat("intellect", 1)
                    GameManager.add_stat("stress", 2)
                    var em = get_tree().root.get_node_or_null("Main/ExamManager")
                    if em and em.has_method("add_subject_score"): em.add_subject_score(target_sub, 1)
                
                _advance_scene()
            )
            return # 挂起事件直到回调调用 _advance_scene
            
        elif cur_scene["logicType"] == "hw_copy_finish":
            GameManager.hw_status = 2
            _advance_scene()
            return

        elif cur_scene["logicType"] == "punish_reflection":
            var next_ev = DataManager.get_event_by_id("dean_punish_reflection")
            start_event(next_ev)
            return
            
        elif cur_scene["logicType"] == "ptm_romance_check":
            # 只有成绩平庸或差，且有极高好感度的女生时才触发修罗场
            var total = GameManager.stats.get("last_exam_total", 0)
            var has_crush = false
            for fav in GameManager.favorability.values():
                if fav > 50:
                    has_crush = true
                    break
            
            if total < 400 and has_crush:
                cur_scene["next"] = 12
            else:
                cur_scene["next"] = 99
            _advance_scene()
            return
            
        elif cur_scene["logicType"] == "ptm_romance_fail":
            # 修罗场搞砸了，所有好感>20的女生暴降30%
            for char_id in GameManager.favorability.keys():
                if GameManager.favorability[char_id] > 20:
                    GameManager.favorability[char_id] = clampi(GameManager.favorability[char_id] - 30, 0, 100)
            _advance_scene()
            return
            
        elif cur_scene["logicType"] == "grad_trip_finish":
            _advance_scene()
            return

        elif cur_scene["logicType"].begins_with("quiz_olympiad"):
            var quiz_ui = preload("res://scripts/QuizUI.gd").new()
            var parent = get_parent()
            parent.add_child(quiz_ui)
            
            var is_final = cur_scene["logicType"] == "quiz_olympiad_final"
            var req_q = 3 if is_final else 1
            var subjects_arr = []
            for i in range(req_q): subjects_arr.append("math_olympiad")
            
            quiz_ui.start_quiz(subjects_arr, func(correct_count):
                var passed = false
                if is_final:
                    passed = correct_count >= 2
                else:
                    passed = correct_count >= 1
                
                if passed:
                    scene_index = int(targets.get("pass", 1))
                else:
                    scene_index = int(targets.get("fail", 2))
                
                play_current_scene()
            )
            return # 挂起等待作答
            
        if jump_to >= 0:
            scene_index = jump_to
            play_current_scene()
            return
            
    # 应用 scene 层面的属性 / 好感度（只在非选项场景执行）
    if not cur_scene.has("choices"):
        _apply_scene_level_effects(cur_scene)

    # 读取 next 决定跳转
    var raw_next = cur_scene.get("next", null)
    var nxt = int(raw_next) if raw_next != null else -1

    if nxt == 99:
        finish_event()
    elif nxt >= 0:
        scene_index = nxt
        play_current_scene()
    else:
        scene_index += 1
        play_current_scene()

func _apply_scene_level_effects(scene: Dictionary):
    var char_id = current_event.get("charId", "")
    # affDelta
    var aff_delta = int(scene.get("affDelta", 0))
    if aff_delta != 0 and char_id != "":
        GameManager.add_favor(char_id, aff_delta)
    # statsDelta / statDelta
    for key in ["statsDelta", "statDelta"]:
        if scene.has(key):
            for stat in scene[key].keys():
                GameManager.add_stat(stat, int(scene[key][stat]))
    # 作业状态重置
    if scene.get("resetHwStatus", false):
        GameManager.reset_hw_status(scene.get("resetHwNeglect", false))
    if scene.get("incHwNeglect", false):
        GameManager.hw_neglect_count += 1


# ── 送礼系统：核心交互逻辑 ─────────────────────────────────
func _setup_gift_overlay():
    gift_overlay = ColorRect.new()
    gift_overlay.anchors_preset = Control.PRESET_FULL_RECT
    gift_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
    gift_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
    gift_overlay.color = Color(0, 0, 0, 0.6)
    add_child(gift_overlay)
    gift_overlay.hide()
    
    # 阻挡点击穿透
    gift_overlay.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed:
            # 点击遮罩空白处关闭
            gift_overlay.hide()
    )
    
    # 送礼面板
    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(360, 260)
    var style = StyleBoxFlat.new()
    style.bg_color = Color("#1e293b")
    style.corner_radius_top_left = 12; style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
    style.border_width_left = 1; style.border_width_right = 1
    style.border_width_top = 1; style.border_width_bottom = 1
    style.border_color = Color("#f472b6") # 浪漫粉色描边
    style.content_margin_left = 12; style.content_margin_right = 12
    style.content_margin_top = 12; style.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", style)
    
    panel.anchor_left = 0.5; panel.anchor_top = 0.5; panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
    panel.offset_left = -180; panel.offset_top = -130; panel.offset_right = 180; panel.offset_bottom = 130
    gift_overlay.add_child(panel)
    
    var outer_vbox = VBoxContainer.new()
    outer_vbox.add_theme_constant_override("separation", 10)
    panel.add_child(outer_vbox)
    
    var title = Label.new()
    title.text = "🎁 挑选给她的礼物"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color("#f472b6"))
    title.add_theme_font_size_override("font_size", 15)
    outer_vbox.add_child(title)
    
    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    outer_vbox.add_child(scroll)
    
    gift_vbox = VBoxContainer.new()
    gift_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gift_vbox.add_theme_constant_override("separation", 6)
    scroll.add_child(gift_vbox)
    
    var close_btn = Button.new()
    close_btn.text = "取消"
    close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    close_btn.custom_minimum_size = Vector2(0, 32)
    var c_style = StyleBoxFlat.new()
    c_style.bg_color = Color("#475569")
    c_style.corner_radius_top_left = 6; c_style.corner_radius_top_right = 6
    c_style.corner_radius_bottom_left = 6; c_style.corner_radius_bottom_right = 6
    close_btn.add_theme_stylebox_override("normal", c_style)
    close_btn.pressed.connect(func(): gift_overlay.hide())
    outer_vbox.add_child(close_btn)

func _on_gift_pressed():
    if not current_event.has("scenes") or scene_index >= current_event.scenes.size():
        return
        
    var scene = current_event.scenes[scene_index]
    var char_id = scene.get("speaker", current_event.get("charId", ""))
    if char_id == null or str(char_id) == "" or char_id == "player" or char_id == "narrator":
        return
        
    gift_overlay.show()
    
    # 清空并重新填装背包道具
    for child in gift_vbox.get_children():
        child.queue_free()
        
    var has_any_item = false
    var db = GameManager.ITEM_DB
    for item_id in db.keys():
        if String(db[item_id].get("category", "")) == "fengwu": continue   # 风物为收藏品，不可作礼物（DS-RN-04）
        var owned = GameManager.inventory.get(item_id, 0)
        if owned > 0:
            has_any_item = true
            var item = db[item_id]
            var btn = Button.new()
            btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            btn.custom_minimum_size = Vector2(0, 38)
            
            var b_style = StyleBoxFlat.new()
            b_style.bg_color = Color("#334155")
            b_style.corner_radius_top_left = 6; b_style.corner_radius_top_right = 6
            b_style.corner_radius_bottom_left = 6; b_style.corner_radius_bottom_right = 6
            b_style.content_margin_left = 8; b_style.content_margin_right = 8
            btn.add_theme_stylebox_override("normal", b_style)
            var b_hover = b_style.duplicate()
            b_hover.bg_color = Color("#475569")
            btn.add_theme_stylebox_override("hover", b_hover)
            btn.add_theme_stylebox_override("pressed", b_hover)
            
            var hbox = HBoxContainer.new()
            hbox.anchors_preset = Control.PRESET_FULL_RECT
            hbox.layout_mode = 1
            hbox.add_theme_constant_override("separation", 8)
            btn.add_child(hbox)
            
            var icon_lbl = Label.new()
            icon_lbl.text = item.get("icon", "📦")
            icon_lbl.add_theme_font_size_override("font_size", 18)
            icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            hbox.add_child(icon_lbl)
            
            var name_lbl = Label.new()
            name_lbl.text = "%s (拥有: %d)" % [item.get("name", "未知"), owned]
            name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            name_lbl.add_theme_font_size_override("font_size", 15)
            name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            hbox.add_child(name_lbl)
            
            btn.pressed.connect(func(): _on_item_gifted(char_id, item_id))
            gift_vbox.add_child(btn)
            
    if not has_any_item:
        var empty_lbl = Label.new()
        empty_lbl.text = "（你的背包里空空如也，快去校外小卖部买点零食和礼物吧！）"
        empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_lbl.add_theme_color_override("font_color", Color("#64748b"))
        empty_lbl.add_theme_font_size_override("font_size", 14)
        gift_vbox.add_child(empty_lbl)

func _on_item_gifted(char_id: String, item_id: String):
    gift_overlay.hide()

    # 关系状态机：冷战期间拒收礼物（不消耗道具，避免误导性的正向回应）
    if GameManager.flags.has("rel_cold_" + char_id):
        is_typing = true
        next_icon.hide()
        name_label.text = GameManager.char_meta.get(char_id, {}).get("name", char_id)
        type_text("（她把礼物推了回来）……现在，我不想收。等你想清楚了再说吧。")
        return

    GameManager.remove_item(item_id, 1)
    
    var pref = DataManager.get_gift_preference(char_id, item_id)
    var favor_gain = pref.get("favor", 3)
    var response_text = pref.get("dialogue", "谢谢你的礼物！我很喜欢。")
    var gallery_unlock = pref.get("gallery_unlock", "")
    
    if gallery_unlock != "":
        GameManager.unlock_gallery(gallery_unlock)
        
    # 应用好感度增长
    GameManager.add_favor(char_id, favor_gain)
    GameManager.flags["achv_gift_given"] = true
    if is_instance_valid(AchievementManager):
        AchievementManager.check_all()
    
    # 强行重写当前对话框的展示，打印女孩的即时回应
    is_typing = true
    next_icon.hide()
    
    var speaker_name = GameManager.char_meta.get(char_id, {}).get("name", char_id)
    name_label.text = speaker_name
    type_text(response_text)
