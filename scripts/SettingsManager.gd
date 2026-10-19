extends Node
## SettingsManager.gd - 全局系统设置单例 (System Settings Manager)
## 管理音频音量、显示窗口模式、垂直同步、文本打字机速度与玩家偏好持久化。

signal settings_changed()

const SETTINGS_FILE_PATH = "user://settings.cfg"

# 默认设置参数
var master_volume: float = 1.0
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0

var window_mode: int = 0 # 0: 窗口化 1280x720, 1: 全屏, 2: 无边框
var vsync_enabled: bool = true

var text_speed_idx: int = 1 # 0: 慢速, 1: 标准, 2: 极速, 3: 瞬间
var auto_delay: float = 2.0 # 自动播放等待秒数
var skip_unread: bool = false # 快进未读文本

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all_settings()

func load_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_FILE_PATH)
	if err != OK:
		# 无配置文件则使用默认配置
		return

	master_volume = clamp(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	bgm_volume = clamp(float(cfg.get_value("audio", "bgm_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clamp(float(cfg.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)

	window_mode = int(cfg.get_value("display", "window_mode", 0))
	vsync_enabled = bool(cfg.get_value("display", "vsync_enabled", true))

	text_speed_idx = int(cfg.get_value("gameplay", "text_speed_idx", 1))
	auto_delay = float(cfg.get_value("gameplay", "auto_delay", 2.0))
	skip_unread = bool(cfg.get_value("gameplay", "skip_unread", false))

func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "bgm_volume", bgm_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)

	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "vsync_enabled", vsync_enabled)

	cfg.set_value("gameplay", "text_speed_idx", text_speed_idx)
	cfg.set_value("gameplay", "auto_delay", auto_delay)
	cfg.set_value("gameplay", "skip_unread", skip_unread)

	cfg.save(SETTINGS_FILE_PATH)
	settings_changed.emit()

func apply_all_settings() -> void:
	# 1. 音频应用
	if is_instance_valid(AudioManager):
		AudioManager.set_master_volume(master_volume)
		AudioManager.set_bgm_volume(bgm_volume)
		AudioManager.set_sfx_volume(sfx_volume)

	# 2. 窗口模式应用 (在非移动端生效)
	if OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD"]:
		match window_mode:
			0:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			1:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			2:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# 3. 垂直同步
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func set_audio_volumes(m: float, b: float, s: float) -> void:
	master_volume = clamp(m, 0.0, 1.0)
	bgm_volume = clamp(b, 0.0, 1.0)
	sfx_volume = clamp(s, 0.0, 1.0)
	apply_all_settings()
	save_settings()

func set_display_config(mode: int, vsync: bool) -> void:
	window_mode = mode
	vsync_enabled = vsync
	apply_all_settings()
	save_settings()

func set_gameplay_config(spd_idx: int, delay: float, skip: bool) -> void:
	text_speed_idx = spd_idx
	auto_delay = delay
	skip_unread = skip
	save_settings()
