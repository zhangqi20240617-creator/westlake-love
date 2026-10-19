# scripts/minigames/ClawMachineUI.gd
class_name ClawMachineUI
extends MiniGameBase

## ══════════════════════════════════════════════════════════════════
## ClawMachineUI.gd — 商业街·梦幻街机娃娃机（进阶技巧与属性联动版）
## 机制核心：
## 1. 角色 5 维属性深度联动：
##    - intellect (智力): 开启几何重心透视，拓宽二段合爪 PERFECT 窗口
##    - strength (体魄): 增加基础抓力与顶端抗颠簸脱落抗性
##    - stress (压力): 压力过高引起微小手抖；抓成后暴击释放压力 (-25)
##    - charm / social (魅力/社交): 同伴积极应援，幸运值充能加速，送礼好感暴击
##    - addict (网瘾): 街机老手直觉，滑车移动操控更平滑细腻
## 2. 真实街机操作博弈：
##    - 横向微调 + 物理摆动惰性
##    - 【二段精准锁定 QTE】: 下落过程中二次拍键锁定深度 (PERFECT / GOOD / MISS)
##    - 【顶端碰撞颠簸 (Top Bump)】: 升至顶部受到撞轨冲击，考验抓握张力与玩偶重量
##    - 玩偶 5 级重量梯度 (粉兔轻软 ★ -> 胖橘猫圆重 ★★★★)
## 3. 保底幸运机制与送礼闭环
## ══════════════════════════════════════════════════════════════════

# ── 游戏状态 ───────────────────────────────────────────────────
enum State { IDLE, AIMING, DROPPING, CATCHING, LIFTING, RETURNING, RELEASING, VICTORY }
var current_state: State = State.IDLE

# ── 数值与保底 ─────────────────────────────────────────────────
const COST_PER_PLAY := 10          # 每次 10 元
var luck_gauge: float = 0.0        # 幸运值 0 ~ 100%
var total_plays: int = 0
var total_catches: int = 0
var is_golden_claw: bool = false   # 黄金强力爪状态

# ── 机械爪参数 ─────────────────────────────────────────────────
const RAIL_MIN_X := 75.0
const RAIL_MAX_X := 470.0
const CHUTE_X := 45.0              # 出货口中心 X
const CLAW_START_Y := 35.0
const CLAW_FLOOR_Y := 280.0

var claw_pos := Vector2(260.0, CLAW_START_Y)
var caught_doll: Dictionary = {}
var move_dir: float = 0.0
var move_speed: float = 160.0

# ── 二段锁定 QTE 参数 ──────────────────────────────────────────
var drop_tween: Tween = null
var has_locked_qte: bool = false
var qte_timing_grade: String = ""  # "PERFECT", "GOOD", "MISS"
var current_claw_grip: float = 60.0 # 当前抓力百分比 (0~100)

# ── 属性衍生加成参数 ──────────────────────────────────────────
var stat_qte_window_bonus: float = 0.0
var stat_grip_bonus: float = 0.0
var stat_luck_mult: float = 1.0
var stat_hand_jitter: float = 0.0

# ── 玩偶数据库（带重量与难度梯度）────────────────────────────
const DOLL_ITEMS = [
    {
        "id": "doll_bunny",
        "name": "软萌粉兔",
        "icon": "🐰",
        "desc": "轻软布偶，长耳朵容易受力",
        "x": 130.0,
        "weight": 42.0,
        "difficulty": "★☆☆",
        "fav": "jingjing",
        "color": Color("#f472b6")
    },
    {
        "id": "doll_koi",
        "name": "西湖锦鲤",
        "icon": "🐟",
        "desc": "吉祥小锦鲤，两端重心均匀",
        "x": 210.0,
        "weight": 52.0,
        "difficulty": "★★☆",
        "fav": "keke",
        "color": Color("#f87171")
    },
    {
        "id": "doll_dino",
        "name": "暴龙怪兽",
        "icon": "🦖",
        "desc": "恐龙玩偶，尾巴略有偏心",
        "x": 290.0,
        "weight": 62.0,
        "difficulty": "★★☆",
        "fav": "xiaoxia",
        "color": Color("#4ade80")
    },
    {
        "id": "doll_bear",
        "name": "学士帽熊",
        "icon": "🧸",
        "desc": "头重身轻，需对准躯干中轴",
        "x": 370.0,
        "weight": 74.0,
        "difficulty": "★★★",
        "fav": "yutong",
        "color": Color("#fbbf24")
    },
    {
        "id": "doll_cat",
        "name": "慵懒橘猫",
        "icon": "🐱",
        "desc": "圆滚滚的大胖猫，分量十足最难抓",
        "x": 445.0,
        "weight": 86.0,
        "difficulty": "★★★★",
        "fav": "wanqing",
        "color": Color("#fb923c")
    }
]

