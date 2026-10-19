extends Node

# ═══════════════════════════════════════════════════════════════
# ── NGPlusManager ─────────────────────────────────────────────
# NG+（跨周目）熟悉感台词系统
# 实现从 GameManager 抽出（门面委托，对外 API 不变）
# 状态留守 GameManager：flags / favorability
# ═══════════════════════════════════════════════════════════════

## 当 ng_count >= 1 时，与角色初次互动触发熟悉感独白（每角色仅一次）。
## 调用方：HotspotExploreUI 或 DialogueUI 在进入地点/触发事件时调用。
## 返回空字符串则无需展示。
func get_ng_familiarity_line(char_id: String) -> String:
	# 非 NG+ 周目不触发
	var ng = GameManager.flags.get("ng_count", 0)
	if ng is int and ng < 1: return ""
	if ng is String and int(ng) < 1: return ""

	# 已触发过则跳过（每角色限一次）
	var shown_key = "ng_familiar_shown_" + char_id
	if GameManager.flags.has(shown_key): return ""

	# 只有继承好感度高于角色默认初始值时才触发（说明上周目有过交情）
	var default_base = {"jingjing": 20, "jingjing_m": 20}
	var base = default_base.get(char_id, 0)
	if GameManager.favorability.get(char_id, 0) <= base: return ""

	# 标记已触发
	GameManager.flags[shown_key] = true

	# 各角色独白台词池
	var lines = {
		"yutong":    ["雨桐看了你一眼，微微歪了歪头：「……我们好像在哪里见过？」",
					  "雨桐说话时停顿了一下，像是想起什么又摇了摇头：「没什么，只是觉得你很眼熟。」"],
		"jingjing":  ["菁菁若有所思地盯着你：「你为什么让我觉得……好像认识你很久了一样？」",
					  "菁菁突然噘嘴：「你干嘛那么自然地和我说话！我们……才认识多久啊。」"],
		"wanqing":   ["晚晴翻着书，忽然抬眼：「有时候，我觉得和你的相遇……像书里写过的故事。」",
					  "晚晴盯着你看了好一会儿：「奇怪，你的眼神让我觉得……你一定见过很多有趣的事。」"],
		"xiaoxia":   ["小夏跑过来挡住你的路：「喂，你……感觉和我认识很久一样，怪奇怪的。」",
					  "小夏歪着头：「你知道吗，我第一次看到你就觉得——嗯，就是莫名其妙不想跑开。」"],
		"yifei":     ["逸飞侧过脸：「……我有一种奇怪的感觉，好像这首曲子，本来就该让你听见。」",
					  "逸飞放下弓，轻声说：「你是第一个让我觉得，不需要解释的听众。」"],
		"zicheng":   ["子诚拍了你肩膀一下：「说不上来，就是觉得和你很对脾气，像老朋友一样。」",
					  "子诚有点不好意思地挠头：「你……别觉得我奇怪，我就是觉得你不像个陌生人。」"],
		"jingjing_m":["叶明轩微微愣了一下，然后笑了：「你知道吗，我有一种预感，我们会成为朋友的。」"],
	}
	var pool: Array = lines.get(char_id, [])
	if pool.is_empty(): return ""
	return pool[randi() % pool.size()]
