class_name TreeUi
extends Control
## Tab: единое кольцо всех навыков и сил; выбор меняет только краткую справку.

signal close_requested

var actor: Actor
var _host: ItemState
var _diagram: PropertyDiagram
var _details: VBoxContainer
var _summary: Label


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
	var title := UiKit.label("Кольцо навыков", 40, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiKit.label("Бой на паузе", 18, UiKit.MUTED))
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
	_summary = UiKit.label("По часовой · 1 — навык, далее — его силы\nНаведи для XP · Нажми для параметров", 17, UiKit.MUTED)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_summary)
	var close := UiKit.button("В бой · Tab", func(): close_requested.emit())
	close.focus_mode = Control.FOCUS_ALL
	footer.add_child(close)
	RunState.ring_changed.connect(_refresh_tree)
	Mastery.changed.connect(_refresh_meta)
	_refresh_tree()


func select_item(id: StringName) -> void:
	var index := _diagram.index_of(id)
	if index >= 0:
		_diagram.select_node(index)


func _refresh_tree() -> void:
	_diagram.show_ring(RunState.ring)


func _refresh_meta() -> void:
	_diagram.queue_redraw()
	if not _diagram.nodes.is_empty():
		_inspect_node(_diagram.selected_node)


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var label := UiKit.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _inspect_node(index: int) -> void:
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	_host = _diagram.nodes[index]["state"]
	var prop: Property = _diagram.nodes[index]["property"]
	var metrics: Array[Dictionary]
	if prop == null:
		var def := _host.def()
		_details.add_child(_wrapped(def.display_name, 34, def.essence.color))
		_details.add_child(UiKit.label("%s · %s" % [def.input_label, def.event_label()], 19, UiKit.GOLD))
		_details.add_child(_wrapped("Облик %s · %s" % [MasteryWheel.ROMAN[_host.appearance - 1], Mastery.form(_host.def_id, _host.appearance)["name"]], 17, UiKit.MUTED))
		_details.add_child(UiKit.label(Mastery.progress_text(_host.def_id), 17))
		var hints := {&"sword": "Три удара подряд; последний — завершающий.", &"shield": "Удерживай ПКМ. Блокирует атаки спереди.", &"armor": "Броня принимает урон раньше здоровья.", &"helmet": "Враг завершил атаку — окно крита.", &"boots": "Рывок по направлению движения.", &"gloves": "Притягивает и оглушает цели перед тобой.", &"amulet": "Волна вокруг героя."}
		_details.add_child(_wrapped(hints[_host.def_id], 17, UiKit.TEXT))
		metrics = BattleSkillInfo.native(_host)
	else:
		var essence := Db.essence(prop.essence_id)
		_details.add_child(_wrapped(Db.item(prop.source_item_id).display_name, 30, essence.color))
		_details.add_child(_wrapped("Носитель: %s · Урон +%d%%" % [_host.def().display_name, roundi((ActionContext.item_mult(_host) - 1) * 100)], 17, UiKit.MUTED))
		_details.add_child(UiKit.label("%s · %d XP · стоп" % [Db.item(prop.source_item_id).display_name, int(Mastery.xp.get(prop.source_item_id, 0))], 17, UiKit.MUTED))
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


func _input(event: InputEvent) -> void:
	# Tab закрывает схему даже после клика, когда кнопка получила клавиатурный фокус.
	if event.is_action_pressed(&"tree") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
