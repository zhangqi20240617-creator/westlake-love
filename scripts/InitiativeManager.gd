extends Node

# ═══════════════════════════════════════════════════════════════
# ── 双向奔赴与主动邀请系统（从 GameManager 拆分出来）────────────
# 本管理器持有角色主动性运行时状态与配置，并依赖 GameManager 的
# 共享状态（char_meta / favorability / locations / day / slot_index 等）。
# 对外接口仍通过 GameManager 的门面方法转发，外部脚本无需改动。
# 信号 initiative_updated 仍声明在 GameManager 上（供 MainGame 连接），
# 本管理器通过 GameManager.initiative_updated.emit() 触发。
# ═══════════════════════════════════════════════════════════════

# 每个角色的主动性运行时状态
var char_initiative: Dictionary = {}

# 邀请有效时段数
const INVITE_EXPIRE_SLOTS: int = 3

# ── 各角色主动邀请配置 ──────────────────────────────────────────
const CHAR_INITIATIVE_CONFIG = {
	"yutong": {
		"invite_locs": {
			50: ["library", "classroom"],
			70: ["lakeside", "cinema"],
			85: ["lakeside", "amusement_park"]
		},
		"wechat_msgs": {
			30: ["今天的数学题有点难，你做完了吗？", "放学路上碰到你同学了，你今天过得怎么样？"],
			50: ["我在图书馆，你下午有时间来自习吗？", "课间休息时我看到你了，你好像在发呆 (｀・ω・´)"],
			70: ["……你今天好像心情不太好，还好吗？", "周末有计划吗？我想去西湖边走走。"],
			85: ["我一直在想一件事，改天当面跟你说。", "你知道吗，你每次笑起来我就很高兴。"]
		},
		"invite_texts": {
			50: "雨桐邀请你去图书馆一起自习！",
			70: "雨桐邀请你去西湖边散步……",
			85: "雨桐发消息说想见你，在小区门口等你。"
		}
	},
	"jingjing": {
		"invite_locs": {
			50: ["community", "school_gate"],
			70: ["lakeside", "cinema"],
			85: ["lakeside", "amusement_park"]
		},
		"wechat_msgs": {
			30: ["喂，你今天有没有听到什么八卦？告诉我！", "妈妈做了红烧肉，你要不要来蹭饭(>ω<)"],
			50: ["你昨天放学走那么快，也不等我！", "我买了两杯奶茶，你要不要来楼下接？"],
			70: ["我有件事想问你……算了，你先说你今天怎么样。", "如果你没事的话，今晚能不能陪我去西湖走走？"],
			85: ["我不知道为什么，就是想找你说说话。", "你有时候真的很烦，但是……我还是想见你。"]
		},
		"invite_texts": {
			50: "菁菁在楼下找你，说有奶茶要给你！",
			70: "菁菁邀请你今晚去西湖边……",
			85: "菁菁说她有话跟你说，让你去找她。"
		}
	},
	"wanqing": {
		"invite_locs": {
			50: ["library"],
			70: ["library", "lakeside"],
			85: ["lakeside"]
		},
		"wechat_msgs": {
			30: ["你最近有在看什么书吗？", "图书馆新到了一批文学馆藏，有空一起去看看。"],
			50: ["我在图书馆靠窗的位置，如果你来了可以找我。", "你写过日记吗？我觉得记录生活很重要。"],
			70: ["我把我写的短篇发给你看，但你要认真读，不许敷衍。", "西湖边的黄昏很适合思考，你愿意陪我去吗？"],
			85: ["我写了一首诗，里面有些话……是想对你说的。", "有时候不知道怎么开口，所以就写下来了。"]
		},
		"invite_texts": {
			50: "晚晴在图书馆靠窗位，邀你一起自习。",
			70: "晚晴邀请你傍晚去西湖边散步聊天。",
			85: "晚晴说她有话要亲口对你说。"
		}
	},
	"xiaoxia": {
		"invite_locs": {
			50: ["playground"],
			70: ["playground", "lakeside"],
			85: ["lakeside", "amusement_park"]
		},
		"wechat_msgs": {
			30: ["今天下午操场有踢球，你来不来？", "我跑了五公里！你呢，有在运动吗？"],
			50: ["跑完步超爽的！你要不要明天一起晨跑？", "你上次说要来操场看我练球，啥时候来？"],
			70: ["……其实我很少邀请别人的，你别多想啊。", "我买了两张游乐园票，你……有空的话一起去？"],
			85: ["我不太会说好听的话，但是我很高兴认识你。", "你知道运动员最厉害的地方是什么吗？就是不放弃。"]
		},
		"invite_texts": {
			50: "小夏邀请你去操场一起运动！",
			70: "小夏邀请你去西湖边跑步……",
			85: "小夏在操场等你，说有话要说。"
		}
	},
	"yifei": {
		"invite_locs": {
			50: ["music_room"],
			70: ["lakeside", "cinema"],
			85: ["lakeside"]
		},
		"wechat_msgs": {
			30: ["今天课上有首曲子，感觉是为你写的。", "你喜欢听什么音乐？我可以给你推荐几首。"],
			50: ["音乐教室下午没有课，你想来听我练琴吗？", "我录了一段，发给你听，要不要反馈一下？"],
			70: ["西湖边黄昏的风很适合演奏，你愿意来吗？", "有件事我想当面告诉你，但每次见到你就说不出口。"],
			85: ["你是我写音乐时，最先想到的听众。", "我知道这样说可能奇怪，但我希望你一直都在。"]
		},
		"invite_texts": {
			50: "逸飞邀你去音乐教室听他练琴。",
			70: "逸飞邀你傍晚去西湖边……",
			85: "逸飞说他写了一首曲子，想亲自演奏给你听。"
		}
	},
	"zicheng": {
		"invite_locs": {
			50: ["playground"],
			70: ["playground", "cinema"],
			85: ["lakeside", "amusement_park"]
		},
		"wechat_msgs": {
			30: ["篮球队今天训练，你要不要来观战？", "学习之余要多动动，约吗？"],
			50: ["我订了两张比赛票，你要不要一起去？", "你昨天帮了我一个忙，我想请你吃饭。"],
			70: ["我不擅长说那些弯弯绕的话，你懂我意思吧？", "周末我们出去吧，你决定去哪。"],
			85: ["你知道吗，比赛最紧张的时候，我会想到你。", "和你在一起我很放松，希望这种感觉一直有。"]
		},
		"invite_texts": {
			50: "子诚邀你去操场看他打篮球！",
			70: "子诚约你周末一起出去……",
			85: "子诚说有话想当面跟你说。"
		}
	},
	"keke": {
		"invite_locs": {
			50: ["playground"],
			70: ["playground", "cinema"],
			85: ["lakeside", "amusement_park"]
		},
		"wechat_msgs": {
			30: ["最近附近有家新开的甜品店，听说很好吃！", "你今天怎么样？"],
			50: ["我买了两张游乐园门票，你要去吗？", "天气真好，出去兜风不？"],
			70: ["周末有空吗？想去西湖边逛逛。"],
			85: ["我有重要的话想跟你讲。"]
		},
		"invite_texts": {
			50: "可可邀你去操场逛逛！",
			70: "可可约你周末一起出去玩……",
			85: "可可说有话想当面跟你说。"
		}
	},
	"beichen": {
		"invite_locs": {
			50: ["library"],
			70: ["library", "cinema"],
			85: ["lakeside", "amusement_park"]
		},
		"wechat_msgs": {
			30: ["你在学习吗？", "遇到问题可以问我。"],
			50: ["周末我打算去图书馆，一起去吗？"],
			70: ["听说今天有流星雨，要不要去西湖边看看？"],
			85: ["我有个心事，想讲给你听。"]
		},
		"invite_texts": {
			50: "北辰邀你去图书馆学习。",
			70: "北辰约你周末一起出去……",
			85: "北辰说有话想当面跟你说。"
		}
	},
	"zijun": {
		"invite_locs": {
			50: ["art_room"],
			70: ["art_room", "cinema"],
			85: ["lakeside", "amusement_park"]
		},
		"wechat_msgs": {
			30: ["我画了一张你，想不想看？", "最近灵感爆棚。"],
			50: ["周末有个画展，有没有兴趣陪我？"],
			70: ["我想去西湖边写生，要不要一起来？"],
			85: ["这幅画，我只想送给你。"]
		},
		"invite_texts": {
			50: "子珺邀你去美术教室欣赏画作。",
			70: "子珺约你周末一起去看展……",
			85: "子珺说有话想当面跟你说。"
		}
	},
	"jingjing_m": {
		"invite_locs": {
			50: ["community"],
			70: ["community", "cinema"],
			85: ["lakeside", "amusement_park"]
		},
		"wechat_msgs": {
			30: ["你的卷子做完没？借我抄抄！", "帮我打掩护，我要出去玩！"],
			50: ["你要不要陪我打游戏？"],
			70: ["周末老地方见，别迟到！"],
			85: ["我只是……突然有点想见你而已。"]
		},
		"invite_texts": {
			50: "明轩在楼下等你打游戏。",
			70: "明轩约你周末一起出去……",
			85: "明轩说有话想当面跟你说。"
		}
	}
}