# ── UI 控件节点 ────────────────────────────────────────────────
var machine_panel: PanelContainer
var glass_view: Control
var rope_line: ColorRect
var trolley_box: Panel
var claw_left: ColorRect
var claw_right: ColorRect
var claw_center: ColorRect
var claw_root: Control
var qte_target_ring: Control       # 重心下探辅助准星

var doll_nodes: Array = []
var coin_btn: Button
var left_btn: Button
var right_btn: Button
var drop_btn: Button

var luck_bar: ProgressBar
var tension_bar: ProgressBar      # 实时机械抓力槽
var coin_lbl: Label
var status_lbl: Label
var stat_perk_lbl: Label          # 属性加成提示横幅

func setup_game() -> void:
    game_id = "claw_machine"
    game_title = "商业街 · 梦幻街机娃娃机"
    _title_lbl.text = "🧸 " + game_title

    _calculate_stat_synergies()
    _build_claw_machine_ui()
    init_companion_dock(_content_root)

    _update_doll_visuals()
    _update_hud_display()
    _greet_companion()

## 计算角色 5 维属性给娃娃机带来的被动增益
func _calculate_stat_synergies() -> void:
    var intellect = float(GameManager.stats.get("intellect", 10))
    var strength = float(GameManager.stats.get("strength", 10))
    var stress = float(GameManager.stats.get("stress", 0))
    var charm = float(GameManager.stats.get("charm", 10))
    var social = float(GameManager.stats.get("social", 10))

    # 1. 智力加成：拓宽 QTE PERFECT 的容错像素窗口
    stat_qte_window_bonus = clamp(intellect * 0.18, 0.0, 24.0)

    # 2. 体魄加成：提升基础抓握力，抗升顶震动
    stat_grip_bonus = clamp(strength * 0.35, 0.0, 30.0)

    # 3. 社交与魅力加成：提升同伴应援效果与幸运积攒速率
    stat_luck_mult = 1.0 + clamp((charm + social) * 0.003, 0.0, 0.5)

    # 4. 压力机制：压力 >= 50 时产生微小手抖
    if stress >= 50.0:
        stat_hand_jitter = clamp((stress - 40.0) * 0.06, 0.0, 4.0)
    else:
        stat_hand_jitter = 0.0

func _greet_companion() -> void:
    var meta = GameManager.char_meta.get(companion_id, {})
    var c_name = meta.get("name", "她")
    var intellect = GameManager.stats.get("intellect", 10)
    if intellect >= 40:
        say_companion_dialogue("“凭你的观察力，找准重心肯定没问题的！”", "default")
    else:
        say_companion_dialogue("“哇，是抓娃娃机！下爪时记得看准时机按第二次锁定哦~”", "default")

