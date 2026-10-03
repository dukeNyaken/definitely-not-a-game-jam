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
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override(&"normal", UiKit.box(Color(0.055, 0.045, 0.065, 0.92), Color(0.22, 0.19, 0.23), 1, 8, 4))
		button.add_theme_stylebox_override(&"hover", UiKit.box(Color(0.12, 0.09, 0.12), Db.item(id).essence.color, 1, 8, 4))
		button.add_theme_stylebox_override(&"focus", UiKit.box(Color.TRANSPARENT, UiKit.GOLD, 2, 8, 4))
		button.pressed.connect(select_item.bind(id))
		button.mouse_entered.connect(func():
			_hover = id
			queue_redraw())
		button.mouse_exited.connect(func():
			_hover = &""
			queue_redraw())
		add_child(button)
		_buttons.append(button)
	resized.connect(_layout_buttons)
	mouse_exited.connect(func():
		_hover = &""
		queue_redraw())
	IconFactory.icons_ready.connect(queue_redraw)
	_layout_buttons()
	_update_buttons()
	if collection_mode:
		_refresh_collection()
		Mastery.changed.connect(_refresh_collection)


func _refresh_collection() -> void:
	start_xp = Mastery.xp.duplicate()
	end_xp = Mastery.xp.duplicate()
	earned_xp.clear()
	finish_animation()
	_update_buttons()


func select_item(id: StringName) -> void:
	selected_id = id
	_update_buttons()
	queue_redraw()
	item_selected.emit(id)


func _center() -> Vector2:
	return size * 0.5


func _radius() -> float:
	return minf(size.x * 0.5 - 122.0, size.y * 0.5 - 100.0)


func _angle(index: int) -> float:
	return -PI * 0.5 + TAU * index / Db.ITEM_IDS.size()


func _layout_buttons() -> void:
	for i in _buttons.size():
		var direction := Vector2.from_angle(_angle(i))
		_buttons[i].size = Vector2(126, 78)
		_buttons[i].position = _center() + direction * (_radius() + 60.0) - _buttons[i].size * 0.5


func _update_buttons() -> void:
	for i in _buttons.size():
		var id := Db.ITEM_IDS[i]
		var lv := tier_at(float(end_xp.get(id, 0)))
		var upgraded := lv > tier_at(float(start_xp.get(id, 0)))
		_buttons[i].text = "%s · %s\n%s%s" % [Db.item(id).display_name, ROMAN[lv - 1], "+%d XP" % int(earned_xp.get(id, 0)), "  ✦" if upgraded else ""]
		if collection_mode:
			_buttons[i].text = "%s\n%d / 3 открыто" % [Db.item(id).display_name, lv]
		_buttons[i].add_theme_font_override(&"font", UiKit.body_font())
		_buttons[i].add_theme_font_size_override(&"font_size", 17)
		_buttons[i].add_theme_color_override(&"font_color", UiKit.TEXT if id != selected_id else UiKit.GOLD)
		_buttons[i].add_theme_stylebox_override(&"normal", UiKit.box(Color(0.1, 0.075, 0.1) if id == selected_id else Color(0.055, 0.045, 0.065, 0.92), Db.item(id).essence.color if id == selected_id else Color(0.22, 0.19, 0.23), 2 if id == selected_id else 1, 8, 4))
		_buttons[i].tooltip_text = "%s\n%d / %d XP%s" % [Db.item(id).display_name, int(end_xp.get(id, 0)), int(Mastery.rules["thresholds"].back()), "\nНовый облик открыт" if upgraded else ""]


static func tier_at(value: float) -> int:
	var thresholds: Array = Mastery.rules["thresholds"]
	for i in range(thresholds.size() - 1, -1, -1):
		if value >= float(thresholds[i]):
			return i + 1
	return 1


func displayed_xp(index: int) -> float:
	var id := Db.ITEM_IDS[index]
	var t := clampf((_time - 0.25 - index * STAGGER) / DURATION, 0.0, 1.0)
	t = 1.0 - pow(1.0 - t, 3.0)
	return lerpf(float(start_xp.get(id, 0)), float(end_xp.get(id, 0)), t)


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
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := sector_at(event.position)
		if index >= 0:
			select_item(Db.ITEM_IDS[index])
			if collection_mode:
				appearance_inspected.emit(Db.ITEM_IDS[index], collection_tier_at(event.position))
			_buttons[index].grab_focus()
			accept_event()


func sector_at(point: Vector2) -> int:
	var offset := point - _center()
	if offset.length() < 58.0 or offset.length() > _radius():
		return -1
	var step := TAU / Db.ITEM_IDS.size()
	return int(fposmod(offset.angle() + PI * 0.5 + step * 0.5, TAU) / step)


