class_name UI
extends RefCounted

static func lbl(text: String, fs := 22, col := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", col)
    return l

static func box(c: Color, r := 16) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = c
    s.set_corner_radius_all(r)
    s.set_content_margin_all(8)
    return s

static func btn(text: String, size := Vector2(240, 56), fs := 22) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = size
    b.add_theme_font_size_override("font_size", fs)
    b.add_theme_stylebox_override("normal", box(Color("3f51b5"), 14))
    b.add_theme_stylebox_override("hover", box(Color("5c6bc0"), 14))
    b.add_theme_stylebox_override("pressed", box(Color("283593"), 14))
    return b
