extends Node
## SaveSystem — 全局存档/读档单例（3槽位）
## 存储位置：user://saves/slot_N.sav（AES-256 加密）

const SAVE_DIR  = "user://saves/"
const SAVE_VER  = 6
# 内置对称密钥（防止普通用户用记事本直接篇改存档）
# 注：高技术玩家可以逆向破解，单机游戏此级别已足够
# 如需更高安全性，应将敏感数据全部迁移到服务端
const _SAVE_KEY = "xh_zkgame_2026_s3cr3t_k3y_xhv1!!"  # 32 字节 AES-256

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(reason: String)
## S3 · 读档失败信号：code 见 LoadError，msg 为可直接展示给玩家的中文提示
signal load_failed(slot: int, code: int, msg: String)

# ── S3 · 读档错误码与降级路径 ────────────────────────────────
## 目的：把「静默 return false」升级为可识别错误码，UI 据此给出准确提示，
## 而不是把「存档损坏」误报成「没有存档」。任何一条路径都不得崩溃。
enum LoadError {
    NONE            = 0,  # 成功
    NOT_FOUND       = 1,  # 槽位为空（正常状态，非错误）
    DECRYPT_FAILED  = 2,  # 打开/解密失败：密钥不符、文件截断或被占用
    CORRUPTED       = 3,  # 解密成功但内容不是合法 JSON 字典
    VERSION_TOO_NEW = 4,  # 存档版本高于当前游戏，拒绝降级读取（防写坏）
    MIGRATE_FAILED  = 5,  # 迁移链执行失败
}

const LOAD_ERROR_MSG = {
    LoadError.NONE:            "读取成功",
    LoadError.NOT_FOUND:       "该存档位是空的",
    LoadError.DECRYPT_FAILED:  "存档无法解密，可能已损坏或被修改过",
    LoadError.CORRUPTED:       "存档内容已损坏，无法解析",
    LoadError.VERSION_TOO_NEW: "存档来自更新版本的游戏，请先更新后再读取",
    LoadError.MIGRATE_FAILED:  "存档版本升级失败",
}

## 最近一次 load_game 的结果，供 UI 在 load_game() 返回 false 后查询
var last_load_error: int = LoadError.NONE
var last_load_error_msg: String = ""

## 统一失败出口：记录错误码 + 打日志 + 发信号；始终返回 false 供调用方直接 return
func _fail_load(slot: int, code: int, detail: String = "") -> bool:
    last_load_error = code
    last_load_error_msg = LOAD_ERROR_MSG.get(code, "未知存档错误")
    var log_line = "SaveSystem: [E%d] Slot %d —— %s" % [code, slot, last_load_error_msg]
    if detail != "":
        log_line += " | " + detail
    if code == LoadError.NOT_FOUND:
        push_warning(log_line)   # 空槽位是正常状态，不作为 error 上报
    else:
        push_error(log_line)
    load_failed.emit(slot, code, last_load_error_msg)
    return false

## 供 UI 查询最近一次读档失败详情（未失败时 code 为 NONE）
func get_last_load_error() -> Dictionary:
    return {"code": last_load_error, "msg": last_load_error_msg}

# ── 存档 ─────────────────────────────────────────────────────
func save_game(slot: int = 0) -> bool:
    var data = {
        "ver":               SAVE_VER,
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
        "weather":           GameManager.current_weather,
        "hw_status":         GameManager.hw_status,
        "current_hw_subject": GameManager.current_hw_subject,
        "quiz_bonus_score":  GameManager.quiz_bonus_score,
        "hw_neglect_count":  GameManager.hw_neglect_count,
        "current_deskmate":  GameManager.current_deskmate,
        "inventory":         GameManager.inventory.duplicate(),
        "diary":             GameManager.diary.duplicate(true),
        "recent_logs":       GameManager.recent_logs.duplicate(true),
        "char_initiative":   GameManager.get_initiative_save_data(),
        "cooking":           CookingManager.get_save_data(),
        "season":            SeasonManager.get_save_data(),
        "subject_scores":    GameManager.subject_scores.duplicate(),
        "char_mood":         GameManager.char_mood.duplicate(),
        "wardrobe":          WardrobeManager.get_save_data(),
        "relationship_state": GameManager.relationship_state.duplicate(),
    }

    if not DirAccess.dir_exists_absolute(SAVE_DIR):
        DirAccess.make_dir_recursive_absolute(SAVE_DIR)

    var path = SAVE_DIR + "slot_%d.sav" % slot
    var file = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, _SAVE_KEY)
    if file == null:
        var msg = "无法写入/加密存档：%s" % path
        push_error(msg); save_failed.emit(msg); return false

    var body_text = JSON.stringify(data)
    file.store_string(body_text)
    file.close()

    # 写入轻量元数据文件（供 UI 快速读取，无需完整解密）
    # S3：附带 body_hash，读档时与主体配对校验，识别「meta 被单独替换/存档被掉包」
    var meta_path = SAVE_DIR + "slot_%d.meta" % slot
    var mf = FileAccess.open(meta_path, FileAccess.WRITE)
    if mf:
        mf.store_string(JSON.stringify({
            "saved_at":    data["saved_at"],
            "day":         data["day"],
            "player_name": data["player_name"],
            "body_hash":   str(body_text.hash())
        }))
        mf.close()

    save_completed.emit(slot)
    return true

