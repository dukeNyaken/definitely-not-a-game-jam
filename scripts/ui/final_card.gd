extends Control
## Итог забега: колесо постоянного опыта и артефакт. Подробности — по запросу.

var _ui: Control
var _wheel: MasteryWheel
var _item_panel: VBoxContainer
var _modal: Control
var _preview_tier := 1
var _preview: ItemShowcase
var _tier_buttons: Array[Button] = []
var _item_title: Label
var _reward_label: Label
var _progress_label: Label
var _unlock_caption: Label
var _form_name: Label
var _form_effect: Label
var _equip: Button


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
	panel.offset_top = -425
	panel.offset_bottom = 425
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
	var story_result := "%s повержен" % Story.TYRANT_NAME if victory else "Погиб на этапе %d" % RunState.stage
	left.add_child(UiKit.label(story_result, 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if victory:
		left.add_child(_wrapped(Story.FINALE["epilogue"], 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	left.add_child(UiKit.button("Путь забега", _open_details))
	_wheel = MasteryWheel.new()
	_wheel.selected_id = _initial_item()
	h.add_child(_wheel)
	_wheel.item_selected.connect(_show_item)
	_wheel.appearance_inspected.connect(func(_id: StringName, tier: int): _inspect_tier(tier))
	var item_frame := PanelContainer.new()
	item_frame.custom_minimum_size = Vector2(300, 0)
	item_frame.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.07, 0.05, 0.075), Color(0.25, 0.2, 0.25), 1, 8, 18))
	h.add_child(item_frame)
	_item_panel = VBoxContainer.new()
	_item_panel.add_theme_constant_override(&"separation", 8)
	item_frame.add_child(_item_panel)
	_build_item_panel()
	_show_item(_wheel.selected_id)
	Mastery.changed.connect(func():
		_refresh_item()
		_update_save_status(status))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 14)
	layout.add_child(buttons)
	var legend := VBoxContainer.new()
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(legend)
	legend.add_child(UiKit.label("Тусклый — до забега · Яркий — полученный XP", 17, UiKit.MUTED))
	legend.add_child(UiKit.label("От центра: I — открыт · II — %d XP · III — %d XP" % [int(Mastery.rules["thresholds"][1]), int(Mastery.rules["thresholds"][2])], 16, UiKit.GOLD))
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


func _build_item_panel() -> void:
	_item_title = UiKit.label("", 34)
	_item_panel.add_child(_item_title)
	_reward_label = UiKit.label("", 22, UiKit.GOLD)
	_item_panel.add_child(_reward_label)
	_preview = ItemShowcase.new()
	_preview.custom_minimum_size = Vector2(0, 130)
	_item_panel.add_child(_preview)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override(&"separation", 8)
	_item_panel.add_child(steps)
	for tier in range(1, 4):
		var badge := UiKit.button(MasteryWheel.ROMAN[tier - 1], _inspect_tier.bind(tier))
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.focus_mode = Control.FOCUS_ALL
		badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		badge.add_theme_font_size_override(&"font_size", 24)
		steps.add_child(badge)
		_tier_buttons.append(badge)
	_progress_label = UiKit.label("", 18, UiKit.TEXT)
	_item_panel.add_child(_progress_label)
	_unlock_caption = _wrapped("", 18, UiKit.GOLD)
	_item_panel.add_child(_unlock_caption)
	_form_name = _wrapped("", 26, UiKit.TEXT)
	# Место под две строки названия и три строки эффекта не меняется при выборе.
	_form_name.custom_minimum_size.y = 70
	_item_panel.add_child(_form_name)
	_form_effect = _wrapped("", 17, UiKit.MUTED)
	_form_effect.custom_minimum_size.y = 75
	_item_panel.add_child(_form_effect)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_panel.add_child(spacer)
	_equip = UiKit.button("", _choose_preview)
	_equip.focus_mode = Control.FOCUS_ALL
	_item_panel.add_child(_equip)


func _show_item(id: StringName) -> void:
	_preview_tier = Mastery.selected(id)
	_item_title.text = Db.item(id).display_name
	_item_title.add_theme_color_override(&"font_color", Db.item(id).essence.color)
	_refresh_item()


func _inspect_tier(tier: int) -> void:
	_preview_tier = clampi(tier, 1, 3)
	_refresh_item()


func _choose_preview() -> void:
	var id := _wheel.selected_id
	if _preview_tier <= Mastery.level(id) and _preview_tier != Mastery.selected(id):
		Mastery.choose(id, _preview_tier)


func _refresh_item() -> void:
	var id := _wheel.selected_id
	var total := int(Mastery.xp.get(id, 0))
	var lv := Mastery.level(id)
	var equipped := Mastery.selected(id)
	var old_lv := MasteryWheel.tier_at(float(Mastery.run_start_xp.get(id, 0)))
	var color := Db.item(id).essence.color
	_reward_label.text = "+%d XP за забег" % int(Mastery.run_xp.get(id, 0))
	var state := ItemState.create(id)
	state.appearance = _preview_tier
	_preview.show_single(state)
	for i in _tier_buttons.size():
		var tier := i + 1
		var unlocked := tier <= lv
		var border := color.darkened(0.45) if unlocked else Color(0.2, 0.17, 0.2)
		if tier == _preview_tier:
			border = UiKit.GOLD
		_tier_buttons[i].add_theme_stylebox_override(&"normal", UiKit.box(Color(color, 0.12) if unlocked else Color(0.04, 0.03, 0.05), border, 2 if tier == _preview_tier else 1, 5, 8))
		_tier_buttons[i].add_theme_stylebox_override(&"hover", UiKit.box(Color(color, 0.18), color, 2, 5, 8))
		_tier_buttons[i].add_theme_color_override(&"font_color", UiKit.GOLD if unlocked else UiKit.MUTED)
		_tier_buttons[i].tooltip_text = "%s · %d XP%s" % [Mastery.form(id, tier)["name"], int(Mastery.rules["thresholds"][i]), " · выбран" if tier == equipped else " · новый" if tier > old_lv and unlocked else ""]
	var cap := int(Mastery.rules["thresholds"].back())
	_progress_label.text = "%d / %d XP%s" % [total, cap, " · МАКС" if lv == 3 else ""]
	var target_tier := mini(lv + 1, 3)
	_unlock_caption.text = "Реликвия открыта" if lv == 3 else "До облика %s: %d XP" % [MasteryWheel.ROMAN[target_tier - 1], int(Mastery.rules["thresholds"][target_tier - 1]) - total]
	if lv > old_lv:
		_unlock_caption.text = "Новый облик %s открыт" % MasteryWheel.ROMAN[lv - 1]
	var form := Mastery.form(id, _preview_tier)
	_form_name.text = str(form["name"]) if _preview_tier > 1 else "%s · исходный облик" % Db.item(id).display_name
	_form_effect.text = str(form["effect"]) if _preview_tier > 1 else Db.item(id).action_text
	_equip.disabled = _preview_tier > lv or _preview_tier == equipped
	_equip.text = "Облик выбран" if _preview_tier == equipped else "Ещё %d XP" % (int(Mastery.rules["thresholds"][_preview_tier - 1]) - total) if _preview_tier > lv else "Выбрать облик"
	_equip.tooltip_text = "Выбран для следующего забега" if _preview_tier == equipped else "Облик пока закрыт" if _preview_tier > lv else "Надеть в следующем забеге"


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
