class_name TreeUi
extends Control
## Tab: опыт и навыки в полосе вещей, дерево событий и инфографика выбранного узла.

signal close_requested

var actor: Actor
var _host: ItemState
var _diagram: PropertyDiagram
var _details: VBoxContainer
var _summary: Label
var _chips: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.91)
	UiKit.full_rect(dim)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -720
	panel.offset_right = 720
	panel.offset_top = -410
	panel.offset_bottom = 410
	panel.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.05, 0.035, 0.055), UiKit.GOLD.darkened(0.35), 2, 12, 24))
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 12)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := UiKit.label("Навыки и связи", 40, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiKit.label("Бой на паузе", 18, UiKit.MUTED))
	var loadout := HBoxContainer.new()
	loadout.add_theme_constant_override(&"separation", 8)
	layout.add_child(loadout)
	for id in Db.ITEM_IDS:
		var button := UiKit.button("", select_item.bind(id))
		button.custom_minimum_size = Vector2(0, 90)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.draw.connect(_draw_chip.bind(button, id))
		loadout.add_child(button)
		_chips[id] = button
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 20)
	layout.add_child(row)
	var graph_frame := PanelContainer.new()
	graph_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_frame.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.04, 0.03, 0.05), Color(0.22, 0.18, 0.24), 1, 8, 8))
	row.add_child(graph_frame)
	_diagram = PropertyDiagram.new()
	graph_frame.add_child(_diagram)
	var detail_frame := PanelContainer.new()
	detail_frame.custom_minimum_size = Vector2(350, 0)
	detail_frame.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.07, 0.05, 0.075), Color(0.25, 0.2, 0.25), 1, 8, 16))
	row.add_child(detail_frame)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override(&"separation", 10)
	detail_frame.add_child(_details)
	_diagram.node_selected.connect(_inspect_node)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 20)
	layout.add_child(footer)
	_summary = UiKit.label("", 17, UiKit.MUTED)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_summary)
	var close := UiKit.button("В бой · Tab", func(): close_requested.emit())
	close.focus_mode = Control.FOCUS_ALL
	footer.add_child(close)
	RunState.ring_changed.connect(_refresh_tree)
	Mastery.changed.connect(_refresh_meta)
	IconFactory.icons_ready.connect(_redraw_chips)
	_refresh_tree()


func owner_of(id: StringName) -> ItemState:
	for state in RunState.ring.items:
		if state.def_id == id:
			return state
		for prop in state.properties:
			if prop.source_item_id == id:
				return state
	return null


func select_item(id: StringName) -> void:
	var owner := owner_of(id)
	if owner == null:
		return
	_host = owner
	_diagram.show_item(owner)
	if owner.def_id != id:
		for i in range(1, _diagram.nodes.size()):
			if (_diagram.nodes[i]["property"] as Property).source_item_id == id:
				_diagram.select_node(i)
				break
	_summary.text = "%s · Свойства: %d · Урон +%d%%   |   Стрелки — порядок срабатывания" % [owner.def().display_name, owner.properties.size(), roundi((ActionContext.item_mult(owner) - 1) * 100)]
	_redraw_chips()


func _refresh_tree() -> void:
	var id: StringName = &""
	if _host != null and owner_of(_host.def_id) != null:
		id = _host.def_id
	else:
		var most := -1
		for item in RunState.ring.items:
			if item.properties.size() > most:
				most = item.properties.size()
				id = item.def_id
	if id != &"":
		select_item(id)


func _refresh_meta() -> void:
	_redraw_chips()
	_diagram.queue_redraw()
	if _host != null:
		_inspect_node(_diagram.selected_node)


func _redraw_chips() -> void:
	var selected_id: StringName = _host.def_id if _host != null else &""
	if _host != null and _diagram.selected_node > 0:
		selected_id = (_diagram.nodes[_diagram.selected_node]["property"] as Property).source_item_id
	for id in _chips:
		var color := Db.item(id).essence.color
		var held := RunState.ring.has_item(id)
		var selected: bool = selected_id == id
		var border := UiKit.GOLD if selected else color.darkened(0.5) if held else Color(0.23, 0.2, 0.25)
		_chips[id].add_theme_stylebox_override(&"normal", UiKit.box(Color(color, 0.1) if held else Color(0.045, 0.035, 0.05), border, 2 if selected else 1, 8, 4))
		_chips[id].add_theme_stylebox_override(&"hover", UiKit.box(Color(color, 0.15), color, 2, 8, 4))
		_chips[id].tooltip_text = "Надета · получает XP" if held else "Пожертвована · больше не получает XP"
		_chips[id].queue_redraw()


