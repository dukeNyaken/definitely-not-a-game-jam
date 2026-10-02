extends CanvasLayer
## Отладочное меню (F1): порядок кольца, жертва без алтаря, выдать свойство, пропуск этапа, бессмертие.

var _panel: PanelContainer
var _ring_box: VBoxContainer
var _host: OptionButton
var _essence: OptionButton
var _immortal: CheckButton
var _status: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.theme = UiKit.theme()
	_panel.position = Vector2(20, 120)
	_panel.custom_minimum_size = Vector2(430, 0)
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	_panel.add_child(v)
	v.add_child(UiKit.label("Отладка (F1)", 22, UiKit.GOLD))
	_status = UiKit.label("", 15, UiKit.MUTED)
	v.add_child(_status)
	v.add_child(UiKit.label("Кольцо по часовой — нажмите, чтобы пожертвовать без алтаря:", 15, UiKit.TEXT))
	_ring_box = VBoxContainer.new()
	v.add_child(_ring_box)
	v.add_child(HSeparator.new())
	v.add_child(UiKit.label("Выдать свойство (слушает событие вещи):", 15, UiKit.TEXT))
	var row := HBoxContainer.new()
	_host = OptionButton.new()
	_host.focus_mode = Control.FOCUS_NONE
	_essence = OptionButton.new()
	_essence.focus_mode = Control.FOCUS_NONE
	for id in Db.ITEM_IDS:
		var e := Db.item(id).essence
		_essence.add_item("%s (%s)" % [e.display_name, e.adjective])
		_essence.set_item_metadata(_essence.item_count - 1, e.id)
	row.add_child(_host)
	row.add_child(_essence)
	v.add_child(row)
	v.add_child(UiKit.button("Выдать", _give))
	v.add_child(HSeparator.new())
	v.add_child(UiKit.button("Пропустить этап", _skip))
	_immortal = CheckButton.new()
	_immortal.text = "Бессмертие"
	_immortal.focus_mode = Control.FOCUS_NONE
	_immortal.toggled.connect(_on_immortal)
	v.add_child(_immortal)
	RunState.ring_changed.connect(_refresh)


func _game() -> Game:
	return get_tree().get_first_node_in_group(&"game") as Game


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug"):
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not _panel.visible:
		return
	for ch in _ring_box.get_children():
		ch.queue_free()
	var r := RunState.ring
	_host.clear()
	for i in r.size():
		var s := r.items[i]
		var def := s.def()
		var next := r.items[r.recipient_index(i)].def()
		var text := "%d. %s → %s  [%d св.]" % [i + 1, def.display_name, next.display_name, s.properties.size()]
		var b := UiKit.button(text, _sacrifice.bind(i))
		b.disabled = r.size() <= 1
		b.add_theme_font_size_override(&"font_size", 16)
		_ring_box.add_child(b)
		_host.add_item(def.display_name)
	_immortal.set_pressed_no_signal(RunState.debug_immortal)
	var g := _game()
	_status.text = "Сид %d · этап %d · %s" % [RunState.seed_value, RunState.stage, "в игре" if g != null else "нет игры"]


func _sacrifice(i: int) -> void:
	if RunState.ring.size() <= 1:
		return
	RunState.sacrifice(i)
	var g := _game()
	if g != null:
		g.debug_refresh_hero()
	_refresh()


func _give() -> void:
	if _host.selected < 0:
		return
	RunState.debug_give_property(_host.selected, _essence.get_item_metadata(_essence.selected))
	var g := _game()
	if g != null:
		g.debug_refresh_hero()
	_refresh()


func _skip() -> void:
	var g := _game()
	if g != null:
		get_tree().paused = false
		g.debug_skip_stage()


func _on_immortal(on: bool) -> void:
	RunState.debug_immortal = on
	var g := _game()
	if g != null:
		g.debug_refresh_hero()
