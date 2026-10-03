extends CanvasLayer
## Отладочное меню (F1): жертвы, свойства, пропуск этапа, бессмертие и мета-прогресс.

var _panel: PanelContainer
var _ring_box: VBoxContainer
var _host: OptionButton
var _essence: OptionButton
var _immortal: CheckButton
var _status: Label
var _meta_status: Label
var _reset_dialog: ConfirmationDialog
var _reset_was_paused := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.theme = UiKit.theme()
	_panel.position = Vector2(20, 40)
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
	v.add_child(HSeparator.new())
	v.add_child(UiKit.button("Открыть все облики", _unlock_all_appearances))
	v.add_child(UiKit.button("Сбросить мета-прогресс", _confirm_meta_reset))
	_meta_status = UiKit.label("Опыт и облики всех вещей", 15, UiKit.MUTED)
	v.add_child(_meta_status)
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.theme = UiKit.theme()
	_reset_dialog.title = "Сброс мета-прогресса"
	_reset_dialog.dialog_text = "Опыт всех вещей и облики II–III будут сброшены.\nСброс сохранится в локальном профиле."
	_reset_dialog.ok_button_text = "Сбросить"
	_reset_dialog.cancel_button_text = "Отмена"
	_reset_dialog.confirmed.connect(_reset_meta)
	_reset_dialog.canceled.connect(_cancel_meta_reset)
	add_child(_reset_dialog)
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


func _unlock_all_appearances() -> void:
	for id in Db.ITEM_IDS:
		# Открываем коллекцию, сохраняя выбранные игроком облики.
		Mastery.choices[id] = Mastery.selected(id)
		Mastery.xp[id] = Mastery.xp_cap()
	var saved := Mastery.save_progress()
	Mastery.changed.emit()
	_meta_status.text = "Все облики открыты" if saved else "Облики открыты в памяти · не удалось сохранить"
	_meta_status.add_theme_color_override(&"font_color", UiKit.GOLD if saved else UiKit.DANGER.lightened(0.3))


func _confirm_meta_reset() -> void:
	if _reset_dialog.visible:
		return
	_reset_was_paused = get_tree().paused
	get_tree().paused = true
	_reset_dialog.popup_centered(Vector2i(560, 180))


func _cancel_meta_reset() -> void:
	get_tree().paused = _reset_was_paused


func _reset_meta() -> void:
	var saved := Mastery.reset_progress()
	_meta_status.text = "Мета-прогресс сброшен" if saved else "Сброс в памяти · не удалось сохранить"
	_meta_status.add_theme_color_override(&"font_color", UiKit.GOLD if saved else UiKit.DANGER.lightened(0.3))
	get_tree().paused = _reset_was_paused
