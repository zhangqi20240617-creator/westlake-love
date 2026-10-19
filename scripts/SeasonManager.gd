extends Node
# SeasonManager.gd — 青春赛季系统（S1 赛季：烟雨江南）

signal season_exp_gained(amount: int)
signal season_level_up(new_level: int)
signal challenge_updated(challenge_id: String, cur_progress: int)
signal challenge_completed(challenge_id: String)
signal reward_claimed(level: int)

# ── 赛季基础信息 ──────────────────────────────────────────────
const SEASON_ID = "S1"
const SEASON_NAME = "烟雨江南"
const SEASON_THEME = "三月烟雨下西湖，与佳人烹茶煮鱼，踏遍青石板路。"
const MAX_SEASON_LEVEL = 10
const EXP_PER_LEVEL = 100

# ── 赛季挑战库（含三档难度：easy/hard/legend）──────────────────────
const CHALLENGES_DB = {
	# ── 简单（easy）EXP 30 ──────────────────────────────────────
	"visit_locations_5": {
		"desc": "探索 5 个不同的地点",
		"type": "visit_locations",
		"target": 5,
		"exp_reward": 30,
		"difficulty": "easy",
		"claimed": false
	},
	"study_count_10": {
		"desc": "累计进行 10 次自主复习或听课",
		"type": "action_study",
		"target": 10,
		"exp_reward": 30,
		"difficulty": "easy",
		"claimed": false
	},
	"accept_invite_3": {
		"desc": "接受并赴约角色主动邀请 3 次",
		"type": "accept_invite",
		"target": 3,
		"exp_reward": 30,
		"difficulty": "easy",
		"claimed": false
	},
	# ── 进阶（hard）EXP 60 ──────────────────────────────────────
	"any_char_favor_60": {
		"desc": "与任意角色好感度达到 60 点",
		"type": "any_favor",
		"target": 60,
		"exp_reward": 60,
		"difficulty": "hard",
		"claimed": false
	},
	"cook_carp_3": {
		"desc": "烹饪「西湖醋溜鱼」达到 3 次",
		"type": "cook_west_lake_fish",
		"target": 3,
		"exp_reward": 60,
		"difficulty": "hard",
		"claimed": false
	},
	"collect_longjing_5": {
		"desc": "累计收集 5 份西湖龙井茶",
		"type": "collect_longjing_tea",
		"target": 5,
		"exp_reward": 60,
		"difficulty": "hard",
		"claimed": false
	},
	# ── 传说（legend）EXP 120 ────────────────────────────────────
	"achieve_intellect_80": {
		"desc": "智力属性达到 80 点",
		"type": "stat_intellect",
		"target": 80,
		"exp_reward": 120,
		"difficulty": "legend",
		"claimed": false
	},
	"any_char_favor_85": {
		"desc": "【传说】与任意角色好感达到 85 点（解锁深度剧情）",
		"type": "any_favor",
		"target": 85,
		"exp_reward": 120,
		"difficulty": "legend",
		"claimed": false
	},
}


# ── 赛季等级奖励 ──────────────────────────────────────────────
const REWARDS_DB = {
	1:  {"type": "money",    "amount": 50,  "name": "新手零花钱", "icon": "💰"},
	2:  {"type": "specialty","amount": 2,   "name": "西湖鲜草鱼", "icon": "🐟", "item_id": "west_lake_carp"},
	3:  {"type": "title",    "amount": 1,   "name": "西湖游客",   "icon": "🏅"},
	4:  {"type": "money",    "amount": 100, "name": "中考备考金", "icon": "💰"},
	5:  {"type": "specialty","amount": 2,   "name": "明前龙井茶", "icon": "🍵", "item_id": "longjing_tea"},
	6:  {"type": "title",    "amount": 1,   "name": "清河坊熟客", "icon": "🏅"},
	7:  {"type": "money",    "amount": 150, "name": "富足青春金", "icon": "💰"},
	8:  {"type": "specialty","amount": 1,   "name": "陈年老龙井", "icon": "🫖", "item_id": "longjing_old"},
	9:  {"type": "title",    "amount": 1,   "name": "烟雨客",     "icon": "👑"},
	10: {"type": "cosmetic", "amount": 1,   "name": "西湖雨景气泡", "icon": "🎨", "flag": "unlocked_rainy_chat_bubble"}
}

# ── 运行时状态（需要存档） ─────────────────────────────────────────
var season_exp: int = 0
var season_level: int = 1
var challenge_progress: Dictionary = {}  # challenge_id -> current_progress
var completed_challenges: Array = []     # 已完成的 challenge_id 列表
var claimed_rewards: Array = []          # 已领取的等级列表 (如 [1, 2])
var visited_locations_list: Array = []   # 已探索地点列表，防止重复计入探索挑战

# ── 初始化 ──────────────────────────────────────────────────────
func _ready():
	# 初始化挑战进度
	for c_id in CHALLENGES_DB.keys():
		if not challenge_progress.has(c_id):
			challenge_progress[c_id] = 0

# ── 记录地点访问并加进度 ──
func record_location_visit(loc_id: String):
	if not loc_id in visited_locations_list:
		visited_locations_list.append(loc_id)
		add_progress("visit_locations", 1)

