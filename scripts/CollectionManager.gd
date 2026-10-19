extends Node
# ═══════════════════════════════════════════════════════════════
# CollectionManager —— 收集系统（物品 + 画廊）
# 实现从 GameManager 拆出。共享常量/状态仍留守 GameManager：
#   ITEM_DB / inventory / GALLERY_ITEMS（外部脚本直接读写）。
# 本类内部统一经 GameManager.xxx 访问；
# FAVOR_GALLERY_UNLOCKS 无外部直接访问，随逻辑整体迁入本类。
# ═══════════════════════════════════════════════════════════════

# ── 物品系统 ────────────────────────────────────────────────
func add_item(item_id: String, amount: int = 1):
	if not GameManager.ITEM_DB.has(item_id): return
	if not GameManager.inventory.has(item_id):
		GameManager.inventory[item_id] = amount
	else:
		GameManager.inventory[item_id] += amount
	GameManager.show_toast.emit("获得物品: %s x%d" % [GameManager.ITEM_DB[item_id].name, amount])
	# 风物志 · 购得路径唯一钩子（DS-RN-04）：category=="fengwu" 的物品自动入册。
	# 放在这里 → ShopUI 购买 / 事件 addItem / 任何 add_item 调用方全部零改动覆盖。
	_try_grant_fengwu_item(item_id)

func remove_item(item_id: String, amount: int = 1):
	if GameManager.inventory.has(item_id):
		GameManager.inventory[item_id] -= amount
		if GameManager.inventory[item_id] <= 0:
			GameManager.inventory.erase(item_id)
		GameManager.show_toast.emit("失去物品: %s x%d" % [GameManager.ITEM_DB[item_id].name, amount])

func has_item(item_id: String, amount: int = 1) -> bool:
	return GameManager.inventory.has(item_id) and GameManager.inventory[item_id] >= amount

# ── 画廊系统 ────────────────────────────────────────────────
func unlock_gallery(flag_name: String):
	if flag_name != "" and not GameManager.flags.has(flag_name):
		GameManager.flags[flag_name] = true

func is_gallery_unlocked(item: Dictionary) -> bool:
	var f = item.get("flag", "")
	if f == "": return true  # 初始解锁
	return GameManager.flags.has(f)

func get_gallery_progress() -> Dictionary:
	var total = GameManager.GALLERY_ITEMS.size()
	var unlocked = 0
	for item in GameManager.GALLERY_ITEMS:
		if is_gallery_unlocked(item): unlocked += 1
	return { "unlocked": unlocked, "total": total }

# ── 好感度阈值自动解锁画廊条目 ──────────────────────────────
# 格式：{ char_id: [ {threshold, flag, label} ] }
const FAVOR_GALLERY_UNLOCKS = {
	"yutong": [
		{ "threshold": 50, "flag": "seen_yutong_anim",   "label": "陈雨桐·动态立绘" },
	],
	"jingjing": [
		{ "threshold": 40, "flag": "seen_jingjing_casual", "label": "叶菁菁·便服" },
	],
	"xiaoxia": [
		{ "threshold": 30, "flag": "seen_xiaoxia_sport",  "label": "林小夏·运动装" },
		{ "threshold": 60, "flag": "seen_xiaoxia_casual", "label": "林小夏·便服" },
	],
	"wanqing": [
		{ "threshold": 30, "flag": "seen_wanqing_serious", "label": "苏晚晴·认真" },
		{ "threshold": 60, "flag": "seen_wanqing_casual",  "label": "苏晚晴·便服" },
	],
	"yifei": [
		{ "threshold": 30, "flag": "seen_yifei_shy",       "label": "沈逸飞·羞涩" },
		{ "threshold": 60, "flag": "seen_yifei_serious",   "label": "沈逸飞·认真" },
	],
	"zicheng": [
		{ "threshold": 30, "flag": "seen_zicheng_shy",     "label": "周子诚·羞涩" },
		{ "threshold": 60, "flag": "seen_zicheng_serious", "label": "周子诚·认真" },
	],
}

func _check_favor_gallery_unlocks(char_id: String, prev: int, current: int):
	if not FAVOR_GALLERY_UNLOCKS.has(char_id): return
	for entry in FAVOR_GALLERY_UNLOCKS[char_id]:
		var threshold = entry["threshold"]
		var flag      = entry["flag"]
		# 只在从阈值以下跨越到阈值以上时触发一次
		if prev < threshold and current >= threshold:
			if not GameManager.flags.has(flag):
				unlock_gallery(flag)
				GameManager.show_toast.emit("🖼️ 画廊解锁：%s！" % entry["label"])

# 游戏启动 / 读档时补偿扫描：修复已达阈值但未解锁画廊 flag 的存量状态
func _retroactive_gallery_check():
	for char_id in GameManager.favorability.keys():
		var cur = GameManager.favorability[char_id]
		_check_favor_gallery_unlocks(char_id, 0, cur)
	# 集章系统共用同一补偿时机（浪漫事件路径写入 stamp_* 后补 day + 集满判定）
	_retroactive_stamp_check()
	# 风物志同构（DS-RN-04）：购得旁路补录 + 补 day + 集满判定
	_retroactive_fengwu_check()

# ═══════════════════════════════════════════════════════════════
# ── 西湖十景集章（DS-RN-03）─────────────────────────────────
# 设计依据：design/west_lake_stamps_gdd.md
# 零新 Autoload / 零存档迁移：所有状态落 GameManager.flags
#   stamp_<sid>            bool  该景已得
#   stamp_<sid>_day        int   获得日（GameManager.day）
#   stamp_checkin_day      int   最近一次「主动打卡」的天数（每日 1 章限速）
#   west_lake_stamps_complete  bool  集满 10 章 → 画廊 CG
#   title_西湖十景通        bool  称号（title_ 前缀 → EndingScreen 自动消费）
# ═══════════════════════════════════════════════════════════════

