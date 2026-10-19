extends Node
# CookingManager.gd — 杭州美食烹饪与本地特产收集系统

signal recipe_unlocked(recipe_id: String)
signal specialty_collected(item_id: String)
signal dish_cooked(dish_id: String, quality: int)

# ── 杭州本地特产数据库 ─────────────────────────────────────────
# 分类：湖鲜、茶叶、糕点、调料、时令食材
const SPECIALTY_DB = {
	# 湖鲜类
	"west_lake_carp":    {"name": "西湖草鱼",   "icon": "🐟", "category": "湖鲜", "price": 18,  "desc": "西湖特产，肉质鲜嫩，是醋溜鱼的必备食材。",       "buy_loc": "market",    "season": "all"},
	"shrimp":            {"name": "河虾",        "icon": "🦐", "category": "湖鲜", "price": 22,  "desc": "钱塘江河虾，新鲜弹嫩，龙井虾仁的主角。",         "buy_loc": "market",    "season": "all"},
	"lotus_root":        {"name": "西湖莲藕",    "icon": "🪷", "category": "蔬菜", "price": 8,   "desc": "西湖出产的白莲藕，清甜脆嫩，秋冬最佳。",         "buy_loc": "market",    "season": "autumn"},
	"water_chestnut":    {"name": "荸荠",        "icon": "🫚", "category": "蔬菜", "price": 6,   "desc": "钱塘特产荸荠，爽脆清甜，可生吃可炒菜。",         "buy_loc": "market",    "season": "winter"},
	# 茶叶类
	"longjing_tea":      {"name": "龙井茶",      "icon": "🍵", "category": "茶叶", "price": 35,  "desc": "西湖龙井，清明前采摘最佳，龙井虾仁的灵魂。",     "buy_loc": "tea_shop",  "season": "spring"},
	"longjing_old":      {"name": "陈年龙井",    "icon": "🫖", "category": "茶叶", "price": 60,  "desc": "陈放三年的老龙井，香气更醇厚，适合制作茶香点心。", "buy_loc": "tea_shop",  "season": "all"},
	# 糕点类
	"osmanthus_cake":    {"name": "桂花糕原料",  "icon": "🌼", "category": "糕点", "price": 12,  "desc": "晒干的西湖桂花，秋季专属，制作桂花糕的核心。",   "buy_loc": "market",    "season": "autumn"},
	"glutinous_rice":    {"name": "糯米粉",      "icon": "🍚", "category": "糕点", "price": 5,   "desc": "上好的糯米粉，制作各类杭州糕点的基础原料。",     "buy_loc": "market",    "season": "all"},
	"red_bean":          {"name": "红豆沙",      "icon": "🫘", "category": "糕点", "price": 8,   "desc": "细腻香甜的红豆沙，猫耳朵等糕点的馅料。",         "buy_loc": "market",    "season": "all"},
	# 调料类
	"zhejiang_vinegar":  {"name": "浙醋",        "icon": "🍶", "category": "调料", "price": 10,  "desc": "浙江米醋，酸香回甘，醋溜鱼的灵魂调料。",         "buy_loc": "market",    "season": "all"},
	"shaoxing_wine":     {"name": "绍兴黄酒",    "icon": "🏺", "category": "调料", "price": 15,  "desc": "绍兴特产黄酒，给菜肴增添独特的江南风味。",       "buy_loc": "market",    "season": "all"},
	"rock_sugar":        {"name": "冰糖",        "icon": "🍬", "category": "调料", "price": 6,   "desc": "上等冰糖，给东坡肉增添晶莹的红亮色泽。",         "buy_loc": "market",    "season": "all"},
	# 肉类
	"pork_belly":        {"name": "五花肉",      "icon": "🥩", "category": "肉类", "price": 20,  "desc": "精选三层五花肉，制作东坡肉的主材料。",           "buy_loc": "market",    "season": "all"},
	"chicken":           {"name": "嫩鸡",        "icon": "🍗", "category": "肉类", "price": 16,  "desc": "散养土鸡，制作叫化鸡时包裹荷叶焖烤，香而不腻。", "buy_loc": "market",    "season": "all"},
	"lotus_leaf":        {"name": "新鲜荷叶",    "icon": "🍃", "category": "蔬菜", "price": 4,   "desc": "西湖荷叶，叫化鸡的天然包装，赋予独特清香。",     "buy_loc": "market",    "season": "summer"},
}

