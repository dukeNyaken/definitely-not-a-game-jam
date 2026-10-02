class_name RingWidget
extends Control
## Кольцо вещей: иконки по кругу, стрелки по часовой. Жертва уходит в соседа по стрелке.

signal hovered(index: int)
signal clicked(index: int)

var items: Array[ItemState] = []
var interactive: bool = false
var hover_index: int = -1
## Подсветка «жертва → получатель».
var highlight_victim: int = -1
var highlight_pair: int = -1
var hold_progress: float = 0.0
var icon_radius: float = 26.0
var show_badges: bool = true
var show_names: bool = false
var _stream: Array[Dictionary] = []
var _stream_t: float = -1.0
var _stream_from: int = -1
var _stream_to: int = -1
var _stream_color: Color = Color.WHITE


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	if not IconFactory.ready_done:
		IconFactory.icons_ready.connect(queue_redraw)


func set_items(list: Array[ItemState]) -> void:
	items = list.duplicate()
	queue_redraw()


func center() -> Vector2:
	return size * 0.5


func ring_radius() -> float:
	return minf(size.x, size.y) * 0.5 - icon_radius - (30.0 if show_names else 6.0)


## Позиции по часовой (экранная ось Y вниз), начиная сверху.
func angle_of(i: int, n: int = -1) -> float:
	var count := items.size() if n < 0 else n
	return -PI / 2 + TAU * float(i) / maxf(count, 1)


func pos_of(i: int) -> Vector2:
	var a := angle_of(i)
	return center() + Vector2(cos(a), sin(a)) * ring_radius()


func index_at(p: Vector2) -> int:
	for i in items.size():
		if pos_of(i).distance_to(p) <= icon_radius * 1.15:
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseMotion:
		var i := index_at(event.position)
		if i != hover_index:
			hover_index = i
			hovered.emit(i)
			if i >= 0:
				Audio.play(&"ui_hover", -8.0)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := index_at(event.position)
		if i >= 0:
			clicked.emit(i)


## Поток цвета сущности по дуге кольца от жертвы к получателю.
func play_stream(from: int, to: int, color: Color) -> void:
	_stream_from = from
	_stream_to = to
	_stream_color = color
	_stream_t = 0.0


func _process(delta: float) -> void:
	if _stream_t >= 0.0:
		_stream_t += delta
		if _stream_t > 1.6:
			_stream_t = -1.0
		queue_redraw()


func _draw() -> void:
	var n := items.size()
	var c := center()
	var r := ring_radius()
	draw_arc(c, r, 0, TAU, 96, Color(UiKit.BORDER, 0.5), 2.0, true)
	if n == 0:
		return
	# Стрелки между соседями, по часовой.
	for i in n:
		if n == 1:
			break
		var a0 := angle_of(i)
		var a1 := angle_of(i + 1)
		var am := (a0 + a1) * 0.5
		var hot := i == highlight_victim or i == highlight_pair
		var col := UiKit.GOLD if hot else Color(UiKit.BORDER, 0.9)
		var gap := (icon_radius + 4.0) / r
		draw_arc(c, r, a0 + gap, a1 - gap, 24, col, 3.0 if hot else 2.0, true)
		_draw_chevron(c + Vector2(cos(am), sin(am)) * r, am + PI / 2, col, 8.0 if hot else 6.0)
	for i in n:
		_draw_item(i)
	if _stream_t >= 0.0 and _stream_from >= 0 and _stream_to >= 0:
		_draw_stream()


func _draw_chevron(p: Vector2, dir_angle: float, col: Color, s: float) -> void:
	var d := Vector2(cos(dir_angle), sin(dir_angle))
	var nrm := Vector2(-d.y, d.x)
	var tip := p + d * s
	var pts := PackedVector2Array([tip, p - d * s * 0.6 + nrm * s * 0.8, p - d * s * 0.6 - nrm * s * 0.8])
	draw_colored_polygon(pts, col)


func _draw_item(i: int) -> void:
	var state := items[i]
	var def := state.def()
	var p := pos_of(i)
	var ir := icon_radius
	var ring_col := def.essence.color
	var hot := i == hover_index or i == highlight_victim
	if i == highlight_pair:
		ring_col = UiKit.GOLD
	draw_circle(p, ir + 3.0, Color(0, 0, 0, 0.6))
	draw_circle(p, ir, Color(0.13, 0.11, 0.13))
	var tex := IconFactory.icon(def.id)
	if tex != null:
		var s := ir * 1.75
		draw_texture_rect(tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	else:
		var font := get_theme_default_font()
		draw_string(font, p + Vector2(-ir, ir * 0.35), def.display_name.substr(0, 2), HORIZONTAL_ALIGNMENT_CENTER, ir * 2.0, int(ir * 0.9), UiKit.TEXT)
	draw_arc(p, ir, 0, TAU, 32, ring_col if hot or i == highlight_pair else Color(ring_col, 0.75), 4.0 if hot else 2.5, true)
	if i == highlight_victim and hold_progress > 0.0:
		draw_arc(p, ir + 7.0, -PI / 2, -PI / 2 + TAU * hold_progress, 48, UiKit.DANGER, 5.0, true)
	if show_badges and state.properties.size() > 0:
		var bp := p + Vector2(ir * 0.72, -ir * 0.72)
		draw_circle(bp, 10.0, UiKit.GOLD)
		var font := get_theme_default_font()
		draw_string(font, bp + Vector2(-10, 5), str(state.properties.size()), HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.1, 0.07, 0.05))
	if show_names:
		var font := get_theme_default_font()
		var lp := p + Vector2(-70, ir + 24.0)
		draw_string_outline(font, lp, def.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 17, 5, Color(0, 0, 0, 0.9))
		draw_string(font, lp, def.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 17, UiKit.TEXT if not hot else UiKit.GOLD)


func _draw_stream() -> void:
	var t := _stream_t / 1.2
	var a0 := angle_of(_stream_from)
	var a1 := angle_of(_stream_to)
	if a1 < a0:
		a1 += TAU
	var r := ring_radius()
	var c := center()
	for k in 16:
		var kt := clampf(t - k * 0.035, 0.0, 1.0)
		if kt <= 0.0 or kt >= 1.0:
			continue
		var a := lerpf(a0, a1, kt)
		var wob := sin(kt * PI) * 14.0 * (1.0 if k % 2 == 0 else -1.0)
		var p := c + Vector2(cos(a), sin(a)) * (r + wob)
		draw_circle(p, 6.0 - k * 0.25, Color(_stream_color, 1.0 - k * 0.04))
