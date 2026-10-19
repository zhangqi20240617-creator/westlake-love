extends Panel
# SeasonUI.gd — 青春赛季界面（S1 赛季：烟雨江南）

signal closed

var reward_container: HBoxContainer
var challenge_container: VBoxContainer
var level_lbl: Label
var exp_lbl: Label
var exp_bar: ProgressBar

func _ready():
	# ── 铺设全屏半透明遮罩 ──
	anchor_left = 0.0; anchor_top = 0.0
	anchor_right = 1.0; anchor_bottom = 1.0
	offset_left = 0; offset_top = 0; offset_right = 0; offset_bottom = 0

	var barrier = ThemeUtils.create_style(Color(0, 0, 0, 0.65), 0)
	add_theme_stylebox_override("panel", barrier)

	# ── 赛季主体面板 ──
	var main = PanelContainer.new()
	main.custom_minimum_size = Vector2(760, 560)
	
	var ms = ThemeUtils.make_card_style(Color("#0f172a"), Color("#10b981"), 18)
	ms.border_width_left = 2; ms.border_width_right = 2
	ms.border_width_top = 2; ms.border_width_bottom = 2
	ms.shadow_color = Color(0, 0, 0, 0.5)
	ms.shadow_size = 20
	main.add_theme_stylebox_override("panel", ms)
	
	main.anchor_left = 0.5; main.anchor_top = 0.5
	main.anchor_right = 0.5; main.anchor_bottom = 0.5
	main.offset_left = -380; main.offset_top = -280
	main.offset_right = 380; main.offset_bottom = 280
	add_child(main)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	main.add_child(vbox)

	# ── 1. 顶部标题 ──
	var hdr = HBoxContainer.new()
	hdr.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(hdr)
	var sp0 = Control.new(); sp0.custom_minimum_size = Vector2(12, 0); hdr.add_child(sp0)
	
	var title = Label.new()
	title.text = "🏆 青春赛季：%s (第1赛季)" % SeasonManager.SEASON_NAME
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#10b981"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 36)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_btn(close_btn, Color("#ef4444"), Color("#dc2626"))
	close_btn.pressed.connect(func(): closed.emit(); queue_free())
	hdr.add_child(close_btn)
	var sp1 = Control.new(); sp1.custom_minimum_size = Vector2(10, 0); hdr.add_child(sp1)

	# ── 2. 赛季核心数据展示区（等级、经验条） ──
	var info_panel = PanelContainer.new()
	var ips = ThemeUtils.create_style(Color("#1e293b", 0.6), 12, Color.TRANSPARENT, 0, -1, 16, 16, 12, 12)
	info_panel.add_theme_stylebox_override("panel", ips)
	vbox.add_child(info_panel)

	var info_vb = VBoxContainer.new()
	info_vb.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_vb)

	var theme_lbl = Label.new()
	theme_lbl.text = "📜 赛季主题：" + SeasonManager.SEASON_THEME
	theme_lbl.add_theme_font_size_override("font_size", 16)
	theme_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	info_vb.add_child(theme_lbl)

	var lvl_row = HBoxContainer.new()
	info_vb.add_child(lvl_row)

	level_lbl = Label.new()
	level_lbl.text = "LV.%d" % SeasonManager.season_level
	level_lbl.add_theme_font_size_override("font_size", 24)
	level_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	lvl_row.add_child(level_lbl)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	lvl_row.add_child(spacer)

	exp_bar = ProgressBar.new()
	exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exp_bar.custom_minimum_size = Vector2(0, 20)
	lvl_row.add_child(exp_bar)

	exp_lbl = Label.new()
	exp_lbl.add_theme_font_size_override("font_size", 15)
	exp_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	lvl_row.add_child(exp_lbl)

	# ── 3. 赛季等级奖励滑轨 (水平滚动) ──
	var rew_scroll = ScrollContainer.new()
	rew_scroll.custom_minimum_size = Vector2(0, 135)
	rew_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rew_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(rew_scroll)

	reward_container = HBoxContainer.new()
	reward_container.add_theme_constant_override("separation", 14)
	rew_scroll.add_child(reward_container)

	# ── 4. 赛季挑战列表 ──
	var chal_lbl = Label.new()
	chal_lbl.text = " 🏆 赛季任务挑战"
	chal_lbl.add_theme_font_size_override("font_size", 18)
	chal_lbl.add_theme_color_override("font_color", Color("#10b981"))
	vbox.add_child(chal_lbl)

	var chal_scroll = ScrollContainer.new()
	chal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(chal_scroll)

	challenge_container = VBoxContainer.new()
	challenge_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_container.add_theme_constant_override("separation", 8)
	chal_scroll.add_child(challenge_container)

	_refresh_all()

func _refresh_all():
	# 刷新经验与等级
	level_lbl.text = "LV.%d" % SeasonManager.season_level
	if SeasonManager.season_level >= SeasonManager.MAX_SEASON_LEVEL:
		exp_bar.value = 100
		exp_lbl.text = " Max Level "
	else:
		exp_bar.value = float(SeasonManager.season_exp) / float(SeasonManager.EXP_PER_LEVEL) * 100
		exp_lbl.text = " %d / %d EXP " % [SeasonManager.season_exp, SeasonManager.EXP_PER_LEVEL]

	# 刷新奖励滑轨
	_build_rewards_track()

	# 刷新挑战列表
	_build_challenges_list()

