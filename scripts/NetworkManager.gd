extends Node
## NetworkManager — 联网通信单例
## 默认连接本地运行的 mock_server.py (127.0.0.1:8000)
##
## M1 · 服务端地址可配置（不再硬编码）。优先级：
##   1. 环境变量 ZKGAME_SERVER_URL   （真机/CI 联调用，无需改代码重新导出）
##   2. project.godot 的 application/config/server_url
##   3. DEFAULT_SERVER_URL 兜底
## ⚠️ 真机上 127.0.0.1 指向手机自身、必然连不上，上线前须改为真实后端地址；
##    在此之前所有联网功能应走降级路径（见 EndingScreen S1 本地兜底）。

const DEFAULT_SERVER_URL = "http://127.0.0.1:8000"
const ENV_SERVER_URL     = "ZKGAME_SERVER_URL"
const SETTING_SERVER_URL = "application/config/server_url"

var SERVER_URL: String = DEFAULT_SERVER_URL

func _init() -> void:
	SERVER_URL = _resolve_server_url()

func _resolve_server_url() -> String:
	var env_url: String = OS.get_environment(ENV_SERVER_URL).strip_edges()
	if env_url != "":
		return env_url.trim_suffix("/")
	if ProjectSettings.has_setting(SETTING_SERVER_URL):
		var cfg: String = str(ProjectSettings.get_setting(SETTING_SERVER_URL)).strip_edges()
		if cfg != "":
			return cfg.trim_suffix("/")
	return DEFAULT_SERVER_URL

signal leaderboard_loaded(data: Array)
signal cloud_save_uploaded(success: bool, msg: String)
signal cloud_save_downloaded(success: bool, data: Dictionary)
signal wishes_loaded(data: Array)
signal wish_submitted(success: bool, msg: String)
signal my_wishes_loaded(data: Array)
signal wish_replied(success: bool, msg: String)
signal world_chat_loaded(data: Array)
signal world_chat_sent(success: bool, msg: String)
signal player_profile_loaded(success: bool, data: Dictionary)
signal player_profile_saved(success: bool, msg: String)

# ── 1. 上报学霸排行榜分数 ──
func submit_score(intellect: int, on_completed: Callable = Callable()):
	var url = SERVER_URL + "/leaderboard/submit"
	var payload = {
		"username": GameManager.player_name,
		"school": GameManager.school_name,
		"intellect": intellect
	}
	_http_post(url, payload, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var parsed = json.data
				if parsed and parsed.get("status") == "success":
					print("排行榜成绩上报成功！")
			else:
				push_warning("上报排行榜解析JSON失败: %s" % json.get_error_message())
		else:
			push_warning("上报排行榜失败，代码: %d" % response_code)
		
		if on_completed.is_valid():
			on_completed.call()
	)

# ── 2. 拉取学霸排行榜 ──
func get_leaderboard():
	var url = SERVER_URL + "/leaderboard"
	_http_get(url, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var parsed = json.data
				print("[NetworkManager] get_leaderboard parsed content: ", parsed)
				if parsed is Array:
					leaderboard_loaded.emit(parsed)
				else:
					print("[NetworkManager] get_leaderboard parsed is not Array!")
					leaderboard_loaded.emit([])
			else:
				print("[NetworkManager] get_leaderboard JSON parse error: ", json.get_error_message(), " | body context: ", body)
				leaderboard_loaded.emit([])
		else:
			print("[NetworkManager] get_leaderboard failed with response_code: ", response_code)
			leaderboard_loaded.emit([])
	)