# ── 读档 ─────────────────────────────────────────────────────
func load_game(slot: int = 0) -> bool:
    var enc_path  = SAVE_DIR + "slot_%d.sav" % slot
    var json_path = SAVE_DIR + "slot_%d.json" % slot
    var parsed: Variant = null
    var raw_text: String = ""

    # 进入前先复位错误态，避免读到上一次失败的残留码
    last_load_error = LoadError.NONE
    last_load_error_msg = ""

    if FileAccess.file_exists(enc_path):
        # 读加密存档
        var file = FileAccess.open_encrypted_with_pass(enc_path, FileAccess.READ, _SAVE_KEY)
        if file == null:
            # 密钥不符 / 文件截断 / 被占用 —— 与「空槽位」严格区分
            return _fail_load(slot, LoadError.DECRYPT_FAILED,
                "open_err=%d path=%s" % [FileAccess.get_open_error(), enc_path])
        raw_text = file.get_as_text()
        file.close()
        parsed = JSON.parse_string(raw_text)

    elif FileAccess.file_exists(json_path):
        # 兼容旧明文存档，读完自动迁移为加密格式
        var file = FileAccess.open(json_path, FileAccess.READ)
        if file == null:
            return _fail_load(slot, LoadError.DECRYPT_FAILED, "无法读取旧明文存档：%s" % json_path)
        raw_text = file.get_as_text()
        file.close()
        parsed = JSON.parse_string(raw_text)
        if parsed == null or not parsed is Dictionary:
            return _fail_load(slot, LoadError.CORRUPTED, "旧明文存档 JSON 解析失败：%s" % json_path)
        if int(parsed.get("ver", 1)) > SAVE_VER:
            return _fail_load(slot, LoadError.VERSION_TOO_NEW,
                "存档 v%d > 本体 v%d" % [int(parsed.get("ver", 1)), SAVE_VER])
        # 先把旧数据写入内存，再存为加密格式，最后删旧文件
        if not load_from_dict(parsed):
            return _fail_load(slot, LoadError.MIGRATE_FAILED, "旧明文存档迁移失败")
        save_game(slot)
        DirAccess.open(SAVE_DIR).remove("slot_%d.json" % slot)
        print("SaveSystem: Slot %d 已自动迁移为加密存档" % slot)
        load_completed.emit(slot)
        return true
    else:
        return _fail_load(slot, LoadError.NOT_FOUND)

    if parsed == null or not parsed is Dictionary:
        # 解密成功但内容不可解析 —— 典型为密文截断/磁盘写坏
        return _fail_load(slot, LoadError.CORRUPTED, "JSON.parse_string 返回 %s" % type_string(typeof(parsed)))

    var orig_ver = int(parsed.get("ver", 1))
    if orig_ver > SAVE_VER:
        # 高版本存档一律拒读：迁移链只能升不能降，硬读会用默认值覆盖新字段并回写，反而毁档
        return _fail_load(slot, LoadError.VERSION_TOO_NEW, "存档 v%d > 本体 v%d" % [orig_ver, SAVE_VER])

    # .meta 与主体配对校验（仅告警不阻断）：老存档无 body_hash 时自动跳过，保证存量档零影响
    _verify_meta_pairing(slot, raw_text)

    var success = load_from_dict(parsed)
    if not success:
        return _fail_load(slot, LoadError.MIGRATE_FAILED, "load_from_dict 返回 false")
    # 如果版本发生迁移，自动回写升级后的存档，保证磁盘上是最新的 schema
    if orig_ver < SAVE_VER:
        save_game(slot)
        print("SaveSystem: Slot %d 存档已升级至 v%d 并已回写磁盘" % [slot, SAVE_VER])
    last_load_error = LoadError.NONE
    last_load_error_msg = ""
    load_completed.emit(slot)
    return true