func _draw_chip(button: Button, id: StringName) -> void:
	var held := RunState.ring.get_item(id)
	var def := Db.item(id)
	var icon := IconFactory.icon(id)
	if icon != null:
		button.draw_texture_rect(icon, Rect2(10, 8, 36, 36), false, Color.WHITE if held != null else Color(0.55, 0.5, 0.55))
	if held == null:
		button.draw_line(Vector2(12, 42), Vector2(43, 10), UiKit.DANGER.lightened(0.1), 2.0, true)
	button.draw_string(UiKit.body_font(), Vector2(53, 25), def.display_name, HORIZONTAL_ALIGNMENT_LEFT, button.size.x - 57, 17, UiKit.TEXT if held != null else UiKit.MUTED)
	var caption := "%s · %s" % [def.input_label, MasteryWheel.ROMAN[held.appearance - 1]] if held != null else "Жертва · XP стоп"
	button.draw_string(UiKit.body_font(), Vector2(53, 46), caption, HORIZONTAL_ALIGNMENT_LEFT, button.size.x - 57, 13, UiKit.GOLD if held != null else UiKit.MUTED)
	var lv := Mastery.level(id)
	var target := int(Mastery.rules["thresholds"][mini(lv, 2)])
	var total := int(Mastery.xp.get(id, 0))
	button.draw_rect(Rect2(10, 58, button.size.x - 20, 4), Color(0.17, 0.13, 0.18))
	button.draw_rect(Rect2(10, 58, (button.size.x - 20) * clampf(float(total) / target, 0, 1), 4), UiKit.GOLD if held != null else UiKit.MUTED.darkened(0.3))
	button.draw_string(UiKit.body_font(), Vector2(10, 80), "%d / %d XP%s" % [total, target, " · MAX" if lv == 3 else ""], HORIZONTAL_ALIGNMENT_CENTER, button.size.x - 20, 13, UiKit.MUTED)


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var label := UiKit.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _inspect_node(index: int) -> void:
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var prop: Property = _diagram.nodes[index]["property"]
	var metrics: Array[Dictionary]
	if prop == null:
		var def := _host.def()
		_details.add_child(_wrapped(def.display_name, 34, def.essence.color))
		_details.add_child(UiKit.label("%s · %s" % [def.input_label, def.event_label()], 19, UiKit.GOLD))
		_details.add_child(_wrapped("Облик %s · %s" % [MasteryWheel.ROMAN[_host.appearance - 1], Mastery.form(_host.def_id, _host.appearance)["name"]], 17, UiKit.MUTED))
		_details.add_child(UiKit.label(Mastery.progress_text(_host.def_id), 17))
		var hints := {&"sword": "Три удара подряд; последний — завершающий.", &"shield": "Удерживай ПКМ. Блокирует атаки спереди.", &"armor": "Броня принимает урон раньше здоровья.", &"helmet": "После атаки врага — окно крита.", &"boots": "Рывок по направлению движения.", &"gloves": "Притягивает и оглушает цели перед тобой.", &"amulet": "Волна вокруг героя."}
		_details.add_child(_wrapped(hints[_host.def_id], 17, UiKit.TEXT))
		metrics = BattleSkillInfo.native(_host)
	else:
		var essence := Db.essence(prop.essence_id)
		_details.add_child(_wrapped(prop.display_name(), 30, essence.color))
		_details.add_child(_wrapped("%s → %s → %s" % [PropertyTree.event_label(prop.listen_event), essence.display_name, PropertyTree.event_label(prop.emit_event)], 19, UiKit.GOLD))
		_details.add_child(_wrapped("%s → %s" % [Db.item(prop.source_item_id).display_name, _host.def().display_name], 17, UiKit.MUTED))
		if not bool(_diagram.nodes[index]["linked"]):
			_details.add_child(_wrapped("Нет связи с родным навыком", 17, UiKit.DANGER.lightened(0.2)))
		metrics = BattleSkillInfo.effect(prop, _host)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	_details.add_child(grid)
	for entry in metrics:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.04, 0.03, 0.05), Color(0.25, 0.2, 0.25), 1, 6, 8))
		grid.add_child(tile)
		var content := VBoxContainer.new()
		tile.add_child(content)
		content.add_child(_wrapped(str(entry["value"]), 24, UiKit.TEXT))
		content.add_child(_wrapped(str(entry["label"]), 14, UiKit.MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_child(spacer)
	if is_instance_valid(actor):
		if prop != null:
			_details.add_child(UiKit.label("Готово" if actor.bus.is_ready(prop) else "На откате", 17, UiKit.GOLD))
		else:
			var comp := actor.component(_host.def_id)
			if comp != null and not comp.is_passive():
				_details.add_child(UiKit.label("Навык готов" if comp.cooldown_left <= 0 else "Готов через %s с" % BattleSkillInfo.number(comp.cooldown_left), 17, UiKit.GOLD))
	_redraw_chips()


func _input(event: InputEvent) -> void:
	# Tab закрывает схему даже после клика, когда кнопка получила клавиатурный фокус.
	if event.is_action_pressed(&"tree") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
