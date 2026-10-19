extends Control

## DS-RN-05b · 社团目标层：跨周目携带的社团荣誉 flag（显式白名单，勿用前缀通配）
## 这 5 个同时也是 GameManager.GALLERY_ITEMS 的 flag，故已由 _upload_profile_on_ending
## 的 gallery 收集器（L348-352）自动写入 profile.gallery_flags，此处只做「回注」。
## ⚠️ 与 GALLERY_ITEMS 中 pose:"grad_club_*" 五条的 flag 必须逐字符一致，改名须同步两处。
## 显式列表而非 begins_with 前缀过滤：可被质量门断言「恰好 5 项、逐字符匹配」，
## 前缀过滤无法断言完整性且会静默吞掉拼写错误。可审计性优先。
const CLUB_ACHIEVEMENT_FLAGS := [
    "flag_club_achievement_literature",
    "flag_club_achievement_astronomy",
    "flag_club_achievement_broadcast",
    "flag_club_achievement_basketball",
    "flag_club_achievement_art",
]

# ── 结局定义（15个：6好结局/通用 + 6暧昧结局 + 3通用/坏/隐藏）──
const ENDINGS = [
    # ── 女角色线（男主攻略）──
    {
        "id": "yutong_good",
        "tag": "✦ 陈雨桐线", "title": "同一所学校的约定",
        "color": Color(0.357, 0.624, 0.831),
        "cg":  "res://assets/endings/yutong.jpg",
        "text": "中考放榜的那天，你们在西湖边等着手机里的通知。两条消息先后弹出——[color=#7ec8e3]同一所高中。[/color]\n\n雨桐没说话，只是把手机收进口袋，然后轻轻靠在你肩膀上。\n\n湖面起了风，桃花还没落完。"
    },
    {
        "id": "jingjing_good",
        "tag": "✦ 叶菁菁线", "title": "隔壁那盏总亮的灯",
        "color": Color(0.910, 0.490, 0.604),
        "cg":  "res://assets/endings/jingjing.jpg",
        "text": "高中录取通知书寄到的那天晚上，你们坐在楼顶看杭州的夜景。\n\n菁菁说，[color=#e87d9a]其实她很早就知道了，她只是想等你先开口。[/color]\n\n那盏从小就透过窗帘的灯光，今晚格外亮。"
    },
    {
        "id": "wanqing_good",
        "tag": "✦ 苏晚晴线", "title": "你是第一个读过那本书的人",
        "color": Color(0.655, 0.545, 0.980),
        "cg":  "res://assets/endings/wanqing.png",
        "text": "毕业前，晚晴把她写了两年的故事手稿放进你的书包，只说了一句话——\n\n[color=#a78bfa]\"只给你看。\"[/color]\n\n那本手稿的扉页上，有一句没写完的话，最后几个字，是你的名字。"
    },
    {
        "id": "xiaoxia_good",
        "tag": "✦ 林小夏线", "title": "最后一场球",
        "color": Color(0.298, 0.686, 0.541),
        "cg":  "res://assets/endings/xiaoxia.png",
        "text": "初三最后一次体育课，小夏在操场中央踢出了一记漂亮的吊射。\n\n球划过弧线的那一秒，她转过身来冲你大喊：\n\n[color=#4caf8a]\"你有没有一直看着我？\"[/color]\n\n你愣了一下——然后笑着点了头。"
    },
    # ── 男角色线（女主攻略）──
    {
        "id": "yifei_good",
        "tag": "✦ 沈逸飞线", "title": "写给你的那首曲子",
        "color": Color(0.357, 0.624, 0.831),
        "cg":  "res://assets/endings/yifei.jpg",  # TODO: 待美术提供专属 CG
        "text": "毕业前夜，音乐教室的灯还亮着。他把那首以你名字命名的曲子拉完，放下了弓。\n\n[color=#7ec8e3]\"我知道。我也是。\"[/color]\n\n月光落在他肩膀上，教室里很安静，却好像什么都有了。"
    },
    {
        "id": "zicheng_good",
        "tag": "✦ 周子诚线", "title": "最后一投",
        "color": Color(0.298, 0.686, 0.541),
        "cg":  "res://assets/endings/zicheng.png",  # TODO: 待美术提供专属 CG
        "text": "毕业前最后一个下午，你把球投了出去——进了。\n\n子诚愣了一下，然后露出那个虎牙大笑：\n\n[color=#4caf8a]\"废话，我当然知道！我也是，喜欢你。\"[/color]\n\n操场上的阳光把影子拉得很长。"
    },
    # ── 通用结局 ──
    {
        "id": "lonely_scholar",
        "tag": "✧ 隐藏结局", "title": "孤独的第一名",
        "color": Color(1.0, 0.843, 0.0),
        "cg":  "res://assets/endings/scholar.jpg",
        "text": "你的中考成绩全区第一，所有老师都来握手。\n\n照片里你一个人站着，笑得很正式。\n\n发圈的时候，你才发现，[color=#ffd700]好像没什么人想分享。[/color]"
    },
    {
        "id": "normal_end",
        "tag": "○ 普通结局", "title": "青春的句号",
        "color": Color(0.75, 0.72, 0.68),
        "cg":  "res://assets/endings/normal.jpg",
        "text": "初三毕业典礼结束，大家在操场上拍照留念。\n\n你把相机举起来，按下快门——\n\n这三年，就这么过去了。"
    },
    {
        "id": "digital_island",
        "tag": "✕ 坏结局", "title": "数字孤岛",
        "color": Color(0.55, 0.55, 0.55),
        "cg":  "res://assets/endings/digital_island.png",
        "text": "毕业典礼结束了。\n\n同学们在操场上互相签名、合影留念，欢声笑语连成一片。\n\n[color=#999999]而你只是一个人站在角落里，机械地刷着手机屏幕上的搞笑视频。\n\n三年时光如同指间沙般流逝，除了空虚，你什么也没留下。[/color]"
    },
    # ── 暧昧结局（好感 60–79，说出口之前）──────────────────────
    {
        "id": "yutong_ambiguous",
        "tag": "◇ 陈雨桐线", "title": "说出口之前",
        "color": Color(0.357, 0.624, 0.831),
        "cg":  "res://assets/endings/yutong.jpg",
        "text": "毕业典礼散场的傍晚，你们并排站在校门口。\n\n她好像想说什么，却只是笑了笑，把联系方式塞进你手里。\n\n[color=#7ec8e3]\"高中……也要联系啊。\"[/color]\n\n那句话背后还有很多，只是你们都没有说出口。"
    },
    {
        "id": "jingjing_ambiguous",
        "tag": "◇ 叶菁菁线", "title": "楼上那盏灯熄了",
        "color": Color(0.910, 0.490, 0.604),
        "cg":  "res://assets/endings/jingjing.jpg",
        "text": "你们最后一次坐在楼道台阶上，像以前那样聊到很晚。\n\n菁菁站起来，顿了一下，回头说：\n\n[color=#e87d9a]\"你要记得我啊，不许忘。\"[/color]\n\n楼道灯熄了，你听见她上楼的脚步声渐渐消失，什么都没来得及说。"
    },
    {
        "id": "wanqing_ambiguous",
        "tag": "◇ 苏晚晴线", "title": "未完的句子",
        "color": Color(0.655, 0.545, 0.980),
        "cg":  "res://assets/endings/wanqing.png",
        "text": "晚晴在毕业纪念册的扉页上写了很长一段话，最后一句卡住了。\n\n她盯着那半截句子看了很久，然后把笔盖上。\n\n[color=#a78bfa]\"有些话，等以后见面再说吧。\"[/color]\n\n你把那本册子收好，心里明白，那个\"以后\"不知道什么时候才会到来。"
    },
    {
        "id": "xiaoxia_ambiguous",
        "tag": "◇ 林小夏线", "title": "最后一声加油",
        "color": Color(0.298, 0.686, 0.541),
        "cg":  "res://assets/endings/xiaoxia.png",
        "text": "你们在操场做了初中最后一场跑步。\n\n小夏跑在你前面，头也没回，大声喊了一句：\n\n[color=#4caf8a]\"你要是跟上来，我就有话对你说！\"[/color]\n\n你追上去了，可那句话，她最终还是没说出口。"
    },
    {
        "id": "yifei_ambiguous",
        "tag": "◇ 沈逸飞线", "title": "一首没拉完的曲子",
        "color": Color(0.357, 0.624, 0.831),
        "cg":  "res://assets/endings/yifei.jpg",  # TODO: 待美术提供专属 CG
        "text": "毕业前夜，他在音乐教室拉了一首没拉完的曲子，然后把琴弓放下。\n\n[color=#7ec8e3]\"这首曲子还没有名字。\"[/color]\n\n他看向你，欲言又止，最后只是笑了笑——你觉得，那个名字你知道是谁。"
    },
    {
        "id": "zicheng_ambiguous",
        "tag": "◇ 周子诚线", "title": "最后一传",
        "color": Color(0.298, 0.686, 0.541),
        "cg":  "res://assets/endings/zicheng.png",
        "text": "毕业那天的最后一场球，子诚把球传给了你，没有多说一句话。\n\n散场时，他拍了拍你的肩膀：\n\n[color=#4caf8a]\"以后打球——记得找我。\"[/color]\n\n你看着他离开，知道那句话里还有另一层意思，你只是没有接住。"
    },
    # ── 真结局（NG+2以上 + 好感>=90 + 看过对应好结局）
    {
        "id": "yutong_true",
        "tag": "★ 陈雨桐·真结局", "title": "西湖，每一年",
        "color": Color(0.357, 0.624, 0.831),
        "cg":  "res://assets/endings/yutong.jpg",
        "text": "不知道是第几次站在西湖边了。\n\n断桥的石缝里还有上次来时你们刻下的名字，字迹已经有些模糊，但指尖碰到时，心里还是一阵暖。\n\n雨桐靠在你肩膀上，说：[color=#7ec8e3]\"我想过了，不管以后在哪，每年都要来这里一次。\"[/color]\n\n你说好。那个好没有期限。"
    },
    {
        "id": "jingjing_true",
        "tag": "★ 叶菁菁·真结局", "title": "楼道里的光，再亮一次",
        "color": Color(0.910, 0.490, 0.604),
        "cg":  "res://assets/endings/jingjing.jpg",
        "text": "楼道的感应灯又坏了。\n\n你们坐在台阶上，黑暗里只有彼此的轮廓。菁菁说，[color=#e87d9a]\"以前我每次踩到那一格台阶都会想——如果他也在就好了。\"[/color]\n\n\"你就是那个他。\"\n\n灯重新亮起来，你看见她眼眶有点红，却在笑。"
    },
    {
        "id": "wanqing_true",
        "tag": "★ 苏晚晴·真结局", "title": "她写完那句话了",
        "color": Color(0.655, 0.545, 0.980),
        "cg":  "res://assets/endings/wanqing.png",
        "text": "纪念册里那半截句子，她终于写完了。\n\n你没有催，只是有一天她把册子递过来，扉页上那行字已经满了。\n\n[color=#a78bfa]\"我曾以为故事里的人都是虚构的，直到遇见你，我才明白，有些故事从一开始就是真的。\"[/color]\n\n你把书合上，轻声说：\"我也有话要说。\"\n\n窗外是西湖，桂花刚开。"
    },
    {
        "id": "xiaoxia_true",
        "tag": "★ 林小夏·真结局", "title": "终点线之后",
        "color": Color(0.298, 0.686, 0.541),
        "cg":  "res://assets/endings/xiaoxia.png",
        "text": "小夏说，她跑了这么多年，第一次在终点线旁边等人。\n\n[color=#4caf8a]\"以前我从来没等过任何人，跑完就跑完了。\"[/color]\n\n她回头看你，表情有些别扭，但没有躲开眼神。\n\n\"你知道这意味着什么吗？\"\n\n你知道。操场上的阳光把影子叠在一起。"
    },
]

