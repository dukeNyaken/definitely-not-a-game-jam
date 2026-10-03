class_name MasteryWheel
extends Control
## Семь секторов: опыт растёт от центра, яркий слой — прибавка этого забега.

signal item_selected(id: StringName)
signal appearance_inspected(id: StringName, tier: int)

const GAP := 0.045
const DURATION := 1.65
const STAGGER := 0.09
const ROMAN := ["I", "II", "III"]

var selected_id: StringName = &"sword"
## Коллекция показывает три облика в каждом секторе и текущий постоянный прогресс.
var collection_mode := false
var start_xp: Dictionary = {}
var end_xp: Dictionary = {}
var earned_xp: Dictionary = {}
var _buttons: Array[Button] = []
var _time := 0.0
var _hover: StringName = &""


func _init() -> void:
	custom_minimum_size = Vector2(610, 570)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	start_xp = Mastery.run_start_xp.duplicate()
	end_xp = Mastery.xp.duplicate()
	earned_xp = Mastery.run_xp.duplicate()
	for id in Db.ITEM_IDS:
		var button := Button.new()
		button.name = String(id)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style in [&"normal", &"hover", &"pressed", &"focus"]:
			button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		button.pressed.connect(select_item.bind(id))
		add_child(button)
		_buttons.append(button)
	resized.connect(_layout_buttons)
	mouse_exited.connect(func():
		_hover = &""
		queue_redraw())
	IconFactory.icons_ready.connect(queue_redraw)
	_layout_buttons()
	if collection_mode:
		_refresh_collection()
		Mastery.changed.connect(_refresh_collection)
	else:
		Mastery.progress_reset.connect(_refresh_after_reset)


func _refresh_after_reset() -> void:
	start_xp = Mastery.run_start_xp.duplicate()
	end_xp = Mastery.xp.duplicate()
	earned_xp = Mastery.run_xp.duplicate()
	finish_animation()


func _refresh_collection() -> void:
	start_xp = Mastery.xp.duplicate()
	end_xp = Mastery.xp.duplicate()
	earned_xp.clear()
	finish_animation()


func select_item(id: StringName) -> void:
	selected_id = id
	queue_redraw()
	item_selected.emit(id)


func _center() -> Vector2:
	return size * 0.5


func _radius() -> float:
	return minf(size.x * 0.5 - 42.0, size.y * 0.5 - 34.0) if collection_mode else minf(size.x * 0.5 - 124.0, size.y * 0.5 - 90.0)


func _form_radius() -> float:
	return _radius() - 102.0 if collection_mode else _radius()


func _icon_position(index: int) -> Vector2:
	return _center() + Vector2.from_angle(_angle(index)) * (_radius() - 46.0 if collection_mode else _radius() + 56.0)


func _angle(index: int) -> float:
	return -PI * 0.5 + TAU * index / Db.ITEM_IDS.size()


func _layout_buttons() -> void:
	for i in _buttons.size():
		_buttons[i].size = Vector2(46, 46)
		_buttons[i].position = _icon_position(i) - _buttons[i].size * 0.5


func _get_tooltip(at_position: Vector2) -> String:
	var index := sector_at(at_position)
	return str(index) if index >= 0 else ""


func _make_custom_tooltip(for_text: String) -> Object:
	if not for_text.is_valid_int():
		return null
	var index := int(for_text)
	if index < 0 or index >= Db.ITEM_IDS.size():
		return null
	var id := Db.ITEM_IDS[index]
	var lv := tier_at(float(end_xp.get(id, 0)))
	var panel := PanelContainer.new()
	panel.theme = UiKit.theme()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.055, 0.045, 0.065), UiKit.item_color(id), 1, 8, 12))
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 6)
	panel.add_child(content)
	content.add_child(UiKit.label("%s · %s" % [Db.item(id).display_name, ROMAN[lv - 1]], 20, UiKit.GOLD))
	if collection_mode:
		content.add_child(UiKit.label("%d / 3 открыто" % lv, 16))
	else:
		content.add_child(UiKit.label("+%d XP за забег" % int(earned_xp.get(id, 0)), 22))
	content.add_child(UiKit.label("%d / %d XP%s" % [int(end_xp.get(id, 0)), int(Mastery.rules["thresholds"].back()), " · МАКС" if lv == 3 else ""], 16, UiKit.MUTED))
	if collection_mode and lv < 3:
		content.add_child(UiKit.label("До %s: %d XP" % [ROMAN[lv], int(Mastery.rules["thresholds"][lv]) - int(end_xp.get(id, 0))], 16, UiKit.GOLD))
	elif not collection_mode and lv > tier_at(float(start_xp.get(id, 0))):
		content.add_child(UiKit.label("Новый облик открыт · %s" % ROMAN[lv - 1], 16, UiKit.GOLD))
	return panel