# ── 3. 上传云存档（已修复：补入 season 和 cooking 数据）──
func upload_cloud_save(slot: int = 0):
	var url = SERVER_URL + "/cloud_save/upload"
	var save_data = {
		"ver":               SaveSystem.SAVE_VER,
		"saved_at":          Time.get_datetime_string_from_system(),
		"day":               GameManager.day,
		"day_of_week":       GameManager.day_of_week,
		"slot_index":        GameManager.slot_index,
		"money":             GameManager.money,
		"player_name":       GameManager.player_name,
		"school_name":       GameManager.school_name,
		"gender":            GameManager.gender,
		"stats":             GameManager.stats.duplicate(),
		"favorability":      GameManager.favorability.duplicate(),
		"flags":             GameManager.flags.duplicate(),
		"inventory":         GameManager.inventory.duplicate(),
		"hw_status":         GameManager.hw_status,
		"hw_neglect_count":  GameManager.hw_neglect_count,
		"diary":             GameManager.diary.duplicate(true),
		"recent_logs":       GameManager.recent_logs.duplicate(true),
		"char_initiative":   GameManager.get_initiative_save_data(),
		"cooking":           CookingManager.get_save_data(),
		"season":            SeasonManager.get_save_data(),
	}
	var payload = {
		"username": GameManager.player_name + "_slot_" + str(slot),
		"save_data": save_data
	}

	_http_post(url, payload, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var parsed = json.data
				if parsed and parsed.get("status") == "success":
					cloud_save_uploaded.emit(true, "上传成功！已同步至云端。")
				else:
					cloud_save_uploaded.emit(false, "云端返回异常")
			else:
				cloud_save_uploaded.emit(false, "解析云端响应失败: %s" % json.get_error_message())
		else:
			cloud_save_uploaded.emit(false, "网络错误，错误码 %d" % response_code)
	)

# ── 4. 下载并恢复云存档 ──
func download_cloud_save(slot: int = 0):
	var username = GameManager.player_name + "_slot_" + str(slot)
	var url = SERVER_URL + "/cloud_save/download?username=" + username.uri_encode()

	_http_get(url, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var parsed = json.data
				if parsed is Dictionary:
					cloud_save_downloaded.emit(true, parsed)
				else:
					cloud_save_downloaded.emit(false, {})
			else:
				print("[NetworkManager] download_cloud_save JSON parse error: ", json.get_error_message())
				cloud_save_downloaded.emit(false, {})
		else:
			cloud_save_downloaded.emit(false, {})
	)


# ── 11. 下载玩家全局档案（跨周目持久数据）──
func load_player_profile():
	var username = GameManager.player_name
	var url = SERVER_URL + "/player/profile?username=" + username.uri_encode()
	_http_get(url, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK and json.data is Dictionary:
				player_profile_loaded.emit(true, json.data)
				return
			push_warning("[NetworkManager] player profile JSON 解析失败")
		else:
			push_warning("[NetworkManager] 拉取 player profile 失败，代码: %d" % response_code)
		player_profile_loaded.emit(false, {})
	)

# ── 12. 上传玩家全局档案（跨周目持久数据）──
func save_player_profile(profile: Dictionary):
	var url = SERVER_URL + "/player/profile"
	var payload = {
		"username": GameManager.player_name,
		"profile": profile
	}
	_http_post(url, payload, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var parsed = json.data
				if parsed and parsed.get("status") == "success":
					player_profile_saved.emit(true, "玩家档案同步成功")
					return
		player_profile_saved.emit(false, "玩家档案保存失败，代码 %d" % response_code)
	)

# ── 基础网络请求封装（动态创建临时 HTTPRequest 节点，设置 5.0s 超时避开无限挂起） ──
func _http_get(url: String, callback: Callable):
	var http_req = HTTPRequest.new()
	add_child(http_req)
	http_req.timeout = 5.0
	http_req.request_completed.connect(func(result, response_code, _headers, body):
		var body_str = body.get_string_from_utf8()
		print("[NetworkManager] GET URL: %s, result: %d, code: %d, body_len: %d" % [url, result, response_code, body_str.length()])
		if result != HTTPRequest.RESULT_SUCCESS:
			print("[NetworkManager] GET Failed internally! Result code: ", result)
			response_code = 0
			body_str = ""
		callback.call(response_code, body_str)
		http_req.queue_free()
	)
	var err = http_req.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)
	if err != OK:
		print("[NetworkManager] GET request initiation failed: ", err)
		callback.call(0, "")
		http_req.queue_free()

