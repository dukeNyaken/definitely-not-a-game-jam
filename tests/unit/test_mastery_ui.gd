extends GutTest

var _xp: Dictionary
var _choices: Dictionary
var _memory: bool
var _save_error: bool


func before_each() -> void:
	_xp = Mastery.xp.duplicate()
	_choices = Mastery.choices.duplicate()
	_memory = Mastery.memory_only
	_save_error = Mastery.save_error
	Mastery.memory_only = true
	Mastery.save_error = false
	Mastery.xp = {&"boots": 1000, &"sword": 250}
	Mastery.choices = {&"boots": 2}


func after_each() -> void:
	Mastery.xp = _xp
	Mastery.choices = _choices
	Mastery.memory_only = _memory
	Mastery.save_error = _save_error


func collection(id: StringName = &"boots") -> MasteryUi:
	var control := MasteryUi.new()
	control.selected_id = id
	add_child_autofree(control)
	return control


func test_collection_starts_on_requested_item_and_equipped_form() -> void:
	var control := collection()
	assert_eq(control._wheel.selected_id, &"boots")
	assert_eq(control.preview_tier, 2)
	assert_eq(control._tier_buttons.size(), 3)
	assert_true(control._equip.disabled)
	assert_eq(control._form_name.text, str(Mastery.form(&"boots", 2)["name"]))


func test_locked_form_can_be_previewed_but_cannot_be_equipped() -> void:
	var control := collection(&"sword")
	control._tier_buttons[2].pressed.emit()
	assert_eq(control.preview_tier, 3)
	assert_eq(control._form_name.text, str(Mastery.form(&"sword", 3)["name"]))
	assert_true(control._equip.disabled)
	control._choose_preview()
	assert_eq(Mastery.selected(&"sword"), 2)
	assert_eq(Mastery.xp[&"sword"], 250)


func test_equip_updates_in_place_without_losing_item_or_inspected_tier() -> void:
	var control := collection()
	control._tier_buttons[0].pressed.emit()
	assert_false(control._equip.disabled)
	control._equip.pressed.emit()
	assert_eq(Mastery.selected(&"boots"), 1)
	assert_eq(control.selected_id, &"boots")
	assert_eq(control.preview_tier, 1)
	assert_false(control.is_queued_for_deletion())
	assert_true(control._equip.disabled)
	assert_eq(control._tier_status[0].text, "Выбран")
	assert_eq(Mastery.level(&"boots"), 3)


func test_circle_click_selects_locked_tier_without_changing_equipped_form() -> void:
	var control := collection()
	var wheel := control._wheel
	wheel.size = Vector2(610, 570)
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = wheel.size * 0.5 + Vector2.UP * (wheel._form_radius() - 10)
	wheel._gui_input(event)
	assert_eq(control.selected_id, &"sword")
	assert_eq(control.preview_tier, 3)
	assert_true(control._equip.disabled)
	assert_eq(Mastery.selected(&"sword"), 2)
	assert_true(wheel.earned_xp.is_empty())
	assert_eq(wheel.displayed_xp(0), 250.0)


func test_external_unlock_refreshes_circle_and_inspected_form() -> void:
	var control := collection(&"sword")
	control._inspect_tier(3)
	Mastery.xp[&"sword"] = 1000
	Mastery.choices[&"sword"] = 3
	Mastery.changed.emit()
	assert_true(control._equip.disabled)
	assert_eq(control._wheel.displayed_xp(0), 1000.0)
	assert_eq(control._tier_status[2].text, "Выбран")
	Mastery.save_error = true
	Mastery.changed.emit()
	assert_true(control._save_status.text.contains("Не удалось сохранить"))


func test_result_tier_buttons_preview_locked_forms_without_unlocking_or_equipping() -> void:
	var card = load("res://scripts/ui/final_card.gd").new()
	add_child_autofree(card)
	card._wheel.select_item(&"sword")
	card._tier_buttons[2].pressed.emit()
	assert_eq(card._preview_tier, 3)
	assert_eq(card._form_name.text, str(Mastery.form(&"sword", 3)["name"]))
	assert_eq(card._form_effect.text, str(Mastery.form(&"sword", 3)["effect"]))
	assert_true(card._equip.disabled)
	card._choose_preview()
	assert_eq(Mastery.selected(&"sword"), 2)
	assert_eq(Mastery.level(&"sword"), 2)
	assert_eq(Mastery.xp[&"sword"], 250)
	card._tier_buttons[0].pressed.emit()
	assert_eq(card._preview_tier, 1)
	assert_eq(card._form_effect.text, Db.item(&"sword").action_text)
	assert_eq(card._preview._displays.size(), 1, "витрина заменяет модель, не складывает облики друг на друга")
	assert_eq(card._preview.pivot.get_child_count(), 1)
	var cameras := 0
	for child in card._preview.viewport.get_children():
		if child is Camera3D:
			cameras += 1
	assert_eq(cameras, 1, "переключение не накапливает камеры")
	assert_null(card._modal, "просмотр остаётся на итоговом экране")


func test_result_equipping_preview_updates_in_place_and_switching_item_selects_its_form() -> void:
	var card = load("res://scripts/ui/final_card.gd").new()
	add_child_autofree(card)
	card._wheel.select_item(&"boots")
	var buttons: Array = card._tier_buttons.duplicate()
	card._tier_buttons[0].pressed.emit()
	assert_false(card._equip.disabled)
	card._equip.pressed.emit()
	assert_eq(Mastery.selected(&"boots"), 1)
	assert_eq(Mastery.level(&"boots"), 3)
	assert_eq(card._preview_tier, 1)
	assert_true(card._equip.disabled)
	assert_eq(card._tier_buttons, buttons, "выбор не пересоздаёт карточку и кнопки")
	card._wheel.select_item(&"sword")
	assert_eq(card._preview_tier, 2)
	assert_eq(card._form_name.text, str(Mastery.form(&"sword", 2)["name"]))