# ── 累加挑战进度 ─────────────────────────────────────────────────
func add_progress(type: String, amount: int = 1):
	for c_id in CHALLENGES_DB.keys():
		if c_id in completed_challenges: continue
		var c = CHALLENGES_DB[c_id]
		if c["type"] == type:
			var prev = challenge_progress.get(c_id, 0)
			var new_p = min(prev + amount, c["target"])
			challenge_progress[c_id] = new_p
			challenge_updated.emit(c_id, new_p)

			if new_p >= c["target"]:
				completed_challenges.append(c_id)
				gain_exp(c["exp_reward"])
				challenge_completed.emit(c_id)
				GameManager.show_toast.emit("🏆 赛季挑战完成：%s！(+%d 经验)" % [c["desc"], c["exp_reward"]])
	
	# 特殊全局监测 (如智力、好感等直接数值)
	_run_conditional_checks()

func _run_conditional_checks():
	# 监测智力
	if not "achieve_intellect_80" in completed_challenges:
		var intellect = GameManager.stats.get("intellect", 0)
		challenge_progress["achieve_intellect_80"] = min(intellect, 80)
		if intellect >= 80:
			completed_challenges.append("achieve_intellect_80")
			gain_exp(CHALLENGES_DB["achieve_intellect_80"]["exp_reward"])
			challenge_completed.emit("achieve_intellect_80")
			GameManager.show_toast.emit("🏆 赛季挑战完成：智力属性达80！")

	# 监测好感度
	if not "any_char_favor_60" in completed_challenges:
		var max_favor = 0
		for ch in GameManager.favorability.keys():
			max_favor = max(max_favor, GameManager.favorability[ch])
		challenge_progress["any_char_favor_60"] = min(max_favor, 60)
		if max_favor >= 60:
			completed_challenges.append("any_char_favor_60")
			gain_exp(CHALLENGES_DB["any_char_favor_60"]["exp_reward"])
			challenge_completed.emit("any_char_favor_60")
			GameManager.show_toast.emit("🏆 赛季挑战完成：与任意角色好感达60！")

# ── 获得赛季经验 ─────────────────────────────────────────────────
func gain_exp(amount: int):
	if season_level >= MAX_SEASON_LEVEL: return
	season_exp += amount
	season_exp_gained.emit(amount)
	
	while season_exp >= EXP_PER_LEVEL and season_level < MAX_SEASON_LEVEL:
		season_exp -= EXP_PER_LEVEL
		season_level += 1
		season_level_up.emit(season_level)
		GameManager.show_toast.emit("✨ 赛季等级提升！当前等级：LV.%d" % season_level)
	
	GameManager.state_updated.emit()

# ── 领取等级奖励 ─────────────────────────────────────────────────
func claim_reward(level: int) -> bool:
	if level > season_level:
		GameManager.show_toast.emit("❌ 尚未达到该赛季等级！")
		return false
	if level in claimed_rewards:
		GameManager.show_toast.emit("❌ 奖励已领取！")
		return false
	
	var rew = REWARDS_DB.get(level)
	if not rew: return false

	# 发放奖励
	match rew["type"]:
		"money":
			GameManager.money += rew["amount"]
			GameManager.show_toast.emit("🎁 获得零花钱：💰 %d！" % rew["amount"])
		"specialty":
			var item_id = rew["item_id"]
			CookingManager.add_specialty(item_id, rew["amount"])
			var item_info = CookingManager.SPECIALTY_DB.get(item_id, {})
			GameManager.show_toast.emit("🎁 获得特产：%s %s × %d！" % [item_info.get("icon", ""), item_info.get("name", ""), rew["amount"]])
		"title":
			# 将称号写入 flags
			var title_str = rew["name"]
			GameManager.set_flag("title_" + title_str, true)
			# 并将当前佩戴称号写入 flags
			GameManager.set_flag("active_title", title_str)
			GameManager.show_toast.emit("🏅 获得赛季专属称号：%s！" % title_str)
		"cosmetic":
			GameManager.set_flag(rew["flag"], true)
			GameManager.show_toast.emit("🎨 获得聊天界面气泡皮肤！")
	
	claimed_rewards.append(level)
	reward_claimed.emit(level)
	GameManager.state_updated.emit()
	return true

# ── 存档恢复 ────────────────────────────────────────────────────
func get_save_data() -> Dictionary:
	return {
		"season_exp":             season_exp,
		"season_level":           season_level,
		"challenge_progress":     challenge_progress.duplicate(),
		"completed_challenges":   completed_challenges.duplicate(),
		"claimed_rewards":        claimed_rewards.duplicate(),
		"visited_locations_list": visited_locations_list.duplicate(),
	}

func load_save_data(data: Dictionary):
	season_exp             = data.get("season_exp", 0)
	season_level           = data.get("season_level", 1)
	challenge_progress     = data.get("challenge_progress", {})
	completed_challenges   = data.get("completed_challenges", [])
	claimed_rewards        = data.get("claimed_rewards", [])
	visited_locations_list = data.get("visited_locations_list", [])
	
	# 确保新字段有保底值
	for c_id in CHALLENGES_DB.keys():
		if not challenge_progress.has(c_id):
			challenge_progress[c_id] = 0