# ── 杭州经典菜谱数据库 ──────────────────────────────────────────
const RECIPE_DB = {
	"west_lake_fish": {
		"name":        "西湖醋溜鱼",
		"icon":        "🐟",
		"desc":        "将草鱼在醋、糖、酱油调制的芡汁中翻炒，酸甜鲜美，是西湖边最著名的本帮菜。",
		"ingredients": {"west_lake_carp": 1, "zhejiang_vinegar": 1, "shaoxing_wine": 1},
		"unlock_day":  1,
		"unlock_flag": "",
		"difficulty":  1,
		"cook_time":   "noon",
		"stat_rewards":{"social": 2, "charm": 1},
		"aff_bonus":   {"char": "", "amount": 0},
		"quality_desc":["差强人意……醋放多了有点酸", "还不错，酸甜比例刚好", "完美！师傅级水准，醋香四溢！"],
		"lore":         "北宋苏东坡在杭州任职时最爱此菜，与友人把酒临风，谈笑风生。"
	},
	"longjing_shrimp": {
		"name":        "龙井虾仁",
		"icon":        "🦐",
		"desc":        "以新鲜河虾配西湖龙井茶叶同炒，虾仁洁白嫩滑，茶香清雅，是杭帮菜的顶级名片。",
		"ingredients": {"shrimp": 1, "longjing_tea": 1},
		"unlock_day":  5,
		"unlock_flag": "seen_longjing_event",
		"difficulty":  2,
		"cook_time":   "noon",
		"stat_rewards":{"intellect": 1, "art": 2, "charm": 2},
		"aff_bonus":   {"char": "wanqing", "amount": 5},
		"quality_desc":["火候不够，虾仁有点老", "茶香与虾鲜完美融合，清雅动人", "极品！连龙井山上的茶农都要竖拇指！"],
		"lore":         "相传乾隆皇帝微服游西湖，在茶馆中偶然尝到此菜，拍案叫绝，御赐名菜。"
	},
	"dongpo_pork": {
		"name":        "东坡肉",
		"icon":        "🥩",
		"desc":        "五花肉以黄酒、冰糖慢炖数小时，色泽红亮，入口即化，是苏东坡流传千年的杭州名菜。",
		"ingredients": {"pork_belly": 1, "shaoxing_wine": 1, "rock_sugar": 1},
		"unlock_day":  10,
		"unlock_flag": "",
		"difficulty":  3,
		"cook_time":   "evening",
		"stat_rewards":{"strength": 2, "stress": -10},
		"aff_bonus":   {"char": "jingjing", "amount": 4},
		"quality_desc":["肉还有点硬，需要再炖两小时", "软糯香甜，筷子一夹就入味", "登峰造极！苏学士在天之灵都要点赞！"],
		"lore":         "苏东坡被贬黄州时，以黄酒炖猪肉自娱，后将此法带入杭州，成为千古名菜。"
	},
	"beggar_chicken": {
		"name":        "叫化鸡",
		"icon":        "🍗",
		"desc":        "整鸡包裹香料，再以新鲜荷叶捆扎后烤制，荷叶清香渗入鸡肉，香气扑鼻。",
		"ingredients": {"chicken": 1, "lotus_leaf": 1, "shaoxing_wine": 1},
		"unlock_day":  20,
		"unlock_flag": "",
		"difficulty":  3,
		"cook_time":   "evening",
		"stat_rewards":{"strength": 3, "stress": -8},
		"aff_bonus":   {"char": "xiaoxia", "amount": 5},
		"quality_desc":["荷叶没包好，香气散了一半", "荷叶清香与鸡肉完美融合，令人食指大动", "神级！连叫化子都感动落泪的绝世叫化鸡！"],
		"lore":         "相传一个乞丐将整鸡包以荷叶，用泥巴糊住放入火堆，误打误撞创出此菜。"
	},
	"osmanthus_cake": {
		"name":        "桂花糕",
		"icon":        "🍡",
		"desc":        "西湖桂花与糯米粉、红豆沙制成的传统糕点，金黄色泽，桂香馥郁，是杭州秋日的专属甜蜜。",
		"ingredients": {"osmanthus_cake": 1, "glutinous_rice": 1, "red_bean": 1},
		"unlock_day":  15,
		"unlock_flag": "",
		"difficulty":  2,
		"cook_time":   "noon",
		"stat_rewards":{"art": 3, "charm": 2, "stress": -5},
		"aff_bonus":   {"char": "yutong", "amount": 4},
		"quality_desc":["糯米没蒸透，有点黏牙", "桂花香气温柔，甜而不腻，恰到好处", "完美！金黄如月，桂香满室，中秋佳品！"],
		"lore":         "西湖边的桂花树秋日盛开，满城飘香，杭州人自古将桂花入馔，寓意富贵吉祥。"
	},
	# ── 节日限定食谱（需对应节日 flag 解锁）─────────────────────────
	"tangyuan": {
		"name":        "汤圆",
		"icon":        "🟤",
		"desc":        "糯米粉包裹红豆沙，在沸水中翻滚，圆润可爱，是元旦应节甜品。",
		"ingredients": {"glutinous_rice": 1, "red_bean": 1},
		"unlock_day":  1,
		"unlock_flag": "new_year_cooking",
		"difficulty":  1,
		"cook_time":   "evening",
		"stat_rewards": {"stress": -10, "charm": 1},
		"aff_bonus":   {"char": "", "amount": 0},
		"quality_desc": ["皮太薄破了几个……但馅是好的", "圆润饱满，皮薄馅多，团圆之味", "完美！颗颗圆满，如月似珠，元宵诗意！"],
		"lore":         "元旦前后家家户户搓汤圆，象征团圆美满。",
		"is_festival":  true
	},
	"zongzi": {
		"name":        "粽子",
		"icon":        "🎋",
		"desc":        "糯米包裹红豆沙，以荷叶捆扎蒸制，端午节的杭州味道。",
		"ingredients": {"glutinous_rice": 2, "red_bean": 1, "lotus_leaf": 1},
		"unlock_day":  1,
		"unlock_flag": "dragon_boat_cooking",
		"difficulty":  2,
		"cook_time":   "noon",
		"stat_rewards": {"strength": 2, "social": 1, "stress": -5},
		"aff_bonus":   {"char": "xiaoxia", "amount": 6},
		"quality_desc": ["荷叶没包实，煮开了……", "糯米软糯清甜，满室荷叶清香", "完美！端午正宗！连屈原都会点头的粽子！"],
		"lore":         "端午节前后，西湖边荷叶飘香，杭州人包粽子纪念屈原。",
		"is_festival":  true
	},
	"mooncake": {
		"name":        "桂花月饼",
		"icon":        "🥮",
		"desc":        "以桂花与莲蓉入馅，外皮酥脆金黄，西湖中秋赏月的最佳点心。",
		"ingredients": {"osmanthus_cake": 2, "glutinous_rice": 1, "rock_sugar": 1},
		"unlock_day":  1,
		"unlock_flag": "mid_autumn_cooking",
		"difficulty":  3,
		"cook_time":   "evening",
		"stat_rewards": {"art": 4, "charm": 3, "stress": -8},
		"aff_bonus":   {"char": "wanqing", "amount": 8},
		"quality_desc": ["面皮没醒好，纹路裂了……", "桂花馥郁，入口即化，月圆人圆", "极品！月圆之夜，此月饼可抵万千词句！"],
		"lore":         "西湖月色是杭州人的心头好，桂花月饼配玉露茶是秋夜最美的相遇。",
		"is_festival":  true
	},
}