# ── 十景注册表：全工程唯一数据真源（GDD §6.1 / §7）───────────
# 字段：
#   name         String        景名（中文 4 字）
#   emoji        String        单 emoji，集章簿格子主视觉
#   season       String        推荐季节 "spring"/"summer"/"autumn"/"winter"/""（无季节）
#                              ⚠️ 仅作展示与弱正反馈，非获取门槛（GDD §2.4 / D-1 已拍板）
#   summary      String        一句话摘要，集章簿详情区首行
#   lines        Array[String] vignette 正文，按序播放
#   season_line  String        当季（双峰插云为晴天）追加的加句
#   romance_ev   String        关联浪漫事件 id；"" 表示无
# ⚠️ 字典保持插入顺序 = 集章簿格子顺序，不要对 keys() 排序。
const WEST_LAKE_STAMP_SCENES = {
	"sudichunxiao": {
		"name": "苏堤春晓", "emoji": "🌸", "season": "spring",
		"romance_ev": "west_lake_spring_jingjing",
		"summary": "桃柳夹堤，花瓣铺水，春天从这条堤上开始。",
		"lines": [
			"苏堤很长，长到你走一半就开始怀疑自己到底想去哪儿。",
			"桃花和柳树一棵隔一棵地种着，粉的白的绿的，被风一吹全落到水面上，浮成一层薄薄的彩色。",
			"你在第三座桥上停下来，看一只野鸭把那层彩色划开一道口子，然后它游走了，口子又慢慢合上。",
		],
		"season_line": "春天的苏堤是有声音的——不是鸟叫，是花瓣落到水上的那种，几乎听不见的声音。",
	},
	"quyuanfenghe": {
		"name": "曲院风荷", "emoji": "🌿", "season": "summer",
		"romance_ev": "west_lake_summer_yutong",
		"summary": "接天莲叶，荷香入院，夏天最凉的一口气。",
		"lines": [
			"还没走到，先闻到荷花味。是那种很淡、带着水汽的甜，不像香水，倒像刚洗过的衣服。",
			"荷叶挤得满满当当，一直铺到看不见岸的地方。有几片翻了个面，露出浅浅的叶背。",
			"你蹲下来，看叶心那颗水珠滚来滚去，就是不掉下去。看了大概有一分钟。",
		],
		"season_line": "夏天最凉快的一口气，是在这里吸到的。",
	},
	"pinghuqiuyue": {
		"name": "平湖秋月", "emoji": "🍂", "season": "autumn",
		"romance_ev": "west_lake_autumn_wanqing",
		"summary": "湖面如镜，桂香十里，月亮是被水捧出来的。",
		"lines": [
			"天刚擦黑，湖面还留着一点白，像有人忘了收起来的一块布。",
			"桂花的味道从背后的树丛里一阵一阵地飘过来，闻久了会有点甜得发晕。",
			"月亮上来的时候你才发现，水里那个比天上那个更清楚一些。",
		],
		"season_line": "秋天的月亮是被水捧上来的——难怪古人非要跑到湖边来看。",
	},
	"duanqiaocanxue": {
		"name": "断桥残雪", "emoji": "❄️", "season": "winter",
		"romance_ev": "west_lake_winter_jingjing",
		"summary": "雪半融，桥似断，白堤安静得像一句没说完的话。",
		"lines": [
			"杭州的雪一年下不了几场，下了也留不住，所以桥上的雪总是化一半留一半。",
			"从远处看，化掉的那半和石头一个颜色，桥就像是断在中间——名字就是这么来的。",
			"你踩上去，脚下发出很轻的一声“咯吱”，然后四周就更安静了。",
		],
		"season_line": "冬天的白堤安静得像一句说到一半、就没再说下去的话。",
	},
	"huagangguanyu": {
		"name": "花港观鱼", "emoji": "🐟", "season": "spring", "romance_ev": "",
		"summary": "红鱼成群，牡丹将开，喂鱼的人比鱼还慢一拍。",
		"lines": [
			"池子里的红鱼多到有点吓人，你把手伸到水面上方，它们就“哗”地全挤过来，把水搅成一团红。",
			"旁边一位老爷爷在撕面包，撕得非常慢，一小块一小块。鱼急得直跳，他也不急。",
			"你忽然觉得，能在这儿把一片面包撕上半小时，大概也算是一种本事。",
		],
		"season_line": "春天的花港，牡丹还没全开，鱼倒是先热闹起来了。",
	},
	"liulangwenying": {
		"name": "柳浪闻莺", "emoji": "🐦", "season": "spring", "romance_ev": "",
		"summary": "柳条垂到肩上，黄莺在头顶换了三个调子。",
		"lines": [
			"这一段的柳树种得特别密，柳条一直垂到人肩膀那么低，走过去得用手拨。",
			"黄莺就在头顶上叫，叫一声换一个调，你抬头找了半天，一只都没看见。",
			"拨开柳条继续往前走，鸟叫声就跟着你，像有谁在树上一路送你到路口。",
		],
		"season_line": "春天的柳浪最经不起风，风一来，整条路都在晃。",
	},
	"leifengxizhao": {
		"name": "雷峰夕照", "emoji": "🌇", "season": "summer", "romance_ev": "",
		"summary": "塔影被夕阳拉长，整座湖被染成橘子汽水的颜色。",
		"lines": [
			"太阳快落到山后面的时候，雷峰塔的影子被拉得老长，一直伸到湖里去。",
			"整片水面变成橘子汽水那个颜色，连远处的游船都镀了一层金边。",
			"湖边站了一排人在拍照，没人说话。你也站着，直到最后那一点橘色沉下去。",
		],
		"season_line": "夏天日落得晚，这一幕能撑到快七点，够你把作业忘个干净。",
	},
	"santanyinyue": {
		"name": "三潭印月", "emoji": "🌕", "season": "autumn", "romance_ev": "",
		"summary": "三座石塔点起烛火，水里多了好几个月亮。",
		"lines": [
			"那三座石塔比想象中小，圆圆的，像三个被人插在水里的石头葫芦。",
			"每座塔身上有五个圆洞，晚上点上蜡烛，加上天上那个真的，据说能数出三十三个月亮。",
			"你认真数了数，只数出七个，剩下的大概得靠想象力补。",
		],
		"season_line": "秋天的湖面最平，塔影一动不动，像是被谁按在水里。",
	},
	"nanpingwanzhong": {
		"name": "南屏晚钟", "emoji": "🔔", "season": "winter", "romance_ev": "",
		"summary": "净慈寺的钟声撞过湖面，把一天的杂音全压下去。",
		"lines": [
			"净慈寺的钟声响起来的时候，你正好走到湖边。",
			"那声音很低，先是“咚”的一下，然后余音贴着水面一路铺过去，铺了好久才散。",
			"钟声没了之后，你才发现刚才那一会儿，脑子里什么都没在想。",
		],
		"season_line": "冬天空气冷而干，钟声传得比平时还要远。",
	},
	"shuangfengchayun": {
		"name": "双峰插云", "emoji": "⛰️", "season": "", "romance_ev": "",
		"summary": "南北高峰探进云里，晴天才看得见两个尖。",
		"lines": [
			"南高峰和北高峰隔着一大片湖水遥遥相对，山尖常年埋在云里，看不见顶。",
			"你眯着眼睛找了半天，云动了一下，露出一个尖，隔了几秒又被盖回去。",
			"有人说要等一个特别晴的日子才能同时看见两个尖。你想，那就下次吧——反正你还有很多个下次。",
		],
		"season_line": "今天天特别透，两个尖都露出来了——这种日子一年也没几天。",
	},
}

const STAMP_TOTAL := 10
const STAMP_TITLE_FLAG := "title_西湖十景通"
const STAMP_COMPLETE_FLAG := "west_lake_stamps_complete"

# ── 查询 API（只读，供 StampBookUI / 打卡面板消费）─────────────
func is_stamp_owned(sid: String) -> bool:
	return GameManager.flags.has("stamp_" + sid)

## 返回获得日；未获得或缺失（补偿扫描前的极端时序）时返回 -1
func get_stamp_day(sid: String) -> int:
	var v = GameManager.flags.get("stamp_" + sid + "_day", -1)
	return int(v) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else -1

