extends GutTest

var _start: Dictionary
var _end: Dictionary
var _earned: Dictionary


func before_each() -> void:
	_start = Mastery.run_start_xp.duplicate()
	_end = Mastery.xp.duplicate()
	_earned = Mastery.run_xp.duplicate()
	Mastery.run_start_xp = {&"boots": 900, &"shield": 1000}
	Mastery.xp = {&"boots": 1000, &"shield": 1000}
	Mastery.run_xp = {&"boots": 450, &"shield": 210}


func after_each() -> void:
	Mastery.run_start_xp = _start
	Mastery.xp = _end
	Mastery.run_xp = _earned


func wheel() -> MasteryWheel:
	var result := MasteryWheel.new()
	add_child_autofree(result)
	result.size = Vector2(610, 570)
	return result


func test_capped_reward_animates_only_actual_progress_and_keeps_full_reward() -> void:
	var control := wheel()
	var boots := Db.ITEM_IDS.find(&"boots")
	var shield := Db.ITEM_IDS.find(&"shield")
	assert_eq(control.displayed_xp(boots), 900.0)
	assert_eq(control.displayed_xp(shield), 1000.0)
	control.finish_animation()
	assert_eq(control.displayed_xp(boots), 1000.0)
	assert_eq(control.displayed_xp(shield), 1000.0)
	assert_eq(control.earned_xp[&"boots"], 450)
	assert_eq(control.displayed_xp(Db.ITEM_IDS.find(&"sword")), 0.0)


func test_all_sectors_select_correct_item_and_hub_does_not_select() -> void:
	var control := wheel()
	watch_signals(control)
	for i in Db.ITEM_IDS.size():
		var point := control.size * 0.5 + Vector2.from_angle(-PI * 0.5 + TAU * i / 7) * 100
		assert_eq(control.sector_at(point), i)
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		control._gui_input(click)
		assert_eq(control.selected_id, Db.ITEM_IDS[i])
	assert_signal_emit_count(control, "item_selected", 7)
	assert_eq(control.sector_at(control.size * 0.5), -1)
	assert_eq(control.sector_at(Vector2(-10, -10)), -1)


func test_wheel_freezes_run_values_and_recognizes_exact_thresholds() -> void:
	var control := wheel()
	Mastery.run_start_xp.clear()
	Mastery.xp.clear()
	Mastery.run_xp.clear()
	assert_eq(control.start_xp[&"boots"], 900)
	control.finish_animation()
	assert_eq(control.displayed_xp(Db.ITEM_IDS.find(&"boots")), 1000.0)
	assert_eq(MasteryWheel.tier_at(249), 1)
	assert_eq(MasteryWheel.tier_at(250), 2)
	assert_eq(MasteryWheel.tier_at(999), 2)
	assert_eq(MasteryWheel.tier_at(1000), 3)


func test_three_bands_keep_initial_form_full_and_split_xp_at_unlock_thresholds() -> void:
	assert_eq(MasteryWheel.tier_progress(0, 1), 1.0, "исходный облик открыт до получения опыта")
	assert_eq(MasteryWheel.tier_progress(0, 2), 0.0)
	assert_eq(MasteryWheel.tier_progress(0, 3), 0.0)
	assert_eq(MasteryWheel.tier_progress(250, 2), 1.0)
	assert_eq(MasteryWheel.tier_progress(250, 3), 0.0)
	assert_eq(MasteryWheel.tier_progress(625, 3), 0.5, "III заполняется на интервале 250–1000")
	for tier in range(1, 4):
		assert_eq(MasteryWheel.tier_progress(1000, tier), 1.0, "на максимуме видны все три полных пояса")
	var old_ii := MasteryWheel.tier_progress(210, 2)
	var new_ii := MasteryWheel.tier_progress(320, 2)
	assert_almost_eq(new_ii - old_ii, 40.0 / 250.0, 0.00001, "40 XP закрывают II")
	assert_almost_eq(MasteryWheel.tier_progress(320, 3), 70.0 / 750.0, 0.00001, "оставшиеся 70 XP заполняют III")
