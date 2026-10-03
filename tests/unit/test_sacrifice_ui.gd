extends GutTest

var _saved: Dictionary


func before_each() -> void:
	_saved = {"ring": RunState.ring, "snapshots": RunState.snapshots.duplicate(), "log": RunState.sacrifice_log.duplicate(), "stage": RunState.stage, "seen": RunState.seen_ring_tutorial, "running": RunState.running}
	RunState.ring = Ring.from_ids([&"shield", &"boots", &"sword", &"armor", &"gloves", &"helmet", &"amulet"])
	RunState.snapshots.clear()
	RunState.sacrifice_log.clear()
	RunState.stage = 1
	RunState.seen_ring_tutorial = true
	RunState.running = false


func after_each() -> void:
	RunState.ring = _saved["ring"]
	RunState.snapshots.assign(_saved["snapshots"])
	RunState.sacrifice_log.assign(_saved["log"])
	RunState.stage = _saved["stage"]
	RunState.seen_ring_tutorial = _saved["seen"]
	RunState.running = _saved["running"]


func _example() -> void:
	RunState.sacrifice(0)
	RunState.sacrifice(RunState.ring.index_of(&"helmet"))
	RunState.stage = 3


func test_inherited_chain_is_explained_and_preview_does_not_sacrifice() -> void:
	_example()
	var data := SacrificePreview.build(RunState.ring, 0)
	assert_true(data["loss"].contains("Пробел"))
	assert_true(data["gain"].contains("При ударе мечом"))
	assert_true(data["gain"].contains("4 м"))
	assert_true(data["gain"].contains("При рывке".to_lower()))
	assert_true(data["gain"].contains("отражение снарядов"))
	assert_eq(data["before"], "10 / 10 / 20")
	assert_eq(data["result"], "12 / 12 / 24")
	assert_eq(RunState.ring.size(), 5)
	assert_eq(RunState.ring.get_item(&"sword").properties.size(), 0)
	assert_eq(RunState.ring.get_item(&"boots").properties.size(), 1)
	assert_eq(RunState.snapshots.size(), 2)


func test_current_appearance_stats_are_used_and_its_native_effect_is_not_transferred() -> void:
	RunState.ring.get_item(&"armor").appearance = 3
	RunState.ring.get_item(&"gloves").appearance = 3
	var data := SacrificePreview.build(RunState.ring, RunState.ring.index_of(&"armor"))
	assert_true(data["now"].contains("70 брони"))
	assert_true(data["loss"].contains("70 брони"))
	assert_true(data["loss"].contains("эффект облика"))
	assert_true(data["gain"].contains("5,5 урона"))
	assert_true(data["keep"].contains("Длань властелина"))
	assert_true(data["details"].contains("100°"))
	assert_true(data["details"].contains("2 с"))
	assert_eq((data["after"] as ItemState).appearance, 3)


func test_properties_use_essence_stats_instead_of_sacrificed_appearance() -> void:
	RunState.ring.get_item(&"boots").appearance = 3
	var data := SacrificePreview.build(RunState.ring, RunState.ring.index_of(&"boots"))
	assert_true(data["now"].contains("5 м"))
	assert_true(data["gain"].contains("4 м"), "сила рывка берётся из сущности, а не облика")
	assert_false(data["gain"].contains("5 м"))


func test_parallel_recipient_properties_survive_and_damage_uses_total_property_count() -> void:
	_example()
	var data := SacrificePreview.build(RunState.ring, RunState.ring.index_of(&"gloves"))
	assert_eq(data["before"], "22")
	assert_eq(data["result"], "24")
	assert_true(data["keep"].contains("Зоркий залп"))
	assert_true(data["details"].contains("открытие врагов"))
	assert_true(data["details"].contains("притяжение врагов"))


func test_every_pair_and_form_has_complete_spoiler_free_copy() -> void:
	for tier in range(1, 4):
		for victim_id in Db.ITEM_IDS:
			for recipient_id in Db.ITEM_IDS:
				if victim_id == recipient_id:
					continue
				var ring := Ring.from_ids([victim_id, recipient_id])
				for item in ring.items:
					item.appearance = tier
				var data := SacrificePreview.build(ring, 0)
				for field in ["now", "loss", "gain", "keep", "details"]:
					var text := str(data[field])
					assert_false(text.is_empty())
					assert_false(text.to_lower().contains("тиран"))
					assert_false(text.to_lower().contains("босс"))
					assert_false(text.to_lower().contains("фаз"))
	assert_eq(SacrificePreview.build(Ring.from_ids([&"sword"]), 0), {})
	assert_eq(SacrificePreview.build(RunState.ring, -1), {})