func get_stamp_progress() -> Dictionary:
	var unlocked = 0
	for sid in WEST_LAKE_STAMP_SCENES.keys():
		if is_stamp_owned(sid): unlocked += 1
	return { "unlocked": unlocked, "total": STAMP_TOTAL }

## 今天是否已主动打卡过（每日 1 章限速，GDD §2.5 L3）
func is_stamp_checkin_used_today() -> bool:
	return int(GameManager.flags.get("stamp_checkin_day", -1)) == GameManager.day

## 该景当前是否处于"当季/晴天"正反馈状态（⭐ 徽标 + season_line + stress -2）
func is_stamp_bonus_active(sid: String) -> bool:
	var data: Dictionary = WEST_LAKE_STAMP_SCENES.get(sid, {})
	if data.is_empty(): return false
	var season: String = data.get("season", "")
	if season == "":
		# 双峰插云（无季节）：改用天气正反馈
		return GameManager.current_weather == "sunny"
	return WeatherManager.get_season() == season

## 获得日的可读文案："第 32 天 · 初一上学期"；缺失时返回 "第 ? 天"
## 学期换算复用 GameManager.get_grade_info() 的既有 90 天分段（真源对齐）
func format_stamp_day(d: int) -> String:
	if d < 0: return "第 ? 天"
	var grade := "初三"
	var sem := "下学期"
	if d <= 90:     grade = "初一"; sem = "上学期"
	elif d <= 180:  grade = "初一"; sem = "下学期"
	elif d <= 270:  grade = "初二"; sem = "上学期"
	elif d <= 360:  grade = "初二"; sem = "下学期"
	elif d <= 450:  grade = "初三"; sem = "上学期"
	return "第 %d 天 · %s%s" % [d, grade, sem]

# ── 授予（唯一写入口）─────────────────────────────────────────
## 幂等。from_checkin=true 时额外写 stamp_checkin_day（占用当日打卡额度）；
## 浪漫事件路径（路径 B）不应占用额度，由 _retroactive_stamp_check 以 false 补齐。
func grant_stamp(sid: String, from_checkin: bool = true) -> bool:
	if not WEST_LAKE_STAMP_SCENES.has(sid): return false
	var flag := "stamp_" + sid
	if GameManager.flags.has(flag): return false   # 已得 → 跳过
	GameManager.set_flag(flag, true)
	GameManager.set_flag(flag + "_day", GameManager.day)
	if from_checkin:
		GameManager.set_flag("stamp_checkin_day", GameManager.day)
	# 若本次授予后即集满，只发集满那条（更隆重），跳过普通章 toast（GDD §8⑤）
	if _check_stamp_completion(): return true
	var data: Dictionary = WEST_LAKE_STAMP_SCENES[sid]
	var prog := get_stamp_progress()
	GameManager.show_toast.emit("🏞️ 获得西湖十景章：%s %s（%d/%d）" % [
		data.get("emoji", ""), data.get("name", sid), prog["unlocked"], prog["total"]])
	return true

## 集满判定。返回 true 表示"本次调用刚刚触发集满"
func _check_stamp_completion() -> bool:
	if GameManager.flags.has(STAMP_COMPLETE_FLAG): return false
	for sid in WEST_LAKE_STAMP_SCENES.keys():
		if not is_stamp_owned(sid): return false
	GameManager.set_flag(STAMP_COMPLETE_FLAG, true)
	GameManager.set_flag(STAMP_TITLE_FLAG, true)
	unlock_gallery(STAMP_COMPLETE_FLAG)
	GameManager.show_toast.emit("🏆 西湖十景通！集章大成——称号已入账，画廊解锁「西湖十景·集章大成」")
	return true

## 补偿扫描（幂等）：
##   1. 浪漫事件（路径 B）经 setFlags 写了 stamp_* 但没有 day → 补当前 day
##   2. 存量存档已集满但未置 complete flag → 补触发集满奖励
## 调用点：GameManager._retroactive_gallery_check()（开局 / 读档 / DEBUG 热键）
##         + MainGame._on_event_finished()（浪漫事件刚播完）
func _retroactive_stamp_check():
	for sid in WEST_LAKE_STAMP_SCENES.keys():
		if is_stamp_owned(sid) and get_stamp_day(sid) < 0:
			GameManager.set_flag("stamp_" + sid + "_day", GameManager.day)
	_check_stamp_completion()

# ── vignette 事件合成（GDD §6.3）──────────────────────────────
## 运行时合成，不写入任何 JSON 事件文件（避免污染 DataManager 随机事件池）。
## ⚠️ 本函数不写任何 flag —— flag 授予统一由 grant_stamp() 负责。
func build_stamp_vignette(sid: String) -> Dictionary:
	var data: Dictionary = WEST_LAKE_STAMP_SCENES.get(sid, {})
	if data.is_empty(): return {}
	var bonus := is_stamp_bonus_active(sid)
	var scenes: Array = []
	for line in data.get("lines", []):
		scenes.append({"speaker": null, "text": line})
	var season_line: String = data.get("season_line", "")
	if bonus and season_line != "":
		scenes.append({"speaker": null, "text": season_line})
	var last := {
		"speaker": null,
		"text": "「西湖十景·%s」——集章簿上，又落下一枚印。" % data.get("name", sid),
		"next": 99,
	}
	# 当季/晴天弱正反馈：压力 -2。字段名对齐 DialogueUI._apply_scene_level_effects()
	if bonus:
		last["statDelta"] = {"stress": -2}
	scenes.append(last)
	return {
		"id":        "west_lake_stamp_" + sid,
		"location":  "lakeside",
		"title":     "%s %s" % [data.get("emoji", ""), data.get("name", sid)],
		"isSpecial": false,
		"repeatable": true,
		"scenes":    scenes,
	}

# ═══════════════════════════════════════════════════════════════
# ── 西湖风物志（DS-RN-04）───────────────────────────────────
# 设计依据：design/gameplay_economy_expansion_gdd.md（概念 A · 经营/收集扩展）
# 零新 Autoload / 零新脚本依赖 / 零存档迁移：所有状态落 GameManager.flags
#   fengwu_<fid>               bool  该件风物已入册
#   fengwu_<fid>_day           int   入册日（GameManager.day）
#   fengwu_pickup_day          int   最近一次「拾得」的天数（每日 1 件限速）
#   west_lake_fengwu_complete  bool  集满 24 件 → 画廊 CG
#   title_西湖风物通            bool  称号（title_ 前缀 → EndingScreen 自动消费/继承）
#
# ⚠️ 交付范围（用户决策 D-1 / D-2 / D-3，勿擅自改动）：
#   拾得 12 + 购得 6 + 手作 6 —— **全部 24 件现已可达**。
#   手作 6 件已接入（fw_craft_* 事件 → 场景级 grantFengwu 字段 → grant_fengwu()），
#   见 events_life.json 的 6 条 fw_craft_<suffix> 与 DialogueUI.play_current_scene()
#   的 grantFengwu 分支。称号 title_西湖风物通 与画廊「西湖风物·大成」
#   自本版本起可真实达成（DS-RN-04b 手作渠道补完）。
#
# ⚠️ D-2：手作产物走纯 flag，不进 ITEM_DB（本区 6 条预留槽同样不进 ITEM_DB）。
# ⚠️ D-4：拾得只弹 toast，不播 vignette / 不消耗时段 / 不与记忆回响叠加
#         （互斥由 MainGame._on_location_selected 的调用位置保证）。
# ═══════════════════════════════════════════════════════════════

