# GameUtils.gd
class_name GameUtils
extends Object

# 动态加载对应天气/时段的背景图
static func load_bg_texture(base_bg_path: String, slot_index: int, current_weather: String) -> Texture2D:
    if base_bg_path == "":
        return null
        
    var active_bg = base_bg_path
    var dot_idx = base_bg_path.rfind(".")
    if dot_idx != -1:
        var prefix = base_bg_path.substr(0, dot_idx)
        var slot_id = ["morning","noon","after","evening"][slot_index] if slot_index < 4 else "morning"
        var w_id = current_weather
        
        # 检索候选：先匹配完整组合，再按时段，再按天气，最后兜底默认
        var candidates = [
            prefix + "_" + slot_id + "_" + w_id + ".jpg",
            prefix + "_" + slot_id + "_" + w_id + ".png",
            prefix + "_" + slot_id + ".jpg",
            prefix + "_" + slot_id + ".png",
            prefix + "_" + w_id + ".jpg",
            prefix + "_" + w_id + ".png",
            base_bg_path
        ]
        for c in candidates:
            if FileAccess.file_exists(c):
                active_bg = c
                break
                
    var tex: Texture2D = null
    if FileAccess.file_exists(active_bg):
        tex = load(active_bg) as Texture2D
        if not tex:
            # 容错：物理绝对路径强行载入，保障未导入资源渲染
            var global_path = ProjectSettings.globalize_path(active_bg)
            var img = Image.load_from_file(global_path)
            if img and not img.is_empty():
                tex = ImageTexture.create_from_image(img)
    return tex
