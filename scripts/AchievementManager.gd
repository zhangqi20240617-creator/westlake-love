# scripts/AchievementManager.gd
extends Node

## ═══════════════════════════════════════════════════════════════
## AchievementManager — 统一成就中心服务单例
## 职责：
##   1. 加载并管理全量成就数据库 (achievements.json)
##   2. 监听游戏状态、收集、小游戏、好感度与标志位变动
##   3. 零侵入解耦：成就持久化落账 GameManager.flags ("achv_<id>")
##   4. 提供原神风格成就达成弹窗横幅队列
##   5. 提供成就统计、分类索引与成就图鉴查询接口
## ═══════════════════════════════════════════════════════════════

signal achievement_unlocked(achv_data: Dictionary)
signal achievement_progress_updated()

const CATEGORY_META = {
	"all":         {"name": "全部成就", "icon": "🌟", "desc": "西湖初中三年的全部回忆足迹"},
	"hangzhou":    {"name": "人间西湖", "icon": "🏞️", "desc": "西湖十景、风物志、杭帮美食与水乡烟火"},
	"academics":   {"name": "学海无涯", "icon": "📘", "desc": "中考备战、刷题连击、奥数竞赛与学霸之路"},
	"social":      {"name": "青春羁绊", "icon": "🌸", "desc": "同窗好友、心动瞬间、信件羁绊与知己"},
	"minigames":   {"name": "闲暇微光", "icon": "🎮", "desc": "调饮、抓娃娃、传纸条、羽毛球与快门摄影"},
	"curiosities": {"name": "天地万象", "icon": "🎭", "desc": "校园趣事、隐藏彩蛋、意外反转与生活微光"},
	"milestones":  {"name": "光阴长卷", "icon": "🏆", "desc": "社团大成、毕业盛典、周目传承与终局荣光"}
}

var _achievements: Array = []
var _achv_map: Dictionary = {}
var _banner_queue: Array = []
var _is_banner_playing: bool = false
var _is_initialized: bool = false

func _ready() -> void:
	load_achievements_db()
	# 延迟绑定，确保 GameManager 及各系统就绪
	call_deferred("_setup_connections")

func _setup_connections() -> void:
	if is_instance_valid(GameManager):
		GameManager.state_updated.connect(func(): call_deferred("check_all"))
		# 首次扫描补偿存量状态
		check_all()

	# 监听烹饪系统
	var cook_mgr = get_node_or_null("/root/CookingManager")
	if cook_mgr:
		if cook_mgr.has_signal("dish_cooked"):
			cook_mgr.dish_cooked.connect(_on_dish_cooked)

	_is_initialized = true

# ── 加载成就数据 ──────────────────────────────────────────────
func load_achievements_db() -> void:
	_achievements.clear()
	_achv_map.clear()

	var file_path = "res://scripts/achievements.json"
	if not FileAccess.file_exists(file_path):
		push_warning("AchievementManager: 未找到成就数据文件 %s" % file_path)
		return

	var f = FileAccess.open(file_path, FileAccess.READ)
	if not f:
		push_error("AchievementManager: 无法读取 %s" % file_path)
		return

	var text = f.get_as_text()
	f.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("AchievementManager: 解析 JSON 失败: %s" % json.get_error_message())
		return

	var list = json.data
	if typeof(list) == TYPE_ARRAY:
		for item in list:
			if typeof(item) == TYPE_DICTIONARY and item.has("id"):
				_achievements.append(item)
				_achv_map[item["id"]] = item
	print("AchievementManager: 成功载入 %d 项成就！" % _achievements.size())

# ── 查询与状态接口 ───────────────────────────────────────────
func is_unlocked(id: String) -> bool:
	if not is_instance_valid(GameManager): return false
	return GameManager.flags.get("achv_" + id, false) == true

func get_unlock_day(id: String) -> int:
	if not is_instance_valid(GameManager): return -1
	return int(GameManager.flags.get("achv_day_" + id, -1))

func get_achievement(id: String) -> Dictionary:
	return _achv_map.get(id, {})

func get_all_achievements() -> Array:
	return _achievements

func get_achievements_by_category(cat: String) -> Array:
	if cat == "all" or cat == "":
		return _achievements
	var res = []
	for a in _achievements:
		if a.get("category", "") == cat:
			res.append(a)
	return res

func get_categories() -> Array:
	var list = []
	for k in ["all", "hangzhou", "academics", "social", "minigames", "curiosities", "milestones"]:
		var meta = CATEGORY_META.get(k, {})
		list.append({
			"id": k,
			"name": meta.get("name", k),
			"icon": meta.get("icon", "⭐"),
			"desc": meta.get("desc", "")
		})
	return list

