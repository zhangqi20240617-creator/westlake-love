extends Control

# UI 引用
@onready var background = $Background
@onready var main_ui = $MainUI
@onready var creation_ui = $CreationUI

@onready var name_input = $CreationUI/Card/Content/Section1/NameInput
@onready var school_input = $CreationUI/Card/Content/Section2/SchoolInput
@onready var boy_card = $CreationUI/Card/Content/Section3/GenderCards/BoyCard
@onready var girl_card = $CreationUI/Card/Content/Section3/GenderCards/GirlCard
@onready var intro_panel = $CreationUI/Card/Content/IntroPanel
@onready var intro_text = $CreationUI/Card/Content/IntroPanel/IntroText

# 按钮引用
@onready var start_button = $MainUI/MainButtons/StartButton
@onready var load_button = $MainUI/MainButtons/LoadButton
@onready var gallery_button = $MainUI/MainButtons/GalleryButton
@onready var back_button = $CreationUI/Card/Content/FooterButtons/BackButton
@onready var confirm_button = $CreationUI/Card/Content/FooterButtons/ConfirmButton

var selected_gender = "male"

# ── 跨周目继承数据（从云端 profile 读取） ──
var _profile: Dictionary = {}   # 完整的云端 profile
var _ng_panel: Control = null   # 「旅途回响」面板节点引用

func _ready():
    _load_title_bg()
    
    # 按钮连接
    start_button.pressed.connect(_on_start_pressed)
    load_button.pressed.connect(_on_load_pressed)
    gallery_button.pressed.connect(_on_gallery_pressed)
    back_button.pressed.connect(_on_back_pressed)
    confirm_button.pressed.connect(_on_confirm_pressed)
    
    # 性别卡片连接
    boy_card.pressed.connect(func(): _select_gender("male"))
    girl_card.pressed.connect(func(): _select_gender("female"))
    
    # 监听输入框变动
    name_input.text_changed.connect(func(_new_text): _update_intro())
    school_input.text_changed.connect(func(_new_text): _update_intro())
    
    # 初始化
    creation_ui.hide()
    main_ui.show()
    name_input.text = ""
    school_input.text = ""
    intro_panel.modulate.a = 0 # 初始完全透明隐藏
    
    # 初始性别选择反馈
    _update_gender_ui()
    
    # 启用高级按钮悬停缩放与光效
    _setup_button_effects(start_button)
    _setup_button_effects(load_button)
    _setup_button_effects(gallery_button)
    _setup_button_effects(back_button)
    _setup_button_effects(confirm_button)
    _setup_button_effects(boy_card)
    _setup_button_effects(girl_card)

    # ── 异步拉取云端玩家档案（静默失败）──
    # 需要已有 player_name（老存档加载等情况）才拉取。
    # 若是全新玩家，名字为默认值，服务器会返回空模板，面板不会弹出。
    if GameManager.player_name != "主角" and GameManager.player_name != "":
        var cb = func(success: bool, data: Dictionary):
            _profile = data
            if data.get("ng_count", 0) >= 1:
                _show_ng_panel()
        NetworkManager.player_profile_loaded.connect(cb, CONNECT_ONE_SHOT)
        NetworkManager.load_player_profile()

func _load_title_bg():
    var path_jpg = "res://assets/backgrounds/title_bg.jpg"
    if ResourceLoader.exists(path_jpg):
        background.texture = load(path_jpg)

func _on_start_pressed():
    main_ui.hide()
    creation_ui.show()

func _on_back_pressed():
    creation_ui.hide()
    main_ui.show()

func _select_gender(gender: String):
    selected_gender = gender
    _update_gender_ui()
    _update_intro()

func _update_gender_ui():
    if selected_gender == "male":
        boy_card.modulate = Color(1.2, 1.2, 1.5)
        girl_card.modulate = Color(0.6, 0.6, 0.6)
    else:
        girl_card.modulate = Color(1.2, 1.2, 1.5)
        boy_card.modulate = Color(0.6, 0.6, 0.6)