static func tier_at(value: float) -> int:
	var thresholds: Array = Mastery.rules["thresholds"]
	for i in range(thresholds.size() - 1, -1, -1):
		if value >= float(thresholds[i]):
			return i + 1
	return 1


## I открыт изначально; II и III имеют собственные интервалы опыта.
static func tier_progress(value: float, tier: int) -> float:
	if tier <= 1:
		return 1.0
	var previous := float(Mastery.rules["thresholds"][tier - 2])
	var target := float(Mastery.rules["thresholds"][tier - 1])
	return clampf((value - previous) / (target - previous), 0.0, 1.0)


func _animation_progress(index: int) -> float:
	var t := clampf((_time - 0.25 - index * STAGGER) / DURATION, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func displayed_xp(index: int) -> float:
	var id := Db.ITEM_IDS[index]
	return lerpf(float(start_xp.get(id, 0)), float(end_xp.get(id, 0)), _animation_progress(index))


func finish_animation() -> void:
	_time = DURATION + STAGGER * Db.ITEM_IDS.size() + 0.3
	queue_redraw()


func _process(delta: float) -> void:
	if _time < DURATION + STAGGER * Db.ITEM_IDS.size() + 0.3:
		_time += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := sector_at(event.position)
		_hover = Db.ITEM_IDS[index] if index >= 0 else &""
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if index >= 0 else Control.CURSOR_ARROW
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := sector_at(event.position)
		if index >= 0:
			select_item(Db.ITEM_IDS[index])
			if event.position.distance_to(_center()) <= _form_radius():
				appearance_inspected.emit(Db.ITEM_IDS[index], collection_tier_at(event.position))
			_buttons[index].grab_focus()
			accept_event()


func sector_at(point: Vector2) -> int:
	if not collection_mode:
		for i in _buttons.size():
			var icon_rect := Rect2(_buttons[i].position, _buttons[i].size)
			var label_rect := Rect2(icon_rect.get_center() + Vector2(-64, 12), Vector2(128, 24))
			if icon_rect.has_point(point) or label_rect.has_point(point):
				return i
	var offset := point - _center()
	if offset.length() < 58.0 or offset.length() > _radius():
		return -1
	var step := TAU / Db.ITEM_IDS.size()
	return int(fposmod(offset.angle() + PI * 0.5 + step * 0.5, TAU) / step)


func collection_tier_at(point: Vector2) -> int:
	var progress := (point.distance_to(_center()) - 58.0) / (_form_radius() - 58.0)
	return clampi(int(floor(progress * 3.0)) + 1, 1, 3)


func _draw() -> void:
	var center := _center()
	var radius := _radius()
	draw_circle(center, radius + 15.0, Color(0.065, 0.05, 0.075))
	draw_arc(center, radius + 13.0, 0, TAU, 112, Color(UiKit.GOLD, 0.22), 1.0, true)
	var forms := 0
	for i in Db.ITEM_IDS.size():
		if collection_mode:
			_draw_collection_sector(i, radius)
		else:
			_draw_sector(i, radius)
		forms += tier_at(displayed_xp(i))
	draw_circle(center, 56.0, Color(0.04, 0.03, 0.05))
	draw_arc(center, 54.0, 0, TAU, 64, Color(UiKit.GOLD, 0.4), 1.0, true)
	draw_string(UiKit.title_font(), center + Vector2(-48, 6), "%d / 21" % forms, HORIZONTAL_ALIGNMENT_CENTER, 96, 30, UiKit.GOLD)
	draw_string(UiKit.body_font(), center + Vector2(-48, 29), "обликов", HORIZONTAL_ALIGNMENT_CENTER, 96, 15, UiKit.MUTED)


func _draw_collection_sector(index: int, radius: float) -> void:
	var id := Db.ITEM_IDS[index]
	var color := UiKit.item_color(id)
	var angle := _angle(index)
	var half := PI / Db.ITEM_IDS.size() - GAP
	var hot := id == selected_id or id == _hover
	var value := float(end_xp.get(id, 0))
	var lv := tier_at(value)
	var width := (_form_radius() - 58.0) / 3.0
	_band(_form_radius() + 2.0, radius, angle - half, angle + half, Color(color, 0.3 if hot else 0.18))
	for tier in range(1, 4):
		var inner := 58.0 + (tier - 1) * width + 2.0
		var outer := 58.0 + tier * width - 2.0
		var unlocked := tier <= lv
		_band(inner, outer, angle - half, angle + half, Color(color, 0.42 if hot else 0.3) if unlocked else Color(0.065, 0.055, 0.075))
		if tier == lv + 1:
			var previous := float(Mastery.rules["thresholds"][tier - 2])
			var target := float(Mastery.rules["thresholds"][tier - 1])
			var progress := clampf((value - previous) / (target - previous), 0.0, 1.0)
			_band(inner, lerpf(inner, outer, progress), angle - half, angle + half, Color(color, 0.2))
		draw_arc(_center(), outer, angle - half, angle + half, 24, Color(color, 0.8) if unlocked else Color(0.24, 0.2, 0.27), 1.0, true)
		var seal := _center() + Vector2.from_angle(angle) * (inner + outer) * 0.5
		draw_string(UiKit.body_font(), seal + Vector2(-20, 7), ROMAN[tier - 1], HORIZONTAL_ALIGNMENT_CENTER, 40, 20, UiKit.TEXT if unlocked else UiKit.MUTED.darkened(0.35))
	var outline := _band_points(58.0, radius, angle - half, angle + half)
	outline.append(outline[0])
	draw_polyline(outline, Color(color, 0.95 if hot else 0.25), 2.0 if hot else 1.0, true)
	_draw_item_label(index)


func _draw_sector(index: int, radius: float) -> void:
	var id := Db.ITEM_IDS[index]
	var color := UiKit.item_color(id)
	var angle := _angle(index)
	var half := PI / Db.ITEM_IDS.size() - GAP
	var hot := id == selected_id or id == _hover
	var start := float(start_xp.get(id, 0))
	var value := displayed_xp(index)
	var width := (radius - 58.0) / 3.0
	for tier in range(1, 4):
		var inner := 58.0 + (tier - 1) * width + 2.0
		var outer := 58.0 + tier * width - 2.0
		var old_fill := lerpf(inner, outer, tier_progress(start, tier))
		var new_fill := lerpf(inner, outer, tier_progress(value, tier))
		_band(inner, outer, angle - half, angle + half, Color(0.065, 0.055, 0.075))
		_band(inner, old_fill, angle - half, angle + half, Color(color, 0.38 if hot else 0.25))
		_band(old_fill, new_fill, angle - half, angle + half, Color(color, 0.85 if hot else 0.68))
		var unlocked := tier <= tier_at(value)
		draw_arc(_center(), outer, angle - half, angle + half, 24, Color(color, 0.8) if unlocked else Color(0.24, 0.2, 0.27), 1.0, true)
		if new_fill > old_fill:
			draw_arc(_center(), new_fill, angle - half, angle + half, 24, color, 2.0, true)
		elif tier == 3 and tier_progress(start, tier) == 1.0 and int(earned_xp.get(id, 0)) > 0:
			# На максимуме шкала не растёт; край отмечает награду, число — в подсказке.
			draw_arc(_center(), outer, angle - half, angle + half, 24, Color(color, _animation_progress(index)), 3.0, true)
		var seal := _center() + Vector2.from_angle(angle) * (inner + outer) * 0.5
		draw_string_outline(UiKit.body_font(), seal + Vector2(-20, 7), ROMAN[tier - 1], HORIZONTAL_ALIGNMENT_CENTER, 40, 20, 2, Color(0.02, 0.015, 0.025, 0.65))
		draw_string(UiKit.body_font(), seal + Vector2(-20, 7), ROMAN[tier - 1], HORIZONTAL_ALIGNMENT_CENTER, 40, 20, UiKit.TEXT if tier_progress(value, tier) > 0 else UiKit.MUTED)
	var outline := _band_points(58.0, radius, angle - half, angle + half)
	outline.append(outline[0])
	draw_polyline(outline, Color(color, 0.95 if hot else 0.28), 2.0 if hot else 1.0, true)
	_draw_item_label(index)


func _draw_item_label(index: int) -> void:
	var id := Db.ITEM_IDS[index]
	var hot := id == selected_id or id == _hover
	var icon := IconFactory.icon(id)
	var pos := _icon_position(index)
	if icon != null:
		draw_circle(pos, 23, Color(0.035, 0.025, 0.04, 0.88))
		draw_texture_rect(icon, Rect2(pos - Vector2(23, 23), Vector2(46, 46)), false)
	draw_string(UiKit.body_font(), pos + Vector2(-64, 42 if collection_mode else 32), Db.item(id).display_name, HORIZONTAL_ALIGNMENT_CENTER, 128, 18, UiKit.GOLD if hot else UiKit.TEXT)


func _band(inner: float, outer: float, from: float, to: float, color: Color) -> void:
	if outer - inner > 0.05:
		draw_colored_polygon(_band_points(inner, outer, from, to), color)


func _band_points(inner: float, outer: float, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 25:
		points.append(_center() + Vector2.from_angle(lerpf(from, to, i / 24.0)) * outer)
	for i in range(24, -1, -1):
		points.append(_center() + Vector2.from_angle(lerpf(from, to, i / 24.0)) * inner)
	return points
