## WardrobeManager.gd
## 纸娃娃换装系统 — 数据管理层
## 负责：物品数据库、库存、拥有/装备状态、属性加成计算、存读档

extends Node

signal item_purchased(item_id: String)
signal item_equipped(item_id: String, slot: String)
signal item_unequipped(slot: String)

# ── 装备槽位定义 ──────────────────────────────────────────────
const SLOTS = ["top", "bottom", "outfit", "head", "accessory", "shoes"]

const SLOT_LABELS = {
	"top":       "上衣",
	"bottom":    "下装",
	"outfit":    "套装",
	"head":      "头饰",
	"accessory": "饰品",
	"shoes":     "鞋",
}

const SLOT_EMOJIS = {
	"top": "👕", "bottom": "👖", "outfit": "👗",
	"head": "🎀", "accessory": "💎", "shoes": "👟",
}

# ── 稀有度配置 ────────────────────────────────────────────────
const RARITY_LABELS = {"common": "普通", "rare": "精良", "limited": "限定"}
const RARITY_COLORS = {
	"common":  Color(0.70, 0.70, 0.70),
	"rare":    Color(0.35, 0.62, 0.95),
	"limited": Color(1.00, 0.78, 0.15),
}

# ── 物品数据库（15件） ─────────────────────────────────────────
# stat_bonus: 穿戴时的属性加成（不永久写入 stats）
# fav_bonus:  {"loc": 地点id, "pct": 0.15} 在该地点活动时好感+%
# stock: -1=无限, >0=限量（需配合服务端）
const WARDROBE_DB: Dictionary = {
	# ── Common（6件）─────────────────────────────────────────
	"uniform_top": {
		"name": "校服上衣",        "emoji": "👕",
		"category": "top",        "rarity": "common",
		"price": 0,               "stock": -1,       "season": "all",
		"stat_bonus": {},          "fav_bonus": {},
		"desc": "西湖中学标准校服上衣，整洁大方，全体同学标配。",
		"image": "res://assets/wardrobe/top_uniform.png",
	},
	"uniform_bottom": {
		"name": "校服裤/裙",       "emoji": "👖",
		"category": "bottom",     "rarity": "common",
		"price": 0,               "stock": -1,       "season": "all",
		"stat_bonus": {},          "fav_bonus": {},
		"desc": "西湖中学标准校服下装，男生款西裤，女生款百褶裙。",
		"image": "res://assets/wardrobe/bottom_uniform.png",
	},
	"sport_outfit": {
		"name": "运动套装",        "emoji": "🏃",
		"category": "outfit",     "rarity": "common",
		"price": 30,              "stock": -1,       "season": "all",
		"stat_bonus": {"strength": 3},  "fav_bonus": {"loc": "playground", "pct": 0.10},
		"desc": "宽松舒适的运动服，穿上它在操场奔跑格外带劲。",
		"image": "res://assets/wardrobe/outfit_sport.png",
	},
	"casual_tee": {
		"name": "百搭T恤",         "emoji": "👕",
		"category": "top",        "rarity": "common",
		"price": 25,              "stock": -1,       "season": "all",
		"stat_bonus": {"social": 1},   "fav_bonus": {},
		"desc": "简约风格T恤，出门逛街的日常之选。",
		"image": "res://assets/wardrobe/top_casual_tee.png",
	},
	"white_sneakers": {
		"name": "小白鞋",          "emoji": "👟",
		"category": "shoes",      "rarity": "common",
		"price": 35,              "stock": -1,       "season": "all",
		"stat_bonus": {"charm": 1},    "fav_bonus": {},
		"desc": "经典百搭小白鞋，和任何穿搭都很配。",
		"image": "res://assets/wardrobe/shoes_white_sneakers.png",
	},
	"simple_ribbon": {
		"name": "素色发带",        "emoji": "🎀",
		"category": "head",       "rarity": "common",
		"price": 15,              "stock": -1,       "season": "all",
		"stat_bonus": {"charm": 1},    "fav_bonus": {},
		"desc": "简约素色发带，清爽干净，随意一束就很好看。",
		"image": "res://assets/wardrobe/head_simple_ribbon.png",
	},
	# ── Rare（6件）───────────────────────────────────────────
	"hanfu_blue": {
		"name": "西湖蓝汉服",      "emoji": "🩱",
		"category": "outfit",     "rarity": "rare",
		"price": 128,             "stock": -1,       "season": "spring",
		"stat_bonus": {"charm": 5, "art": 3},
		"fav_bonus": {"loc": "lakeside", "pct": 0.15},
		"desc": "一袭西湖蓝，走在断桥碧柳间，自有江南古典气韵。",
		"image": "res://assets/wardrobe/outfit_hanfu_blue.png",
	},
	"qipao_red": {
		"name": "江南旗袍",        "emoji": "🥻",
		"category": "outfit",     "rarity": "rare",
		"price": 158,             "stock": -1,       "season": "autumn",
		"stat_bonus": {"charm": 6, "social": 2},
		"fav_bonus": {"loc": "lakeside", "pct": 0.10},
		"desc": "改良旗袍，秋日桂花香里穿上格外有韵味。",
		"image": "res://assets/wardrobe/outfit_qipao_red.png",
	},
	"new_year_dress": {
		"name": "元旦礼服",        "emoji": "🎄",
		"category": "outfit",     "rarity": "rare",
		"price": 99,              "stock": -1,       "season": "winter",
		"stat_bonus": {"charm": 4, "social": 4},
		"fav_bonus": {"loc": "school_gate", "pct": 0.12},
		"desc": "新年活动专属，亮片设计在夜晚光彩夺目，元旦舞会首选。",
		"image": "res://assets/wardrobe/outfit_new_year_dress.png",
	},
	"dragon_boat_hanfu": {
		"name": "端午汉服",        "emoji": "🎋",
		"category": "outfit",     "rarity": "rare",
		"price": 118,             "stock": -1,       "season": "summer",
		"stat_bonus": {"art": 4, "charm": 3},
		"fav_bonus": {"loc": "lakeside", "pct": 0.12},
		"desc": "端午节气专属汉服，翠绿配色融入夏日荷叶清香。",
		"image": "res://assets/wardrobe/outfit_dragon_boat_hanfu.png",
	},
	"osmanthus_hairpin": {
		"name": "桂花簪",          "emoji": "🌼",
		"category": "head",       "rarity": "rare",
		"price": 68,              "stock": -1,       "season": "autumn",
		"stat_bonus": {"charm": 3, "art": 2},
		"fav_bonus": {"loc": "lakeside", "pct": 0.08},
		"desc": "西湖桂花制成的发簪，秋日戴上香气萦绕，少女心满满。",
		"image": "res://assets/wardrobe/head_osmanthus_hairpin.png",
	},
	"longjing_bracelet": {
		"name": "龙井玉手链",      "emoji": "💚",
		"category": "accessory",  "rarity": "rare",
		"price": 88,              "stock": -1,       "season": "all",
		"stat_bonus": {"social": 3, "charm": 2},
		"fav_bonus": {},
		"desc": "龙井山出产的绿玉制成，清雅脱俗，每次活动都让人多看一眼。",
		"image": "res://assets/wardrobe/accessory_longjing_bracelet.png",
	},
	# ── Limited（3件）────────────────────────────────────────
	"duanqiao_set": {
		"name": "断桥同款",        "emoji": "🌉",
		"category": "outfit",     "rarity": "limited",
		"price": 298,             "stock": 100,      "season": "all",
		"stat_bonus": {"charm": 8, "art": 5, "social": 3},
		"fav_bonus": {"loc": "lakeside", "pct": 0.20},
		"desc": "【限定】断桥残雪联名款，白底冰雪纹，穿上它站在断桥上恍若画中人。",
		"image": "res://assets/wardrobe/outfit_duanqiao_set.png",
	},
	"westlake_collab": {
		"name": "西湖联名款",      "emoji": "🏞️",
		"category": "outfit",     "rarity": "limited",
		"price": 368,             "stock": 80,       "season": "all",
		"stat_bonus": {"charm": 10, "social": 5},
		"fav_bonus": {"loc": "lakeside", "pct": 0.25},
		"desc": "【限定】西湖十景官方联名，极致工艺，全服限量发售，穿上让人直呼出片。",
		"image": "res://assets/wardrobe/outfit_westlake_collab.png",
	},
	"spring_festival": {
		"name": "新春特供旗袍",    "emoji": "🧧",
		"category": "outfit",     "rarity": "limited",
		"price": 188,             "stock": 200,      "season": "winter",
		"stat_bonus": {"charm": 7, "social": 4},
		"fav_bonus": {"loc": "community", "pct": 0.15},
		"desc": "【限定】新春联欢会专属旗袍，红金配色喜气洋洋，一年只此一次。",
		"image": "res://assets/wardrobe/outfit_spring_festival.png",
	},
}