# ── 深夜聊天：各角色 night_start 首句（用作 wechat_msg 预览/首条气泡文本）──
# 必须与 WeChatUI.chats_db[cid]["nodes"]["night_start"]["text"] 完全一致
const NIGHT_CHAT_OPENERS = {
	"yutong": "还没睡吧？刚整理完模拟卷才发现这么晚了。\n……其实今天想跟你说声抱歉，白天催作业的时候，语气好像有点凶。",
	"jingjing": "喂……你睡了吗？我睡不着。今天白天跟妈妈吵架了，一直心里闷闷的。\n从小到大好像每次难受，最后都是找你说。",
	"wanqing": "睡不着，就着台灯读了会儿诗。“今夜偏知春气暖，虫声新透绿窗纱。”\n……忽然想，不知道你此刻的窗外，是什么声音。",
	"xiaoxia": "喂！你还醒着吧！我睡不着——明天区运动会4x100我跑最后一棒，越想越紧张。\n居然会紧张，我诶！",
	"keke": "呜……你还醒着吗？今天跟爸妈视频，看到我家楼下的桂花开了，突然有点想家。\n杭州明明也有桂花，闻起来却不太一样。",
	"yifei": "抱歉，这么晚打扰。那首曲子……刚才终于写完了最后一小节。\n写完的第一秒，不知道为什么，就想告诉你。",
	"zicheng": "兄弟，睡了没。今天训练赛我罚球三连铁，最后输了两分……\n队长当成这样，有点没脸见队里那帮人。",
	"beichen": "还醒着？\n刚才在阳台看月亮，突然想，这座城市里大概只有你会回我这种时间的消息。",
	"jingjing_m": "你房间灯还亮着，别装，我阳台看得一清二楚。\n这么晚不睡，又在跟哪道题过不去？",
	"zijun": "还没睡？哼，正好。艺术节的海报……评委说要大改。\n我盯着画板两个小时了，一笔都下不去。"
}