# ── 风物注册表：全工程唯一数据真源 ────────────────────────────
# 字段：
#   name      String  风物名
#   category  String  "味" / "物" / "草木" / "声景"（图鉴分类徽标）
#   obtain    String  "拾得" / "购得" / "手作"
#   loc       String  【仅 拾得】唯一**硬门槛**地点；购得/手作恒为 ""
#   season    String  软条件 · ""=不限（"spring"/"summer"/"autumn"/"winter"）
#   weather   String  软条件 · ""=不限（"sunny"/"cloudy"/"rainy"/"snowy"）
#   slot      String  软条件 · ""=不限（"morning"/"noon"/"after"/"evening"）
#   hint      String  图鉴随笔一句
#
# ⚠️ season / weather / slot 一律**只加权、不设门槛**（GDD §7 风险 R-3）：
#    游戏内四季线性单次（春1-150/夏151-300/秋301-450/冬451-570），
#    一旦把季节做成硬门槛，玩家错过当季即**永久**无法补齐 → 称号永锁。
#    唯一硬门槛是 loc。改这里之前先读这段注释。
# ⚠️ 字典保持插入顺序 = 图鉴格子顺序，不要对 keys() 排序。
# ⚠️ 购得 6 条的 fid **必须**与 GameManager.ITEM_DB 的 key 逐字相同
#    （购得路径靠 _try_grant_fengwu_item 以 item_id 直接当 fid 落账）。
const FENGWU_ITEMS = {
	# ── 拾得 12（loc 硬门槛；season/weather/slot 仅加权）──────────
	"liuxu": {
		"name": "苏堤柳絮", "category": "草木", "obtain": "拾得",
		"loc": "lakeside", "season": "spring", "weather": "", "slot": "morning",
		"hint": "四月的苏堤会下一场白色的雪，落在肩上不化，拍两下就没了。",
	},
	"taohuaban": {
		"name": "桃瓣浮水", "category": "草木", "obtain": "拾得",
		"loc": "lakeside", "season": "spring", "weather": "sunny", "slot": "after",
		"hint": "花瓣落到水面上不沉，一片挨一片，被野鸭划开一道口子，又慢慢合上。",
	},
	"hefeng": {
		"name": "荷风一缕", "category": "味", "obtain": "拾得",
		"loc": "lakeside", "season": "summer", "weather": "sunny", "slot": "after",
		"hint": "曲院那边过来的风是甜的。说不清是荷叶的味道，还是水本身的味道。",
	},
	"xuehen": {
		"name": "湖畔雪痕", "category": "物", "obtain": "拾得",
		"loc": "lakeside", "season": "winter", "weather": "snowy", "slot": "morning",
		"hint": "栏杆上那道雪，你伸手抹掉一截。回头再看，它又慢慢补齐了。",
	},
	"guihua_jin": {
		"name": "桂花碎金", "category": "草木", "obtain": "拾得",
		"loc": "community", "season": "autumn", "weather": "", "slot": "evening",
		"hint": "楼下一夜之间铺了一层碎金。扫地的阿姨说，别扫，留两天好看。",
	},
	"wapian": {
		"name": "老墙碎瓦", "category": "物", "obtain": "拾得",
		"loc": "community", "season": "", "weather": "", "slot": "evening",
		"hint": "拆了一半的老墙根下捡的，边缘磨得很圆，不知道在那儿躺了多少年。",
	},
	"yinxing_shu": {
		"name": "书页银杏", "category": "草木", "obtain": "拾得",
		"loc": "library", "season": "autumn", "weather": "", "slot": "after",
		"hint": "借的书里夹着一片银杏，脉络还很清楚。上一个人是哪一年放进去的？",
	},
	"yansheng": {
		"name": "檐下雨声", "category": "声景", "obtain": "拾得",
		"loc": "library", "season": "", "weather": "rainy", "slot": "after",
		"hint": "雨顺着屋檐排成一条线往下掉，砸在窗台上的节奏，比翻书还稳。",
	},
	"chanming": {
		"name": "树上蝉声", "category": "声景", "obtain": "拾得",
		"loc": "playground", "season": "summer", "weather": "sunny", "slot": "noon",
		"hint": "整片操场只剩蝉在响。响到某一秒忽然全停了，然后又一起响起来。",
	},
	"chaohuo": {
		"name": "巷口炒货香", "category": "味", "obtain": "拾得",
		"loc": "off_campus_shop", "season": "", "weather": "", "slot": "after",
		"hint": "放学那条巷子永远飘着炒货的焦香。你一次都没买过，却一直记得。",
	},
	"longjing_qi": {
		"name": "头道龙井香", "category": "味", "obtain": "拾得",
		"loc": "market", "season": "spring", "weather": "", "slot": "morning",
		"hint": "茶叶铺开水一冲，那股青气直冲上来，像把整座山搬进了杯子里。",
	},
	"xiaozhong": {
		"name": "放学铃声", "category": "声景", "obtain": "拾得",
		"loc": "school_gate", "season": "", "weather": "", "slot": "after",
		"hint": "三年听了一千多次。最后一次响的时候，你居然没听出什么不一样。",
	},
	# ── 购得 6（fid == GameManager.ITEM_DB 的 key；价格真源在 ITEM_DB）──
	"fw_longjing": {
		"name": "明前龙井", "category": "味", "obtain": "购得",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "清河坊买的一小罐，一直舍不得喝，最后放陈了。",
	},
	"fw_oufen": {
		"name": "西湖藕粉", "category": "味", "obtain": "购得",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "冲开是半透明的糊，撒一撮干桂花。甜得很温吞，像杭州本身。",
	},
	"fw_guihuatang": {
		"name": "桂花糖", "category": "味", "obtain": "购得",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "小小一罐，挖一勺兑水。秋天就这样被存到了冬天。",
	},
	"fw_chousan": {
		"name": "西湖绸伞", "category": "物", "obtain": "购得",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "伞面薄得能透光，其实不太挡雨——它本来也不是拿来挡雨的。",
	},
	"fw_wangxingji": {
		"name": "王星记黑纸扇", "category": "物", "obtain": "购得",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "一开是「唰」的一声。那一声比风本身更像夏天。",
	},
	"fw_tianzhukuai": {
		"name": "天竺筷", "category": "物", "obtain": "购得",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "竹节上烙着西湖十景。用久了字会淡，竹子倒会越来越亮。",
	},
	# ── 手作 6 · 经 fw_craft_* 事件授予（纯 flag，不进 ITEM_DB）──
	# 授予链路：events_life.json 的 fw_craft_<suffix>（location:"home"，
	#   requireItem:"handmade_gift" + requireItemAmt:1 + requireMoney:<材料费> 门控）
	#   → 场景级 grantFengwu 字段 → DialogueUI → CollectionManager.grant_fengwu(fid)。
	# ⚠️ D-2：这 6 个 fid **不得**注册进 GameManager.ITEM_DB —— 一旦进 ITEM_DB，
	#   ShopUI 会把 price:0 的它们当作免费商品上架，玩家可直接白嫖，手作渠道形同虚设。
	"fw_hm_yahua": {
		"name": "押花书签", "category": "草木", "obtain": "手作",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "把苏堤的花瓣夹进字典里压平。在家备一份手作礼物，加一点材料费，就能做出来。",
	},
	"fw_hm_guihuajiang": {
		"name": "手熬桂花酱", "category": "味", "obtain": "手作",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "小火熬到糖色发亮，满屋子都是秋天。在家备一份手作礼物，加一点材料费，就能做出来。",
	},
	"fw_hm_xiangnang": {
		"name": "荷叶香囊", "category": "味", "obtain": "手作",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "晒干的荷叶碎裹进布袋，塞在枕头底下。在家备一份手作礼物，加一点材料费，就能做出来。",
	},
	"fw_hm_taci": {
		"name": "瓦当拓片", "category": "物", "obtain": "手作",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "宣纸铺上去，墨包一点点拍。老纹路就这么被偷走一层。在家备一份手作礼物，加一点材料费，就能做出来。",
	},
	"fw_hm_zhuze": {
		"name": "竹编茶则", "category": "物", "obtain": "手作",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "削了半天竹片，手指头缠了三块创可贴。在家备一份手作礼物，加一点材料费，就能做出来。",
	},
	"fw_hm_luyin": {
		"name": "湖声一段", "category": "声景", "obtain": "手作",
		"loc": "", "season": "", "weather": "", "slot": "",
		"hint": "拿手机在湖边录了四分钟，全是风。在家备一份手作礼物，加一点材料费，就能做出来。",
	},
}

