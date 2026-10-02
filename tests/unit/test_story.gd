extends GutTest
## Сюжет: у каждой вещи есть свой получатель и все реплики; строк Ильвы и Сигварда — по числу жертв;
## выбор вещей для финала и для реплик в бою совпадает с тем, что делает босс.

const REQUIRED := ["who", "plea", "reply", "oath", "secret", "bark", "payoff"]


func _snaps(ids: Array) -> Array[ItemState]:
	var out: Array[ItemState] = []
	for id in ids:
		out.append(ItemState.create(id))
	return out


func test_every_item_has_a_full_gift() -> void:
	for id in Db.ITEM_IDS:
		var g := Story.gift(id)
		assert_false(g.is_empty(), "дар для %s" % id)
		for key in REQUIRED:
			assert_ne(str(g.get(key, "")), "", "%s.%s" % [id, key])
		assert_true(Story.SPEAKERS.has(g["who"]), "говорящий %s" % g["who"])


func test_each_item_has_its_own_recipient() -> void:
	var seen := {}
	for id in Db.ITEM_IDS:
		var who: StringName = Story.gift(id)["who"]
		assert_false(seen.has(who), "%s получает только одну вещь" % who)
		seen[who] = true
	assert_eq(Story.gift(&"amulet")["who"], &"beloved", "оберег — любимой")
	assert_false(seen.has(&"faithful"), "Ильва ничего не получает")


func test_lines_per_sacrifice() -> void:
	var sacrifices := Db.balance.stage_count - 1
	assert_eq(Story.IVA_LINES.size(), sacrifices)
	assert_eq(Story.BROTHER_LINES.size(), sacrifices)


func test_brother_barks_cover_every_phase_change() -> void:
	for p in range(1, Db.balance.boss_phase_item_counts.size()):
		assert_true(Story.BROTHER_BARKS.has(p), "фаза %d" % (p + 1))


func test_genitive_for_every_item() -> void:
	for id in Db.ITEM_IDS:
		assert_true(Story.GENITIVE.has(id), str(id))


func test_light_caption() -> void:
	assert_eq(Story.light_caption(&"sword", &"boots", "Режущий рывок"),
		"Сила меча не ослабла — она осветила путь: сапоги, «Режущий рывок».")


func test_speakers_with_models_are_npc_kinds() -> void:
	for who in Story.SPEAKERS:
		var sp: Dictionary = Story.SPEAKERS[who]
		if sp.has("kind"):
			assert_gte(int(sp["kind"]), ActorModel.Kind.FRIEND, str(who))
	assert_eq(Story.kind_of(&"hero"), ActorModel.Kind.HERO)
	assert_eq(Story.kind_of(&"brother"), ActorModel.Kind.TYRANT)


func test_recipients_in_sacrifice_order() -> void:
	var snaps := _snaps([&"boots", &"amulet", &"sword"])
	assert_eq(Story.recipients(snaps), [&"refugee", &"beloved", &"friend"] as Array[StringName])
	assert_true(Story.was_given(snaps, &"amulet"))
	assert_false(Story.was_given(snaps, &"gloves"))


func test_finale_items_only_sacrificed_and_capped() -> void:
	assert_eq(Story.finale_items(_snaps([&"sword", &"boots"])), [&"sword", &"boots"] as Array[StringName])
	var all := _snaps([&"sword", &"shield", &"armor", &"helmet", &"gloves", &"boots"])
	assert_eq(Story.finale_items(all, 4).size(), 4)
	assert_eq(Story.finale_items(all, 4)[0], &"sword")


func test_phase_dropped_matches_boss_phases() -> void:
	var all := _snaps([&"sword", &"shield", &"armor", &"helmet", &"gloves", &"boots"])
	var counts: PackedInt32Array = Db.balance.boss_phase_item_counts
	assert_eq(Story.phase_dropped(0, all).size(), 0)
	for p in range(1, counts.size()):
		var dropped := Story.phase_dropped(p, all)
		assert_eq(dropped.size(), counts[p - 1] - counts[p], "фаза %d" % (p + 1))
		assert_eq(dropped[0], all[counts[p]], "первой сбрасывается вещь сразу за оставшимися")
	# Мало жертв: сбрасывать нечего или почти нечего.
	var two := _snaps([&"sword", &"boots"])
	assert_eq(Story.phase_dropped(1, two).size(), 0)
	assert_eq(Story.phase_dropped(2, two), [two[1]] as Array[ItemState])