# ── 运行时状态 ────────────────────────────────────────────────
var owned_items: Array = []           # 已拥有的 item_id 列表（含免费默认款）
var equipped: Dictionary = {}         # slot -> item_id
var item_stock: Dictionary = {}       # item_id -> 本地缓存库存（服务端同步）

# ── 初始化 ────────────────────────────────────────────────────
func _ready() -> void:
	# 默认拥有两件校服
	if owned_items.is_empty():
		owned_items = ["uniform_top", "uniform_bottom"]
	# 同步一次服务端限量库存（无网络时回退本地值）
	_sync_limited_stock()

func _sync_limited_stock() -> void:
	for item_id in WARDROBE_DB.keys():
		var item = WARDROBE_DB[item_id]
		if item.get("stock", -1) > 0:
			item_stock[item_id] = item["stock"]   # 本地默认，服务端同步后覆盖
	# TODO: 接入 NetworkManager.get_item_stock(item_id) 更新 item_stock
	# NetworkManager.wardrobe_stock_synced.connect(_on_stock_synced)

# ── 购买 ──────────────────────────────────────────────────────
func buy_item(item_id: String) -> Dictionary:
	if not WARDROBE_DB.has(item_id):
		return {"success": false, "reason": "物品不存在"}
	if item_id in owned_items:
		return {"success": false, "reason": "已拥有此物品"}

	var item = WARDROBE_DB[item_id]
	var price = item.get("price", 0)

	# 金钱检查
	if GameManager.money < price:
		return {"success": false, "reason": "零花钱不足！需要 💰%d" % price}

	# 限量库存检查
	var stock = item.get("stock", -1)
	if stock == 0:
		return {"success": false, "reason": "该物品已售罄"}
	if stock > 0:
		var cur = item_stock.get(item_id, stock)
		if cur <= 0:
			return {"success": false, "reason": "该物品已售罄"}
		# TODO: 调用服务端扣减库存，成功后再扣金钱
		item_stock[item_id] = cur - 1

	GameManager.money -= price
	owned_items.append(item_id)
	item_purchased.emit(item_id)

	var rarity_tag = RARITY_LABELS.get(item.get("rarity","common"), "")
	GameManager.add_log("🛍️ 购入【%s】%s" % [rarity_tag, item["name"]])
	GameManager.show_toast.emit("🛍️ 购入：%s %s" % [item["emoji"], item["name"]])
	GameManager.state_updated.emit()
	return {"success": true, "item": item}

