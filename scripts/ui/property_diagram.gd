class_name PropertyDiagram
extends Control
## Общее кольцо: все родные навыки и поглощённые силы, без переключения деревьев.

signal node_selected(index: int)

const GAP := 0.035
const HUB := 58.0
const INNER := 112.0

var nodes: Array[Dictionary] = []
var selected_node := 0
var _buttons: Array[Button] = []
var _groups: Array[Dictionary] = []
var _hover := -1


func _init() -> void:
	custom_minimum_size = Vector2(940, 650)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	resized.connect(_layout)
	IconFactory.icons_ready.connect(queue_redraw)
	mouse_exited.connect(func(): _hover = -1; queue_redraw())


static func tree_nodes(item: ItemState) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"property": null, "parent": -1, "linked": true}]
	var stack: Dictionary = {}
	for entry in PropertyTree.walk(item):
		var prop: Property = entry["property"]
		var depth := int(entry["depth"])
		var parent := 0 if depth == 0 and prop.listen_event == item.def().event_id else int(stack.get(depth - 1, -1))
		if parent >= 0:
			var event := item.def().event_id if parent == 0 else (result[parent]["property"] as Property).emit_event
			if event != prop.listen_event:
				parent = -1
		var linked := parent >= 0 and bool(result[parent]["linked"])
		result.append({"property": prop, "parent": parent, "linked": linked})
		stack[depth] = result.size() - 1
	return result


static func ring_nodes(ring: Ring) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in ring.items:
		var base := result.size()
		var order := 0
		for entry in tree_nodes(item):
			var node := entry.duplicate()
			var parent := int(node["parent"])
			node["parent"] = base + parent if parent >= 0 else -1
			node["state"] = item
			var prop: Property = node["property"]
			node["source"] = item.def_id if prop == null else prop.source_item_id
			if bool(node["linked"]):
				order += 1
			node["order"] = order if bool(node["linked"]) else 0
			result.append(node)
	return result


func show_ring(ring: Ring) -> void:
	var selected_id: StringName = nodes[selected_node]["source"] if not nodes.is_empty() else &""
	nodes = ring_nodes(ring)
	_groups.clear()
	for button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	for i in nodes.size():
		var state: ItemState = nodes[i]["state"]
		if nodes[i]["property"] == null:
			_groups.append({"state": state, "first": i, "last": i})
		else:
			_groups.back()["last"] = i
		var button := UiKit.button("", select_node.bind(i))
		button.focus_mode = Control.FOCUS_ALL
		# Невидимые цели для клавиатурного фокуса; мышь обрабатывает сам сектор.
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for style in [&"normal", &"hover", &"pressed", &"focus"]:
			button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		add_child(button)
		_buttons.append(button)
	_layout()
	if not nodes.is_empty():
		select_node(maxi(index_of(selected_id), 0))
	else:
		queue_redraw()


func index_of(id: StringName) -> int:
	for i in nodes.size():
		if nodes[i]["source"] == id:
			return i
	return -1


func select_node(index: int) -> void:
	if nodes.is_empty():
		return
	selected_node = clampi(index, 0, nodes.size() - 1)
	queue_redraw()
	node_selected.emit(selected_node)


func selected_path() -> Array[int]:
	var path: Array[int] = []
	var index := selected_node
	while index >= 0 and not index in path:
		path.append(index)
		index = int(nodes[index]["parent"])
	return path


func _center() -> Vector2:
	return size * 0.5


func _radius() -> float:
	return minf(size.y * 0.5 - 44, size.x * 0.5 - 64)


func _angle(index: int) -> float:
	return -PI * 0.5 + TAU * index / maxi(nodes.size(), 1)


func _layout() -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		button.size = Vector2(46, 46)
		button.position = _center() + Vector2.from_angle(_angle(i)) * (_radius() - 46) - button.size * 0.5
	queue_redraw()


func _color(index: int) -> Color:
	var prop: Property = nodes[index]["property"]
	return (nodes[index]["state"] as ItemState).def().essence.color if prop == null else Color(0.55, 0.55, 0.55)


func _label(index: int) -> String:
	return Db.item(nodes[index]["source"]).display_name


func _get_tooltip(at_position: Vector2) -> String:
	var index := sector_at(at_position)
	return str(index) if index >= 0 else ""


func _make_custom_tooltip(for_text: String) -> Object:
	var index := int(for_text)
	if not for_text.is_valid_int() or index < 0 or index >= nodes.size():
		return null
	var state: ItemState = nodes[index]["state"]
	var prop: Property = nodes[index]["property"]
	var panel := PanelContainer.new()
	panel.theme = UiKit.theme()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.055, 0.045, 0.065), _color(index), 1, 8, 12))
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 6)
	panel.add_child(content)
	content.add_child(UiKit.label(_label(index), 20, UiKit.GOLD))
	if prop == null:
		content.add_child(UiKit.label("%s · Облик %s" % [state.def().input_label, MasteryWheel.ROMAN[state.appearance - 1]], 16))
		var lv := Mastery.level(state.def_id)
		var target := int(Mastery.rules["thresholds"][mini(lv, 2)])
		var xp := int(Mastery.xp.get(state.def_id, 0))
		var bar := ProgressBar.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(180, 5)
		bar.show_percentage = false
		bar.max_value = target
		bar.value = xp
		bar.add_theme_stylebox_override(&"background", UiKit.box(Color(0.2, 0.16, 0.21), Color.TRANSPARENT, 0, 0, 0))
		bar.add_theme_stylebox_override(&"fill", UiKit.box(UiKit.GOLD, Color.TRANSPARENT, 0, 0, 0))
		content.add_child(bar)
		content.add_child(UiKit.label("%d / %d XP" % [xp, target], 15, UiKit.MUTED))
	else:
		content.add_child(UiKit.label("Поглощённая сила", 16))
		content.add_child(UiKit.label("Носитель: %s" % state.def().display_name, 15, UiKit.MUTED))
		content.add_child(UiKit.label("%d XP · не растёт" % int(Mastery.xp.get(nodes[index]["source"], 0)), 15, UiKit.MUTED))
	return panel


