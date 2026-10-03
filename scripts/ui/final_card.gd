extends Control
## Карточка артефакта: имя, дерево свойств, жертвы по порядку, сид, время, итог, «Ещё забег».


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
	var ui := Control.new()
	ui.theme = UiKit.theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(ui)
	ui_layer.add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -720
	panel.offset_right = 720
	panel.offset_top = -410
	panel.offset_bottom = 410
	panel.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.05, 0.035, 0.04, 0.97), UiKit.GOLD if victory else UiKit.BLOOD, 3, 2, 26))
	ui.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 28)
	panel.add_child(h)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override(&"separation", 10)
	h.add_child(left)
	left.add_child(UiKit.label("Победа" if victory else "Поражение", 30, UiKit.GOLD if victory else UiKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	var holder := RunState.artifact_holder()
	var showcase := ItemShowcase.new()
	showcase.custom_minimum_size = Vector2(420, 380)
	left.add_child(showcase)
	if holder != null:
		showcase.show_single(holder)
	left.add_child(UiKit.outlined(UiKit.label("«%s»" % RunState.artifact_name(), 34, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 6))
	var result := "%s повержен" % Story.TYRANT_NAME if victory else "Погиб на этапе %d" % RunState.stage
	left.add_child(UiKit.label(result, 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if victory:
		var epilogue := UiKit.label(Story.FINALE["epilogue"], 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		epilogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		epilogue.custom_minimum_size = Vector2(420, 0)
		left.add_child(epilogue)
	left.add_child(UiKit.label("Сид %d · Время %s" % [RunState.seed_value, RunState.time_text()], 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 14)
	buttons.add_child(UiKit.button("Ещё забег", _again))
	buttons.add_child(UiKit.button("Главное меню", _menu))
	left.add_child(buttons)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	var text := UiKit.rich(_details(holder), 19)
	text.custom_minimum_size = Vector2(900, 0)
	scroll.add_child(text)


func _details(holder: ItemState) -> String:
	var g := UiKit.hex(UiKit.GOLD)
	var muted := UiKit.hex(UiKit.MUTED)
	var lines := PackedStringArray()
	lines.append("[b]Опыт вещей за забег — сохранён навсегда[/b]" if not Mastery.save_error else "[b]Ошибка сохранения опыта: прогресс пока только в памяти[/b]")
	for id in Db.ITEM_IDS:
		lines.append("%s: +%d XP · %s" % [Db.item(id).display_name, int(Mastery.run_xp.get(id, 0)), Mastery.progress_text(id)])
	lines.append("")
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