# ── 节点引用 ──────────────────────────────────────────────────
@onready var bg_tex      = $BG
@onready var overlay     = $Overlay
@onready var tag_lbl     = $Card/TagRow/Tag
@onready var title_lbl   = $Card/Title
@onready var text_lbl    = $Card/Text
@onready var back_btn    = $Card/BtnRow/BackBtn
@onready var restart_btn = $Card/BtnRow/RestartBtn
@onready var card        = $Card

var _tween: Tween
var _current_ending_id: String = ""
var _ng_btn: Button = null  # 「开始第二周目」按钮（动态创建）
# S1 · NG+ 离线兜底：结算时就地留存一份「本周目继承快照」。
# 云端 profile 拉取失败（无网 / 后端不可达 / JSON 损坏）时以此为准，
# 保证 ng_count / seen_endings / title_* 等跨周目数据不因网络问题丢失。
var _ng_profile_snapshot: Dictionary = {}

func _ready():
    back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/StartMenu.tscn"))
    restart_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/StartMenu.tscn"))
    _style_buttons()
    hide()

func _style_buttons():
    for btn in [back_btn, restart_btn]:
        var s = StyleBoxFlat.new()
        s.bg_color = Color(0.1, 0.1, 0.15, 0.85)
        s.border_width_left = 1; s.border_width_right = 1
        s.border_width_top = 1; s.border_width_bottom = 1
        s.border_color = Color(1, 1, 1, 0.25)
        s.corner_radius_top_left = 10; s.corner_radius_top_right = 10
        s.corner_radius_bottom_left = 10; s.corner_radius_bottom_right = 10
        btn.add_theme_stylebox_override("normal", s)
        var h = s.duplicate(); h.bg_color = Color(0.2, 0.2, 0.3, 0.9)
        btn.add_theme_stylebox_override("hover", h)
        btn.add_theme_color_override("font_color", Color(0.94, 0.92, 0.88, 1))