# ── 娃娃机主结构搭建 ──────────────────────────────────────────
func _build_claw_machine_ui() -> void:
    machine_panel = PanelContainer.new()
    machine_panel.custom_minimum_size = Vector2(560, 0)
    machine_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    machine_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var cabinet_style = ThemeUtils.create_style(
        Color(0.12, 0.14, 0.22, 0.95), 16,
        Color(0.96, 0.45, 0.65, 0.8), 3,
        -1, 14, 14, 10, 10
    )
    machine_panel.add_theme_stylebox_override("panel", cabinet_style)
    _content_root.add_child(machine_panel)

    var v_box = VBoxContainer.new()
    v_box.add_theme_constant_override("separation", 8)
    machine_panel.add_child(v_box)

    # 1. 顶部发光招牌与属性增益横幅
    var marquee_panel = PanelContainer.new()
    marquee_panel.custom_minimum_size = Vector2(0, 38)
    var marquee_style = ThemeUtils.create_style(
        Color(0.85, 0.25, 0.55, 0.9), 10,
        Color(1, 0.9, 0.5, 0.9), 2,
        -1, 10, 10, 4, 4
    )
    marquee_panel.add_theme_stylebox_override("panel", marquee_style)
    v_box.add_child(marquee_panel)

    var marquee_lbl = Label.new()
    marquee_lbl.text = "★ DREAM CRANE · 技巧抓娃娃机 ★"
    marquee_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    marquee_lbl.add_theme_font_size_override("font_size", 15)
    marquee_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
    marquee_panel.add_child(marquee_lbl)

    # 属性被动加成状态栏
    stat_perk_lbl = Label.new()
    var perk_texts := []
    if stat_qte_window_bonus > 0:
        perk_texts.append("🧠智力透视+%.0fpx" % stat_qte_window_bonus)
    if stat_grip_bonus > 0:
        perk_texts.append("💪体魄抓力+%.0f%%" % stat_grip_bonus)
    if stat_luck_mult > 1.0:
        perk_texts.append("💖魅力应援×%.1f" % stat_luck_mult)
    if stat_hand_jitter > 0:
        perk_texts.append("😰高压手抖")

    stat_perk_lbl.text = " [个人天赋] " + (" · ".join(perk_texts) if perk_texts.size() > 0 else "均衡状态")
    stat_perk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stat_perk_lbl.add_theme_font_size_override("font_size", 11)
    stat_perk_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
    v_box.add_child(stat_perk_lbl)

    # 2. 玻璃机舱展区
    glass_view = Control.new()
    glass_view.custom_minimum_size = Vector2(0, 300)
    glass_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    glass_view.clip_contents = true

    var glass_bg = ColorRect.new()
    glass_bg.set_anchors_preset(PRESET_FULL_RECT)
    glass_bg.color = Color(0.05, 0.07, 0.12, 0.92)
    glass_view.add_child(glass_bg)

    # 左侧出料口（落货斗 Chute）
    var chute = Panel.new()
    chute.position = Vector2(10, 225)
    chute.size = Vector2(70, 75)
    var chute_style = ThemeUtils.create_style(Color(0.2, 0.1, 0.25, 0.8), 8, Color(0.9, 0.4, 0.6), 2)
    chute.add_theme_stylebox_override("panel", chute_style)
    glass_view.add_child(chute)

    var chute_lbl = Label.new()
    chute_lbl.text = "出料仓\n⬇"
    chute_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    chute_lbl.set_anchors_preset(PRESET_FULL_RECT)
    chute_lbl.add_theme_font_size_override("font_size", 12)
    chute_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 1))
    chute.add_child(chute_lbl)

    # 顶部滑轨
    var rail = ColorRect.new()
    rail.position = Vector2(RAIL_MIN_X, 20)
    rail.size = Vector2(RAIL_MAX_X - RAIL_MIN_X + 40, 6)
    rail.color = Color(0.5, 0.55, 0.7, 0.8)
    glass_view.add_child(rail)

    # 重心辅助准星（智力 >= 20 时激活透视微光）
    qte_target_ring = Control.new()
    qte_target_ring.visible = false
    glass_view.add_child(qte_target_ring)

    # 搭建机械爪节点体系
    claw_root = Control.new()
    claw_root.position = claw_pos
    glass_view.add_child(claw_root)

    trolley_box = Panel.new()
    trolley_box.position = Vector2(-16, -14)
    trolley_box.size = Vector2(32, 14)
    var tr_style = ThemeUtils.create_style(Color(0.9, 0.4, 0.6), 4)
    trolley_box.add_theme_stylebox_override("panel", tr_style)
    claw_root.add_child(trolley_box)

    rope_line = ColorRect.new()
    rope_line.position = Vector2(-2, 0)
    rope_line.size = Vector2(4, 20)
    rope_line.color = Color(0.85, 0.85, 0.9)
    claw_root.add_child(rope_line)

    var claw_head = Panel.new()
    claw_head.position = Vector2(-14, 20)
    claw_head.size = Vector2(28, 14)
    var head_style = ThemeUtils.create_style(Color(0.8, 0.35, 0.55), 4)
    claw_head.add_theme_stylebox_override("panel", head_style)
    claw_root.add_child(claw_head)

    claw_left = ColorRect.new()
    claw_left.position = Vector2(-12, 34)
    claw_left.size = Vector2(5, 22)
    claw_left.rotation_degrees = -18
    claw_left.color = Color(0.95, 0.7, 0.2)
    claw_root.add_child(claw_left)

    claw_center = ColorRect.new()
    claw_center.position = Vector2(-2, 34)
    claw_center.size = Vector2(4, 24)
    claw_center.color = Color(0.95, 0.7, 0.2)
    claw_root.add_child(claw_center)

    claw_right = ColorRect.new()
    claw_right.position = Vector2(8, 34)
    claw_right.size = Vector2(5, 22)
    claw_right.rotation_degrees = 18
    claw_right.color = Color(0.95, 0.7, 0.2)
    claw_root.add_child(claw_right)

    # 生成带重量梯度的玩偶群
    _spawn_dolls()

    v_box.add_child(glass_view)

    # 3. 街机操作台与 HUD 控制区
    var ctrl_panel = PanelContainer.new()
    var ctrl_style = ThemeUtils.create_style(Color(0.08, 0.10, 0.16, 0.95), 10, Color(0.3, 0.35, 0.5), 1)
    ctrl_panel.add_theme_stylebox_override("panel", ctrl_style)
    v_box.add_child(ctrl_panel)

    var ctrl_vbox = VBoxContainer.new()
    ctrl_vbox.add_theme_constant_override("separation", 6)
    ctrl_panel.add_child(ctrl_vbox)

    # 状态提示与仪表行
    var hud_row = HBoxContainer.new()
    coin_lbl = Label.new()
    coin_lbl.text = "💰 余额: %d 元" % GameManager.money
    coin_lbl.add_theme_font_size_override("font_size", 13)
    coin_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
    hud_row.add_child(coin_lbl)

    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hud_row.add_child(spacer)

    # 实时抓握张力槽 (Tension)
    var tension_lbl = Label.new()
    tension_lbl.text = "🦾 抓握张力:"
    tension_lbl.add_theme_font_size_override("font_size", 12)
    tension_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.9))
    hud_row.add_child(tension_lbl)

    tension_bar = ProgressBar.new()
    tension_bar.custom_minimum_size = Vector2(90, 14)
    tension_bar.max_value = 100
    tension_bar.value = 0
    tension_bar.show_percentage = true
    var t_style = ThemeUtils.create_style(Color(0.2, 0.7, 0.8), 3)
    tension_bar.add_theme_stylebox_override("fill", t_style)
    hud_row.add_child(tension_bar)

    # 幸运保底槽
    var luck_lbl = Label.new()
    luck_lbl.text = "  ✨ 幸运保底:"
    luck_lbl.add_theme_font_size_override("font_size", 12)
    luck_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 1))
    hud_row.add_child(luck_lbl)

    luck_bar = ProgressBar.new()
    luck_bar.custom_minimum_size = Vector2(80, 14)
    luck_bar.max_value = 100
    luck_bar.show_percentage = true
    var l_style = ThemeUtils.create_style(Color(0.9, 0.3, 0.6), 3)
    luck_bar.add_theme_stylebox_override("fill", l_style)
    hud_row.add_child(luck_bar)

    ctrl_vbox.add_child(hud_row)

    # 状态横幅
    status_lbl = Label.new()
    status_lbl.text = "投币后左右对准，下爪过程中可【再次拍键】二段锁定深度！"
    status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_lbl.add_theme_font_size_override("font_size", 12)
    status_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
    ctrl_vbox.add_child(status_lbl)

    # 物理按键行
    var btn_row = HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 8)

    coin_btn = Button.new()
    coin_btn.text = "🪙 投币 (10元)"
    coin_btn.custom_minimum_size = Vector2(110, 40)
    ThemeUtils.style_accent_btn(coin_btn, Color(0.95, 0.65, 0.2), 8, 2)
    coin_btn.pressed.connect(_on_coin_inserted)
    btn_row.add_child(coin_btn)

    left_btn = Button.new()
    left_btn.text = "◀ 左移"
    left_btn.custom_minimum_size = Vector2(85, 40)
    ThemeUtils.style_accent_btn(left_btn, Color(0.3, 0.45, 0.7), 8, 1)
    left_btn.button_down.connect(func(): move_dir = -1.0)
    left_btn.button_up.connect(func(): move_dir = 0.0)
    left_btn.disabled = true
    btn_row.add_child(left_btn)

    right_btn = Button.new()
    right_btn.text = "右移 ▶"
    right_btn.custom_minimum_size = Vector2(85, 40)
    ThemeUtils.style_accent_btn(right_btn, Color(0.3, 0.45, 0.7), 8, 1)
    right_btn.button_down.connect(func(): move_dir = 1.0)
    right_btn.button_up.connect(func(): move_dir = 0.0)
    right_btn.disabled = true
    btn_row.add_child(right_btn)

    drop_btn = Button.new()
    drop_btn.text = "👇 下爪 CATCH!"
    drop_btn.custom_minimum_size = Vector2(140, 40)
    drop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ThemeUtils.style_accent_btn(drop_btn, Color(0.9, 0.25, 0.4), 8, 2)
    drop_btn.pressed.connect(_on_drop_or_lock_pressed)
    drop_btn.disabled = true
    btn_row.add_child(drop_btn)

    ctrl_vbox.add_child(btn_row)