func _update_intro():
    var p_name = name_input.text.strip_edges()
    var s_name = school_input.text.strip_edges()
    
    if p_name != "" and s_name != "":
        var g_name = "男生" if selected_gender == "male" else "女生"
        intro_text.text = "你是一名刚升入 %s 的 %s。窗外西湖的水汽带着初秋的微凉，教室里陌生的面孔——你的三年故事，从这里开始。" % [s_name, g_name]
        
        # 优雅地淡入显示
        var tween = create_tween()
        tween.tween_property(intro_panel, "modulate:a", 1.0, 0.3)
    else:
        # 否则隐藏
        intro_panel.modulate.a = 0

func _on_confirm_pressed():
    var p_name = name_input.text.strip_edges()
    var s_name = school_input.text.strip_edges()
    
    if p_name == "":
        _shake_input(name_input)
        return
    if s_name == "":
        _shake_input(school_input)
        return
        
    GameManager.player_name = p_name
    GameManager.school_name = s_name
    GameManager.gender = selected_gender
    
    # ── 完整重置游戏状态 ─────────────────────────────────────
    GameManager.day          = 1
    GameManager.slot_index   = 0
    GameManager.day_of_week  = 1
    GameManager.money        = 100
    GameManager.hw_status    = 0
    GameManager.hw_neglect_count = 0
    GameManager.flags        = {}
    GameManager.recent_logs  = []
    GameManager.diary        = []
    GameManager.stats        = {
        "intellect": 10, "strength": 10, "social": 10,
        "art": 10, "charm": 10, "stress": 0, "addict": 0
    }
    GameManager.reset_char_initiative()
    # 根据性别初始化好感度（只保留对应性别的攻略角色）
    if selected_gender == "male":
        GameManager.favorability = {
            "yutong": 0, "jingjing": 20, "wanqing": 0, "xiaoxia": 0, "keke": 0,
            "yifei": 0, "zicheng": 0, "beichen": 0, "jingjing_m": 0, "zijun": 0
        }
    else:
        GameManager.favorability = {
            "yutong": 0, "jingjing": 0, "wanqing": 0, "xiaoxia": 0, "keke": 0,
            "yifei": 0, "zicheng": 0, "beichen": 0, "jingjing_m": 20, "zijun": 0
        }

    # ── 注入跨周目继承数据（若有云端 profile）────────────────
    if _profile.get("ng_count", 0) >= 1:
        var ng = _profile["ng_count"]
        var inherited_money = _profile.get("inherited_money", 0)
        var inherited_titles = _profile.get("unlocked_titles", [])
        var inherited_recipes = _profile.get("unlocked_recipes", [])
        var seen_endings = _profile.get("seen_endings", [])

        GameManager.money += inherited_money
        GameManager.flags["ng_count"] = ng
        GameManager.flags["seen_endings"] = seen_endings
        for t in inherited_titles:
            GameManager.flags["title_" + t] = true

        if not inherited_recipes.is_empty() and CookingManager.has_method("inherit_recipes"):
            CookingManager.inherit_recipes(inherited_recipes)

        # 重置赛季数据（新周目重开）
        SeasonManager.season_exp = 0
        SeasonManager.season_level = 1
        SeasonManager.challenge_progress = {}
        SeasonManager.completed_challenges = []
        SeasonManager.claimed_rewards = []
        SeasonManager.visited_locations_list = []

        GameManager.add_diary_entry("第 %d 周目开始。还是这所学校，还是这片西湖，但有些东西不一样了。" % [ng + 1])
    else:
        GameManager.add_diary_entry("开学第一天，杭州的天空很蓝。")
    
    get_tree().change_scene_to_file("res://scenes/MainGame.tscn")