const FENGWU_TOTAL := 24
const FENGWU_TITLE_FLAG := "title_西湖风物通"
const FENGWU_COMPLETE_FLAG := "west_lake_fengwu_complete"
const FENGWU_PICKUP_DAY_FLAG := "fengwu_pickup_day"
# 拾得概率（GDD §3）：地点命中 → 基础概率；每满足一项软条件 +BONUS；封顶 CAP
const FENGWU_PICK_BASE  := 0.18
const FENGWU_PICK_BONUS := 0.12
const FENGWU_PICK_CAP   := 0.60
const FENGWU_END_DAY    := 570   # 结局日：不插入任何被动授予（对齐 ECHO_END_DAY）

# ── 查询 API（只读，供 FengwuBookUI 消费）─────────────────────
func is_fengwu_owned(fid: String) -> bool:
	return GameManager.flags.has("fengwu_" + fid)

## 返回入册日；未获得或缺失（补偿扫描前的极端时序）时返回 -1
func get_fengwu_day(fid: String) -> int:
	var v = GameManager.flags.get("fengwu_" + fid + "_day", -1)
	return int(v) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else -1

func get_fengwu_progress() -> Dictionary:
	var unlocked := 0
	for fid in FENGWU_ITEMS.keys():
		if is_fengwu_owned(fid): unlocked += 1
	return { "unlocked": unlocked, "total": FENGWU_TOTAL }

## 本版本**可达**上限。三渠道（拾得 / 购得 / 手作）均已接线，全部 24 件现已开放，
## 故恒等于 FENGWU_TOTAL。图鉴据此自动隐藏「本章可达 N 件」的降级提示
## （FengwuBookUI 侧该提示由 reachable < total 守卫，此处回 24 后即不再显示）。
func get_fengwu_reachable_total() -> int:
	return FENGWU_TOTAL

## 今天是否已拾得过（每日 1 件限速，避免刷地点刷满）
func is_fengwu_pickup_used_today() -> bool:
	return int(GameManager.flags.get(FENGWU_PICKUP_DAY_FLAG, -1)) == GameManager.day

## 该件风物当前是否处于「软条件正反馈」状态（图鉴挂 ⭐，纯提示非门槛）
func is_fengwu_bonus_active(fid: String) -> bool:
	var data: Dictionary = FENGWU_ITEMS.get(fid, {})
	if data.is_empty(): return false
	if String(data.get("obtain", "")) != "拾得": return false
	var s: String = String(data.get("season", ""))
	var w: String = String(data.get("weather", ""))
	if s == "" and w == "": return false
	if s != "" and WeatherManager.get_season() != s: return false
	if w != "" and String(GameManager.current_weather) != w: return false
	return true

## 入册日的可读文案，复用十景的学期换算（真源对齐，勿另写一份）
func format_fengwu_day(d: int) -> String:
	return format_stamp_day(d)

# ── 授予（唯一写入口）─────────────────────────────────────────
## 幂等。拾得 / 购得 / 手作三条路径全部经此落账。
## 返回 true 表示「本次调用真的授予了一件新风物」。
func grant_fengwu(fid: String) -> bool:
	if not FENGWU_ITEMS.has(fid): return false
	var flag := "fengwu_" + fid
	if GameManager.flags.has(flag): return false   # 已入册 → 幂等跳过
	GameManager.set_flag(flag, true)
	GameManager.set_flag(flag + "_day", GameManager.day)
	# 若本次授予后即集满，只发集满那条（更隆重），跳过普通入册 toast
	if _check_fengwu_completion(): return true
	var data: Dictionary = FENGWU_ITEMS[fid]
	var prog := get_fengwu_progress()
	GameManager.show_toast.emit("🍃 风物入册：%s·%s（%d/%d）" % [
		data.get("category", ""), data.get("name", fid), prog["unlocked"], prog["total"]])
	return true

## 集满判定。返回 true 表示「本次调用刚刚触发集满」
## ⚠️ 需要全部 24 件（拾得 12 + 购得 6 + 手作 6）—— 三渠道均已接线，本版本可真实触发。
func _check_fengwu_completion() -> bool:
	if GameManager.flags.has(FENGWU_COMPLETE_FLAG): return false
	for fid in FENGWU_ITEMS.keys():
		if not is_fengwu_owned(fid): return false
	GameManager.set_flag(FENGWU_COMPLETE_FLAG, true)
	GameManager.set_flag(FENGWU_TITLE_FLAG, true)
	unlock_gallery(FENGWU_COMPLETE_FLAG)
	GameManager.show_toast.emit("🏆 西湖风物通！廿四风物尽入册——称号已入账，画廊解锁「西湖风物·大成」")
	return true

## 补偿扫描（幂等）：
##   1. 购得路径旁路：inventory 里已有 fengwu 类物品却没入册（存量存档 / 事件直塞 inventory）
##   2. 已入册但缺 _day（极端时序）→ 补当前 day
##   3. 存量存档已集满但未置 complete flag → 补触发集满奖励
## 调用点：GameManager._retroactive_gallery_check()（开局 / 读档 / DEBUG 热键）
func _retroactive_fengwu_check():
	for fid in FENGWU_ITEMS.keys():
		if String(FENGWU_ITEMS[fid].get("obtain", "")) != "购得": continue
		if is_fengwu_owned(fid): continue
		if GameManager.inventory.has(fid):
			grant_fengwu(fid)
	for fid in FENGWU_ITEMS.keys():
		if is_fengwu_owned(fid) and get_fengwu_day(fid) < 0:
			GameManager.set_flag("fengwu_" + fid + "_day", GameManager.day)
	_check_fengwu_completion()

