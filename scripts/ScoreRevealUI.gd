extends CanvasLayer

signal reveal_finished

@onready var panel = PanelContainer.new()
@onready var vbox = VBoxContainer.new()
@onready var title_lbl = Label.new()
@onready var loading_lbl = Label.new()
@onready var scores_grid = GridContainer.new()
@onready var total_lbl = Label.new()
@onready var event_lbl = Label.new()
@onready var admission_lbl = Label.new()
@onready var close_btn = Button.new()

var target_result = {}
var subject_labels = {}
var current_anim_step = 0

func _init():
    layer = 100 # 保证在最上层
    visible = false

func _ready():
    # ── 背景遮罩 ──
    var bg = ColorRect.new()
    bg.color = Color(0, 0, 0, 0.85)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    # ── 居中容器 ──
    var center_container = CenterContainer.new()
    center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center_container)

    # ── 主面板 ──
    panel.custom_minimum_size = Vector2(500, 600)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.14, 0.20, 1.0)
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.3, 0.5, 0.8, 0.5)
    panel.add_theme_stylebox_override("panel", style)
    center_container.add_child(panel)

    # ── 垂直布局 ──
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 20)
    
    # 留点边距
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_top", 30)
    margin.add_theme_constant_override("margin_bottom", 30)
    margin.add_theme_constant_override("margin_left", 40)
    margin.add_theme_constant_override("margin_right", 40)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_child(margin)
    margin.add_child(vbox)

    # ── 标题 ──
    title_lbl.text = "杭州市教育考试网 - 成绩查询"
    title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_lbl.add_theme_font_size_override("font_size", 24)
    title_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
    vbox.add_child(title_lbl)

    var sep1 = HSeparator.new()
    vbox.add_child(sep1)

    # ── 正在加载 ──
    loading_lbl.text = "正在连接服务器，获取数据中..."
    loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    vbox.add_child(loading_lbl)

    # ── 成绩网格 ──
    scores_grid.columns = 2
    scores_grid.add_theme_constant_override("h_separation", 80)
    scores_grid.add_theme_constant_override("v_separation", 15)
    scores_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vbox.add_child(scores_grid)
    scores_grid.hide()

    var subjects = [
        {"key": "chinese", "name": "语 文"},
        {"key": "math", "name": "数 学"},
        {"key": "english", "name": "英 语"},
        {"key": "science", "name": "科 学"},
        {"key": "society", "name": "社 会"},
        {"key": "pe", "name": "体 育"}
    ]

    for sub in subjects:
        var name_lbl = Label.new()
        name_lbl.text = sub.name
        name_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
        scores_grid.add_child(name_lbl)

        var val_lbl = Label.new()
        val_lbl.text = "???"
        val_lbl.add_theme_font_size_override("font_size", 20)
        val_lbl.add_theme_color_override("font_color", Color.WHITE)
        val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        scores_grid.add_child(val_lbl)
        subject_labels[sub.key] = val_lbl

    var sep2 = HSeparator.new()
    vbox.add_child(sep2)

    # ── 总分 ──
    total_lbl.text = "总分：???"
    total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    total_lbl.add_theme_font_size_override("font_size", 32)
    total_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
    vbox.add_child(total_lbl)
    total_lbl.hide()

    # ── 考试事件日志 ──
    event_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    event_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    event_lbl.add_theme_font_size_override("font_size", 14)
    event_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
    vbox.add_child(event_lbl)
    event_lbl.hide()

    # ── 录取结果 ──
    admission_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    admission_lbl.add_theme_font_size_override("font_size", 22)
    vbox.add_child(admission_lbl)
    admission_lbl.hide()

    # ── 确认按钮 ──
    close_btn.text = "确 认"
    close_btn.custom_minimum_size = Vector2(200, 45)
    close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    close_btn.pressed.connect(_on_close)
    vbox.add_child(close_btn)
    close_btn.hide()

func show_result():
    target_result = GameManager.latest_exam_result
    visible = true
    
    # 重置状态
    loading_lbl.show()
    scores_grid.hide()
    total_lbl.hide()
    event_lbl.hide()
    admission_lbl.hide()
    close_btn.hide()
    
    for key in subject_labels.keys():
        subject_labels[key].text = "???"
        
    total_lbl.text = "总分：???"
    
    # 开始悬念动画
    _simulate_loading()

func _simulate_loading():
    # 模拟网络卡顿
    var tween = create_tween()
    tween.tween_interval(1.5)
    tween.tween_callback(func():
        loading_lbl.text = "连接成功，正在解密数据..."
    )
    tween.tween_interval(1.0)
    tween.tween_callback(func():
        loading_lbl.hide()
        scores_grid.show()
        _start_rolling_scores()
    )
func _start_rolling_scores():
    # 逐个从 0 滚动揭晓成绩，仪式感拉满
    var keys = ["chinese", "math", "english", "science", "society", "pe"]
    var tween = create_tween()
    for i in range(keys.size()):
        var key = keys[i]
        var target_val = int(target_result[key])
        
        # 1. 高亮闪烁反馈
        tween.tween_callback(func():
            var lbl = subject_labels[key]
            lbl.modulate = Color(2, 2, 2, 1) # 强光闪烁
            var sub_tween = create_tween()
            sub_tween.tween_property(lbl, "modulate", Color.WHITE, 0.3)
        )
        # 2. 顺滑滚动显示分数
        tween.tween_method(
            func(val: int): subject_labels[key].text = str(val),
            0,
            target_val,
            0.25
        ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        
        # 3. 间隔微调
        tween.tween_interval(0.15)
        
    tween.tween_interval(0.5)
    tween.tween_callback(func():
        total_lbl.show()
        var total_val = int(target_result["total"])
        
        # 总分采用华丽的滚动大动画
        var total_tween = create_tween()
        total_tween.tween_method(
            func(val: int): total_lbl.text = "总分：%d" % val,
            0,
            total_val,
            0.8
        ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        
        # 总分文字弹性微弹跳，制造震撼感
        total_lbl.pivot_offset = total_lbl.size / 2.0
        total_lbl.scale = Vector2(0.8, 0.8)
        var scale_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
        scale_tween.tween_property(total_lbl, "scale", Vector2(1.0, 1.0), 1.0)
        
        # 显示突发事件（如果有）
        if target_result.has("events") and target_result["events"].size() > 0:
            var txt = ""
            for e in target_result["events"]:
                txt += "※ " + e + "\n"
            event_lbl.text = txt.strip_edges()
            event_lbl.show()
            
        # 延迟显示录取结果
        var delay_tween = create_tween()
        delay_tween.tween_interval(1.5)
        delay_tween.tween_callback(_show_admission)
    )

func _show_admission():
    if target_result.get("is_mock", false):
        admission_lbl.text = "【模拟考评估结束】"
        admission_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
    else:
        var adm = GameManager.get_admission_result()
        if adm.success:
            admission_lbl.text = adm.reason
            admission_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
        else:
            admission_lbl.text = adm.reason
            admission_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
            
    admission_lbl.show()
    close_btn.show()

func _on_close():
    visible = false
    reveal_finished.emit()