# 深夜遴选并列时的关系阶梯权重
const NIGHT_REL_ORDER = {
	"stranger": 0, "acquaintance": 1, "friend": 2, "close": 3, "crush": 4
}

## 深夜聊天遴选与投递：由 GameManager.advance_time() 在进入 evening 时段时调用。
## 每晚最多 1 位角色、1 条消息；复用既有主动微信消息队列，无新管道。
func check_night_chat():
	_init_char_initiative()
	var day = GameManager.day

	# 每日去重（同时防网瘾跳时段 advance_time(true) 递归重复触发）
	if GameManager.flags.get("night_chat_day_" + str(day), false):
		return

	var candidates = []
	for cid in GameManager.char_meta.keys():
		var meta = GameManager.char_meta[cid]
		if GameManager.day < meta.get("unlockDay", 1): continue
		var st = RelationshipManager.get_rel_state(cid)
		if st == "cold": continue                                   # 冷战态排除
		if st != "friend" and st != "close" and st != "crush": continue
		var state = char_initiative.get(cid, {})
		if state.get("wechat_msg", "") != "": continue              # 已有未读主动消息，防覆盖
		if GameManager.day - GameManager.flags.get("night_chat_last_" + cid, -999) < 3: continue
		if not NIGHT_CHAT_OPENERS.has(cid): continue
		candidates.append(cid)

	# 无论是否有候选，今晚都算已处理
	GameManager.set_flag("night_chat_day_" + str(day), true)
	if candidates.is_empty():
		return

	# 遴选：好感降序 → 关系阶梯降序 → char_id 字典序升序（确定性，便于复现测试）
	candidates.sort_custom(_night_candidate_sorter)

	var best_cid: String = candidates[0]
	var opener = NIGHT_CHAT_OPENERS[best_cid]
	char_initiative[best_cid]["wechat_msg"] = opener
	char_initiative[best_cid]["wechat_day"] = day
	GameManager.set_flag("night_chat_pending_" + best_cid, true)
	GameManager.set_flag("night_chat_last_" + best_cid, day)

	var char_name = GameManager.char_meta[best_cid].get("name", best_cid)
	GameManager.show_toast.emit("🌙 %s 深夜给你发来了消息…" % char_name)
	GameManager.initiative_updated.emit()