# ── 装备 / 卸下 ───────────────────────────────────────────────
func equip(item_id: String) -> bool:
	if not item_id in owned_items: return false
	if not WARDROBE_DB.has(item_id): return false
	var slot = WARDROBE_DB[item_id]["category"]
	equipped[slot] = item_id
	item_equipped.emit(item_id, slot)
	GameManager.state_updated.emit()
	return true

func unequip(slot: String) -> void:
	if not equipped.has(slot): return
	equipped.erase(slot)
	item_unequipped.emit(slot)
	GameManager.state_updated.emit()

func get_equipped_item(slot: String) -> Dictionary:
	var id = equipped.get(slot, "")
	if id == "": return {}
	return WARDROBE_DB.get(id, {})

# ── 属性加成计算 ──────────────────────────────────────────────
## 返回当前所有装备叠加的属性加成 Dictionary
func get_active_bonus() -> Dictionary:
	var bonus: Dictionary = {}
	var has_outfit = equipped.has("outfit") and equipped["outfit"] != ""

	for slot in equipped.keys():
		# 穿套装时，上衣/下装的加成禁用
		if has_outfit and (slot == "top" or slot == "bottom"):
			continue
		var id = equipped[slot]
		if id == "": continue
		var item = WARDROBE_DB.get(id, {})
		for stat in item.get("stat_bonus", {}).keys():
			bonus[stat] = bonus.get(stat, 0) + item["stat_bonus"][stat]
	return bonus

## 返回当前穿搭在指定地点的好感加成倍率（0.0 = 无加成）
func get_fav_bonus_for_loc(loc_id: String) -> float:
	var total_pct: float = 0.0
	var has_outfit = equipped.has("outfit") and equipped["outfit"] != ""

	for slot in equipped.keys():
		if has_outfit and (slot == "top" or slot == "bottom"): continue
		var id = equipped[slot]
		if id == "": continue
		var item = WARDROBE_DB.get(id, {})
		var fb = item.get("fav_bonus", {})
		if fb.get("loc", "") == loc_id:
			total_pct += fb.get("pct", 0.0)
	return total_pct

## 按槽位返回玩家已拥有的物品列表（UI 筛选用）
func get_owned_by_slot(slot: String) -> Array:
	var result: Array = []
	for id in owned_items:
		if WARDROBE_DB.has(id) and WARDROBE_DB[id]["category"] == slot:
			result.append(id)
	return result

## 判断某家 item 是否售罄
func is_sold_out(item_id: String) -> bool:
	var item = WARDROBE_DB.get(item_id, {})
	var stock = item.get("stock", -1)
	if stock < 0: return false
	if stock == 0: return true
	return item_stock.get(item_id, stock) <= 0

# ── 存读档 ────────────────────────────────────────────────────
func get_save_data() -> Dictionary:
	return {
		"owned_items":  owned_items.duplicate(),
		"equipped":     equipped.duplicate(),
		"item_stock":   item_stock.duplicate(),
	}

func load_save_data(data: Dictionary) -> void:
	owned_items = data.get("owned_items", ["uniform_top", "uniform_bottom"])
	equipped    = data.get("equipped", {})
	item_stock  = data.get("item_stock", {})