# ── 五社通大成 判定（DS-RN-05c）────────────────────────────────
## 判断当前局（含 NG+ 继承的 flag）是否集齐全部 5 个社团成就 flag。
func _is_club_master_complete() -> bool:
    for f in CLUB_ACHIEVEMENT_FLAGS:
        if not GameManager.flags.get(f, false):
            return false
    return true

# ── 对外接口：自动评定结局 ────────────────────────────────────
func trigger_ending():
    var ending = _evaluate_ending()
    show_ending(ending)

# ── 对外接口：直接触发指定结局（事件 isEndTrigger 用）────────
func trigger_specific_ending(ending_id: String):
    var ending = _find_ending(ending_id)
    show_ending(ending)

func _find_ending(ending_id: String) -> Dictionary:
    for e in ENDINGS:
        if e["id"] == ending_id:
            return e
    # 找不到则用普通结局
    for e in ENDINGS:
        if e["id"] == "normal_end":
            return e
    return ENDINGS[ENDINGS.size() - 1]

# ── 结局评定逻辑（融合中考志愿系统）────────────────
func _evaluate_ending() -> Dictionary:
    var aff       = GameManager.favorability
    var addict    = GameManager.stats.get("addict", 0)
    var intellect = GameManager.stats.get("intellect", 0)
    var gender    = GameManager.gender

    # 坏结局：网瘾 >= 65（与全局惩罚区间 >60 接轨，玩家感知更一致）
    if addict >= 65:
        return _find_ending("digital_island")

    # 找最高好感角色
    var best_char = ""
    var best_aff  = 0
    var female_chars = ["yutong", "jingjing", "wanqing", "xiaoxia"]
    var male_chars   = ["yifei", "zicheng", "beichen", "jingjing_m", "zijun"]
    var targets = female_chars if gender == "male" else male_chars

    for char_id in targets:
        var char_aff = aff.get(char_id, 0)
        if char_aff > best_aff:
            best_aff  = char_aff
            best_char = char_id

    # ── 真结局（NG+2+ 且好感>=90 且已看过对应好结局）────────
    var ng_count: int = GameManager.flags.get("ng_count", 0)
    var seen_endings: Array = GameManager.flags.get("seen_endings", [])
    if ng_count >= 2 and best_aff >= 90 and best_char != "":
        var good_id = best_char + "_good"
        var true_id = best_char + "_true"
        if good_id in seen_endings:
            var found = _find_ending(true_id)
            if found["id"] == true_id:
                return found

    # 好感 >= 80 → 角色专属好结局（需要考入同校！）
    if best_aff >= 80:
        var char_target_schools = {
            "yutong":   "hz2",
            "jingjing": "hz14",
            "wanqing":  "hanggao",
            "xiaoxia":  "xuejun",
            "yifei":    "hz2",
            "zicheng":  "normal"
        }
        var target_school = char_target_schools.get(best_char, "normal")
        var admission = GameManager.get_admission_result()
        var player_school = ""
        if admission.success and admission.school != null:
            player_school = admission.school.id
        elif admission.school != null:
            player_school = admission.school.id

        if player_school == target_school:
            var ending_id = best_char + "_good"
            var found = _find_ending(ending_id)
            if found["id"] == ending_id:
                return found
        else:
            # 遗憾错过：好感够了但没考入同校 → 独立遗憾结局
            var char_name = GameManager.char_meta.get(best_char, {}).get("name", "她")
            var miss_end = _find_ending("normal_end").duplicate()
            miss_end["id"]    = "miss_end"
            miss_end["tag"]   = "◈ 遗憾结局"
            miss_end["title"] = "渐行渐远"
            miss_end["text"]  = \
                "毕业典礼上，你看着%s的背影，心里有些怅然。\n\n" % char_name + \
                "你们最终没有考入同一所高中。\n\n" + \
                "高中三年，各自忙碌，这段初中的懵懂感情，" + \
                "最终变成了压在青春箱底的回忆。"
            return miss_end

    # ── 暧昧结局：好感 60–79，关系尚未说破那层窗户纸 ────────
    if best_aff >= 60 and best_char != "":
        var amb_id = best_char + "_ambiguous"
        var found = _find_ending(amb_id)
        if found["id"] == amb_id:
            return found

    # 隐藏结局：学习 >= 85 且好感 < 40
    if intellect >= 85 and best_aff < 40:
        return _find_ending("lonely_scholar")

    return _find_ending("normal_end")