# ── 计数器服务 ────────────────────────────────────────────────
func get_counter(counter_key: String) -> int:
	if not is_instance_valid(GameManager): return 0
	return int(GameManager.flags.get("achv_cnt_" + counter_key, 0))

func add_counter(counter_key: String, amount: int = 1) -> void:
	if not is_instance_valid(GameManager): return
	var cur = get_counter(counter_key) + amount
	GameManager.flags["achv_cnt_" + counter_key] = cur
	check_all()

# ── 成就授予（唯一落账入口）──────────────────────────────────
func unlock(id: String) -> bool:
	if not _achv_map.has(id): return false
	if is_unlocked(id): return false
	if not is_instance_valid(GameManager): return false

	var data = _achv_map[id]
	GameManager.flags["achv_" + id] = true
	GameManager.flags["achv_day_" + id] = GameManager.day

	# 触发信号
	achievement_unlocked.emit(data)
	achievement_progress_updated.emit()

	# 入队播放动效横幅
	_queue_banner(data)
	return true

# ── 全面状态自动扫描 ─────────────────────────────────────────
func check_all() -> void:
	if not is_instance_valid(GameManager): return
	
	# 特殊组合与衍生条件预检
	_check_derived_conditions()

	for a in _achievements:
		var aid: String = a.get("id", "")
		if is_unlocked(aid): continue

		var c_type: String = a.get("condition_type", "")
		var c_key: String = a.get("condition_key", "")
		var c_target: int = int(a.get("condition_target", 0))

		match c_type:
			"flag":
				if GameManager.flags.get(c_key, false) == true:
					unlock(aid)
			"stat":
				if int(GameManager.stats.get(c_key, 0)) >= c_target:
					unlock(aid)
			"favor":
				if int(GameManager.favorability.get(c_key, 0)) >= c_target:
					unlock(aid)
			"counter":
				if get_counter(c_key) >= c_target:
					unlock(aid)

## 检查组合衍生条件并置入过渡 flag
func _check_derived_conditions() -> void:
	# 检查单科 100 分
	if not GameManager.flags.has("achv_subject_100"):
		for subj in GameManager.subject_scores.keys():
			if int(GameManager.subject_scores[subj]) >= 100:
				GameManager.flags["achv_subject_100"] = true
				break

	# 检查单科满分系列
	if int(GameManager.subject_scores.get("math", 0)) >= 100:
		GameManager.flags["achv_math_100"] = true
	if int(GameManager.subject_scores.get("chinese", 0)) >= 100:
		GameManager.flags["achv_chinese_100"] = true
	if int(GameManager.subject_scores.get("english", 0)) >= 100:
		GameManager.flags["achv_english_100"] = true
	if int(GameManager.subject_scores.get("science", 0)) >= 100:
		GameManager.flags["achv_science_100"] = true

	# 检查文理双状元 (语数双双 >= 95)
	if int(GameManager.subject_scores.get("math", 0)) >= 95 and int(GameManager.subject_scores.get("chinese", 0)) >= 95:
		GameManager.flags["achv_double_scholar"] = true

	# 检查全科 80分以上 (六边形战士)
	if not GameManager.flags.has("achv_subjects_all_80") and not GameManager.subject_scores.is_empty():
		var all_80 = true
		for subj in ["math", "chinese", "english", "science"]:
			if int(GameManager.subject_scores.get(subj, 0)) < 80:
				all_80 = false
				break
		if all_80:
			GameManager.flags["achv_subjects_all_80"] = true

	# 检查偏科之神 (单门 >= 90，且另一门 <= 25)
	if not GameManager.flags.has("achv_extreme_skew") and not GameManager.subject_scores.is_empty():
		var has_high = false
		var has_low = false
		for val in GameManager.subject_scores.values():
			if int(val) >= 90:
				has_high = true
			if int(val) <= 25 and int(val) > 0:
				has_low = true
		if has_high and has_low:
			GameManager.flags["achv_extreme_skew"] = true

	# 检查压力临界点 (压力值 >= 98)
	if int(GameManager.stress) >= 98:
		GameManager.flags["achv_stress_99"] = true

	# 检查钱包比脸干净 (金币恰好为 0，且游戏已经开局第2天以后)
	if int(GameManager.money) == 0 and int(GameManager.current_day) >= 2:
		GameManager.flags["achv_penniless"] = true

	# 检查全科 50 分以上
	if not GameManager.flags.has("achv_subjects_all_50"):
		var all_pass = true
		for subj in GameManager.subject_scores.keys():
			if int(GameManager.subject_scores[subj]) < 50:
				all_pass = false
				break
		if all_pass and not GameManager.subject_scores.is_empty():
			GameManager.flags["achv_subjects_all_50"] = true

	# 检查最高好感突破 80 与 100
	for cid in GameManager.favorability.keys():
		var fv = int(GameManager.favorability[cid])
		if fv >= 80:
			GameManager.flags["achv_favor_80"] = true
		if fv >= 100:
			GameManager.flags["achv_favor_100"] = true

	# 检查修罗场的微风 (3个女生好感 >= 50)
	var high_favor_count = 0
	for cid in GameManager.favorability.keys():
		if int(GameManager.favorability[cid]) >= 50:
			high_favor_count += 1
	if high_favor_count >= 3:
		GameManager.flags["achv_trio_jealousy"] = true

	# 检查手作风物
	if not GameManager.flags.has("achv_fengwu_handcrafted"):
		if GameManager.flags.has("fengwu_fw_hm_tuopian") or \
		   GameManager.flags.has("fengwu_fw_hm_zhuze") or \
		   GameManager.flags.has("fengwu_fw_hm_luyin"):
			GameManager.flags["achv_fengwu_handcrafted"] = true

	# 检查多周目启动
	if not GameManager.flags.has("achv_ng_started"):
		if int(GameManager.flags.get("ng_count", 0)) >= 1:
			GameManager.flags["achv_ng_started"] = true