# ── 玩偶群生成（展示重量与难度）────────────────────────────
func _spawn_dolls() -> void:
    for d in DOLL_ITEMS:
        var panel = PanelContainer.new()
        panel.position = Vector2(d["x"] - 26, CLAW_FLOOR_Y - 26)
        panel.custom_minimum_size = Vector2(52, 54)

        var p_style = ThemeUtils.create_style(
            Color(0.12, 0.15, 0.24, 0.95), 10,
            d["color"], 2,
            -1, 4, 4, 3, 3
        )
        panel.add_theme_stylebox_override("panel", p_style)

        var v = VBoxContainer.new()
        v.add_theme_constant_override("separation", 1)

        var icon = Label.new()
        icon.text = d["icon"]
        icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        icon.add_theme_font_size_override("font_size", 20)
        v.add_child(icon)

        var name_lbl = Label.new()
        name_lbl.text = d["name"]
        name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_lbl.add_theme_font_size_override("font_size", 10)
        name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
        v.add_child(name_lbl)

        # 难度星级标
        var diff_lbl = Label.new()
        diff_lbl.text = d["difficulty"]
        diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        diff_lbl.add_theme_font_size_override("font_size", 8)
        diff_lbl.add_theme_color_override("font_color", d["color"].lightened(0.2))
        v.add_child(diff_lbl)

        panel.add_child(v)
        glass_view.add_child(panel)

        doll_nodes.append({
            "data": d,
            "node": panel,
            "base_pos": panel.position
        })

