extends Node

# ═══════════════════════════════════════════════════════════════
# ── RelationshipManager ───────────────────────────────────────
# 关系状态机：状态 = 好感度的纯函数 + 冷战覆盖态
# 状态缓存留守 GameManager.relationship_state（经门面访问）
# ═══════════════════════════════════════════════════════════════

# 状态定义（id / 中文 / 颜色 / 好感下限）
const REL_STATES = {
	"stranger":    {"label": "陌生", "color": "#9ca3af", "min_fav": 0},
	"acquaintance":{"label": "熟悉", "color": "#60a5fa", "min_fav": 15},
	"friend":      {"label": "朋友", "color": "#34d399", "min_fav": 30},
	"close":       {"label": "暧昧", "color": "#f472b6", "min_fav": 60},
	"crush":       {"label": "心动", "color": "#fb7185", "min_fav": 85},
	"cold":        {"label": "冷战", "color": "#ef4444", "min_fav": -1},
}

# 上升态顺序（用于升级/降级判断；cold 不在其中，作为覆盖态单独处理）
const REL_ORDER = ["stranger", "acquaintance", "friend", "close", "crush"]

signal rel_state_changed(char_id: String, prev_state: String, new_state: String)

func _rel_index(state: String) -> int:
	return REL_ORDER.find(state)

# ── 由好感推导基础状态（不含冷战覆盖）────────────────────────
func _derive_base_state(char_id: String) -> String:
	var fav = GameManager.favorability.get(char_id, 0)
	var result = "stranger"
	for s in REL_ORDER:
		if fav >= REL_STATES[s]["min_fav"]:
			result = s
	return result

# ── 重算单个角色状态（含冷战覆盖 + 升级提示）────────────────
func recompute_rel_state(char_id: String, silent: bool = false):
	var prev = GameManager.relationship_state.get(char_id, "stranger")
	var now = _derive_base_state(char_id)
	if GameManager.flags.has("rel_cold_" + char_id):
		now = "cold"
	GameManager.relationship_state[char_id] = now
	rel_state_changed.emit(char_id, prev, now)
	if not silent and _rel_index(now) > _rel_index(prev):
		var char_name = GameManager.char_meta.get(char_id, {}).get("name", char_id)
		GameManager.show_toast.emit("💞 你和 %s 的关系进入了『%s』阶段！" % [char_name, REL_STATES[now]["label"]])

# ── 重算所有角色 ──────────────────────────────────────────────
func recompute_all_states(silent: bool = false):
	for char_id in GameManager.favorability.keys():
		recompute_rel_state(char_id, silent)

# ── 查询门面 ──────────────────────────────────────────────────
func get_rel_state(char_id: String) -> String:
	if GameManager.relationship_state.has(char_id):
		return GameManager.relationship_state[char_id]
	return _derive_base_state(char_id)

func get_rel_state_display(char_id: String) -> Dictionary:
	var st = get_rel_state(char_id)
	return REL_STATES.get(st, REL_STATES["stranger"])

# ── 冷战：进入 ────────────────────────────────────────────────
func enter_cold_war(char_id: String):
	if GameManager.flags.has("rel_cold_" + char_id):
		return  # 已在冷战，避免重复扣好感
	var char_name = GameManager.char_meta.get(char_id, {}).get("name", char_id)
	GameManager.set_flag("rel_cold_" + char_id, true)
	GameManager.favorability[char_id] = clampi(GameManager.favorability[char_id] - 10, 0, 100)
	var prev = GameManager.relationship_state.get(char_id, "stranger")
	GameManager.relationship_state[char_id] = "cold"
	GameManager.show_toast.emit("❄️ 你和 %s 陷入了冷战……" % char_name)
	rel_state_changed.emit(char_id, prev, "cold")

# ── 冷战：挽回 ────────────────────────────────────────────────
func recover_from_cold(char_id: String):
	if not GameManager.flags.has("rel_cold_" + char_id):
		return
	var char_name = GameManager.char_meta.get(char_id, {}).get("name", char_id)
	GameManager.set_flag("rel_cold_" + char_id, false)
	var prev = "cold"
	var now = _derive_base_state(char_id)
	# 挽回小补偿：好感 +5（已脱离冷战封锁，正常累加）
	GameManager.favorability[char_id] = clampi(GameManager.favorability[char_id] + 5, 0, 100)
	GameManager.relationship_state[char_id] = now
	GameManager.show_toast.emit("🌸 你和 %s 和好了。" % char_name)
	rel_state_changed.emit(char_id, prev, now)