## 深夜候选排序：好感降序 → 关系阶梯降序 → char_id 升序（全序，结果确定可复现）
func _night_candidate_sorter(a: String, b: String) -> bool:
	var fa = GameManager.favorability.get(a, 0)
	var fb = GameManager.favorability.get(b, 0)
	if fa != fb: return fa > fb
	var ra = NIGHT_REL_ORDER.get(RelationshipManager.get_rel_state(a), 0)
	var rb = NIGHT_REL_ORDER.get(RelationshipManager.get_rel_state(b), 0)
	if ra != rb: return ra > rb
	return a < b

func _init_char_initiative():
	for char_id in GameManager.char_meta.keys():
		if not char_initiative.has(char_id):
			char_initiative[char_id] = {
				"cooldown": 0,
				"pending_invite": "",
				"invite_slot": -1,
				"invite_day": 0,
				"wechat_msg": "",
				"wechat_day": 0,
			}

func reset_char_initiative():
	char_initiative.clear()
	_init_char_initiative()

func _check_char_initiative():
	# _init_char_initiative 只在首次/存档加载时调用，此处仅确保新角色有状态项
	for char_id in GameManager.char_meta.keys():
		if not char_initiative.has(char_id):
			char_initiative[char_id] = {
				"cooldown": 0,
				"pending_invite": "",
				"invite_slot": -1,
				"invite_day": 0,
				"wechat_msg": "",
				"wechat_day": 0,
			}
	for char_id in CHAR_INITIATIVE_CONFIG.keys():
		var meta = GameManager.char_meta.get(char_id, {})
		if GameManager.day < meta.get("unlockDay", 1): continue
		var aff = GameManager.favorability.get(char_id, 0)
		if aff < 30: continue

		var state = char_initiative[char_id]

		# 失效处理：邀请超过 INVITE_EXPIRE_SLOTS 个时段撤销
		if state["pending_invite"] != "":
			var elapsed = (GameManager.day - state["invite_day"]) * 4 + (GameManager.slot_index - state["invite_slot"])
			if elapsed >= INVITE_EXPIRE_SLOTS:
				state["pending_invite"] = ""
				state["invite_slot"] = -1
				state["invite_day"] = 0

		# 失效处理：微信消息超过2天消失
		if state["wechat_msg"] != "" and GameManager.day - state["wechat_day"] >= 2:
			state["wechat_msg"] = ""
			state["wechat_day"] = 0

		# 冷却倒计
		if state["cooldown"] > 0:
			state["cooldown"] -= 1
			continue

		if state["pending_invite"] != "" or state["wechat_msg"] != "":
			continue

		# 根据好感度决定触发概率和冷却
		var trigger_chance: float
		var cooldown_days: int
		if aff >= 85:
			trigger_chance = 0.60; cooldown_days = 2
		elif aff >= 70:
			trigger_chance = 0.40; cooldown_days = 5
		elif aff >= 50:
			trigger_chance = 0.30; cooldown_days = 5
		else:
			trigger_chance = 0.20; cooldown_days = 3

		if randf() > trigger_chance:
			state["cooldown"] = cooldown_days
			continue

		var config = CHAR_INITIATIVE_CONFIG[char_id]
		var do_wechat = randf() < 0.5 or aff < 50

		if do_wechat:
			var msg = _pick_wechat_msg(config["wechat_msgs"], aff)
			if msg != "":
				state["wechat_msg"] = msg
				state["wechat_day"] = GameManager.day
				var char_name  = meta.get("name", char_id)
				var char_emoji = meta.get("emoji", "💬")
				GameManager.show_toast.emit("%s %s 给你发来了消息！" % [char_emoji, char_name])
		else:
			var loc = _pick_invite_loc(config["invite_locs"], aff)
			if loc != "":
				state["pending_invite"] = loc
				state["invite_slot"]    = GameManager.slot_index
				state["invite_day"]     = GameManager.day
				var invite_text = _pick_invite_text(config.get("invite_texts", {}), aff)
				var char_name = meta.get("name", char_id)
				GameManager.show_toast.emit("💌 %s" % (invite_text if invite_text != "" else "%s 想见你！" % char_name))

		state["cooldown"] = cooldown_days
		GameManager.initiative_updated.emit()

