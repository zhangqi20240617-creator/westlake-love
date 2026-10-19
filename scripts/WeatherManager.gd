extends Node
## ═══════════════════════════════════════════════════════════════
## WeatherManager — 天气 / 季节 / 运势系统（自 GameManager 拆出）
## ═══════════════════════════════════════════════════════════════
## 职责：
##   - 四季判定（春1-150 / 夏151-300 / 秋301-450 / 冬451-570）与西湖十景
##   - 天气对属性收益的动态加成（晴天户外 / 雨雪室内）与描述文本
##   - 每日按季节刷新天气（杭州时节：春雨、夏暴雨、秋雾、冬雪）
##   - 每日运势（1-5 星，含天气因子）
##
## 共享状态归属说明（重要）：
##   current_weather 与 WEATHER_NAMES 仍保留在 GameManager 上——因为
##   CenterDashboardUI / HeaderUI / DataManager / DialogueUI /
##   HotspotExploreUI 等外部脚本直接读取。本管理器统一经 GameManager.xxx
##   读写 current_weather / day / player_name。
##
## 外部脚本无需感知本管理器：GameManager 保留同名门面方法委托到这里。

# ── 四季系统 ──────────────────────────────────────────────────
# 春1-150 / 夏151-300 / 秋301-450 / 冬451-570（对应杭州初一到初三）
const WEST_LAKE_SCENES = {
	"spring": {"name": "苏堤春晓", "emoji": "🌸", "season_label": "🌸 春日", "desc": "春暖花开，苏堤垂柳如烟，桃花片片飘落湖面。"},
	"summer": {"name": "曲院风荷", "emoji": "🌿", "season_label": "☀️ 盛夏", "desc": "接天莲叶无穷碧，荷香随风入曲院。"},
	"autumn": {"name": "平湖秋月", "emoji": "🍂", "season_label": "🍂 金秋", "desc": "桂花香飘十里，湖面如镜映秋月。"},
	"winter": {"name": "断桥残雪", "emoji": "❄️", "season_label": "❄️ 寒冬", "desc": "积雪半融，断桥横卧，白堤寂静如诗。"}
}

func get_season() -> String:
	var day = GameManager.day
	if day <= 150:   return "spring"
	elif day <= 300: return "summer"
	elif day <= 450: return "autumn"
	else:            return "winter"

func get_season_label() -> String:
	var scene = WEST_LAKE_SCENES.get(get_season(), {})
	return scene.get("season_label", "🌸 春日")

func get_west_lake_scene() -> Dictionary:
	return WEST_LAKE_SCENES.get(get_season(), WEST_LAKE_SCENES["spring"])

# 天气对属性的动态加成倍率（供 DataManager.apply_location_gains 调用）
func get_weather_stat_bonus(stat_name: String, location_id: String) -> float:
	var w = GameManager.current_weather
	var is_outdoor = location_id in ["lakeside", "playground", "school_gate", "community", "amusement_park"]
	if w == "rainy" or w == "snowy":
		# 雨/雪天室内学习+20%
		if stat_name == "intellect" and not is_outdoor:
			return 1.2
		# 雨/雪天户外压力增大
		if stat_name == "stress" and is_outdoor:
			return 1.3
	elif w == "sunny":
		# 晴天户外运动/社交/艺术+30%
		if is_outdoor and stat_name in ["strength", "social", "art"]:
			return 1.3
	return 1.0

# 天气加成描述文本（用于中央信息面板）
func get_weather_effect_desc() -> String:
	match GameManager.current_weather:
		"sunny":  return "☀️ 晴天加持：户外好感度×1.3，运动收益翻倍！"
		"cloudy": return "☁️ 阴天宜静：适合图书馆学习，心情平稳。"
		"rainy":  return "🌧️ 烟雨西湖：室内学习效率+20%，出门压力略增。"
		"snowy":  return "❄️ 漫天飞雪：断桥残雪美如画，可触发冬季限定事件！"
	return ""

func _refresh_weather_by_season():
	# 按季节调整天气概率，深度扣题"杭州时节事件"
	var season = get_season()
	var r = randf()
	match season:
		"spring":
			# 春天：多晴、多烟雨（杭州春雨绵绵），偶有阴天
			if r < 0.50: GameManager.current_weather = "sunny"
			elif r < 0.75: GameManager.current_weather = "cloudy"
			else: GameManager.current_weather = "rainy"
		"summer":
			# 夏天：晴热为主，暴雨频繁（曲院风荷之雨）
			if r < 0.45: GameManager.current_weather = "sunny"
			elif r < 0.65: GameManager.current_weather = "cloudy"
			else: GameManager.current_weather = "rainy"
		"autumn":
			# 秋天：以晴为主，偶有大雾（平湖秋月卧雾湖）
			if r < 0.60: GameManager.current_weather = "sunny"
			elif r < 0.85: GameManager.current_weather = "cloudy"
			else: GameManager.current_weather = "rainy"
		"winter":
			# 冬天：阴冷为主，偶有飘雪（断桥残雪）
			if r < 0.30: GameManager.current_weather = "sunny"
			elif r < 0.60: GameManager.current_weather = "cloudy"
			elif r < 0.85: GameManager.current_weather = "rainy"
			else: GameManager.current_weather = "snowy"

## 每日运势（1-5星），每日固定但不可预测，基于日期+玩家名哈希组合
## 5星=大吉（好感加成×1.2），1-2星=背运
func get_daily_fortune() -> int:
	# 使用日期和玩家名的哈希组合，同一天多时段运势稳定，但规律不易被推算
	var name_hash: int = 0
	for c in GameManager.player_name:
		name_hash = (name_hash * 31 + c.unicode_at(0)) & 0xFFFFFF
	var seed_val = (GameManager.day * 1000003 + name_hash * 7919) & 0x7FFFFFFF
	# 混合天气因子（天气影响运势分布，但不改变基础随机性）
	var weather_mod = {"sunny": 1, "cloudy": 0, "rainy": -1, "snowy": 1}.get(GameManager.current_weather, 0)
	var raw = (seed_val % 5) + 1
	# 晴/雪天略微偏向好运，烟雨略微偏向厄运（±1，不超出1-5范围）
	return clampi(raw + weather_mod, 1, 5)