func _process(delta: float) -> void:
    if current_state == State.AIMING:
        # 处理键盘方向键输入与压力手抖微摆
        var input_axis = 0.0
        if Input.is_action_pressed("ui_left") or move_dir < -0.5:
            input_axis -= 1.0
        if Input.is_action_pressed("ui_right") or move_dir > 0.5:
            input_axis += 1.0

        var jitter = 0.0
        if stat_hand_jitter > 0.0:
            jitter = sin(Time.get_ticks_msec() * 0.015) * stat_hand_jitter

        if input_axis != 0.0 or jitter != 0.0:
            claw_pos.x = clamp(claw_pos.x + (input_axis * move_speed + jitter) * delta, RAIL_MIN_X, RAIL_MAX_X)
            claw_root.position.x = claw_pos.x

# ── 投币与二段合爪核心逻辑 ────────────────────────────────────
func _on_coin_inserted() -> void:
    if GameManager.money < COST_PER_PLAY:
        GameManager.show_toast.emit("零花钱不够啦，需要 %d 元！" % COST_PER_PLAY)
        say_companion_dialogue("钱包见底了呢……下次再来抓吧？", "shy")
        return

    GameManager.add_stat("money", -COST_PER_PLAY)
    total_plays += 1
    if is_instance_valid(AudioManager):
        AudioManager.play_sfx("coin_drop")
    if is_instance_valid(AchievementManager):
        AchievementManager.add_counter("claw_plays_total", 1)
        AchievementManager.check_all()
    current_state = State.AIMING
    has_locked_qte = false
    qte_timing_grade = ""
    current_claw_grip = 55.0 + stat_grip_bonus
    tension_bar.value = 0

    if luck_gauge >= 100.0:
        is_golden_claw = true
        status_lbl.text = "✨ 黄金神爪已激活！张力 100% 锁死必中！✨"
        status_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
    else:
        is_golden_claw = false
        status_lbl.text = "左右微调对准玩偶，下爪后可【再次拍键】锁定最佳深度！"
        status_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1))

    coin_btn.disabled = true
    left_btn.disabled = false
    right_btn.disabled = false
    drop_btn.disabled = false
    drop_btn.text = "👇 下爪 CATCH!"
    ThemeUtils.style_accent_btn(drop_btn, Color(0.9, 0.25, 0.4), 8, 2)

    _update_hud_display()
    say_companion_dialogue("投币成功！左右对准它，下爪记得抓准时机按第二次！", "default")

## 点击下爪或进行二段 QTE 锁定
func _on_drop_or_lock_pressed() -> void:
    if current_state == State.AIMING:
        # 第一段：开始下落
        _start_dropping_phase()
    elif current_state == State.DROPPING:
        # 第二段：下落中二次拍键进行 QTE 深度锁定！
        _trigger_qte_lock()