## 白色情人节（day 330）：好感≥60的角色强制推送今日邀请
func _push_valentines_invites():
	var female_chars = ["yutong", "jingjing", "wanqing", "xiaoxia"]
	var male_chars   = ["yifei", "zicheng"]
	var targets = female_chars if GameManager.gender == "male" else male_chars
	var pushed = 0
	for char_id in targets:
		if GameManager.favorability.get(char_id, 0) >= 60 and pushed < 2:
			var meta = GameManager.char_meta.get(char_id, {})
			var state = char_initiative.get(char_id, {})
			if state.get("pending_invite", "") == "":
				state["pending_invite"] = "community" if char_id in ["jingjing", "jingjing_m"] else "lakeside"
				state["invite_slot"]    = GameManager.slot_index
				state["invite_day"]     = GameManager.day
				state["cooldown"]       = 0
				char_initiative[char_id] = state
				var char_name = meta.get("name", char_id)
				var char_emoji = meta.get("emoji", "💌")
				GameManager.show_toast.emit("%s %s：今天是白色情人节，我……想见见你。" % [char_emoji, char_name])
				pushed += 1
	if pushed > 0:
		GameManager.initiative_updated.emit()

func _pick_wechat_msg(msgs_by_aff: Dictionary, aff: int) -> String:
	var best = -1
	for t in msgs_by_aff.keys():
		if aff >= int(t) and int(t) > best: best = int(t)
	if best < 0: return ""
	var pool: Array = msgs_by_aff[best]
	return pool[randi() % pool.size()] if not pool.is_empty() else ""

func _pick_invite_loc(locs_by_aff: Dictionary, aff: int) -> String:
	var best = -1
	for t in locs_by_aff.keys():
		if aff >= int(t) and int(t) > best: best = int(t)
	if best < 0: return ""
	var pool: Array = locs_by_aff[best]
	return pool[randi() % pool.size()] if not pool.is_empty() else ""