func _http_post(url: String, payload: Dictionary, callback: Callable):
	var http_req = HTTPRequest.new()
	add_child(http_req)
	http_req.timeout = 5.0
	http_req.request_completed.connect(func(result, response_code, _headers, body):
		var body_str = body.get_string_from_utf8()
		print("[NetworkManager] POST URL: %s, result: %d, code: %d, body_len: %d" % [url, result, response_code, body_str.length()])
		if result != HTTPRequest.RESULT_SUCCESS:
			print("[NetworkManager] POST Failed internally! Result code: ", result)
			response_code = 0
			body_str = ""
		callback.call(response_code, body_str)
		http_req.queue_free()
	)
	var json_str = JSON.stringify(payload)
	var err = http_req.request(
		url, 
		["Content-Type: application/json", "Accept: application/json"], 
		HTTPClient.METHOD_POST, 
		json_str
	)
	if err != OK:
		print("[NetworkManager] POST request initiation failed: ", err)
		callback.call(0, "")
		http_req.queue_free()

# ── 5. 拉取随机许愿花灯/漂流瓶 ──
func get_random_wishes(count: int = 5):
	var url = SERVER_URL + "/wishes/random?count=" + str(count)
	_http_get(url, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var data = json.data
				if data is Array:
					wishes_loaded.emit(data)
					return
			push_warning("解析许愿列表 JSON 失败: %s" % json.get_error_message())
		else:
			push_warning("拉取许愿列表失败，代码: %d" % response_code)
		wishes_loaded.emit([])
	)

# ── 6. 放入许愿花灯/漂流瓶 ──
func submit_wish(content: String):
	var url = SERVER_URL + "/wishes/submit"
	var payload = {
		"username": GameManager.player_name,
		"school": GameManager.school_name,
		"content": content
	}
	_http_post(url, payload, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var parsed = json.data
				if parsed and parsed.get("status") == "success":
					wish_submitted.emit(true, "花灯已徐徐飘向西湖中央……")
					return
			wish_submitted.emit(false, "数据解析异常")
		else:
			wish_submitted.emit(false, "提交失败，网络连接错误")
	)

# ── 7. 拉取自己放出的许愿花灯 ──
func get_my_wishes():
	var url = SERVER_URL + "/wishes/my?username=" + GameManager.player_name.uri_encode()
	_http_get(url, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var data = json.data
				if data is Array:
					my_wishes_loaded.emit(data)
					return
			push_warning("解析自己心愿列表 JSON 失败: %s" % json.get_error_message())
		else:
			push_warning("拉取自己心愿列表失败，代码: %d" % response_code)
		my_wishes_loaded.emit([])
	)

# ── 8. 给某盏许愿花灯留言/评论 ──
func reply_to_wish(wish_id: String, content: String):
	var url = SERVER_URL + "/wishes/reply"
	var payload = {
		"wish_id": wish_id,
		"username": GameManager.player_name,
		"school": GameManager.school_name,
		"content": content
	}
	_http_post(url, payload, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var parsed = json.data
				if parsed and parsed.get("status") == "success":
					wish_replied.emit(true, "留言成功！已挂载到该花灯上。")
					return
			wish_replied.emit(false, "留言解析异常")
		else:
			wish_replied.emit(false, "留言失败，网络错误")
	)

# ── 9. 拉取世界聊天记录 ──
func get_world_chat_history():
	var url = SERVER_URL + "/chat/history"
	_http_get(url, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var data = json.data
				if data is Array:
					world_chat_loaded.emit(data)
					return
			push_warning("解析聊天记录 JSON 失败: %s" % json.get_error_message())
		else:
			push_warning("拉取世界聊天历史失败，代码: %d" % response_code)
		world_chat_loaded.emit([])
	)

# ── 10. 发送世界聊天消息 ──
func send_world_chat_message(content: String):
	var url = SERVER_URL + "/chat/send"
	var payload = {
		"username": GameManager.player_name,
		"title": GameManager.flags.get("active_title", "西湖游客"),
		"school": GameManager.school_name,
		"content": content
	}
	_http_post(url, payload, func(response_code: int, body: String):
		if response_code == 200:
			var json = JSON.new()
			var err = json.parse(body.strip_edges())
			if err == OK:
				var parsed = json.data
				if parsed and parsed.get("status") == "success":
					world_chat_sent.emit(true, "消息已发送！")
					return
			world_chat_sent.emit(false, "消息数据解析异常")
		else:
			world_chat_sent.emit(false, "发送失败，网络连接错误")
	)
