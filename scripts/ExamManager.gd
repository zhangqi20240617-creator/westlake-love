extends Node
## ═══════════════════════════════════════════════════════════════
## ExamManager — 中考与志愿系统（自 GameManager 拆出）
## ═══════════════════════════════════════════════════════════════
## 职责：
##   - 分科复习加分（带衰减防刷满）与薄弱科目推荐
##   - 中考成绩结算（智力40% + 分科60% + 临场波动 + 网瘾惩罚）
##   - 志愿填报与录取判定（含滑档逻辑）
##
## 共享状态归属说明（重要）：
##   subject_scores / SUBJECT_META / target_high_school / latest_exam_result
##   仍保留在 GameManager 上——因为 SaveSystem / EndingScreen / MainGame /
##   ScoreRevealUI / StudySubjectPopup / CharacterStatsPopup 等外部脚本
##   直接读写这些字段。本管理器统一经 GameManager.xxx 访问。
##
## 外部脚本无需感知本管理器：GameManager 保留同名门面方法委托到这里。

# ── 高中志愿数据库（仅本系统使用，随逻辑一起迁入）───────────────
const HIGH_SCHOOLS = [
	{"id": "hz2", "name": "杭二中", "req_score": 580, "type": "前三所"},
	{"id": "xuejun", "name": "学军中学", "req_score": 575, "type": "前三所"},
	{"id": "hanggao", "name": "杭高", "req_score": 560, "type": "前三所"},
	{"id": "hz14", "name": "十四中", "req_score": 540, "type": "前八所"},
	{"id": "zheda", "name": "浙大附中", "req_score": 530, "type": "前八所"},
	{"id": "normal", "name": "普通优高", "req_score": 480, "type": "优高"},
	{"id": "vocational", "name": "职业高/技校", "req_score": 0, "type": "保底"}
]

# ── 分科复习 ────────────────────────────────────────────────────

## 带衰减的分科加分（越熟练收益越低，防止无脑刷满）
func add_subject_score(subject: String, amount: int):
	if not GameManager.subject_scores.has(subject): return
	var cur = GameManager.subject_scores[subject]
	var mult = 1.0
	if cur >= 80: mult = 0.3
	elif cur >= 60: mult = 0.6
	elif cur >= 40: mult = 0.8
	var gained = max(1, int(amount * mult))
	GameManager.subject_scores[subject] = clampi(cur + gained, 0, 100)
	var m = GameManager.SUBJECT_META.get(subject, {})
	GameManager.show_toast.emit("%s %s +%d分" % [m.get("emoji", "📚"), m.get("label", subject), gained])
	GameManager.state_updated.emit()

## 返回当前最薄弱科目（供UI展示推荐复习提示）
func get_weakest_subject() -> Dictionary:
	var wid = "math"; var wval = 101
	for s in GameManager.subject_scores.keys():
		if GameManager.subject_scores[s] < wval:
			wval = GameManager.subject_scores[s]; wid = s
	return {"id": wid, "score": wval, "meta": GameManager.SUBJECT_META.get(wid, {})}

# ── 中考成绩结算 ────────────────────────────────────────────────