## S3 · .meta 与主体配对校验
## 只在 meta 里存在 body_hash 时比对；不一致仅 push_warning 并重写 meta，
## 不阻断读档 —— 主体本身已解析成功，阻断反而会把可玩存档判死。
func _verify_meta_pairing(slot: int, body_text: String) -> void:
    var meta_path = SAVE_DIR + "slot_%d.meta" % slot
    if not FileAccess.file_exists(meta_path):
        push_warning("SaveSystem: Slot %d 缺少 .meta（不影响读档，将在下次存档时重建）" % slot)
        return
    var mf = FileAccess.open(meta_path, FileAccess.READ)
    if mf == null:
        return
    var meta = JSON.parse_string(mf.get_as_text())
    mf.close()
    if not meta is Dictionary or not meta.has("body_hash"):
        return   # 旧版 meta 无校验字段 —— 向后兼容，跳过
    if str(meta["body_hash"]) != str(body_text.hash()):
        push_warning("SaveSystem: Slot %d 的 .meta 与存档主体不配对（可能被单独替换），已按主体为准继续读取" % slot)

# ── 存档版本迁移与架构演进 ──────────────────────────────
func _migrate_save_dict(d: Dictionary) -> Dictionary:
    var ver = int(d.get("ver", 1))
    if ver < SAVE_VER:
        print("SaveSystem: 正在对存档数据运行版本迁移流程...")
        if ver < 2:
            d = _migrate_v1_to_v2(d)
            d["ver"] = 2
        if ver < 3:
            d = _migrate_v2_to_v3(d)
            d["ver"] = 3
        if ver < 4:
            d = _migrate_v3_to_v4(d)
            d["ver"] = 4
        if ver < 5:
            d = _migrate_v4_to_v5(d)
            d["ver"] = 5
        if ver < 6:
            d = _migrate_v5_to_v6(d)
            d["ver"] = 6
        # 未来升级流程可在此追加
    return d

func _migrate_v1_to_v2(d: Dictionary) -> Dictionary:
    print("SaveSystem: 执行迁移 v1 -> v2 (初始化新增的游戏机制数据结构)")
    if not d.has("cooking"):
        d["cooking"] = {}
    if not d.has("season"):
        d["season"] = {}
    if not d.has("hw_status"):
        d["hw_status"] = 0
    if not d.has("hw_neglect_count"):
        d["hw_neglect_count"] = 0
    return d

func _migrate_v2_to_v3(d: Dictionary) -> Dictionary:
    print("SaveSystem: 执行迁移 v2 -> v3 (分科复习系统)")
    if not d.has("subject_scores"):
        d["subject_scores"] = {"chinese": 0, "math": 0, "english": 0, "science": 0, "society": 0}
    return d

func _migrate_v3_to_v4(d: Dictionary) -> Dictionary:
    print("SaveSystem: 执行迁移 v3 -> v4 (角色心情持久化)")
    if not d.has("char_mood"):
        d["char_mood"] = {}  # 空字典，首次换日时自动刷新
    return d

func _migrate_v4_to_v5(d: Dictionary) -> Dictionary:
    print("SaveSystem: 执行迁移 v4 -> v5 (关系状态机占位)")
    if not d.has("relationship_state"):
        d["relationship_state"] = {}
    return d

func _migrate_v5_to_v6(d: Dictionary) -> Dictionary:
    print("SaveSystem: 执行迁移 v5 -> v6 (关系状态机持久化)")
    if not d.has("relationship_state"):
        d["relationship_state"] = {}
    return d

