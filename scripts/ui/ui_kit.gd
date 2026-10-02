class_name UiKit
extends RefCounted
## Общий стиль интерфейса: тёмный камень и золото.

const BG := Color(0.07, 0.06, 0.08, 0.92)
const PANEL := Color(0.11, 0.09, 0.12, 0.94)
const BORDER := Color(0.55, 0.44, 0.26)
const GOLD := Color(1.0, 0.8, 0.4)
const TEXT := Color(0.93, 0.9, 0.84)
const MUTED := Color(0.66, 0.62, 0.58)
const DANGER := Color(0.95, 0.32, 0.25)
const HP := Color(0.82, 0.18, 0.16)
const ARMOR := Color(0.62, 0.68, 0.78)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_color(&"font_color", &"Button", TEXT)
	t.set_color(&"font_hover_color", &"Button", GOLD)
	t.set_color(&"font_pressed_color", &"Button", GOLD)
	t.set_color(&"font_focus_color", &"Button", GOLD)
	t.set_font_size(&"font_size", &"Button", 22)
	t.set_stylebox(&"normal", &"Button", box(Color(0.14, 0.11, 0.13), BORDER.darkened(0.3), 2, 6, 14))
	t.set_stylebox(&"hover", &"Button", box(Color(0.2, 0.15, 0.15), GOLD, 2, 6, 14))
	t.set_stylebox(&"pressed", &"Button", box(Color(0.26, 0.19, 0.14), GOLD, 2, 6, 14))
	t.set_stylebox(&"focus", &"Button", box(Color(0, 0, 0, 0), GOLD.darkened(0.2), 1, 6, 14))
	t.set_stylebox(&"disabled", &"Button", box(Color(0.1, 0.09, 0.1), Color(0.3, 0.28, 0.28), 2, 6, 14))
	t.set_stylebox(&"panel", &"PanelContainer", box(PANEL, BORDER, 2, 8, 18))
	t.set_stylebox(&"normal", &"LineEdit", box(Color(0.05, 0.04, 0.05), BORDER.darkened(0.3), 2, 4, 10))
	t.set_stylebox(&"focus", &"LineEdit", box(Color(0.05, 0.04, 0.05), GOLD, 2, 4, 10))
	t.set_color(&"font_color", &"LineEdit", TEXT)
	t.set_font_size(&"font_size", &"LineEdit", 22)
	t.set_color(&"default_color", &"RichTextLabel", TEXT)
	t.set_font_size(&"normal_font_size", &"RichTextLabel", 18)
	t.set_font_size(&"bold_font_size", &"RichTextLabel", 18)
	_theme = t
	return t


static func box(bg: Color, border: Color, border_w: int = 2, radius: int = 8, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s


static func label(text: String, size: int = 18, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = align
	return l


static func outlined(l: Label, outline: int = 6) -> Label:
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override(&"outline_size", outline)
	return l


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Audio.play(&"ui_click")
		cb.call()
	)
	b.mouse_entered.connect(func(): Audio.play(&"ui_hover", -8.0))
	return b


static func rich(bbcode: String, size: int = 18) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override(&"normal_font_size", size)
	r.add_theme_font_size_override(&"bold_font_size", size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func hex(c: Color) -> String:
	return c.to_html(false)


static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