# ── 运行时状态 ──────────────────────────────────────────────────
var collected_specialties: Dictionary = {}  # item_id -> count
var unlocked_recipes: Array = []            # 已解锁的菜谱 ID 列表
var cooked_dishes: Dictionary = {}          # dish_id -> {count, best_quality}
var cooking_exp: int = 0                    # 烹饪经验值

# ── 初始化 ──────────────────────────────────────────────────────
func _ready():
	# 根据当前日期自动解锁基础菜谱
	_check_recipe_unlocks()

func _check_recipe_unlocks():
	for recipe_id in RECIPE_DB.keys():
		var recipe = RECIPE_DB[recipe_id]
		var already = recipe_id in unlocked_recipes
		if already: continue
		var day_ok  = GameManager.day >= recipe.get("unlock_day", 1)
		var flag    = recipe.get("unlock_flag", "")
		var flag_ok = flag == "" or GameManager.has_flag(flag)
		if day_ok and flag_ok:
			unlocked_recipes.append(recipe_id)
			if GameManager.day > 1:  # 非首次，才发通知
				recipe_unlocked.emit(recipe_id)
				GameManager.show_toast.emit("🍳 新菜谱解锁：%s！" % recipe["name"])

# ── 食材获取（市场购买） ────────────────────────────────────────
func buy_ingredient(item_id: String) -> bool:
	if not SPECIALTY_DB.has(item_id): return false
	var item = SPECIALTY_DB[item_id]
	var price = item.get("price", 0)

	# 季节检查
	var season = item.get("season", "all")
	if season != "all" and season != GameManager.get_season():
		GameManager.show_toast.emit("❌ 此食材只在%s才有！" % _season_label(season))
		return false

	if GameManager.money < price:
		GameManager.show_toast.emit("❌ 零花钱不足！需要 💰%d" % price)
		return false

	GameManager.money -= price
	collected_specialties[item_id] = collected_specialties.get(item_id, 0) + 1
	specialty_collected.emit(item_id)
	
	# ── 赛季系统挑战挂钩 ──
	if item_id == "longjing_tea":
		SeasonManager.add_progress("collect_longjing_tea", 1)
	
	GameManager.show_toast.emit("🛒 购入 %s %s × 1" % [item["icon"], item["name"]])
	GameManager.state_updated.emit()
	return true