func calculate_exam_score(is_mock: bool = false) -> Dictionary:
	var intellect = GameManager.stats.get("intellect", 0)
	var art = GameManager.stats.get("art", 0)
	var social = GameManager.stats.get("social", 0)
	var strength = GameManager.stats.get("strength", 0)
	var stress_val = GameManager.stats.get("stress", 0)
	var addict_val = GameManager.stats.get("addict", 0)

	# 分科复习分数（占总成绩 60%，智力属性占 40%）
	var sub_c = GameManager.subject_scores.get("chinese", 0)
	var sub_m = GameManager.subject_scores.get("math", 0)
	var sub_e = GameManager.subject_scores.get("english", 0)
	var sub_sc = GameManager.subject_scores.get("science", 0)
	var sub_so = GameManager.subject_scores.get("society", 0)

	# 基础折算： intellect 提供上限，分科复习补充利用率
	var chinese = 60 + (intellect * 0.25) + (art * 0.1)     + (sub_c  * 0.45)
	var math    = 40 + (intellect * 0.40)                    + (sub_m  * 0.50)
	var english = 50 + (intellect * 0.25) + (social * 0.1)  + (sub_e  * 0.40)
	var science = 60 + (intellect * 0.55)                    + (sub_sc * 0.55)
	var society = 40 + (intellect * 0.20) + (social * 0.1)  + (sub_so * 0.40)
	var pe = min((strength / 100.0) * 30.0, 30.0)

	# 临场发挥波动系数
	var multiplier = 1.0
	var events_log = []

	if stress_val > 80:
		multiplier = randf_range(0.85, 0.95)
		events_log.append("压力过大，在考场上出现了大脑空白的情况。")
	elif stress_val < 30:
		multiplier = randf_range(0.98, 1.05)
		events_log.append("心态轻松，考场上文思泉涌，超常发挥！")
	else:
		multiplier = randf_range(0.95, 1.02)

	# 中考答题加成（大决战时的5道题，每题加5分，转换为 2% 的最终分数波动）
	var final_bonus_mult = 1.0 + (GameManager.quiz_bonus_score / 250.0) # 满分25分的话，加成 10%。
	multiplier *= final_bonus_mult
	if GameManager.quiz_bonus_score > 0:
		events_log.append("考场上得心应手，完美发挥了此前的复习成果！")

	chinese *= multiplier
	math *= multiplier
	english *= multiplier
	science *= multiplier
	society *= multiplier

	# 网瘾惩罚：随机单科大跌
	if addict_val > 60:
		var penalty = randf_range(10, 25)
		match randi() % 5:
			0: chinese -= penalty; events_log.append("语文考试时满脑子都是游戏画面，作文没写完。")
			1: math -= penalty; events_log.append("数学最后的大题算了一半，满脑子都是连招。")
			2: english -= penalty; events_log.append("英语听力时走神，错过了好几道题。")
			3: science -= penalty; events_log.append("科学物理题计算失误，满脑子都是副本。")
			4: society -= penalty; events_log.append("社会历史年份全记混了。")

	# 保证不超过满分
	chinese = clamp(int(chinese), 0, 120)
	math = clamp(int(math), 0, 120)
	english = clamp(int(english), 0, 120)
	science = clamp(int(science), 0, 160)
	society = clamp(int(society), 0, 100)
	pe = clamp(int(pe), 0, 30)

	var total = chinese + math + english + science + society + pe

	GameManager.latest_exam_result = {
		"chinese": chinese,
		"math": math,
		"english": english,
		"science": science,
		"society": society,
		"pe": pe,
		"total": total,
		"events": events_log,
		"is_mock": is_mock
	}
	return GameManager.latest_exam_result

# ── 志愿填报与录取判定 ──────────────────────────────────────────

func set_target_high_school(school_id: String):
	GameManager.target_high_school = school_id

func get_admission_result() -> Dictionary:
	# ── 奥林匹克竞赛金牌直升保送特权 (D线 DS-RN) ────────
	if GameManager.flags.has("flag_olympiad_gold"):
		return {
			"success": true,
			"school": {"id": "hz2", "name": "西湖二中", "req_score": 580, "desc": "省顶尖名校"},
			"reason": "🎉 【提前批直升】\n凭借在省奥赛中的绝杀金牌，你获得了保送录取最高学府的特权！中考裸分自动作废。"
		}

	# 根据志愿和最新成绩，判断是否录取
	if GameManager.target_high_school == "":
		return {"success": false, "school": null, "reason": "未填报志愿"}

	var school = null
	for s in HIGH_SCHOOLS:
		if s.id == GameManager.target_high_school:
			school = s
			break

	if school == null:
		return {"success": false, "school": null, "reason": "志愿异常"}

	var total = GameManager.latest_exam_result.get("total", 0)
	if total >= school.req_score:
		return {"success": true, "school": school, "reason": "已被 %s 录取！" % school.name}
	else:
		# 滑档，寻找下一个能录取的
		var fallback = null
		for s in HIGH_SCHOOLS:
			if total >= s.req_score:
				fallback = s
				break
		return {"success": false, "school": fallback, "reason": "滑档至 %s" % (fallback.name if fallback else "职业技校")}

# ── 时间即代价：预估分 / 中考倒计时 / 机会成本 ─────────────────────
## 中考日（第 570 天毕业典礼当天为结算日）
const EXAM_DAY := 570
## 机会成本提示的起始日：初三开学（day 361）起，时间才开始"计价"
const PRESSURE_START_DAY := 361