# ── 烹饪系统钩子 ─────────────────────────────────────────────
func _on_dish_cooked(dish_id: String, quality: int) -> void:
	add_counter("total_dishes_cooked", 1)
	
	# 记录已做过的不同菜谱
	var cooked_list = GameManager.flags.get("achv_distinct_recipes", [])
	if not (dish_id in cooked_list):
		cooked_list.append(dish_id)
		GameManager.flags["achv_distinct_recipes"] = cooked_list
		GameManager.flags["achv_cnt_distinct_recipes_cooked"] = cooked_list.size()

	match dish_id:
		"dongpo_pork":
			GameManager.flags["achv_cooked_dongpo"] = true
		"longjing_shrimp":
			GameManager.flags["achv_cooked_longjing_shrimp"] = true
		"beggar_chicken":
			GameManager.flags["achv_cooked_beggar_chicken"] = true
		"west_lake_fish":
			if quality == 0: # 醋放多了
				GameManager.flags["achv_fish_too_sour"] = true

	check_all()

# ── 统计信息接口 ─────────────────────────────────────────────
func get_stats() -> Dictionary:
	var total_count = _achievements.size()
	var unlocked_count = 0
	var total_pts = 0
	var unlocked_pts = 0

	for a in _achievements:
		var pts = int(a.get("points", 10))
		total_pts += pts
		if is_unlocked(a.get("id", "")):
			unlocked_count += 1
			unlocked_pts += pts

	var pct = 0.0
	if total_count > 0:
		pct = (float(unlocked_count) / float(total_count)) * 100.0

	return {
		"total_count": total_count,
		"unlocked_count": unlocked_count,
		"total_points": total_pts,
		"unlocked_points": unlocked_pts,
		"percent": pct
	}

func get_category_stats(cat: String) -> Dictionary:
	var list = get_achievements_by_category(cat)
	var total_count = list.size()
	var unlocked_count = 0
	var total_pts = 0
	var unlocked_pts = 0

	for a in list:
		var pts = int(a.get("points", 10))
		total_pts += pts
		if is_unlocked(a.get("id", "")):
			unlocked_count += 1
			unlocked_pts += pts

	var pct = 0.0
	if total_count > 0:
		pct = (float(unlocked_count) / float(total_count)) * 100.0

	return {
		"total_count": total_count,
		"unlocked_count": unlocked_count,
		"total_points": total_pts,
		"unlocked_points": unlocked_pts,
		"percent": pct
	}

# ── 横幅队列播放 ─────────────────────────────────────────────
func _queue_banner(data: Dictionary) -> void:
	_banner_queue.append(data)
	if not _is_banner_playing:
		_play_next_banner()

func _play_next_banner() -> void:
	if _banner_queue.is_empty():
		_is_banner_playing = false
		return

	_is_banner_playing = true
	var data = _banner_queue.pop_front()

	var banner_script = load("res://scripts/AchievementBannerUI.gd")
	if not banner_script:
		_is_banner_playing = false
		return

	var banner = banner_script.new()
	var tree = get_tree()
	if not tree or not tree.root:
		_is_banner_playing = false
		return

	tree.root.add_child(banner)
	banner.show_banner(data)
	banner.banner_finished.connect(func():
		_play_next_banner()
	)
