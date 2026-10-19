extends Node
## AudioManager.gd - 全局音频管理单例 (BGM / SFX Audio Controller)
## 提供原神风成就提示音、UI交互音、小游戏音效池与平滑BGM交叉淡入淡出。

signal bgm_changed(track_name: String)

var master_volume: float = 1.0
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0

# 音频流播放器节点
var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _active_bgm_player: AudioStreamPlayer
var _current_bgm_track: String = ""

# SFX 播放池（支持并发播放不截断）
const SFX_POOL_SIZE = 8
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

# 音频资源预加载缓存表
var _sfx_cache: Dictionary = {}
var _bgm_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 初始化 BGM 双轨道播放器（用于 Crossfade 交叉淡入淡出）
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.bus = "Master"
	add_child(_bgm_player_a)

	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.bus = "Master"
	add_child(_bgm_player_b)

	_active_bgm_player = _bgm_player_a

	# 初始化 SFX 播放器对象池
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	# 预加载核心内置音效
	_preload_assets()

func _preload_assets() -> void:
	var sfx_list = [
		"achievement_unlock", "ui_click", "ui_hover", "ui_popup",
		"camera_shutter", "coin_drop", "badminton_hit", "paper_rustle"
	]
	for sname in sfx_list:
		var path = "res://assets/audio/sfx/%s.wav" % sname
		if ResourceLoader.exists(path):
			_sfx_cache[sname] = load(path)

	var bgm_list = ["bgm_peaceful_campus"]
	for bname in bgm_list:
		var path = "res://assets/audio/bgm/%s.wav" % bname
		if ResourceLoader.exists(path):
			_bgm_cache[bname] = load(path)

# ── 播放 SFX 音效 ─────────────────────────────────────────────
func play_sfx(sfx_name: String, pitch_variance: float = 0.0) -> void:
	var stream: AudioStream = null

	if _sfx_cache.has(sfx_name):
		stream = _sfx_cache[sfx_name]
	else:
		var path = "res://assets/audio/sfx/%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			stream = load(path)
			_sfx_cache[sfx_name] = stream

	if stream == null:
		return

	# 从池中获取空闲播放器
	var player = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE

	player.stop()
	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume * master_volume)

	if pitch_variance > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		player.pitch_scale = 1.0

	player.play()

# ── 播放 BGM 背景音乐 ─────────────────────────────────────────
func play_bgm(bgm_name: String, fade_duration: float = 1.2) -> void:
	if _current_bgm_track == bgm_name and _active_bgm_player.playing:
		return

	var stream: AudioStream = null
	if _bgm_cache.has(bgm_name):
		stream = _bgm_cache[bgm_name]
	else:
		var path = "res://assets/audio/bgm/%s.wav" % bgm_name
		if ResourceLoader.exists(path):
			stream = load(path)
			_bgm_cache[bgm_name] = stream

	if stream == null:
		return

	_current_bgm_track = bgm_name

	# 选择交叉淡入的新播放器
	var next_player = _bgm_player_b if _active_bgm_player == _bgm_player_a else _bgm_player_a
	var prev_player = _active_bgm_player
	_active_bgm_player = next_player

	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()

	var target_db = linear_to_db(bgm_volume * master_volume)

	var tw = create_tween().set_parallel(true)
	# 新音乐淡入
	tw.tween_property(next_player, "volume_db", target_db, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 旧音乐淡出
	if prev_player.playing:
		tw.tween_property(prev_player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(prev_player.stop)

	bgm_changed.emit(bgm_name)

func stop_bgm(fade_duration: float = 1.0) -> void:
	if not _active_bgm_player.playing:
		return
	var tw = create_tween()
	tw.tween_property(_active_bgm_player, "volume_db", -80.0, fade_duration)
	tw.finished.connect(_active_bgm_player.stop)
	_current_bgm_track = ""

# ── 音量控制 ──────────────────────────────────────────────────
func set_master_volume(vol: float) -> void:
	master_volume = clamp(vol, 0.0, 1.0)
	_update_bgm_volume()

func set_bgm_volume(vol: float) -> void:
	bgm_volume = clamp(vol, 0.0, 1.0)
	_update_bgm_volume()

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clamp(vol, 0.0, 1.0)

func _update_bgm_volume() -> void:
	if _active_bgm_player and _active_bgm_player.playing:
		_active_bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