# ── 展示「旅途回响」历史周目面板 ──────────────────────────
func _show_ng_panel():
    if _ng_panel and is_instance_valid(_ng_panel):
        return

    var ng_count  = _profile.get("ng_count", 0)
    var seen      = _profile.get("seen_endings", [])
    var inherited = _profile.get("inherited_money", 0)
    var titles    = _profile.get("unlocked_titles", [])

    # 外层容器
    _ng_panel = PanelContainer.new()
    _ng_panel.name = "_NgPanel"
    _ng_panel.layout_mode = 1
    _ng_panel.anchor_left = 0.0; _ng_panel.anchor_right = 0.0
    _ng_panel.anchor_top  = 1.0; _ng_panel.anchor_bottom = 1.0
    _ng_panel.offset_left = 16; _ng_panel.offset_right = 320
    _ng_panel.offset_top  = -160; _ng_panel.offset_bottom = -16
    _ng_panel.grow_horizontal = Control.GROW_DIRECTION_END
    _ng_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

    var ps = StyleBoxFlat.new()
    ps.bg_color = Color(0.05, 0.06, 0.10, 0.88)
    ps.border_width_left = 1; ps.border_width_right = 1
    ps.border_width_top = 1; ps.border_width_bottom = 1
    ps.border_color = Color("#10b981", 0.5)
    ps.corner_radius_top_left = 12; ps.corner_radius_top_right = 12
    ps.corner_radius_bottom_left = 12; ps.corner_radius_bottom_right = 12
    _ng_panel.add_theme_stylebox_override("panel", ps)
    add_child(_ng_panel)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    _ng_panel.add_child(margin)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 6)
    margin.add_child(vbox)

    # 标题
    var hdr = Label.new()
    hdr.text = "✨ 旅途回响"
    hdr.add_theme_font_size_override("font_size", 15)
    hdr.add_theme_color_override("font_color", Color("#10b981"))
    vbox.add_child(hdr)

    # 分隔线
    var sep = HSeparator.new()
    sep.modulate = Color(1, 1, 1, 0.12)
    vbox.add_child(sep)

    # 周目数
    _add_ng_row(vbox, "🔄 已完成周目", "%d 周目" % ng_count)

    # 已见结局
    var endings_text = "%d 个结局" % seen.size() if not seen.is_empty() else "尚无"
    _add_ng_row(vbox, "🎬 已见结局", endings_text)

    # 继承金币
    _add_ng_row(vbox, "💰 继承金币", "+%d 元" % inherited, Color("#fbbf24"))

    # 称号
    if not titles.is_empty():
        _add_ng_row(vbox, "🏅 已有称号", "%d 个" % titles.size())

    # 淡入动画
    _ng_panel.modulate.a = 0.0
    var tw = create_tween()
    tw.tween_property(_ng_panel, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)

func _add_ng_row(parent: VBoxContainer, label: String, value: String, val_color: Color = Color(0.9, 0.9, 0.85)):
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    parent.add_child(row)

    var lbl = Label.new()
    lbl.text = label
    lbl.add_theme_font_size_override("font_size", 12)
    lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
    lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(lbl)

    var val = Label.new()
    val.text = value
    val.add_theme_font_size_override("font_size", 12)
    val.add_theme_color_override("font_color", val_color)
    row.add_child(val)

func _shake_input(node: Control):
    var orig_x = node.position.x
    node.modulate = Color(1.5, 0.5, 0.5) # 红色微光
    var tween = create_tween().set_parallel(false)
    # 物理横向往复弹动，营造强烈的反馈碰撞感
    for i in range(4):
        tween.tween_property(node, "position:x", orig_x + (6 if i % 2 == 0 else -6), 0.05)
    tween.tween_property(node, "position:x", orig_x, 0.05)
    tween.tween_property(node, "modulate", Color.WHITE, 0.15)

func _setup_button_effects(btn: Control):
    btn.mouse_entered.connect(func():
        btn.pivot_offset = btn.size / 2.0
        var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15)
        if btn != boy_card and btn != girl_card:
            tween.tween_property(btn, "modulate", Color(1.15, 1.15, 1.25), 0.15)
    )
    btn.mouse_exited.connect(func():
        btn.pivot_offset = btn.size / 2.0
        var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
        if btn != boy_card and btn != girl_card:
            tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 0.15)
    )

func _on_load_pressed() -> void:
    var popup_mgr = PopupManager.new()
    popup_mgr.setup(self, func(): get_tree().change_scene_to_file("res://scenes/MainGame.tscn"))
    popup_mgr.show_save_load_popup(false)

func _on_gallery_pressed() -> void:
    var gallery_ui = GalleryPopupUI.new()
    gallery_ui.setup(self)
    gallery_ui.show_gallery_popup(func(title, builder): PopupManager.make_overlay_popup(self, title, builder))