func _season_label(s: String) -> String:
	return {"spring": "春季", "summer": "夏季", "autumn": "秋季", "winter": "冬季"}.get(s, s)

func add_specialty(item_id: String, amount: int = 1) -> void:
	if amount <= 0: return
	if not SPECIALTY_DB.has(item_id): return
	collected_specialties[item_id] = collected_specialties.get(item_id, 0) + amount
	specialty_collected.emit(item_id)
	GameManager.state_updated.emit()

# ── 检查是否有足够食材 ────────────────────────────────────────
func can_cook(recipe_id: String) -> bool:
	if not RECIPE_DB.has(recipe_id): return false
	if not recipe_id in unlocked_recipes: return false
	var recipe = RECIPE_DB[recipe_id]
	for ing_id in recipe["ingredients"].keys():
		var needed = recipe["ingredients"][ing_id]
		if collected_specialties.get(ing_id, 0) < needed:
			return false
	return true

func get_missing_ingredients(recipe_id: String) -> Array:
	if not RECIPE_DB.has(recipe_id): return []
	var recipe = RECIPE_DB[recipe_id]
	var missing = []
	for ing_id in recipe["ingredients"].keys():
		var needed = recipe["ingredients"][ing_id]
		var have   = collected_specialties.get(ing_id, 0)
		if have < needed:
			var ing_data = SPECIALTY_DB.get(ing_id, {})
			missing.append({
				"id": ing_id, "name": ing_data.get("name", ing_id),
				"icon": ing_data.get("icon", "📦"),
				"have": have, "need": needed
			})
	return missing