func _start_dropping_phase() -> void:
    current_state = State.DROPPING
    left_btn.disabled = true
    right_btn.disabled = true
    move_dir = 0.0

    # 按钮切换为二段拍键模式
    drop_btn.text = "🎯 二段锁定 LOCK!"
    ThemeUtils.style_accent_btn(drop_btn, Color(0.2, 0.75, 0.95), 8, 2)
    status_lbl.text = "下探中！看准高度再次拍击【二段锁定】！"

    say_companion_dialogue("下去了！看准它肚子的高度快按锁定！", "default")

    # 张开爪子
    _set_claw_angles(-38.0, 38.0)

    # 动画下探 (1.4 秒匀速触底)
    drop_tween = create_tween()
    drop_tween.tween_property(claw_root, "position:y", CLAW_FLOOR_Y - 35, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    drop_tween.finished.connect(_on_claw_reached_bottom)

## 二段 QTE 深度判定
func _trigger_qte_lock() -> void:
    if has_locked_qte:
        return
    has_locked_qte = true

    # 停止下落并立即执行合爪
    if drop_tween and drop_tween.is_valid():
        drop_tween.kill()

    var current_y = claw_root.position.y
    var optimal_y = CLAW_FLOOR_Y - 45.0  # 玩偶黄金中心深度
    var dy = abs(current_y - optimal_y)

    # 智力扩大 PERFECT 容错窗口
    var perfect_threshold = 16.0 + stat_qte_window_bonus

    if dy <= perfect_threshold:
        qte_timing_grade = "PERFECT"
        current_claw_grip = clamp(current_claw_grip + 40.0, 0.0, 100.0)
        status_lbl.text = "🎯 完美锁定 (PERFECT)！抓握力大幅提升 +40%！"
        status_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
        say_companion_dialogue("“好准的手法！就是这个位置，锁死它了！”", "shy")
    elif dy <= perfect_threshold + 30.0:
        qte_timing_grade = "GOOD"
        current_claw_grip = clamp(current_claw_grip + 15.0, 0.0, 100.0)
        status_lbl.text = "👍 良好时机 (GOOD)！抓力提升 +15%！"
        status_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
        say_companion_dialogue("“抓住了！感觉还挺稳的！”", "default")
    else:
        qte_timing_grade = "EARLY"
        current_claw_grip = clamp(current_claw_grip - 15.0, 10.0, 100.0)
        status_lbl.text = "⚠️ 拍太早了 (EARLY)！爪子未达玩偶中心！"
        status_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))

    _on_claw_reached_bottom()

func _on_claw_reached_bottom() -> void:
    if not has_locked_qte:
        # 玩家完全没按二段锁定，直接硬撞底板散架
        qte_timing_grade = "MISS"
        current_claw_grip = clamp(current_claw_grip - 30.0, 10.0, 100.0)
        status_lbl.text = "❌ 触底反弹 (MISS)！爪子撞底震松，抓力损失 -30%！"
        status_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
        say_companion_dialogue("“哎呀……撞到底板弹开了，好可惜！”", "default")

    current_state = State.CATCHING
    drop_btn.disabled = true
    drop_btn.text = "👇 下爪 CATCH!"
    ThemeUtils.style_accent_btn(drop_btn, Color(0.9, 0.25, 0.4), 8, 2)

    # 黄金爪直接拉满 100%
    if is_golden_claw:
        current_claw_grip = 100.0

    tension_bar.value = current_claw_grip

    # 合爪动画
    _set_claw_angles(-8.0, 8.0)

    # 寻找最近玩偶与 X 轴精度
    var target_doll = _find_closest_doll(claw_pos.x)
    caught_doll = {}

    if not target_doll.is_empty():
        var dx = abs(claw_pos.x - target_doll["data"]["x"])
        # X 轴容差
        if is_golden_claw or dx <= 26.0:
            caught_doll = target_doll
            _attach_doll_to_claw(target_doll["node"])
        elif dx <= 42.0:
            caught_doll = target_doll
            # 偏心夹持，扣除张力
            current_claw_grip -= 20.0
            tension_bar.value = current_claw_grip
            _attach_doll_to_claw(target_doll["node"])

    var tw = create_tween()
    tw.tween_interval(0.35)
    tw.finished.connect(_lift_claw)

