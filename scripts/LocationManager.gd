extends Node

# ═══════════════════════════════════════════════════════════════
# ── LocationManager ───────────────────────────────────────────
# 地点可访问性 / 热点 / 特殊日期地点扩展系统
# 实现从 GameManager 抽出（门面委托，对外 API 不变）
# ═══════════════════════════════════════════════════════════════

## 返回某地点的全部热点（基础 + 当日特殊追加）
## HotspotExploreUI 应调用此函数而非直接读 locations[id]["hotspots"]
func get_location_hotspots(loc_id: String) -> Array:
	var base: Array = GameManager.locations.get(loc_id, {}).get("hotspots", [])
	return base + _get_temp_hotspots(loc_id)

## 当日临时追加热点（文化节、节日等）
func _get_temp_hotspots(loc_id: String) -> Array:
	# 文化节（第 240 天）：教室 + 校门口各增一个专属热点
	if GameManager.day == 240:
		match loc_id:
			"classroom":
				return [{"label": "🎪 展位布置 (参与文化节)", "pos": Vector2(0.75, 0.30), "event_id": "cultural_festival"}]
			"school_gate":
				return [{"label": "🎭 演出舞台 (观看表演)", "pos": Vector2(0.50, 0.25), "event_id": "cultural_festival"}]
	# 长假临时热点：长假期间按 [假期, 地点] 追加中性 filler 热点
	var h = GameManager.current_holiday
	if h != "":
		match h:
			"winter":
				match loc_id:
					"community":
						return [
							{"label": "🎿 郊外滑雪", "pos": Vector2(0.30, 0.35), "event_id": "break_winter_ski"},
							{"label": "🏮 新春庙会", "pos": Vector2(0.62, 0.45), "event_id": "break_winter_temple"},
						]
					"home":
						return [{"label": "🏠 寒假·家的温度", "pos": Vector2(0.50, 0.40), "event_id": "break_winter_family"}]
			"summer":
				match loc_id:
					"amusement_park":
						return [{"label": "⛺ 暑期夏令营", "pos": Vector2(0.55, 0.30), "event_id": "break_summer_camp"}]
					"lakeside":
						return [{"label": "🌉 西湖夏夜游", "pos": Vector2(0.40, 0.50), "event_id": "break_summer_lake_night"}]
			"spring":
				match loc_id:
					"community":
						return [{"label": "🌸 春日短途春游", "pos": Vector2(0.35, 0.40), "event_id": "break_spring_outing"}]
					"lakeside":
						return [{"label": "🍃 清明踏青", "pos": Vector2(0.40, 0.45), "event_id": "break_spring_qingming"}]
			"autumn":
				match loc_id:
					"lakeside":
						return [{"label": "🇨🇳 国庆西湖行", "pos": Vector2(0.38, 0.48), "event_id": "break_autumn_nationalday"}]
					"community":
						return [{"label": "🌼 桂花市集", "pos": Vector2(0.55, 0.38), "event_id": "break_autumn_osmanthus"}]
	return []

## 毕业前夜（第 569 天）：强制锁定只能去西湖边
## 返回非空字符串时，LocationListUI 应仅显示该地点
func get_forced_location_for_day() -> String:
	if GameManager.day == 569:
		return "lakeside"
	return ""

# ── 地点可访问性判断 ─────────────────────────────────────────
func get_available_locations() -> Array:
	var slot_id = GameManager._get_slot_id()
	var weekend = GameManager.is_weekend()
	var result = []

	# 上学日上午/中午，这些校外地点不可见
	var school_only_mode = ["home", "lakeside", "community", "cinema", "amusement_park", "off_campus_shop", "school_gate"]

	for loc_id in GameManager.locations.keys():
		var loc = GameManager.locations[loc_id]

		# 解锁天数检查
		if GameManager.day < loc.get("unlock", 1):
			result.append({"id": loc_id, "available": false, "reason": "locked"})
			continue

		# 时间段检查
		var loc_slots = loc.get("slots", [])
		if loc_id == "lakeside" and weekend:
			loc_slots = ["morning", "noon", "after", "evening"]

		if not slot_id in loc_slots:
			continue  # 该时段此地点不显示

		# 上学日上午/中午，屏蔽校外地点
		if not weekend and GameManager.current_holiday == "" and (slot_id == "morning" or slot_id == "noon"):
			if loc_id in school_only_mode:
				continue

		# 仅工作日限制
		if weekend and loc.get("workdayOnly", false):
			continue

		# 假期期间：workdayOnly 地点（校园场所）也隐藏
		if GameManager.current_holiday != "" and loc.get("workdayOnly", false):
			continue

		# 仅假期限制：假期外不显示
		if GameManager.current_holiday == "" and loc.get("vacationOnly", false):
			continue

		# 仅周末限制
		if not weekend and loc.get("weekendOnly", false):
			continue

		result.append({"id": loc_id, "available": true, "reason": ""})

	return result