# ── 烹饪 ────────────────────────────────────────────────────────
# 返回 { success, quality(0-2), quality_text, rewards }
func cook_dish(recipe_id: String) -> Dictionary:
	if not can_cook(recipe_id):
		return {"success": false, "reason": "食材不足或菜谱未解锁"}

	var recipe = RECIPE_DB[recipe_id]

	# 消耗食材
	for ing_id in recipe["ingredients"].keys():
		collected_specialties[ing_id] -= recipe["ingredients"][ing_id]
		if collected_specialties[ing_id] <= 0:
			collected_specialties.erase(ing_id)

	# 品质计算：基于烹饪经验 + 随机
	var base_chance = clampf(float(cooking_exp) / 200.0, 0.0, 0.8)
	var roll = randf()
	var quality: int
	if roll < 0.2 + base_chance * 0.1:
		quality = 2   # 完美
	elif roll < 0.6 + base_chance * 0.3:
		quality = 1   # 普通
	else:
		quality = 0   # 失败

	# 经验增长
	var diff = recipe.get("difficulty", 1)
	cooking_exp += diff * (quality + 1) * 5

	# 记录烹饪历史
	if not cooked_dishes.has(recipe_id):
		cooked_dishes[recipe_id] = {"count": 0, "best_quality": 0}
	cooked_dishes[recipe_id]["count"] += 1
	cooked_dishes[recipe_id]["best_quality"] = max(cooked_dishes[recipe_id]["best_quality"], quality)

	# 应用属性奖励（品质越高奖励越多）
	var rewards = []
	var multiplier = [0.5, 1.0, 1.5][quality]
	for stat in recipe["stat_rewards"].keys():
		var amount = recipe["stat_rewards"][stat]
		var final_amount = int(amount * multiplier)
		if final_amount != 0:
			GameManager.add_stat(stat, final_amount)
			rewards.append({"stat": stat, "amount": final_amount})

	# 好感度奖励（只有普通及以上品质才触发）
	var aff_bonus = recipe.get("aff_bonus", {})
	if quality >= 1 and aff_bonus.get("char", "") != "":
		var aff_amount = int(aff_bonus["amount"] * multiplier)
		GameManager.add_favor(aff_bonus["char"], aff_amount)

	# 日志
	var quality_text = recipe["quality_desc"][quality]
	GameManager.add_log("🍳 烹饪了 %s —— %s" % [recipe["name"], quality_text])
	GameManager.add_diary_entry("今天做了%s，%s" % [recipe["name"], quality_text])
	dish_cooked.emit(recipe_id, quality)
	
	# ── 赛季系统挑战挂钩 ──
	if recipe_id == "west_lake_fish":
		SeasonManager.add_progress("cook_west_lake_fish", 1)
	
	GameManager.state_updated.emit()

	# 解锁新菜谱
	_check_recipe_unlocks()

	return {
		"success": true,
		"quality": quality,
		"quality_text": quality_text,
		"dish_name": recipe["name"],
		"dish_icon": recipe["icon"],
		"lore": recipe.get("lore", ""),
		"rewards": rewards
	}

# ── 收集进度统计 ─────────────────────────────────────────────────
# ── 带饭送礼系统 ──────────────────────────────────────────────────
## 菜肴 × 角色 → 专属台词与好感加成；未配置角色使用默认值
const FOOD_GIFT_TABLE: Dictionary = {
	"longjing_shrimp": {
		"wanqing": {"bonus": 8,  "line": "「龙井虾仁」！你怎么知道我就喜欢这道菜。茶香清雅，谢谢你的注意。"},
		"yutong":  {"bonus": 5,  "line": "辛苦学习之余，能吃到这么细心的美食真不易。我会加倍拼劲回报你的。"},
	},
	"dongpo_pork": {
		"jingjing": {"bonus": 7, "line": "小天才！！东坡肉！我最爱这个了。下次冰淇淋考试必须帮你抢到第一名！"},
		"yutong":   {"bonus": 4, "line": "谢谢，我会记得犒劳顿饭后多帮一个小时习题。我也敌不住这个气味。"},
	},
	"beggar_chicken": {
		"xiaoxia": {"bonus": 8, "line": "哇塞！叫化鸡诶！下次训练请带我一块，不见不散！"},
		"jingjing":{"bonus": 5, "line": "这鸡肉居然不腥！补充一下运动量，让败者乖乖的，就谢谢你就行。"},
	},
	"osmanthus_cake": {
		"yutong": {"bonus": 6, "line": "桂花糕，秋天的味道。谢谢你记得这是我的最爱。以后有机会再一起看赏桂花展吧。"},
	},
	"mooncake": {
		"wanqing": {"bonus": 10, "line": "桂花月饼，月圆人圆。谢谢，这是我收过最美的中秋礼物。"},
		"yutong":  {"bonus": 7,  "line": "月饼软滑香甜，好战！下次一起去西湖赏月吧。"},
	},
	"tangyuan": {
		"jingjing": {"bonus": 6, "line": "汤圆！圆圆满满，就像本天才一样满分不缺。下回再做记得多包几个！"},
	},
	"zongzi": {
		"xiaoxia": {"bonus": 8, "line": "哇！粽子！端午节快乐！下次一起去西湖边划龙舟吗？"},
	},
}

## 将已烹饪的菜肴赠送给角色（消耗一份烹饪记录）
var gifted_dishes: Dictionary = {}  # recipe_id -> {char_id -> count}

func can_gift_dish(recipe_id: String) -> bool:
	return cooked_dishes.get(recipe_id, {}).get("count", 0) > 0