# ── 绘制等级奖励轨道 ──
func _build_rewards_track():
	for c in reward_container.get_children(): c.queue_free()

	for lvl in range(1, SeasonManager.MAX_SEASON_LEVEL + 1):
		var rew = SeasonManager.REWARDS_DB[lvl]
		var claimed = lvl in SeasonManager.claimed_rewards
		var unlocked = lvl <= SeasonManager.season_level

		var box = PanelContainer.new()
		box.custom_minimum_size = Vector2(110, 110)
		
		var bg_col: Color
		var bd_col: Color
		if claimed:
			bg_col = Color("#0f172a", 0.4)
			bd_col = Color("#334155")
		elif unlocked:
			bg_col = Color("#064e3b", 0.6)
			bd_col = Color("#10b981")
		else:
			bg_col = Color("#1e293b", 0.3)
			bd_col = Color("#334155")
		var bs = ThemeUtils.create_style(bg_col, 8, bd_col, 1)
		box.add_theme_stylebox_override("panel", bs)

		var vb = VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 2)
		box.add_child(vb)

		var lvl_lbl = Label.new()
		lvl_lbl.text = "LV.%d" % lvl
		lvl_lbl.add_theme_font_size_override("font_size", 14)
		lvl_lbl.add_theme_color_override("font_color", Color("#fbbf24") if unlocked else Color("#64748b"))
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lvl_lbl)

		var icon_lbl = Label.new()
		icon_lbl.text = rew["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 24)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(icon_lbl)

		var name_lbl = Label.new()
		name_lbl.text = rew["name"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color("#f8fafc") if unlocked else Color("#64748b"))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(name_lbl)

		# 领取按钮
		if unlocked and not claimed:
			var btn = Button.new()
			btn.text = "领取"
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.add_theme_font_size_override("font_size", 13)
			_style_btn(btn, Color("#10b981"), Color("#059669"))
			btn.pressed.connect(func():
				if SeasonManager.claim_reward(lvl):
					_refresh_all()
			)
			vb.add_child(btn)
		elif claimed:
			var lbl = Label.new()
			lbl.text = "已领取"
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color("#64748b"))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(lbl)
		else:
			var lbl = Label.new()
			lbl.text = "未解锁"
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color("#475569"))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(lbl)

		reward_container.add_child(box)

# ── 绘制赛季任务列表 ──
func _build_challenges_list():
	for c in challenge_container.get_children(): c.queue_free()

	for c_id in SeasonManager.CHALLENGES_DB.keys():
		var c = SeasonManager.CHALLENGES_DB[c_id]
		var cur = SeasonManager.challenge_progress.get(c_id, 0)
		var completed = c_id in SeasonManager.completed_challenges

		var row = PanelContainer.new()
		var bg_c = Color("#1e293b", 0.4) if not completed else Color("#064e3b", 0.2)
		var bd_c = Color("#475569") if not completed else Color("#059669", 0.5)
		var rs = ThemeUtils.create_style(bg_c, 10, bd_c, 1, -1, 14, 14, 8, 8)
		row.add_theme_stylebox_override("panel", rs)

		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)

		var status_lbl = Label.new()
		status_lbl.text = "✅" if completed else "⏳"
		status_lbl.add_theme_font_size_override("font_size", 20)
		status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(status_lbl)

		var text_vb = VBoxContainer.new()
		text_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_vb.add_theme_constant_override("separation", 2)
		hb.add_child(text_vb)

		var desc_lbl = Label.new()
		desc_lbl.text = c["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", Color("#f8fafc") if not completed else Color("#a7f3d0"))
		text_vb.add_child(desc_lbl)

		var progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(0, 14)
		progress_bar.value = float(cur) / float(c["target"]) * 100
		text_vb.add_child(progress_bar)

		var progress_lbl = Label.new()
		progress_lbl.text = "%d / %d" % [cur, c["target"]]
		progress_lbl.add_theme_font_size_override("font_size", 14)
		progress_lbl.add_theme_color_override("font_color", Color("#10b981") if completed else Color("#94a3b8"))
		progress_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(progress_lbl)

		# 难度徽章 + EXP 奖励
		var reward_vb = VBoxContainer.new()
		reward_vb.add_theme_constant_override("separation", 2)
		reward_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_child(reward_vb)

		var diff = c.get("difficulty", "easy")
		var diff_info = {
			"easy":   {"label": "普通", "color": Color("#4ade80")},
			"hard":   {"label": "进阶", "color": Color("#fb923c")},
			"legend": {"label": "传说", "color": Color("#fbbf24")}
		}.get(diff, {"label": "普通", "color": Color("#4ade80")})
		var diff_lbl = Label.new()
		diff_lbl.text = "[%s]" % diff_info["label"]
		diff_lbl.add_theme_font_size_override("font_size", 12)
		diff_lbl.add_theme_color_override("font_color", diff_info["color"])
		diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_vb.add_child(diff_lbl)

		var exp_reward_lbl = Label.new()
		exp_reward_lbl.text = "+%d EXP" % c["exp_reward"]
		exp_reward_lbl.add_theme_font_size_override("font_size", 15)
		exp_reward_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
		exp_reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_vb.add_child(exp_reward_lbl)

		challenge_container.add_child(row)


# ── 按钮样式工具 ──
func _style_btn(btn: Button, col: Color, hover: Color):
	var s = ThemeUtils.create_style(col, 6, Color.TRANSPARENT, 0, -1, 8, 8, 4, 4)
	btn.add_theme_stylebox_override("normal", s)
	var h = ThemeUtils.create_style(hover, 6, Color.TRANSPARENT, 0, -1, 8, 8, 4, 4)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