func _lift_claw() -> void:
    current_state = State.LIFTING
    status_lbl.text = "机械爪提拉中……"

    var tw = create_tween()
    tw.tween_property(claw_root, "position:y", CLAW_START_Y, 1.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.finished.connect(_on_claw_reached_top)

## 升到顶部触发街机核心：【顶端碰撞颠簸 (Top Bump)】
func _on_claw_reached_top() -> void:
    # 画面颠簸震动特效
    _shake_screen_impact()

    if not caught_doll.is_empty() and not is_golden_claw:
        var doll_weight = caught_doll["data"]["weight"]
        # 体魄加成提供颠簸抗性
        var resistance = current_claw_grip + (stat_grip_bonus * 0.5)

        # 若张力不足以支撑玩偶重量，被顶端颠簸直接震落！
        if resistance < doll_weight:
            _slip_doll_midair("💥 升顶颠簸冲击！【%s】太重被震脱了！" % caught_doll["data"]["name"])
        else:
            # 稳稳通过颠簸考验，消耗少量张力
            current_claw_grip -= 10.0
            tension_bar.value = current_claw_grip
            say_companion_dialogue("“顶住了！顶住震动了！好厉害，快移过来！”", "shy")

    _return_claw_to_chute()

func _shake_screen_impact() -> void:
    if is_instance_valid(glass_view):
        var tw = create_tween()
        glass_view.position.y += 4
        tw.tween_property(glass_view, "position:y", glass_view.position.y - 4, 0.12).set_trans(Tween.TRANS_BOUNCE)

func _slip_doll_midair(reason: String = "") -> void:
    if caught_doll.is_empty(): return
    var node = caught_doll["node"]
    _detach_doll_from_claw(node)
    caught_doll = {}

    # 触发意外成就：就差一厘米！
    GameManager.flags["achv_claw_drop"] = true
    if is_instance_valid(AchievementManager):
        AchievementManager.check_all()

    _set_claw_angles(-30.0, 30.0)
    status_lbl.text = reason if reason != "" else "爪力不足，玩偶从半空中滑落了……"
    status_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
    say_companion_dialogue("“啊！就差一点点！别灰心，下一次肯定能行！”", "default")

func _return_claw_to_chute() -> void:
    current_state = State.RETURNING
    status_lbl.text = "机械爪平移回出料仓……"

    var tw = create_tween()
    tw.tween_property(claw_root, "position:x", CHUTE_X, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tw.finished.connect(_on_claw_returned_home)

func _on_claw_returned_home() -> void:
    current_state = State.RELEASING
    _set_claw_angles(-35.0, 35.0)

    if not caught_doll.is_empty():
        current_state = State.VICTORY
        var node = caught_doll["node"]
        var tw = create_tween()
        tw.tween_property(node, "position:y", CLAW_FLOOR_Y + 10, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tw.finished.connect(func():
            _detach_doll_from_claw(node)
            _on_catch_success(caught_doll["data"])
        )
    else:
        _on_catch_fail()

# ── 结算与交互 ────────────────────────────────────────────────
func _on_catch_success(doll_data: Dictionary) -> void:
    total_catches += 1
    if is_golden_claw:
        GameManager.flags["achv_claw_golden"] = true
    luck_gauge = 0.0
    is_golden_claw = false
    _update_hud_display()

    status_lbl.text = "🎉 恭喜！凭高超技巧成功抓获【%s】！" % doll_data["name"]
    status_lbl.add_theme_color_override("font_color", Color(0.9, 1, 0.3))

    # 压力机制联动：高压力下抓获触发减压狂喜暴击！
    var current_stress = GameManager.stats.get("stress", 0)
    if current_stress >= 50:
        GameManager.add_stat("stress", -25)
        GameManager.show_toast.emit("大舒一口气！高压下抓到娃娃，压力狂减 -25！")
    else:
        GameManager.add_stat("stress", -15)

    # ── 成就系统联动 ──
    GameManager.flags["achv_claw_caught"] = true
    if is_instance_valid(AchievementManager):
        AchievementManager.add_counter("claw_won_count", 1)

    _show_victory_popup(doll_data)

func _on_catch_fail() -> void:
    # 社交/魅力加成：提升保底幸运充能速度
    var base_luck_gain = 35.0 * stat_luck_mult
    luck_gauge = clamp(luck_gauge + base_luck_gain, 0.0, 100.0)
    _update_hud_display()

    status_lbl.text = "遗憾脱爪……幸运充能 +%.0f%%！" % base_luck_gain
    say_companion_dialogue("“就差一点点！我已经感觉到了，再试一次！”", "default")
    _reset_machine_to_idle()

func _reset_machine_to_idle() -> void:
    claw_pos = Vector2(260.0, CLAW_START_Y)
    claw_root.position = claw_pos
    _set_claw_angles(-18.0, 18.0)
    current_state = State.IDLE
    has_locked_qte = false
    tension_bar.value = 0
    coin_btn.disabled = false
    left_btn.disabled = true
    right_btn.disabled = true
    drop_btn.disabled = true
    drop_btn.text = "👇 下爪 CATCH!"
    ThemeUtils.style_accent_btn(drop_btn, Color(0.9, 0.25, 0.4), 8, 2)

# ── 抓获专属奖励弹窗（含魅力送礼加成）────────────────────────
func _show_victory_popup(doll_data: Dictionary) -> void:
    var pop = PanelContainer.new()
    pop.set_anchors_preset(PRESET_CENTER)
    pop.custom_minimum_size = Vector2(360, 260)
    var p_style = ThemeUtils.create_style(
        Color(0.08, 0.1, 0.16, 0.98), 16,
        Color(1, 0.8, 0.3, 0.9), 2,
        -1, 16, 16, 16, 16
    )
    pop.add_theme_stylebox_override("panel", p_style)
    add_child(pop)

    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    pop.add_child(v)

    var icon_lbl = Label.new()
    icon_lbl.text = doll_data["icon"]
    icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon_lbl.add_theme_font_size_override("font_size", 42)
    v.add_child(icon_lbl)

    var title = Label.new()
    title.text = "✨ 获得了【%s】！✨" % doll_data["name"]
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 16)
    title.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
    v.add_child(title)

    var desc = Label.new()
    desc.text = "%s (重量: %.0f)" % [doll_data["desc"], doll_data["weight"]]
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc.add_theme_font_size_override("font_size", 12)
    desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
    v.add_child(desc)

    # 选项 1：当场送给同伴（魅力加成）
    var gift_btn = Button.new()
    var meta = GameManager.char_meta.get(companion_id, {})
    var c_name = meta.get("name", "她")
    var is_fav = (doll_data.get("fav", "") == companion_id)

    # 魅力属性提供额外送礼暴击好感
    var charm = GameManager.stats.get("charm", 10)
    var charm_bonus = int(charm * 0.05)
    var total_favor = (12 if is_fav else 8) + charm_bonus

    gift_btn.text = "🎁 送给 %s (好感+%d%s)" % [c_name, total_favor, "·魅力暴击!" if charm_bonus > 0 else ""]
    ThemeUtils.style_accent_btn(gift_btn, Color(0.95, 0.35, 0.6), 8, 2)
    gift_btn.pressed.connect(func():
        pop.queue_free()
        _gift_doll_to_companion(doll_data, is_fav, total_favor)
    )
    v.add_child(gift_btn)

    # 选项 2：收进自己背包
    var keep_btn = Button.new()
    keep_btn.text = "🎒 收进背包收藏"
    ThemeUtils.style_accent_btn(keep_btn, Color(0.3, 0.5, 0.8), 8, 1)
    keep_btn.pressed.connect(func():
        pop.queue_free()
        CollectionManager.add_item(doll_data["id"], 1)
        say_companion_dialogue("“恭喜你！这只玩偶放在书桌上一定很治愈！”", "default")
        _reset_machine_to_idle()
    )
    v.add_child(keep_btn)

func _gift_doll_to_companion(doll_data: Dictionary, is_fav: bool, favor_boost: int) -> void:
    GameManager.add_favor(companion_id, favor_boost)

    var meta = GameManager.char_meta.get(companion_id, {})
    var c_name = meta.get("name", "她")

    if is_fav:
        say_companion_dialogue("“天哪！竟然抓到了我最想要的这个！谢谢你，我一定会好好珍惜的……！”", "shy")
        GameManager.show_toast.emit("送出心仪玩偶！%s 的好感度大幅提升 +%d！" % [c_name, favor_boost])
    else:
        say_companion_dialogue("“送给我吗？哇……好开心！今天真的很棒呢！”", "shy")
        GameManager.show_toast.emit("送出玩偶！%s 的好感度提升 +%d！" % [c_name, favor_boost])

    _reset_machine_to_idle()

# ── 辅助计算与节点绑定 ────────────────────────────────────────
func _find_closest_doll(x_val: float) -> Dictionary:
    var closest: Dictionary = {}
    var min_dist: float = 9999.0
    for d in doll_nodes:
        var dist = abs(x_val - d["data"]["x"])
        if dist < min_dist:
            min_dist = dist
            closest = d
    return closest

func _attach_doll_to_claw(node: Control) -> void:
    node.get_parent().remove_child(node)
    claw_root.add_child(node)
    node.position = Vector2(-26, 40)

func _detach_doll_from_claw(node: Control) -> void:
    if node.get_parent() == claw_root:
        claw_root.remove_child(node)
        glass_view.add_child(node)
        for d in doll_nodes:
            if d["node"] == node:
                node.position = d["base_pos"]
                break

func _set_claw_angles(left_deg: float, right_deg: float) -> void:
    var tw = create_tween().set_parallel(true)
    tw.tween_property(claw_left, "rotation_degrees", left_deg, 0.22)
    tw.tween_property(claw_right, "rotation_degrees", right_deg, 0.22)

func _update_hud_display() -> void:
    coin_lbl.text = "💰 余额: %d 元" % GameManager.money
    luck_bar.value = luck_gauge

func _update_doll_visuals() -> void:
    pass

# ── 快速跳过（Anti-Grind）─────────────────────────────────────
func execute_skip() -> void:
    if GameManager.money < COST_PER_PLAY:
        GameManager.show_toast.emit("余额不足，无法快速扫荡！")
        return

    GameManager.add_stat("money", -COST_PER_PLAY)
    # 综合玩家体魄与智力计算扫荡成功率
    var intellect = GameManager.stats.get("intellect", 10)
    var strength = GameManager.stats.get("strength", 10)
    var skip_success_rate = 0.35 + (intellect + strength) * 0.003

    if randf() < skip_success_rate or luck_gauge >= 100.0:
        var d = DOLL_ITEMS.pick_random()
        luck_gauge = 0.0
        _on_catch_success(d)
    else:
        luck_gauge = clamp(luck_gauge + 35.0 * stat_luck_mult, 0.0, 100.0)
        GameManager.show_toast.emit("本次扫荡未抓中，幸运充能中！")
        _update_hud_display()