func gift_dish(recipe_id: String, char_id: String, quality: int = 1) -> Dictionary:
	if not RECIPE_DB.has(recipe_id):
		return {"success": false, "reason": "菜谱不存在"}
	if not can_gift_dish(recipe_id):
		return {"success": false, "reason": "还没烹饪过这道菜，快去厨房做一份吧"}

	# 消耗一次烹饪记录（count-1，最低归零）
	cooked_dishes[recipe_id]["count"] = max(0, cooked_dishes[recipe_id]["count"] - 1)

	# 查找专属反应台词与加成
	var gift_entry = FOOD_GIFT_TABLE.get(recipe_id, {}).get(char_id, {})
	var recipe = RECIPE_DB[recipe_id]
	var base_bonus = gift_entry.get("bonus", recipe.get("aff_bonus", {}).get("amount", 2))
	var line = gift_entry.get("line", "谢谢你的%s，真的很好吃！" % recipe["name"])

	# 品质系数：普通×1.0，完美×1.4，失败×0.6
	var mult = [0.6, 1.0, 1.4][clampi(quality, 0, 2)]
	var final_bonus = max(1, int(base_bonus * mult))
	GameManager.add_favor(char_id, final_bonus)

	# 日记记录
	var char_name = GameManager.char_meta.get(char_id, {}).get("name", char_id)
	GameManager.add_diary_entry("今天把做好的%s送给了%s。%s" % [recipe["name"], char_name, line])

	# 统计赠送记录
	if not gifted_dishes.has(recipe_id): gifted_dishes[recipe_id] = {}
	gifted_dishes[recipe_id][char_id] = gifted_dishes[recipe_id].get(char_id, 0) + 1

	GameManager.state_updated.emit()
	return {"success": true, "line": line, "bonus": final_bonus, "char_name": char_name,
			"dish_name": recipe["name"], "dish_icon": recipe["icon"]}

# ── 收藏进度统计 ─────────────────────────────────────────────────
func get_collection_stats() -> Dictionary:

	var total_spec = SPECIALTY_DB.size()
	var collected  = collected_specialties.keys().size()
	var total_rec  = RECIPE_DB.size()
	var unlocked   = unlocked_recipes.size()
	var cooked_cnt = cooked_dishes.size()
	var level = _get_cook_level()
	return {
		"specialties_collected": collected,
		"specialties_total":     total_spec,
		"recipes_unlocked":      unlocked,
		"recipes_total":         total_rec,
		"dishes_cooked":         cooked_cnt,
		"cooking_exp":           cooking_exp,
		"cook_level":            level["name"],
		"cook_level_emoji":      level["emoji"],
		"next_level_exp":        level["next_exp"],
	}

func _get_cook_level() -> Dictionary:
	if cooking_exp >= 300: return {"name": "西湖厨神",    "emoji": "👨‍🍳", "next_exp": 999}
	if cooking_exp >= 150: return {"name": "杭帮大厨",    "emoji": "🧑‍🍳", "next_exp": 300}
	if cooking_exp >= 60:  return {"name": "江南食客",    "emoji": "🍴",  "next_exp": 150}
	if cooking_exp >= 20:  return {"name": "厨房学徒",    "emoji": "🥄",  "next_exp": 60}
	return                        {"name": "厨房小白",    "emoji": "🍳",  "next_exp": 20}

# ── 存档支持 ──────────────────────────────────────────────────
func get_save_data() -> Dictionary:
	return {
		"collected_specialties": collected_specialties.duplicate(),
		"unlocked_recipes":      unlocked_recipes.duplicate(),
		"cooked_dishes":         cooked_dishes.duplicate(true),
		"cooking_exp":           cooking_exp,
	}

func load_save_data(data: Dictionary):
	collected_specialties = data.get("collected_specialties", {})
	unlocked_recipes      = data.get("unlocked_recipes", [])
	cooked_dishes         = data.get("cooked_dishes", {})
	cooking_exp           = data.get("cooking_exp", 0)

# ── 跨周目接口：导出当前已解锁菜谱 ID 列表 ──────────────────────
func get_unlocked_recipe_ids() -> Array:
	return unlocked_recipes.duplicate()

# ── 跨周目接口：NG+ 开始时继承上周目解锁的菜谱 ─────────────────
func inherit_recipes(recipe_ids: Array):
	for rid in recipe_ids:
		if RECIPE_DB.has(rid) and not rid in unlocked_recipes:
			unlocked_recipes.append(rid)
			GameManager.show_toast.emit("🍳 继承菜谱：%s" % RECIPE_DB[rid]["name"])