# ── 拾得判定 + 授予（D-4）────────────────────────────────────
## 调用点：MainGame._on_location_selected()，**必须**在记忆回响 step 0
##   `if _try_memory_echo(loc_id): return` 之后 —— 回响命中时那里已 return，
##   二者天然互斥，本函数不会与回响同屏（GDD §5 集成点）。
## 行为：被动、静默、不打断 —— 不播 vignette、不消耗时段、不改属性/好感，
##   命中时仅 grant_fengwu()（内部一条 toast）+ 一行 add_log。
## 硬门槛只有 loc；season / weather / slot 一律只加权（见 FENGWU_ITEMS 注释）。
## 返回本次拾得的 fid；未拾得返回 ""。
func pick_fengwu_pickup(loc_id: String) -> String:
	if GameManager.day >= FENGWU_END_DAY: return ""     # 结局日不插入任何东西
	if is_fengwu_pickup_used_today(): return ""         # 每日 1 件限速
	var season: String = WeatherManager.get_season()
	var weather: String = String(GameManager.current_weather)
	var slot: String = GameManager._get_slot_id()
	var best_fid: String = ""
	var best_chance: float = 0.0
	for key in FENGWU_ITEMS.keys():
		var fid: String = String(key)
		var data: Dictionary = FENGWU_ITEMS[fid]
		if String(data.get("obtain", "")) != "拾得": continue    # 购得/手作 不走拾得
		if String(data.get("loc", "")) != loc_id: continue       # 唯一硬门槛
		if is_fengwu_owned(fid): continue
		var chance: float = FENGWU_PICK_BASE
		var s: String = String(data.get("season", ""))
		var w: String = String(data.get("weather", ""))
		var sl: String = String(data.get("slot", ""))
		if s != "" and s == season:   chance += FENGWU_PICK_BONUS
		if w != "" and w == weather:  chance += FENGWU_PICK_BONUS
		if sl != "" and sl == slot:   chance += FENGWU_PICK_BONUS
		chance = minf(chance, FENGWU_PICK_CAP)
		# 软条件命中越多越优先；平局按 fid 字典序升序（稳定、可静态验证）
		if best_fid == "" or chance > best_chance or (is_equal_approx(chance, best_chance) and fid < best_fid):
			best_chance = chance
			best_fid = fid
	if best_fid == "": return ""
	GameManager.set_flag(FENGWU_PICKUP_DAY_FLAG, GameManager.day)   # 消耗当日尝试额度（成败都计）
	if randf() >= best_chance: return ""   # 失败则今日不再 roll（额度已消耗）
	grant_fengwu(best_fid)
	GameManager.add_log("🍃 拾得风物 · " + String(FENGWU_ITEMS[best_fid].get("name", best_fid)))
	return best_fid

## 购得路径钩子（唯一）：ITEM_DB 中 category == "fengwu" 的物品，
## item_id 与 FENGWU_ITEMS 的 fid 逐字相同 → 直接落账。
## 由 add_item() 尾部调用，ShopUI / 事件 addItem 全部零改动自动覆盖。
func _try_grant_fengwu_item(item_id: String) -> void:
	var meta: Dictionary = GameManager.ITEM_DB.get(item_id, {})
	if String(meta.get("category", "")) != "fengwu": return
	grant_fengwu(item_id)

# ═══════════════════════════════════════════════════════════════
# ── 记忆回响 · 情境回响（DS-RN-02）───────────────────────────
# 设计依据：design/memory_echo_gdd.md（形态已拍板：情境回响 Contextual Echo）
# 零新 Autoload / 零新脚本 / 零存档迁移：所有状态落 GameManager.flags
#   mem_echo_<sid>_last   int  该条记忆最近一次回响的 day（G5 冷却基准，默认 -999）
#   mem_echo_<sid>_count  int  该条记忆整局已回响次数（G7 上限基准，默认 0）
#   mem_echo_last_day     int  任意记忆最近一次回响的 day（G6 全局冷却基准，默认 -999）
#   mem_echo_total        int  整局回响总次数（G8 上限基准，默认 0）
# ⚠️ 本区对画廊只读：不调用 unlock_gallery()，不写任何 stamp_* / holiday_memory_* /
#    seen_* / night_chat_* 键，不 emit show_toast（GDD §3.5 / S-8）。
# ═══════════════════════════════════════════════════════════════

# ── 调参常量（GDD §5.1）──────────────────────────────────────
const ECHO_MATURE_DAYS       := 30    # 记忆「沉淀期」：born_day + 30 起才可回响（G4）
const ECHO_MEM_COOLDOWN_DAYS := 60    # 单条记忆冷却（G5）
const ECHO_GLOBAL_GAP_DAYS   := 14    # 全局冷却 · 常态（G6）
const ECHO_GLOBAL_GAP_FINALE := 5     # 全局冷却 · 终章加密（G6，day >= 540）
const ECHO_PER_MEM_CAP       := 2     # 单条记忆整局回响次数上限（G7）
const ECHO_TOTAL_CAP         := 8     # 全局整局回响次数上限（G8）
const ECHO_FINALE_BONUS      := 2     # 终章额外配额（G8，day >= 540）
const ECHO_FINALE_DAY        := 540   # 终章起始日（finale_line + 加密 + 加配额）
const ECHO_LAST_NIGHT_DAY    := 569   # 毕业前夜特例日（GDD §2.5）
const ECHO_END_DAY           := 570   # 结局日：不插入任何软演出（G0）
# P1 可选（GDD §3.3）：微暖褪色「旧照片」感。当前未接线 —— 见 §7⑤ 的 modulate 复位风险，
# P0 不依赖它；此处仅先定义常量备用，DialogueUI 侧零改动。
const ECHO_BG_TINT           := [1.0, 0.94, 0.86, 1.0]