## 确定性预估分：无临场随机、无网瘾随机惩罚，且不写入 latest_exam_result。
## 供 HUD / 机会成本提示实时读取，反映"当前实力"折算的中考总分。
func project_exam_score() -> int:
	var intellect = GameManager.stats.get("intellect", 0)
	var art = GameManager.stats.get("art", 0)
	var social = GameManager.stats.get("social", 0)
	var strength = GameManager.stats.get("strength", 0)
	var stress_val = GameManager.stats.get("stress", 0)

	var sub_c = GameManager.subject_scores.get("chinese", 0)
	var sub_m = GameManager.subject_scores.get("math", 0)
	var sub_e = GameManager.subject_scores.get("english", 0)
	var sub_sc = GameManager.subject_scores.get("science", 0)
	var sub_so = GameManager.subject_scores.get("society", 0)

	# 与 calculate_exam_score 相同的基础折算，但省去随机波动与网瘾惩罚
	var chinese = 60 + (intellect * 0.25) + (art * 0.1)    + (sub_c  * 0.45)
	var math    = 40 + (intellect * 0.40)                   + (sub_m  * 0.50)
	var english = 50 + (intellect * 0.25) + (social * 0.1) + (sub_e  * 0.40)
	var science = 60 + (intellect * 0.55)                   + (sub_sc * 0.55)
	var society = 40 + (intellect * 0.20) + (social * 0.1) + (sub_so * 0.40)
	var pe = min((strength / 100.0) * 30.0, 30.0)

	chinese = clamp(int(chinese), 0, 120)
	math    = clamp(int(math), 0, 120)
	english = clamp(int(english), 0, 120)
	science = clamp(int(science), 0, 160)
	society = clamp(int(society), 0, 100)
	pe      = clamp(int(pe), 0, 30)

	# 确定性 stress 乘数：让 HUD 实时预估分随压力波动。
	# 用区间中值（非随机），保证显示稳定不跳动；
	# 与 calculate_exam_score 的 stress 分支对齐：>80 折损 / <30 微增 / 其余略降。
	var stress_mult = 1.0
	if stress_val > 80:
		stress_mult = 0.90
	elif stress_val < 30:
		stress_mult = 1.015
	else:
		stress_mult = 0.985

	return int((chinese + math + english + science + society + pe) * stress_mult)

func project_exam_interval() -> String:
	var base = project_exam_score()
	var min_s = int(base * 0.95)
	var max_s = int(base * 1.05)
	return "%d ~ %d" % [min_s, max_s]

## 返回距目标高中的差距信息：{projected, school, gap, days_left, projected_range}
## 未填志愿时以"普通优高"(能上高中的底线) 作默认目标。
func get_target_gap() -> Dictionary:
	var projected = project_exam_score()
	var projected_range = "%d~%d" % [int(projected * 0.95), int(projected * 1.05)]
	var school = null
	var tid = GameManager.target_high_school
	if tid != "":
		for s in HIGH_SCHOOLS:
			if s.id == tid:
				school = s
				break
	if school == null:
		for s in HIGH_SCHOOLS:
			if s.id == "normal":
				school = s
				break
	var req = int(school.get("req_score", 0)) if school else 0
	return {
		"projected": projected,
		"projected_range": projected_range,
		"school": school,
		"gap": req - projected,
		"days_left": max(0, EXAM_DAY - GameManager.day)
	}

## 机会成本提示：初三期间，一个非学习时段流逝时提醒玩家"时间即代价"。
## 由 GameManager.advance_time 每天节流调用一次。
func emit_opportunity_cost_hint():
	var info = get_target_gap()
	var sname = info.school.get("name", "高中") if info.school else "高中"
	var gap = int(info.gap)
	var days = int(info.days_left)
	if gap > 0:
		GameManager.show_toast.emit("⏳ 又一个时段没复习——预估中考 %d 分，离%s还差 %d 分（剩 %d 天）" % [int(info.projected), sname, gap, days])
	else:
		GameManager.show_toast.emit("⏳ 预估已过%s线（%d 分），但别松懈，还剩 %d 天" % [sname, int(info.projected), days])
