class_name PropertyDiagram
extends Control
## Родной навык в центре; связи берутся из событий, а не из порядка жертв.

signal node_selected(index: int)

var state: ItemState
var nodes: Array[Dictionary] = []
var selected_node := 0
var _buttons: Array[Button] = []


func _init() -> void:
	custom_minimum_size = Vector2(860, 470)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	resized.connect(_layout)
	IconFactory.icons_ready.connect(_redraw_nodes)


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


func show_item(item: ItemState) -> void:
	state = item
	nodes = tree_nodes(item)
	selected_node = 0
	for button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	for i in nodes.size():
		var button := UiKit.button("", select_node.bind(i))
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.draw.connect(_draw_node.bind(button, i))
		add_child(button)
		_buttons.append(button)
	_layout()
	select_node(0)


func select_node(index: int) -> void:
	selected_node = clampi(index, 0, nodes.size() - 1)
	_redraw_nodes()
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
	return minf(size.y * 0.5 - 62.0, size.x * 0.5 - 125.0)


func _angle(index: int) -> float:
	return -PI * 0.5 + TAU * (index - 1) / maxi(nodes.size() - 1, 1)


func _layout() -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		button.size = Vector2(146, 120) if i == 0 else Vector2(132, 98)
		var center := _center() if i == 0 else _center() + Vector2.from_angle(_angle(i)) * _radius()
		button.position = center - button.size * 0.5
	queue_redraw()


func _redraw_nodes() -> void:
	for i in _buttons.size():
		var prop: Property = nodes[i]["property"]
		var color := state.def().essence.color if i == 0 else Db.essence(prop.essence_id).color
		var linked := bool(nodes[i]["linked"])
		var border := UiKit.GOLD if i == selected_node else color if linked else UiKit.MUTED.darkened(0.4)
		_buttons[i].add_theme_stylebox_override(&"normal", UiKit.box(Color(color, 0.12), border, 2 if i == selected_node else 1, 12, 4))
		_buttons[i].add_theme_stylebox_override(&"hover", UiKit.box(Color(color, 0.2), color, 2, 12, 4))
		_buttons[i].tooltip_text = "%s · %s" % [state.def().input_label, state.def().event_label()] if i == 0 else prop.display_name()
		_buttons[i].queue_redraw()


func _draw_node(button: Button, index: int) -> void:
	var prop: Property = nodes[index]["property"]
	var id := state.def_id if index == 0 else prop.source_item_id
	var icon := IconFactory.icon(id)
	if icon != null:
		var width := 46.0 if index == 0 else 36.0
		button.draw_texture_rect(icon, Rect2(Vector2(button.size.x * 0.5 - width * 0.5, 8), Vector2(width, width)), false)
	var name := state.def().display_name if index == 0 else Db.essence(prop.essence_id).display_name
	var event := state.def().event_id if index == 0 else prop.emit_event
	var y := 77.0 if index == 0 else 64.0
	button.draw_string(UiKit.body_font(), Vector2(0, y), name, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 19, UiKit.TEXT)
	var caption := "%s · %s" % [state.def().input_label, PropertyTree.event_label(event)] if index == 0 else PropertyTree.event_label(event)
	button.draw_string(UiKit.body_font(), Vector2(0, y + 23), caption, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 14, UiKit.GOLD if index == 0 else UiKit.MUTED)
	if not bool(nodes[index]["linked"]):
		button.draw_line(Vector2(10, 10), Vector2(22, 10), UiKit.DANGER, 2.0)


func _draw() -> void:
	if state == null:
		return
	var center := _center()
	draw_arc(center, _radius(), 0, TAU, 96, Color(UiKit.GOLD, 0.1), 1, true)
	var path := selected_path()
	for i in range(1, nodes.size()):
		var parent := int(nodes[i]["parent"])
		if parent < 0:
			continue
		var points := _edge_points(parent, i)
		var color := Db.essence((nodes[i]["property"] as Property).essence_id).color
		var highlighted := i in path
		draw_polyline(points, Color(color, 0.95 if highlighted else 0.42), 3.0 if highlighted else 1.5, true)
		var end := points[points.size() - 1]
		var direction := (end - points[points.size() - 2]).normalized()
		var side := direction.orthogonal() * 5
		draw_colored_polygon(PackedVector2Array([end, end - direction * 11 + side, end - direction * 11 - side]), color)
	draw_circle(center, 96, Color(0.04, 0.03, 0.05))
	draw_arc(center, 94, 0, TAU, 64, Color(UiKit.GOLD, 0.2), 2, true)
	var progress := float(Mastery.xp.get(state.def_id, 0)) / float(Mastery.rules["thresholds"].back())
	if progress > 0:
		draw_arc(center, 94, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, UiKit.GOLD, 3, true)
	if nodes.size() == 1:
		draw_string(UiKit.body_font(), center + Vector2(-230, 155), "Жертвы добавят сюда силы соседей", HORIZONTAL_ALIGNMENT_CENTER, 460, 18, UiKit.MUTED)


func _border_point(index: int, toward: Vector2) -> Vector2:
	var button := _buttons[index]
	var center := button.position + button.size * 0.5
	var direction := (toward - center).normalized()
	if index == 0:
		return center + direction * 98.0
	var half := button.size * 0.5 + Vector2(5, 5)
	var x := half.x / maxf(absf(direction.x), 0.001)
	var y := half.y / maxf(absf(direction.y), 0.001)
	return center + direction * minf(x, y)


func _edge_points(parent: int, child: int) -> PackedVector2Array:
	var from := _buttons[parent].position + _buttons[parent].size * 0.5
	var to := _buttons[child].position + _buttons[child].size * 0.5
	var control := (from + to) * 0.5
	if parent > 0 and Geometry2D.get_closest_point_to_segment(_center(), from, to).distance_to(_center()) < 110:
		var angle := (_angle(parent) + _angle(child)) * 0.5
		control = _center() + Vector2.from_angle(angle) * (_radius() + 25)
	var start := _border_point(parent, control)
	var end := _border_point(child, control)
	var points := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		points.append((1 - t) * (1 - t) * start + 2 * (1 - t) * t * control + t * t * end)
	return points
