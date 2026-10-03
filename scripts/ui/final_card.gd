extends Control
## Итог забега: колесо постоянного опыта и артефакт. Подробности — по запросу.

var _ui: Control
var _wheel: MasteryWheel
var _item_panel: VBoxContainer
var _modal: Control


func _ready() -> void:
	theme = UiKit.theme()
	get_tree().paused = false
	Engine.time_scale = 1.0
	var victory := RunState.outcome == RunState.Outcome.VICTORY
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.035, 0.05)
	UiKit.full_rect(bg)
	add_child(bg)
	Audio.play_music(&"music_menu")
	Audio.play(&"victory" if victory else &"defeat_sting")
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_ui = Control.new()
	_ui.theme = UiKit.theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_ui)
	ui_layer.add_child(_ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -720
	panel.offset_right = 720
	panel.offset_top = -410
	panel.offset_bottom = 410
	panel.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.05, 0.035, 0.055, 0.97), UiKit.GOLD if victory else UiKit.BLOOD, 2, 12, 24))
	_ui.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 10)
	panel.add_child(layout)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override(&"separation", 4)
	layout.add_child(heading)
	heading.add_child(UiKit.label("Победа" if victory else "Поражение", 72, UiKit.GOLD if victory else UiKit.DANGER.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER))
	heading.add_child(UiKit.label("Этап %d / 7 · %s · Сид %d" % [RunState.stage, RunState.time_text(), RunState.seed_value], 17, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var status := UiKit.label("", 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_update_save_status(status)
	heading.add_child(status)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 22)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(h)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(290, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override(&"separation", 10)
	h.add_child(left)
	left.add_child(UiKit.label("АРТЕФАКТ ЗАБЕГА", 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var holder := RunState.artifact_holder()
	if holder != null:
		var showcase := ItemShowcase.new()
		showcase.custom_minimum_size = Vector2(290, 280)
		left.add_child(showcase)
		showcase.show_single(holder)
		left.add_child(_wrapped("«%s»" % RunState.artifact_name(), 30, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		left.add_child(UiKit.label("%d свойств · %d жертв" % [holder.properties.size(), RunState.sacrifices_count()], 17, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		left.add_child(_wrapped("Дерево ещё не выросло", 30, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		left.add_child(_wrapped("Опыт вещей остаётся даже после поражения.", 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	left.add_child(UiKit.button("Путь забега", _open_details))
	_wheel = MasteryWheel.new()
	_wheel.selected_id = _initial_item()
	h.add_child(_wheel)
	_wheel.item_selected.connect(_show_item)
	var item_frame := PanelContainer.new()
	item_frame.custom_minimum_size = Vector2(300, 0)
	item_frame.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.07, 0.05, 0.075), Color(0.25, 0.2, 0.25), 1, 8, 18))
	h.add_child(item_frame)
	_item_panel = VBoxContainer.new()
	_item_panel.add_theme_constant_override(&"separation", 10)
	item_frame.add_child(_item_panel)
	_show_item(_wheel.selected_id)
	Mastery.changed.connect(func():
		_show_item(_wheel.selected_id)
		_update_save_status(status))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 14)
	layout.add_child(buttons)
	var legend := VBoxContainer.new()
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(legend)
	legend.add_child(UiKit.label("Тусклый — прежний опыт · Яркий — за этот забег", 17, UiKit.MUTED))
	legend.add_child(UiKit.label("Внутренняя отметка: II · %d XP     Край: III · %d XP" % [int(Mastery.rules["thresholds"][1]), int(Mastery.rules["thresholds"][2])], 16, UiKit.GOLD))
	buttons.add_child(UiKit.button("Ещё забег", _again))
	buttons.add_child(UiKit.button("Главное меню", _menu))


func _wrapped(text: String, font_size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := UiKit.label(text, font_size, color, align)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _update_save_status(label: Label) -> void:
	label.text = "Не удалось сохранить опыт · прогресс пока в памяти" if Mastery.save_error else "Опыт сохранён · наведи для +XP · нажми для обликов"
	label.add_theme_color_override(&"font_color", UiKit.DANGER.lightened(0.3) if Mastery.save_error else UiKit.MUTED)


func _initial_item() -> StringName:
	var best: StringName = Db.ITEM_IDS[0]
	var best_score := -1
	for id in Db.ITEM_IDS:
		var unlocked := MasteryWheel.tier_at(float(Mastery.xp.get(id, 0))) - MasteryWheel.tier_at(float(Mastery.run_start_xp.get(id, 0)))
		var score := unlocked * 100000 + int(Mastery.run_xp.get(id, 0))
		if score > best_score:
			best = id
			best_score = score
	return best


func _show_item(id: StringName) -> void:
	for child in _item_panel.get_children():
		_item_panel.remove_child(child)
		child.queue_free()
	var color := Db.item(id).essence.color
	var total := int(Mastery.xp.get(id, 0))
	var lv := Mastery.level(id)
	var old_lv := MasteryWheel.tier_at(float(Mastery.run_start_xp.get(id, 0)))
	_item_panel.add_child(UiKit.label(Db.item(id).display_name, 34, color))
	var gained := int(Mastery.run_xp.get(id, 0))
	_item_panel.add_child(UiKit.label("+%d XP за забег" % gained, 22, UiKit.GOLD))
	var preview := ItemShowcase.new()
	preview.custom_minimum_size = Vector2(0, 170)
	_item_panel.add_child(preview)
	var state := ItemState.create(id)
	state.appearance = Mastery.selected(id)
	preview.show_single(state)
	if state.appearance != lv:
		_item_panel.add_child(UiKit.label("Выбран облик %s" % MasteryWheel.ROMAN[state.appearance - 1], 16, UiKit.MUTED))
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override(&"separation", 8)
	_item_panel.add_child(steps)
	for tier in range(1, 4):
		var badge := PanelContainer.new()
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border := color.darkened(0.45) if tier <= lv else Color(0.2, 0.17, 0.2)
		if tier > old_lv and tier <= lv:
			border = UiKit.GOLD
		badge.add_theme_stylebox_override(&"panel", UiKit.box(Color(color, 0.12) if tier <= lv else Color(0.04, 0.03, 0.05), border, 1, 5, 8))
		badge.add_child(UiKit.label(MasteryWheel.ROMAN[tier - 1], 24, UiKit.GOLD if tier <= lv else UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		badge.tooltip_text = "%s · %d XP" % [Mastery.form(id, tier)["name"], int(Mastery.rules["thresholds"][tier - 1])]
		steps.add_child(badge)
	var cap := int(Mastery.rules["thresholds"].back())
	_item_panel.add_child(UiKit.label("%d / %d XP%s" % [total, cap, " · МАКС" if lv == 3 else ""], 18, UiKit.TEXT))
	var target_tier := mini(lv + 1, 3)
	var form := Mastery.form(id, target_tier)
	var caption := "Реликвия открыта" if lv == 3 else "До облика %s: %d XP" % [MasteryWheel.ROMAN[target_tier - 1], int(Mastery.rules["thresholds"][target_tier - 1]) - total]
	if lv > old_lv:
		caption = "Новый облик %s открыт" % MasteryWheel.ROMAN[lv - 1]
		form = Mastery.form(id, lv)
	_item_panel.add_child(_wrapped(caption, 18, UiKit.GOLD))
	_item_panel.add_child(_wrapped(str(form["name"]), 26, UiKit.TEXT))
	_item_panel.add_child(_wrapped(str(form["effect"]), 17, UiKit.MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_panel.add_child(spacer)
	_item_panel.add_child(UiKit.button("Все облики", _open_collection))


func _open_collection() -> void:
	_close_modal()
	get_viewport().gui_release_focus()
	var collection := MasteryUi.new()
	collection.selected_id = _wheel.selected_id
	_modal = collection
	_ui.add_child(_modal)


func _open_details() -> void:
	_close_modal()
	get_viewport().gui_release_focus()
	_modal = Control.new()
	UiKit.full_rect(_modal)
	_ui.add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.01, 0.025, 0.94)
	UiKit.full_rect(dim)
	_modal.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -540
	panel.offset_right = 540
	panel.offset_top = -370
	panel.offset_bottom = 370
	_modal.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 14)
	panel.add_child(layout)
	layout.add_child(UiKit.label("Путь забега", 36, UiKit.GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var text := UiKit.rich(_details(RunState.artifact_holder()), 19)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text)
	layout.add_child(UiKit.button("Закрыть", _close_modal))


func _close_modal() -> void:
	if is_instance_valid(_modal):
		_ui.remove_child(_modal)
		_modal.queue_free()
	_modal = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and is_instance_valid(_modal):
		_close_modal()
		get_viewport().set_input_as_handled()


func _details(holder: ItemState) -> String:
	var g := UiKit.hex(UiKit.GOLD)
	var muted := UiKit.hex(UiKit.MUTED)
	var lines := PackedStringArray()
	lines.append("[b][color=#%s]Дерево свойств[/color][/b]" % g)
	if holder != null:
		lines.append(PropertyTree.tree_bbcode(holder, true))
	else:
		lines.append("[color=#%s]жертв не было — дерево не выросло[/color]" % muted)
	if RunState.ring.size() > 1:
		lines.append("")
		lines.append("[b][color=#%s]Оставшиеся вещи[/color][/b]" % g)
		for s in RunState.ring.items:
			if s != holder:
				lines.append(PropertyTree.tree_bbcode(s))
	lines.append("")
	lines.append("[b][color=#%s]Жертвы по порядку[/color][/b]" % g)
	if RunState.sacrifice_log.is_empty():
		lines.append("[color=#%s]—[/color]" % muted)
	for i in RunState.sacrifice_log.size():
		var e: Dictionary = RunState.sacrifice_log[i]
		var p: Property = e["property"]
		var ess := Db.essence(p.essence_id)
		lines.append("%d. [b]%s[/b] → %s: [color=#%s]«%s»[/color]  [color=#%s](этап %d)[/color]" % [
			i + 1, Db.item(e["victim"]).display_name, Db.item(e["recipient"]).display_name,
			UiKit.hex(ess.color), p.display_name(), muted, int(e["stage"])])
	return "\n".join(lines)


func _again() -> void:
	RunState.new_run()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
