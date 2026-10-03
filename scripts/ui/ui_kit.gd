class_name UiKit
extends RefCounted
## Общий стиль интерфейса: тёмный камень и золото.

const BG := Color(0.04, 0.03, 0.035, 0.94)
const PANEL := Color(0.06, 0.045, 0.05, 0.95)
const BORDER := Color(0.4, 0.3, 0.25)
const GOLD := Color(0.88, 0.76, 0.52)
const TEXT := Color(0.9, 0.84, 0.74)
const MUTED := Color(0.6, 0.54, 0.48)
const DANGER := Color(0.82, 0.14, 0.1)
const BLOOD := Color(0.5, 0.05, 0.04)
const HP := Color(0.62, 0.07, 0.06)
const ARMOR := Color(0.58, 0.6, 0.66)

static var _theme: Theme
static var _title_font: Font
static var _body_font: Font
static var _bold_font: Font


## Цвет вещи в кольцах интерфейса; меч отличается от серых пожертвованных сил.
static func item_color(id: StringName) -> Color:
	return Color(1.0, 0.3, 0.65) if id == &"sword" else Db.item(id).essence.color


static func roman(value: int) -> String:
	var result := ""
	for entry in [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while value >= int(entry[0]):
			result += str(entry[1])
			value -= int(entry[0])
	return result


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://assets/fonts/CormorantSC-Bold.ttf")
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		_body_font = load("res://assets/fonts/PT_Serif-Web-Regular.ttf")
	return _body_font


static func bold_font() -> Font:
	if _bold_font == null:
		var v := FontVariation.new()
		v.base_font = body_font()
		v.variation_embolden = 0.7
		_bold_font = v
	return _bold_font


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 18
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_font(&"font", &"Button", title_font())
	t.set_color(&"font_color", &"Button", TEXT)
	t.set_color(&"font_hover_color", &"Button", Color(1.0, 0.9, 0.75))
	t.set_color(&"font_pressed_color", &"Button", GOLD)
	t.set_color(&"font_focus_color", &"Button", GOLD)
	t.set_color(&"font_disabled_color", &"Button", Color(0.4, 0.36, 0.33))
	t.set_font_size(&"font_size", &"Button", 26)
	t.set_stylebox(&"normal", &"Button", box(Color(0.08, 0.06, 0.065), BORDER.darkened(0.25), 2, 2, 16))
	t.set_stylebox(&"hover", &"Button", box(Color(0.16, 0.06, 0.05), DANGER.darkened(0.15), 2, 2, 16))
	t.set_stylebox(&"pressed", &"Button", box(Color(0.24, 0.07, 0.05), DANGER, 2, 2, 16))
	t.set_stylebox(&"focus", &"Button", box(Color(0, 0, 0, 0), BORDER, 1, 2, 16))
	t.set_stylebox(&"disabled", &"Button", box(Color(0.06, 0.05, 0.05), Color(0.22, 0.2, 0.2), 2, 2, 16))
	t.set_stylebox(&"panel", &"PanelContainer", box(PANEL, BORDER, 2, 2, 18))
	t.set_stylebox(&"normal", &"LineEdit", box(Color(0.03, 0.02, 0.025), BORDER.darkened(0.3), 2, 2, 10))
	t.set_stylebox(&"focus", &"LineEdit", box(Color(0.03, 0.02, 0.025), DANGER.darkened(0.2), 2, 2, 10))
	t.set_color(&"font_color", &"LineEdit", TEXT)
	t.set_color(&"font_placeholder_color", &"LineEdit", MUTED.darkened(0.2))
	t.set_font_size(&"font_size", &"LineEdit", 22)
	t.set_color(&"default_color", &"RichTextLabel", TEXT)
	t.set_font(&"normal_font", &"RichTextLabel", body_font())
	t.set_font(&"bold_font", &"RichTextLabel", bold_font())
	t.set_font_size(&"normal_font_size", &"RichTextLabel", 18)
	t.set_font_size(&"bold_font_size", &"RichTextLabel", 18)
	t.set_font(&"font", &"CheckButton", body_font())
	t.set_color(&"font_color", &"CheckButton", TEXT)
	t.set_font(&"font", &"OptionButton", body_font())
	t.set_stylebox(&"normal", &"OptionButton", box(Color(0.08, 0.06, 0.065), BORDER.darkened(0.25), 2, 2, 10))
	t.set_stylebox(&"hover", &"OptionButton", box(Color(0.16, 0.06, 0.05), DANGER.darkened(0.15), 2, 2, 10))
	t.set_stylebox(&"slider", &"HSlider", box(Color(0.1, 0.07, 0.07), BORDER.darkened(0.2), 1, 2, 3))
	t.set_stylebox(&"grabber_area", &"HSlider", box(BLOOD, BLOOD, 1, 2, 3))
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", box(DANGER.darkened(0.2), DANGER, 1, 2, 3))
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


## Крупные надписи (от 26) — заголовочным шрифтом Cormorant SC.
static func label(text: String, size: int = 18, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	if size >= 26:
		l.add_theme_font_override(&"font", title_font())
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