func load_from_dict(d: Dictionary) -> bool:
    # 自动执行存档结构迁移，确保新加入的系统有默认的数据字段
    d = _migrate_save_dict(d)
    
    GameManager.day              = int(d.get("day",              1))
    GameManager.day_of_week      = int(d.get("day_of_week",      1))
    GameManager.slot_index       = int(d.get("slot_index",       0))
    GameManager.money            = int(d.get("money",            100))
    GameManager.player_name      = d.get("player_name",      "同学")
    GameManager.school_name      = d.get("school_name",      "西湖中学")
    GameManager.current_weather  = d.get("weather",              "sunny")
    GameManager.hw_status        = int(d.get("hw_status",        0))
    GameManager.current_hw_subject = d.get("current_hw_subject", "")
    GameManager.quiz_bonus_score = int(d.get("quiz_bonus_score", 0))
    GameManager.hw_neglect_count = int(d.get("hw_neglect_count", 0))
    GameManager.current_deskmate = d.get("current_deskmate", "generic_boy_trouble")
    GameManager.flags            = d.get("flags",            {})
    GameManager.inventory        = d.get("inventory",        {})
    GameManager.diary            = d.get("diary",            [])
    GameManager.recent_logs      = d.get("recent_logs",      [])


    var saved_stats = d.get("stats", {})
    for k in GameManager.stats.keys():
        if saved_stats.has(k): GameManager.stats[k] = int(saved_stats[k])

    var saved_fav = d.get("favorability", {})
    for k in GameManager.favorability.keys():
        if saved_fav.has(k): GameManager.favorability[k] = int(saved_fav[k])

    var saved_initiative = d.get("char_initiative", {})
    if not saved_initiative.is_empty():
        GameManager.load_initiative_save_data(saved_initiative)

    var saved_cooking = d.get("cooking", {})
    if not saved_cooking.is_empty(): CookingManager.load_save_data(saved_cooking)

    var saved_season = d.get("season", {})
    if not saved_season.is_empty(): SeasonManager.load_save_data(saved_season)

    # 分科复习数据恢复
    var saved_subjects = d.get("subject_scores", {})
    for s in GameManager.subject_scores.keys():
        if saved_subjects.has(s):
            GameManager.subject_scores[s] = int(saved_subjects[s])

    # 角色心情恢复（v4+）
    var saved_moods = d.get("char_mood", {})
    for char_id in saved_moods.keys():
        GameManager.char_mood[char_id] = saved_moods[char_id]

    # 衣橱数据恢复（v5+）
    var saved_wardrobe = d.get("wardrobe", {})
    if not saved_wardrobe.is_empty():
        var wm = get_node_or_null("/root/WardrobeManager")
        if wm: wm.load_save_data(saved_wardrobe)

    # 关系状态恢复（v6+）：先取存档值，再由 favorability / 冷战 flag 静默重算，保证一致
    var saved_rel = d.get("relationship_state", {})
    GameManager.relationship_state = saved_rel.duplicate() if saved_rel is Dictionary else {}
    RelationshipManager.recompute_all_states(true)

    # 长假状态属于派生状态，不随存档序列化；读档后按 day 重建
    DailyCycleManager._update_current_holiday()
    GameManager._retroactive_gallery_check()
    GameManager.state_updated.emit()
    return true

# ── 查询存档元数据（用于槽位 UI 显示）─────────────────────
func get_slot_meta(slot: int) -> Dictionary:
    # 优先读取轻量 .meta 文件，避免完整解密
    var meta_path = SAVE_DIR + "slot_%d.meta" % slot
    if FileAccess.file_exists(meta_path):
        var mf = FileAccess.open(meta_path, FileAccess.READ)
        if mf:
            var parsed = JSON.parse_string(mf.get_as_text())
            mf.close()
            if parsed is Dictionary and not parsed.is_empty():
                return {
                    "saved_at":    parsed.get("saved_at",    "--"),
                    "day":         parsed.get("day",         1),
                    "player_name": parsed.get("player_name", "同学"),
                }

    # 兑底：完整解密（用于旧版存档无 .meta 文件的情况）
    var enc_path  = SAVE_DIR + "slot_%d.sav" % slot
    var json_path = SAVE_DIR + "slot_%d.json" % slot
    var parsed: Variant = null

    if FileAccess.file_exists(enc_path):
        var file = FileAccess.open_encrypted_with_pass(enc_path, FileAccess.READ, _SAVE_KEY)
        if file == null: return {}
        parsed = JSON.parse_string(file.get_as_text())
        file.close()
    elif FileAccess.file_exists(json_path):
        var file = FileAccess.open(json_path, FileAccess.READ)
        if file == null: return {}
        parsed = JSON.parse_string(file.get_as_text())
        file.close()
    else:
        return {}

    if parsed == null or not parsed is Dictionary: return {}
    return {
        "saved_at":    parsed.get("saved_at",    "--"),
        "day":         parsed.get("day",         1),
        "player_name": parsed.get("player_name", "同学"),
    }

# ── 简便方法：单槽读写（兼容旧代码调用）────────────────────
func has_save() -> bool:
    return FileAccess.file_exists(SAVE_DIR + "slot_0.sav") \
        or FileAccess.file_exists(SAVE_DIR + "slot_0.json")

func delete_slot(slot: int) -> bool:
    var ok = true
    for ext in ["sav", "json", "meta"]:
        var p = SAVE_DIR + "slot_%d.%s" % [slot, ext]
        if FileAccess.file_exists(p):
            ok = ok and DirAccess.open(SAVE_DIR).remove("slot_%d.%s" % [slot, ext]) == OK
    return ok