func collection_tier_at(point: Vector2) -> int:
	var progress := (point.distance_to(_center()) - 58.0) / (_radius() - 58.0)
	return clampi(int(floor(progress * 3.0)) + 1, 1, 3)


func _draw() -> void:
	var center := _center()
	var radius := _radius()
	draw_circle(center, radius + 15.0, Color(0.065, 0.05, 0.075))
	draw_arc(center, radius + 13.0, 0, TAU, 112, Color(UiKit.GOLD, 0.22), 1.0, true)
	var relics := 0
	var forms := 0
	for i in Db.ITEM_IDS.size():
		if collection_mode:
			_draw_collection_sector(i, radius)
		else:
			_draw_sector(i, radius)
		forms += tier_at(displayed_xp(i))
		if tier_at(displayed_xp(i)) == 3:
			relics += 1
	draw_circle(center, 56.0, Color(0.04, 0.03, 0.05))
	draw_arc(center, 54.0, 0, TAU, 64, Color(UiKit.GOLD, 0.4), 1.0, true)
	draw_string(UiKit.title_font(), center + Vector2(-48, 6), "%d / 21" % forms if collection_mode else "%d / 7" % relics, HORIZONTAL_ALIGNMENT_CENTER, 96, 30 if collection_mode else 34, UiKit.GOLD)
	draw_string(UiKit.body_font(), center + Vector2(-48, 29), "обликов" if collection_mode else "реликвий", HORIZONTAL_ALIGNMENT_CENTER, 96, 15, UiKit.MUTED)


func _draw_collection_sector(index: int, radius: float) -> void:
	var id := Db.ITEM_IDS[index]
	var color := Db.item(id).essence.color
	var angle := _angle(index)
	var half := PI / Db.ITEM_IDS.size() - GAP
	var hot := id == selected_id or id == _hover
	var value := float(end_xp.get(id, 0))
	var lv := tier_at(value)
	var width := (radius - 58.0) / 3.0
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
		if tier == Mastery.selected(id):
			var mark := _center() + Vector2.from_angle(angle + half - 0.09) * (inner + outer) * 0.5
			draw_circle(mark, 3.5, UiKit.GOLD)
	var outline := _band_points(58.0, radius, angle - half, angle + half)
	outline.append(outline[0])
	draw_polyline(outline, Color(color, 0.95 if hot else 0.25), 2.0 if hot else 1.0, true)


func _draw_sector(index: int, radius: float) -> void:
	var id := Db.ITEM_IDS[index]
	var color := Db.item(id).essence.color
	var angle := _angle(index)
	var half := PI / Db.ITEM_IDS.size() - GAP
	var hot := id == selected_id or id == _hover
	var start := float(start_xp.get(id, 0))
	var value := displayed_xp(index)
	var limit := float(Mastery.rules["thresholds"].back())
	var fill_radius := lerpf(58.0, radius, clampf(value / limit, 0.0, 1.0))
	var old_radius := lerpf(58.0, radius, clampf(start / limit, 0.0, 1.0))
	_band(58.0, radius, angle - half, angle + half, Color(color.darkened(0.84), 0.95))
	if old_radius > 58.0:
		_band(58.0, old_radius, angle - half, angle + half, Color(color, 0.25 if not hot else 0.38))
	if fill_radius > old_radius:
		_band(old_radius, fill_radius, angle - half, angle + half, Color(color, 0.68 if not hot else 0.85))
	if value > 0:
		draw_arc(_center(), fill_radius, angle - half, angle + half, 24, color, 2.0, true)
	for tier in range(1, Mastery.rules["thresholds"].size()):
		var threshold := float(Mastery.rules["thresholds"][tier])
		var marker_radius := lerpf(58.0, radius, threshold / limit)
		draw_arc(_center(), marker_radius, angle - half, angle + half, 24, Color(UiKit.GOLD, 0.4), 1.0, true)
		var marker := _center() + Vector2.from_angle(angle + half) * marker_radius
		var unlocked := value >= threshold
		draw_circle(marker, 4.0, UiKit.GOLD if unlocked else Color(0.24, 0.2, 0.25))
		if unlocked and start < threshold:
			draw_arc(marker, 7.0, 0, TAU, 16, Color(color, 0.8), 1.5, true)
	var outline := _band_points(58.0, radius, angle - half, angle + half)
	outline.append(outline[0])
	draw_polyline(outline, Color(color, 0.95 if hot else 0.28), 2.0 if hot else 1.0, true)
	var icon := IconFactory.icon(id)
	if icon != null:
		var pos := _center() + Vector2.from_angle(angle) * (radius - 24.0)
		draw_circle(pos, 23, Color(0.035, 0.025, 0.04, 0.88))
		draw_texture_rect(icon, Rect2(pos - Vector2(23, 23), Vector2(46, 46)), false)


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