# ── 展示结局画面 ───────────────────────────────────────────────
func show_ending(ending: Dictionary):
    _current_ending_id = ending.get("id", "")
    GameManager.set_flag("achv_ending_reached", true)
    if is_instance_valid(AchievementManager):
        AchievementManager.check_all()
    var char_color: Color = ending.get("color", Color.WHITE)
    var is_bad = _current_ending_id == "digital_island"
    var is_good = _current_ending_id.ends_with("_good")

    # ── 专属 CG 背景图 ────────────────────────────────────────
    var cg_path = ending.get("cg", "")
    if cg_path != "" and ResourceLoader.exists(cg_path):
        bg_tex.texture = load(cg_path)
        overlay.color = Color(0, 0, 0, 0.78 if is_bad else 0.52)
    else:
        bg_tex.texture = null
        overlay.color = Color(0, 0, 0, 0.88)

    # ── 标签 ─────────────────────────────────────────────────
    tag_lbl.text = ending.get("tag", "")
    tag_lbl.add_theme_color_override("font_color", char_color)

    # ── 标题 ─────────────────────────────────────────────────
    title_lbl.text = ending.get("title", "")
    title_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90, 1))

    # ── 正文 ─────────────────────────────────────────────────
    text_lbl.text = ending.get("text", "")

    # ── 入场动画 ─────────────────────────────────────────────
    card.modulate.a = 0.0
    card.position.y = 40.0
    show()

    if _tween: _tween.kill()
    _tween = create_tween().set_parallel(true)
    _tween.tween_property(card, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_OUT)
    _tween.tween_property(card, "position:y", 0.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

    if bg_tex.texture:
        bg_tex.modulate.a = 0.0
        _tween.tween_property(bg_tex, "modulate:a", 1.0, 1.4).set_ease(Tween.EASE_OUT)

    # ── 上传玩家全局档案到云端（异步，失败静默处理）────────
    _upload_profile_on_ending(is_good)

    # ── 好结局/普通结局显示「开始第二周目」按钮 ────────────
    if not is_bad:
        _show_ng_button(char_color)

    # ── DS-RN-05c 五社通大成延迟演出 ─────────────────────────
    # 当集齐所有 5 个社团成就 flag 时，在常规结局 6 秒后追加第二幕大成 CG。
    if not is_bad and _is_club_master_complete():
        _play_club_master_epilogue.call_deferred(char_color)

# ── 五社通大成 第二幕演出（异步）──────────────────────────────
func _play_club_master_epilogue(char_color: Color) -> void:
    # 等待 6 秒让玩家欣赏常规结局
    await get_tree().create_timer(6.0).timeout

    # 卡片淡出
    if _tween: _tween.kill()
    _tween = create_tween()
    _tween.tween_property(card, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
    await _tween.finished

    # 替换背景 CG
    var master_bg = "res://assets/backgrounds/grad_club_master.jpg"
    if ResourceLoader.exists(master_bg):
        bg_tex.modulate.a = 0.0
        bg_tex.texture = load(master_bg)
        overlay.color   = Color(0, 0, 0, 0.40)
        var t2 = create_tween()
        t2.tween_property(bg_tex, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_OUT)
        await t2.finished

    # 重写标签/标题/正文
    tag_lbl.text = "★★★ 隐藏结局"
    tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
    title_lbl.text = "《全能王·西湖之夏》"
    title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
    text_lbl.text = \
        "文学、天文、广播、篮球、美术……\n\n" + \
        "三年我全都走过了。\n\n" + \
        "[color=#ffd700]有人说，静得下心才能做好一件事。[/color]\n\n" + \
        "也许说得对。只是那三年——\n就这么真实地、乐此不疲地，把每一个社团都给走到了尾巅。"

    # 卡片重新入场
    if _tween: _tween.kill()
    _tween = create_tween().set_parallel(true)
    _tween.tween_property(card, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_OUT)
    _tween.tween_property(card, "position:y", 0.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

    # 解锁大成画廊并持久化
    GameManager.set_flag("flag_club_achievement_master", true)
    GameManager.show_toast.emit("⭐ 密层画廊《全能王·西湖之夏》已解锁！")
    _upload_profile_on_ending(true)

# ── 上传结局数据到玩家全局档案 ──────────────────────────────
func _upload_profile_on_ending(is_good: bool):
    # 收集当前周目需要持久化的数据
    var titles: Array = []
    for flag_key in GameManager.flags.keys():
        if flag_key.begins_with("title_"):
            titles.append(flag_key.substr(6))  # 去掉 "title_" 前缀

    var recipes: Array = []
    if CookingManager.has_method("get_unlocked_recipe_ids"):
        recipes = CookingManager.get_unlocked_recipe_ids()

    var gallery: Array = []
    for item in GameManager.GALLERY_ITEMS:
        var f = item.get("flag", "")
        if f != "" and GameManager.flags.has(f):
            gallery.append(f)

    # 跨周目保留所有已达成的成就与计数器
    for flg in GameManager.flags.keys():
        if String(flg).begins_with("achv_") and not flg in gallery:
            gallery.append(flg)

    var seen_endings: Array = GameManager.flags.get("seen_endings", [])
    if _current_ending_id != "" and not _current_ending_id in seen_endings:
        seen_endings.append(_current_ending_id)
    GameManager.set_flag("seen_endings", seen_endings)

    # 继承金钱：当前金钱的 50%，上限 500
    var inherited = min(int(GameManager.money * 0.5), 500)

    # ── 继承好感度快照（NG+ 时按 20% 起步）──
    var inherited_favorability: Dictionary = {}
    for char_id in GameManager.favorability.keys():
        var fav = GameManager.favorability[char_id]
        if fav > 0:
            inherited_favorability[char_id] = fav

    # ── 分科复习进度快照（NG+ 时按30%继承）──
    var inherited_subjects: Dictionary = {}
    for subj in GameManager.subject_scores.keys():
        var sc = GameManager.subject_scores[subj]
        if sc > 0:
            inherited_subjects[subj] = sc

    var profile = {
        "ng_count":               GameManager.flags.get("ng_count", 0) + 1,
        "unlocked_titles":        titles,
        "unlocked_recipes":       recipes,
        "seen_endings":           seen_endings,
        "gallery_flags":          gallery,
        "inherited_money":        inherited,
        "inherited_favorability": inherited_favorability,
        "inherited_subjects":     inherited_subjects,
    }
    # S1：先落本地快照，再发起上传。快照与上传载荷同源，
    # 因此「云端可用」与「云端不可用」两条路径的继承语义完全一致。
    _ng_profile_snapshot = profile.duplicate(true)
    NetworkManager.save_player_profile(profile)

# ── S1 · 继承数据合并：云端优先，缺失项回落本地快照 ─────────────
## cloud 为空 / 字段缺失 / 列表为空时一律采用 local 的对应项；
## ng_count 取两者最大值（防云端滞后回退周目数），
## seen_endings / unlocked_titles / unlocked_recipes / gallery_flags 取并集（只增不减）。
func _merge_inherit_profile(cloud: Dictionary, local: Dictionary) -> Dictionary:
    var out: Dictionary = local.duplicate(true)
    for k in cloud.keys():
        var v = cloud[k]
        if v == null:
            continue
        # 云端返回的空列表/空字典不覆盖本地已有值（首次请求会返回空默认结构）
        if v is Array and (v as Array).is_empty() and out.has(k):
            continue
        if v is Dictionary and (v as Dictionary).is_empty() and out.has(k):
            continue
        out[k] = v

    out["ng_count"] = max(int(cloud.get("ng_count", 0)), int(local.get("ng_count", 0)))
    for list_key in ["seen_endings", "unlocked_titles", "unlocked_recipes", "gallery_flags"]:
        var merged: Array = []
        for arr in [local.get(list_key, []), cloud.get(list_key, [])]:
            if arr is Array:
                for item in arr:
                    if not item in merged:
                        merged.append(item)
        out[list_key] = merged
    return out

# ── 创建「开始第二周目」NG+ 按钮 ─────────────────────────────
func _show_ng_button(accent: Color):
    # 若已存在则不重复创建
    if _ng_btn and is_instance_valid(_ng_btn):
        return

    _ng_btn = Button.new()
    _ng_btn.text = "✨ 开始第二周目"
    _ng_btn.custom_minimum_size = Vector2(180, 44)
    _ng_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

    ThemeUtils.style_accent_btn(_ng_btn, accent, 10, 2)
    _ng_btn.add_theme_font_size_override("font_size", 16)

    # 插入到按钮行（BackBtn 的父节点）
    var btn_row = back_btn.get_parent()
    btn_row.add_child(_ng_btn)
    btn_row.move_child(_ng_btn, 0)  # 放最左边

    _ng_btn.pressed.connect(_on_ng_plus_pressed)

# ── NG+ 按下：拉取云端 profile 后开始新周目 ───────────────────
func _on_ng_plus_pressed():
    _ng_btn.disabled = true
    _ng_btn.text = "加载中..."

    # 先尝试从云端拉最新 profile（含继承数据）
    var on_loaded = func(success: bool, data: Dictionary):
        # ── S1 · 继承数据来源决策（本地兜底优先于云端失败）──────────
        # 云端成功 → 与本地快照合并（只增不减）；
        # 云端失败 → 全量采用本地快照，NG+ 照常开始，仅提示降级；
        # 两者皆空 → 属异常路径，保留旧档不进入空 NG+（绝不清 flags）。
        var cloud: Dictionary = data if success and data is Dictionary else {}
        var src: Dictionary = _merge_inherit_profile(cloud, _ng_profile_snapshot)
        if src.is_empty():
            GameManager.show_toast.emit("❌ 继承数据缺失，未开始新周目（存档保持不变）。")
            _ng_btn.disabled = false
            _ng_btn.text = "✨ 开始第二周目"
            return
        if not success:
            push_warning("[EndingScreen] 云端 profile 拉取失败，已回落本地继承快照（离线 NG+）")
            GameManager.show_toast.emit("📴 云端不可用，已用本地记录继承进入新周目。")

        var inherited_money: int      = src.get("inherited_money", 0)
        var inherited_recipes: Array  = src.get("unlocked_recipes", [])
        var inherited_titles: Array   = src.get("unlocked_titles", [])
        var ng_count: int             = max(1, int(src.get("ng_count", 1)))
        var seen_endings: Array       = src.get("seen_endings", [])
        var inherited_fav: Dictionary = src.get("inherited_favorability", {})

        # 重置 GameManager 到初始状态（保留玩家名/学校/性别）
        var pname  = GameManager.player_name
        var sname  = GameManager.school_name
        var gender = GameManager.gender

        GameManager.day = 1
        GameManager.day_of_week = 1
        GameManager.slot_index = 0
        GameManager.money = 100 + inherited_money
        GameManager.player_name = pname
        GameManager.school_name = sname
        GameManager.gender = gender
        GameManager.stats = {"intellect": 10, "strength": 10, "social": 10,
                             "art": 10, "charm": 10, "stress": 0, "addict": 0}
        GameManager.reset_char_initiative()
        GameManager.flags = {}
        # S4 · 漏清修复：关系状态机缓存不在 flags 内，整体清 flags 清不掉它。
        # 不清则上周目的 cold/crush 等状态会带入新周目 day1（冷战 flag 已随 flags 清空，
        # 但缓存里的 "cold" 仍会被 get_rel_state() 直接命中）。下方好感重置后统一重算。
        GameManager.relationship_state = {}
        GameManager.inventory = {}
        GameManager.diary = []
        GameManager.recent_logs = []
        GameManager.hw_status = 0
        GameManager.hw_neglect_count = 0

        # ── 好感度重置 + NG+ 继承（取上周目 20% 为起点，不低于角色默认初始值）──
        var default_favs = {"jingjing": 20, "jingjing_m": 20}
        for char_id in GameManager.favorability.keys():
            var base  = default_favs.get(char_id, 0)
            var prev  = inherited_fav.get(char_id, 0)
            var bonus = int(prev * 0.20)   # 继承上周目好感的 20%
            GameManager.favorability[char_id] = max(base, bonus)

        # S4 · 按新周目好感重建关系状态（silent：不弹「关系进入 XX 阶段」提示）。
        # 此刻 flags 已清空 → 无 rel_cold_* → 全部由好感纯函数推导，状态机自洽。
        RelationshipManager.recompute_all_states(true)

        # ── 分科复习进度继承（30%，新周目保留复习基础）──
        var inherited_subjects: Dictionary = src.get("inherited_subjects", {})
        for subj in GameManager.subject_scores.keys():
            var prev_sc = inherited_subjects.get(subj, 0)
            if prev_sc is String: prev_sc = int(prev_sc)
            GameManager.subject_scores[subj] = min(int(prev_sc * 0.30), 30)

        # 写入继承的跨周目 flags
        GameManager.flags["ng_count"]     = ng_count
        GameManager.flags["seen_endings"] = seen_endings
        for t in inherited_titles:
            GameManager.flags["title_" + t] = true

        # ── DS-RN-05b · 画廊 flag 跨周目回注 ──────────────────────
        # 背景：gallery_flags 此前只被「上传」(L381 附近) 与「并集合并」(_merge_inherit_profile)，
        # 却从未回注 GameManager.flags —— 导致 flags={} 之后所有画廊 CG 在 NG+ 一律丢失。
        # 本次一并根治：① 显式白名单回注社团成就；② 全集回注既有 CG（holiday_memory_* /
        # grad_photo / grad_yearbook / pet_orange_cat / west_lake_* 等）。
        # 两处均为幂等置真；成就 flag 不被任何 excludeFlags 引用（红线 R6），故不阻断链重走。
        var inherited_gallery: Array = src.get("gallery_flags", [])
        for g in CLUB_ACHIEVEMENT_FLAGS:
            if g in inherited_gallery:
                GameManager.flags[g] = true
        for g in inherited_gallery:
            if g is String and g != "":
                GameManager.flags[g] = true

        # 继承已解锁菜谱
        if not inherited_recipes.is_empty() and CookingManager.has_method("inherit_recipes"):
            CookingManager.inherit_recipes(inherited_recipes)

        # 重置赛季数据
        SeasonManager.season_exp             = 0
        SeasonManager.season_level           = 1
        SeasonManager.challenge_progress     = {}
        SeasonManager.completed_challenges   = []
        SeasonManager.claimed_rewards        = []
        SeasonManager.visited_locations_list = []

        GameManager.state_updated.emit()
        GameManager.show_toast.emit("✨ 第 %d 周目开始！继承金钱：💰%d" % [ng_count, inherited_money])
        if ng_count > 1:
            GameManager.show_toast.emit("💫 某些人……仿佛在记忆深处留下了印记。")

        # 切换到游戏主场景
        get_tree().change_scene_to_file("res://scenes/MainGame.tscn")

    NetworkManager.player_profile_loaded.connect(on_loaded, CONNECT_ONE_SHOT)
    NetworkManager.load_player_profile()