# ── 记忆回响上下文映射（GDD §1.2 / §1.3）· 本层唯一真源 ──────
# 键 sid = "<season>_<char>"，与 flag 一一对应：flag = "holiday_memory_" + sid
# 字段（仅 4 个，其余全部派生）：
#   loc          String        原发地点 —— 逐字取自 events_break.json 对应 chapter 的 "location"
#   slot         String        原发时段 —— 逐字取自同一 chapter 的 "slotId"（仅作排序强权重，非门槛）
#   lines        Array[String] 回响正文 3 句：触景 / 闪回 / 独白
#   finale_line  String        day >= ECHO_FINALE_DAY 时追加的第 4 句
# 派生（刻意不在此重复定义，由函数运行时求值，GDD S-6）：
#   flag   = "holiday_memory_" + sid
#   season = sid.split("_")[0]
#   born   = DailyCycleManager.BREAK_PERIODS[season][1]
#   char / bg / label / hint = _memory_gallery_item(sid) 从 GameManager.GALLERY_ITEMS 反查
# ⚠️ 字典保持插入顺序；不要对 keys() 排序（排序由 pick_memory_echo 的打分函数负责）。
const MEMORY_ECHO_CONTEXTS = {
	"winter_yutong": {
		"loc": "lakeside", "slot": "evening",
		"lines": [
			"湖风从断桥那头灌过来，你下意识把手插进口袋——又想起来，那天口袋里不是空的。",
			"那年寒假的雪夜，雪落在栏杆上化成一层薄水。她的手在你掌心颤了一下，谁都没有先松开。",
			"桥还是那座桥。只是今天没有下雪。",
		],
		"finale_line": "还有不到两个月就毕业了。你忽然很想再下一场那样的雪。",
	},
	"winter_jingjing": {
		"loc": "off_campus_shop", "slot": "after",
		"lines": [
			"小卖部门口飘出一股热气，甜的。你站了两秒才想起来这味道像什么。",
			"那年寒假的糖水铺，桂花酒酿冒着白汽。她把空碗往你这边一推：「记住你说的啊，赖账我就……」后半句她自己先笑没了。",
			"「明年同班」——那句话到底算不算数，你至今没敢问。",
		],
		"finale_line": "明年已经没有「同班」这回事了。你把这句咽了回去。",
	},
	"winter_yifei": {
		"loc": "cinema", "slot": "noon",
		"lines": [
			"影院大厅的空调风一吹，你打了个哆嗦。冬天的时候，这里更冷一点。",
			"那年寒假散场，街灯把两个人的影子拉得很长。他把保温杯塞进你手里捂了捂：「拿着，暖。」",
			"杯子后来还回去了。手心那点温度倒是留到了现在。",
		],
		"finale_line": "快毕业了。你想，散场之后，总得有人先走。",
	},
	"spring_wanqing": {
		"loc": "lakeside", "slot": "evening",
		"lines": [
			"苏堤这一段的桃树又开了。你走着走着就慢了下来。",
			"那年春假她坐在树下写生，花瓣落满裙摆。她念出故事主角的名字，声音轻得像花瓣落地——「……就是现在这个春天。」",
			"那个名字你听清了。你从来没有跟任何人说过。",
		],
		"finale_line": "春天还会再来。她那个本子，你不知道还在不在。",
	},
	"spring_xiaoxia": {
		"loc": "community", "slot": "after",
		"lines": [
			"楼下那面广告牌换过一轮，还是攀岩馆的。你盯着看了一会儿。",
			"那年春假她挂在半空回头喊你，手心全是镁粉。落地之后撞了下你的肩：「说话算话啊，笨蛋！」",
			"「每年春天都来」——今年的春天，好像已经过去了。",
		],
		"finale_line": "毕业以后还能不能凑齐一次，谁也说不好。你决定先不想。",
	},
	"spring_beichen": {
		"loc": "cinema", "slot": "noon",
		"lines": [
			"排片表上又挂了一部科幻片。海报那种蓝，跟那年那张有点像。",
			"那年春假的场子几乎没人。片尾字幕滚到一半，他忽然说：「下个春假，老地方。」虎牙一咧，「跑了我追你三条街。」",
			"老地方还在。追不追得上，就不一定了。",
		],
		"finale_line": "下个春假，你们大概已经不在同一所学校了。",
	},
	"summer_keke": {
		"loc": "lakeside", "slot": "evening",
		"lines": [
			"天刚黑，芦苇荡那边有细碎的光在动。可能是萤火虫，也可能只是眼花。",
			"那年暑假她拽着你一路跑到水边，指着一片乱晃的光说：「这是我们的秘密基地。」然后把额头轻轻抵在你肩上。",
			"秘密基地这种东西，好像只要说出口，就开始过期了。",
		],
		"finale_line": "今年夏天你没再来过这里。而现在再来，已经是最后一个夏天。",
	},
	"summer_zijun": {
		"loc": "community", "slot": "after",
		"lines": [
			"楼下有人在摆摊，灯串一闪一闪。你想起另一条更长的街。",
			"那年暑假的夜市，河灯顺水漂得很慢。他把灯往水里推了推：「愿望要两个人一起许，才算数。」",
			"你到现在也没想起来，那天自己许的是什么。",
		],
		"finale_line": "现在倒是很清楚该许什么了。可惜灯早就漂远了。",
	},
	"autumn_zicheng": {
		"loc": "lakeside", "slot": "evening",
		"lines": [
			"风里有桂花味。杭州一到这个时候，整座城都是这个味道。",
			"那年秋假的桂花林，花落了一石桌。他把纸袋往你怀里一塞：「成交！敢不来我天天堵你。」",
			"「每年秋天都来」——你数了数，还剩几个秋天。",
		],
		"finale_line": "答案是没有了。下一个秋天，你已经不在这所学校。",
	},
	"autumn_jingjing_m": {
		"loc": "community", "slot": "after",
		"lines": [
			"楼下的桂花开过一茬了，地上还留着一层碎金似的东西。",
			"那年秋假的诗会，他把整首桂花念完了，最后一行念得特别慢。散场时塞给你一枚桂花书签：「记住啊。」",
			"书签夹在哪本书里，你一时想不起来。但那一行你记得。",
		],
		"finale_line": "快毕业了。你翻遍了书架，想把那枚书签找出来。",
	},
}

# ── 派生查询（GDD §5.5）· 全部只读 ───────────────────────────
## 从 GALLERY_ITEMS 反查该记忆的画廊条目（char / label / hint / bg 的唯一真源）
## 未找到时返回 {}，调用方须做空判断（数据异常兜底：整条回响静默跳过，不崩）
func _memory_gallery_item(sid: String) -> Dictionary:
	var flag := "holiday_memory_" + sid
	for entry in GameManager.GALLERY_ITEMS:
		var item: Dictionary = entry
		if String(item.get("flag", "")) == flag:
			return item
	return {}

## 从 DailyCycleManager.BREAK_PERIODS 推导该记忆的「发生日」（= 所属长假结束日）
## sid 前缀不在 BREAK_PERIODS 中时返回 99999（永不成熟，安全失败）
func _memory_born_day(sid: String) -> int:
	var season: String = sid.split("_")[0]
	if not DailyCycleManager.BREAK_PERIODS.has(season):
		return 99999
	var rng: Array = DailyCycleManager.BREAK_PERIODS[season]
	return int(rng[1])

