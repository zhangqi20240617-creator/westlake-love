# ThemeUtils.gd
class_name ThemeUtils
extends Object

# 创建配置好的 StyleBoxFlat
static func create_style(
    bg: Color,
    radius: int = 8,
    border_col: Color = Color.TRANSPARENT,
    border_w: int = 0,
    margin_all: int = -1,
    margin_left: int = -1,
    margin_right: int = -1,
    margin_top: int = -1,
    margin_bottom: int = -1
) -> StyleBoxFlat:
    var s = StyleBoxFlat.new()
    s.bg_color = bg
    s.set_corner_radius_all(radius)
    if border_w > 0:
        s.set_border_width_all(border_w)
        s.border_color = border_col
    
    if margin_all >= 0:
        s.content_margin_left = margin_all
        s.content_margin_right = margin_all
        s.content_margin_top = margin_all
        s.content_margin_bottom = margin_all
    else:
        if margin_left >= 0: s.content_margin_left = margin_left
        if margin_right >= 0: s.content_margin_right = margin_right
        if margin_top >= 0: s.content_margin_top = margin_top
        if margin_bottom >= 0: s.content_margin_bottom = margin_bottom
        
    return s

## \u4e3a\u6309\u9215\u5e94\u7528 normal/hover/pressed \u4e09\u6001 Accent \u6837\u5f0f\uff08\u987b\u4e0e\u80cc\u666f\u8272\u5bf9\u6bd4\uff09
## btn:       \u76ee\u6807 Button \u8282\u70b9
## accent:    \u4e3b\u9898\u8272\uff08\u5982 Color(0.3, 0.35, 0.55)\uff09
## radius:    \u5706\u89d2\uff0c\u9ed8\u8ba4 8
## border_w:  \u8fb9\u6846\u5bbd\u5ea6\uff0c\u9ed8\u8ba4 1
static func style_accent_btn(btn: Button, accent: Color,
        radius: int = 8, border_w: int = 1) -> void:
    var s = create_style(accent.darkened(0.45), radius, accent.lightened(0.15), border_w)
    btn.add_theme_stylebox_override("normal", s)
    var h = s.duplicate(); h.bg_color = accent.darkened(0.2)
    btn.add_theme_stylebox_override("hover", h)
    var p = s.duplicate(); p.bg_color = accent.lightened(0.05)
    btn.add_theme_stylebox_override("pressed", p)
    btn.add_theme_color_override("font_color", Color(0.94, 0.92, 0.88, 1))

## \u5feb\u901f\u751f\u6210\u5361\u7247\u5e95\u8272 + \u8fb9\u6846\u7684\u901a\u7528\u5361\u7247\u6837\u5f0f
## border_accent: \u4e0d\u4e3a TRANSPARENT \u65f6\u542f\u7528\u5bbd\u5ea6\u4e3a 1 \u7684\u8fb9\u6846
static func make_card_style(bg: Color = Color(0.08, 0.10, 0.16),
        border_accent: Color = Color.TRANSPARENT,
        radius: int = 8) -> StyleBoxFlat:
    var bw = 0 if border_accent == Color.TRANSPARENT else 1
    return create_style(bg, radius, border_accent, bw)