func sector_at(point: Vector2) -> int:
	if nodes.is_empty():
		return -1
	var offset := point - _center()
	if offset.length() < HUB or offset.length() > _radius() + 12:
		return -1
	var step := TAU / nodes.size()
	var index := int(fposmod(offset.angle() + PI * 0.5 + step * 0.5, TAU) / step)
	if offset.length() < INNER:
		for group in _groups:
			if index >= int(group["first"]) and index <= int(group["last"]):
				return int(group["first"])
	return index


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = sector_at(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover >= 0 else Control.CURSOR_ARROW
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := sector_at(event.position)
		if index >= 0:
			select_node(index)
			_buttons[index].grab_focus()
			accept_event()


func _draw() -> void:
	if nodes.is_empty():
		return
	var radius := _radius()
	var step := TAU / nodes.size()
	var path := selected_path()
	draw_circle(_center(), radius + 14, Color(0.065, 0.05, 0.075))
	draw_arc(_center(), radius + 13, 0, TAU, 112, Color(UiKit.GOLD, 0.22), 1, true)
	for group in _groups:
		var state: ItemState = group["state"]
		var from := _angle(int(group["first"])) - step * 0.5 + GAP
		var to := _angle(int(group["last"])) + step * 0.5 - GAP
		var color := state.def().essence.color
		_band(HUB + 4, INNER - 4, from, to, Color(color, 0.23))
		draw_arc(_center(), INNER - 4, from, to, 40, Color(color, 0.8), 2, true)
		var mark := _center() + Vector2.from_angle((from + to) * 0.5) * 83
		draw_string(UiKit.body_font(), mark + Vector2(-42, 6), state.def().input_label, HORIZONTAL_ALIGNMENT_CENTER, 84, 16, UiKit.GOLD)
	for i in nodes.size():
		var angle := _angle(i)
		var half := step * 0.5 - GAP
		var color := _color(i)
		var hot := i == selected_node or i == _hover
		_band(INNER, radius, angle - half, angle + half, Color(color, 0.36 if hot else 0.23))
		var outline := _band_points(INNER, radius, angle - half, angle + half)
		outline.append(outline[0])
		draw_polyline(outline, UiKit.GOLD if i == selected_node else Color(color, 0.8 if i in path else 0.35), 2 if i in path or hot else 1, true)
		var icon := IconFactory.icon(nodes[i]["source"])
		var pos := _center() + Vector2.from_angle(angle) * (radius - 46)
		if icon != null:
			draw_circle(pos, 23, Color(0.035, 0.025, 0.04, 0.9))
			draw_texture_rect(icon, Rect2(pos - Vector2(23, 23), Vector2(46, 46)), false)
		draw_string(UiKit.body_font(), pos + Vector2(-68, 42), _label(i), HORIZONTAL_ALIGNMENT_CENTER, 136, 18, UiKit.GOLD if hot else UiKit.TEXT)
		var number_pos := _center() + Vector2.from_angle(angle) * (INNER + 21)
		draw_circle(number_pos, 15, Color(0.04, 0.03, 0.05))
		draw_string(UiKit.body_font(), number_pos + Vector2(-15, 6), str(nodes[i]["order"]) if bool(nodes[i]["linked"]) else "!", HORIZONTAL_ALIGNMENT_CENTER, 30, 18, UiKit.GOLD if i in path else UiKit.TEXT)
	draw_circle(_center(), HUB, Color(0.04, 0.03, 0.05))
	draw_arc(_center(), HUB - 2, 0, TAU, 64, Color(UiKit.GOLD, 0.4), 1, true)
	draw_string(UiKit.title_font(), _center() + Vector2(-50, 7), "%d / 7" % _groups.size(), HORIZONTAL_ALIGNMENT_CENTER, 100, 34, UiKit.GOLD)
	draw_string(UiKit.body_font(), _center() + Vector2(-50, 30), "надето", HORIZONTAL_ALIGNMENT_CENTER, 100, 15, UiKit.MUTED)


func _band(inner: float, outer: float, from: float, to: float, color: Color) -> void:
	draw_colored_polygon(_band_points(inner, outer, from, to), color)


func _band_points(inner: float, outer: float, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 33:
		points.append(_center() + Vector2.from_angle(lerpf(from, to, i / 32.0)) * outer)
	for i in range(32, -1, -1):
		points.append(_center() + Vector2.from_angle(lerpf(from, to, i / 32.0)) * inner)
	return points