# ── 判定（GDD §2）· 纯函数式，不写任何 flag ──────────────────
## 输入：玩家正在进入的地点 loc_id
## 输出：{"sid": String} 命中一条 | {} 不触发
## 副作用：无 —— 写入由 commit_memory_echo() 独立负责
## 刻意不设的守卫（GDD §2.3 注，勿加）：stress / 天气 / minAff / slot 硬匹配 /
##   季节匹配（§1.2 ⚠️：游戏内四季线性单次且与长假命名错位，加季节门槛会让
##   spring_* 与 summer_* 共 5 条记忆永远无法命中 —— 死分支）。
func pick_memory_echo(loc_id: String) -> Dictionary:
	var day: int = GameManager.day
	# ── 阶段 0 · 全局门（与具体记忆无关，先算，短路最快）──
	if day >= ECHO_END_DAY:                                  # G0 非结局日
		return {}
	if String(GameManager.current_holiday) != "":            # G3 非长假期间
		return {}
	# 毕业前夜特例（§2.5）：放宽 G2 / G5 / G6 / G7 / G8，保留 G0 / G1 / G3 / G4 / G9
	var is_last_night: bool = day == ECHO_LAST_NIGHT_DAY
	# BUG-ME-01 修复：毕业前夜放宽 G5/G6/G7/G8 后，唯一刹车仅剩"同日仅一次"。
	# 否则 CONNECT_ONE_SHOT lambda 重入会在同一地点无限连播同一记忆（推演 200 层未终止）。
	if is_last_night and int(GameManager.flags.get("mem_echo_last_day", -999)) == day:
		return {}
	var is_finale: bool = day >= ECHO_FINALE_DAY
	if not is_last_night:
		var gap: int = ECHO_GLOBAL_GAP_FINALE if is_finale else ECHO_GLOBAL_GAP_DAYS
		if day - int(GameManager.flags.get("mem_echo_last_day", -999)) < gap:   # G6
			return {}
		var total_cap: int = ECHO_TOTAL_CAP + (ECHO_FINALE_BONUS if is_finale else 0)
		if int(GameManager.flags.get("mem_echo_total", 0)) >= total_cap:        # G8
			return {}
	# ── 阶段 1 · 逐条筛选 + 打分（§2.4，降序取第一；平局按 sid 字典序升序）──
	var cur_slot: String = GameManager._get_slot_id()
	var best_sid: String = ""
	var best_score: float = -INF
	for key in MEMORY_ECHO_CONTEXTS.keys():
		var sid: String = String(key)
		var ctx: Dictionary = MEMORY_ECHO_CONTEXTS[sid]
		if not GameManager.flags.has("holiday_memory_" + sid):   # G1 已解锁
			continue
		if not is_last_night and String(ctx.get("loc", "")) != loc_id:   # G2 地点匹配
			continue
		if day < _memory_born_day(sid) + ECHO_MATURE_DAYS:       # G4 成熟期
			continue
		var item: Dictionary = _memory_gallery_item(sid)
		if item.is_empty():                                      # 数据异常兜底
			continue
		var cid: String = String(item.get("char", ""))
		if cid != "" and RelationshipManager.get_rel_state(cid) == "cold":   # G9 排除冷战
			continue
		var last: int = int(GameManager.flags.get("mem_echo_%s_last" % sid, -999))
		var cnt: int = int(GameManager.flags.get("mem_echo_%s_count" % sid, 0))
		if not is_last_night:
			if day - last < ECHO_MEM_COOLDOWN_DAYS:              # G5 单条冷却
				continue
			if cnt >= ECHO_PER_MEM_CAP:                          # G7 单条上限
				continue
		var score: float = 0.0
		if is_last_night:
			# §2.5：毕业前夜按 count 升序优先（量级 1000，压过下方全部权重）
			score -= 1000.0 * float(cnt)
		if String(ctx.get("slot", "")) == cur_slot:
			score += 100.0                                       # 原发时段匹配
		if cnt == 0:
			score += 50.0                                        # 从未回响过，覆盖广度优先
		score += float(clampi(int(GameManager.favorability.get(cid, 0)) / 10, 0, 10))
		var idle: int = 200 if last <= -999 else mini(day - last, 200)
		score += float(idle) / 100.0                             # 越久未响越优先（0.0-2.0）
		if best_sid == "" or score > best_score or (is_equal_approx(score, best_score) and sid < best_sid):
			best_score = score
			best_sid = sid
	if best_sid == "":
		return {}
	return { "sid": best_sid }

# ── vignette 合成（GDD §5.4）· 运行时合成，不写入任何 JSON 事件文件 ──
## ⚠️ 硬约束：scene 一律不写 pose / setFlag / setFlags / addItem / affDelta /
##    statDelta / statsDelta / choices；仅最后一句写 next:99；
##    location 传空串（跳过地点增益重复发放 + 天气 toast）；charId 刻意不写。
## ⚠️ 本函数不写任何 flag —— 冷却与配额统一由 commit_memory_echo() 负责。
func build_memory_echo_vignette(sid: String) -> Dictionary:
	var ctx: Dictionary = MEMORY_ECHO_CONTEXTS.get(sid, {})
	if ctx.is_empty():
		return {}
	var item: Dictionary = _memory_gallery_item(sid)
	if item.is_empty():
		return {}
	var label: String = String(item.get("label", sid))
	var scenes: Array = []
	var raw_lines: Array = ctx.get("lines", [])
	for line in raw_lines:
		var t: String = String(line)
		if t != "":
			scenes.append({ "speaker": null, "text": t })
	if scenes.is_empty():
		# 兜底（GDD §1.5）：lines 缺失 → 降级为该条画廊 hint 单句，不报错、不崩
		var hint: String = String(item.get("hint", ""))
		if hint == "":
			return {}
		scenes.append({ "speaker": null, "text": hint })
	if GameManager.day >= ECHO_FINALE_DAY:
		var fl: String = String(ctx.get("finale_line", ""))
		if fl != "":
			scenes.append({ "speaker": null, "text": fl })
	var last_scene: Dictionary = scenes[scenes.size() - 1]
	last_scene["next"] = 99                                  # 仅最后一句写 next:99
	return {
		"id":         "mem_echo_" + sid,
		"location":   "",
		"title":      "🕯️ 记忆回响 · " + label,
		"bg":         String(item.get("bg", "")),
		"isSpecial":  false,
		"repeatable": true,
		"noTimeCost": true,
		"scenes":     scenes,
	}

# ── 落账（GDD §5.3 / §3.5）· mem_echo_* 的唯一写入源 ─────────
## 必须在 DialogueUI.start_event() 之前调用（防重入：宁可漏播一次，不可重复播）。
## 写入一律走 GameManager.set_flag(key, int)（L678-685 支持 int 值），不直接改 flags。
func commit_memory_echo(sid: String) -> void:
	if not MEMORY_ECHO_CONTEXTS.has(sid):
		return
	var day: int = GameManager.day
	var key_last: String = "mem_echo_%s_last" % sid
	var key_count: String = "mem_echo_%s_count" % sid
	GameManager.set_flag(key_last, day)
	GameManager.set_flag(key_count, int(GameManager.flags.get(key_count, 0)) + 1)
	GameManager.set_flag("mem_echo_last_day", day)
	GameManager.set_flag("mem_echo_total", int(GameManager.flags.get("mem_echo_total", 0)) + 1)
	# 唯一的两条落地痕迹（纯记录，不发 toast、不加属性/好感/物品）
	var label: String = String(_memory_gallery_item(sid).get("label", sid))
	GameManager.add_log("🕯️ 记忆回响 · " + label)
	GameManager.add_diary_entry("忽然想起" + label)