func _pick_invite_text(texts_by_aff: Dictionary, aff: int) -> String:
	var best = -1
	for t in texts_by_aff.keys():
		if aff >= int(t) and int(t) > best: best = int(t)
	if best < 0: return ""
	return texts_by_aff.get(best, "")

func get_pending_invites() -> Array:
	_init_char_initiative()
	var result = []
	for char_id in char_initiative.keys():
		var state = char_initiative[char_id]
		if state["pending_invite"] == "": continue
		var meta     = GameManager.char_meta.get(char_id, {})
		var loc_id   = state["pending_invite"]
		var loc_data = GameManager.locations.get(loc_id, {})
		var config   = CHAR_INITIATIVE_CONFIG.get(char_id, {})
		var aff      = GameManager.favorability.get(char_id, 0)
		result.append({
			"char_id":    char_id,
			"char_name":  meta.get("name", char_id),
			"char_emoji": meta.get("emoji", "💌"),
			"char_color": meta.get("color", "#ffffff"),
			"loc_id":     loc_id,
			"loc_name":   loc_data.get("name", loc_id),
			"invite_text": _pick_invite_text(config.get("invite_texts", {}), aff)
		})
	return result

func get_pending_wechat_msgs() -> Array:
	_init_char_initiative()
	var result = []
	for char_id in char_initiative.keys():
		var state = char_initiative[char_id]
		if state["wechat_msg"] == "": continue
		var meta = GameManager.char_meta.get(char_id, {})
		result.append({
			"char_id":    char_id,
			"char_name":  meta.get("name", char_id),
			"char_emoji": meta.get("emoji", "💬"),
			"char_color": meta.get("color", "#ffffff"),
			"message":    state["wechat_msg"]
		})
	return result

func accept_invite(char_id: String) -> String:
	_init_char_initiative()
	if not char_initiative.has(char_id): return ""
	var state  = char_initiative[char_id]
	var loc_id = state["pending_invite"]
	state["pending_invite"] = ""
	state["invite_slot"]    = -1
	state["invite_day"]     = 0
	GameManager.add_favor(char_id, 3)

	# ── 赛季检测 ──
	SeasonManager.add_progress("accept_invite", 1)

	var char_name = GameManager.char_meta.get(char_id, {}).get("name", char_id)
	GameManager.add_log("💌 接受了 %s 的邀请，前往 %s" % [char_name, GameManager.locations.get(loc_id, {}).get("name", loc_id)])
	GameManager.initiative_updated.emit()
	return loc_id

func decline_invite(char_id: String):
	_init_char_initiative()
	if not char_initiative.has(char_id): return
	var state = char_initiative[char_id]
	state["pending_invite"] = ""
	state["invite_slot"]    = -1
	state["invite_day"]     = 0
	GameManager.add_favor(char_id, -1)
	var char_name = GameManager.char_meta.get(char_id, {}).get("name", char_id)
	GameManager.add_log("🙅 婉拒了 %s 的邀请..." % char_name)
	GameManager.initiative_updated.emit()

func consume_wechat_msg(char_id: String):
	_init_char_initiative()
	if char_initiative.has(char_id):
		char_initiative[char_id]["wechat_msg"] = ""
		char_initiative[char_id]["wechat_day"] = 0
	GameManager.initiative_updated.emit()

func get_chars_at_location(loc_id: String) -> Array:
	_init_char_initiative()
	var result = []
	for char_id in char_initiative.keys():
		var state = char_initiative[char_id]
		if state["pending_invite"] == loc_id:
			var meta = GameManager.char_meta.get(char_id, {})
			result.append({
				"char_id":    char_id,
				"char_name":  meta.get("name", char_id),
				"char_emoji": meta.get("emoji", "💌"),
				"char_color": meta.get("color", "#ffffff"),
			})
	return result

func get_initiative_save_data() -> Dictionary:
	return char_initiative.duplicate(true)

func load_initiative_save_data(data: Dictionary):
	char_initiative = data