func test_card_remains_available_when_pointer_leaves_ring_and_details_do_not_sacrifice() -> void:
	_example()
	var ui := AltarUi.new()
	ui.theme = UiKit.theme()
	add_child_autofree(ui)
	ui._on_hover(0)
	var text := ui._gain.text
	ui._on_hover(-1)
	ui._leave_ring()
	assert_eq(ui._gain.text, text)
	assert_eq(ui.ring.highlight_victim, 0)
	assert_eq(ui._holding_index, -1)
	ui._details_button.button_pressed = true
	assert_true(ui._details.visible)
	assert_eq(RunState.ring.size(), 5)
	assert_false(ui._done)


func test_click_requires_hold_and_leaving_ring_resets_confirmation_progress() -> void:
	var ui := AltarUi.new()
	ui.theme = UiKit.theme()
	add_child_autofree(ui)
	watch_signals(ui)
	ui._begin_hold(0)
	assert_eq(ui._holding_index, 0)
	assert_false(ui._done)
	assert_signal_not_emitted(ui, "confirmed", "короткое нажатие не отдаёт вещь")
	ui._hold = 0.7
	ui.ring.hold_progress = 0.7
	ui._leave_ring()
	assert_eq(ui._holding_index, -1)
	assert_eq(ui._hold, 0.0)
	assert_eq(ui.ring.hold_progress, 0.0)
	ui._process(2.0)
	assert_signal_not_emitted(ui, "confirmed", "после ухода с вещи жертва не продолжается")
	assert_eq(RunState.ring.size(), 7)


func test_escape_cancels_screen_without_changing_the_ring() -> void:
	var ui := AltarUi.new()
	ui.theme = UiKit.theme()
	add_child_autofree(ui)
	watch_signals(ui)
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	ui._unhandled_input(event)
	assert_signal_emitted(ui, "cancelled")
	assert_eq(RunState.ring.size(), 7)
	assert_signal_not_emitted(ui, "confirmed")


func test_ring_card_and_footer_fit_without_overlap_at_game_resolutions() -> void:
	_example()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	add_child_autofree(viewport)
	var ui := AltarUi.new()
	ui.theme = UiKit.theme()
	viewport.add_child(ui)
	for resolution in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(2133, 900)]:
		viewport.size = resolution
		await wait_process_frames(5)
		for i in RunState.ring.size():
			ui._on_hover(i)
			await wait_process_frames(3)
			var screen := Rect2(Vector2.ZERO, Vector2(resolution))
			assert_true(screen.encloses(ui.ring.get_global_rect()))
			assert_true(screen.encloses(ui._panel.get_global_rect()))
			assert_true(screen.encloses(ui._footer.get_global_rect()))
			assert_false(ui.ring.get_global_rect().intersects(ui._panel.get_global_rect()))
			assert_lte(ui._panel.get_global_rect().end.y, ui._footer.position.y)
			assert_lte(ui._content.size.x, ui._scroll.size.x, "длинный текст переносится, а не расширяет окно")


func test_tutorial_and_final_stage_hint_do_not_reveal_sacrifice_story() -> void:
	RunState.stage = Db.balance.stage_count - 1
	RunState.seen_ring_tutorial = false
	var ui := AltarUi.new()
	ui.theme = UiKit.theme()
	add_child_autofree(ui)
	var strings := PackedStringArray()
	_collect_text(ui, strings)
	var text := "\n".join(strings).to_lower()
	assert_false(text.contains("тиран"))
	assert_false(text.contains("босс"))
	assert_false(text.contains("фаз"))
	assert_true(text.contains("ворота дворца"))


func _collect_text(node: Node, strings: PackedStringArray) -> void:
	if node is Label or node is RichTextLabel or node is Button:
		strings.append(node.text)
	for child in node.get_children():
		_collect_text(child, strings)
