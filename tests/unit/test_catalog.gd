extends GutTest
## Меню «Катсцены»: каталог сцен по порядку забега и подготовка забега под сцену (Theater).

var _old_cutscenes: bool


func before_each() -> void:
	_old_cutscenes = Render.cutscenes


func after_each() -> void:
	Render.cutscenes = _old_cutscenes
	Theater.close()
	RunState.new_run(0)
	RunState.running = false


func _keys() -> Array[String]:
	var out: Array[String] = []
	for e in CutsceneCatalog.entries():
		out.append(e["key"])
	return out


func _given(key: String, chosen: Dictionary = {}) -> Array[StringName]:
	var e := CutsceneCatalog.find(key)
	return CutsceneCatalog.given_before(e, CutsceneCatalog.resolve(e, chosen))


func test_entries_are_complete() -> void:
	var seen := {}
	for e in CutsceneCatalog.entries():
		var key: String = e["key"]
		assert_false(seen.has(key), "ключ %s не повторяется" % key)
		seen[key] = true
		for field in ["group", "when", "about"]:
			assert_ne(str(e[field]), "", "%s.%s" % [key, field])
		assert_false((e["logic"] as Array).is_empty(), "%s: логика" % key)
		var opts := CutsceneCatalog.resolve(e)
		assert_ne(str(CutsceneCatalog.title_of(e, opts)[0]), "", "%s: заголовок" % key)
		var cast := CutsceneCatalog.cast_of(e, opts)
		assert_false(cast.is_empty(), "%s: действующие лица" % key)
		for who in cast:
			assert_true(Story.SPEAKERS.has(who), "%s: %s" % [key, who])
		var quote := CutsceneCatalog.quote_of(e, opts)
		assert_eq(quote.size(), 2, "%s: ключевая реплика" % key)
		assert_ne(str(quote[1]), "", "%s: текст реплики" % key)
		if e["playable"]:
			assert_gt(int(e["seconds"]), 0, "%s: длительность" % key)


func test_timeline_follows_the_run() -> void:
	var keys := _keys()
	var gifts := Db.balance.stage_count - 1
	assert_eq(keys.front(), "prologue")
	assert_eq(keys.back(), "finale")
	for n in range(1, gifts + 1):
		assert_lt(keys.find("gift_%d" % n), keys.find("palace_%d" % n), "дар %d — раньше голоса из дворца" % n)
	# Дом Сольвейг и её разговор с Сигвардом — между даром и голосом из дворца.
	for pair in [["hearth", Story.HEARTH_AFTER_GIFT], ["temptation", Story.TEMPTATION_AFTER_GIFT]]:
		var at := keys.find(pair[0])
		assert_eq(keys[at - 1], "gift_%d" % pair[1], pair[0])
		assert_eq(keys[at + 1], "palace_%d" % pair[1], pair[0])
	assert_lt(keys.find("gates"), keys.find("finale"))
	assert_eq(CutsceneCatalog.playable().size(), keys.size() - 1, "отдельно не показать только реплики в бою")
	assert_false(CutsceneCatalog.find("barks")["playable"])


func test_options_have_a_default_among_choices() -> void:
	for e in CutsceneCatalog.entries():
		for o in e["options"]:
			var values := []
			for c in o["choices"]:
				values.append(c[0])
			assert_true(values.has(o["default"]), "%s.%s" % [e["key"], o["key"]])
	assert_eq(CutsceneCatalog.resolve(CutsceneCatalog.find("hearth"), {"amulet": "kept", "чужой": 1}), {"amulet": "kept"})


func test_gift_takes_its_title_and_cast_from_the_item() -> void:
	var e := CutsceneCatalog.find("gift_3")
	assert_eq(CutsceneCatalog.title_of(e, {"item": &"sword"}), ["Дар третий", "Меч · Торстейн"])
	assert_eq(CutsceneCatalog.cast_of(e, {"item": &"sword"}), [&"hero", &"friend", &"faithful"] as Array[StringName])
	assert_eq(CutsceneCatalog.quote_of(e, {"item": &"amulet"}), [&"beloved", Story.GIFTS[&"amulet"]["oath"]])


func test_given_before_follows_the_options() -> void:
	assert_eq(_given("prologue").size(), 0)
	assert_eq(_given("gift_1").size(), 0)
	var before_third := _given("gift_3", {"item": &"sword"})
	assert_eq(before_third.size(), 2)
	assert_false(before_third.has(&"sword"), "вещь дара ещё у Солдата")
	assert_eq(_given("hearth", {"amulet": "given"}).size(), Story.HEARTH_AFTER_GIFT)
	assert_true(_given("hearth", {"amulet": "given"}).has(&"amulet"))
	assert_eq(_given("hearth", {"amulet": "kept"}).size(), Story.HEARTH_AFTER_GIFT)
	assert_false(_given("hearth", {"amulet": "kept"}).has(&"amulet"))
	assert_eq(_given("temptation").size(), Story.TEMPTATION_AFTER_GIFT)
	var ring := "palace_%d" % Story.RING_LINE_INDEX
	assert_true(_given(ring, {"ring": "given"}).has(&"gloves"))
	assert_false(_given(ring, {"ring": "kept"}).has(&"gloves"))
	assert_eq(_given(ring, {"ring": "kept"}).size(), Story.RING_LINE_INDEX)
	for key in ["gates", "finale"]:
		var given := _given(key, {"kept": &"amulet"})
		assert_eq(given.size(), Db.ITEM_IDS.size() - 1, key)
		assert_false(given.has(&"amulet"), key)


func test_quotes_follow_the_options() -> void:
	var ring := CutsceneCatalog.find("palace_%d" % Story.RING_LINE_INDEX)
	assert_eq(CutsceneCatalog.quote_of(ring, {"ring": "given"})[1], Story.BROTHER_RING_LINE)
	assert_eq(CutsceneCatalog.quote_of(ring, {"ring": "kept"})[1], Story.BROTHER_LINES[Story.RING_LINE_INDEX - 1])
	var gates := CutsceneCatalog.find("gates")
	assert_eq(CutsceneCatalog.quote_of(gates, {"kept": &"amulet"})[1], Story.GATES["confess_kept"])
	assert_eq(CutsceneCatalog.quote_of(gates, {"kept": &"helmet"})[1], Story.GATES["confess_given"])
	var finale := CutsceneCatalog.find("finale")
	assert_true(CutsceneCatalog.cast_of(finale, {"kept": &"helmet"}).has(&"captain"))
	assert_false(CutsceneCatalog.cast_of(finale, {"kept": &"gloves"}).has(&"captain"), "перчатки не отданы — Бьёрн не выходит")


func test_prepare_sets_up_the_run_for_a_scene() -> void:
	var e := CutsceneCatalog.find("temptation")
	Theater.prepare({"key": "temptation", "opts": CutsceneCatalog.resolve(e)})
	assert_eq(RunState.sacrifices_count(), Story.TEMPTATION_AFTER_GIFT)
	assert_eq(RunState.stage, Story.TEMPTATION_AFTER_GIFT)
	assert_eq(RunState.ring.size(), Db.ITEM_IDS.size() - Story.TEMPTATION_AFTER_GIFT)
	assert_false(RunState.running, "время забега в просмотре не идёт")
	var gates := CutsceneCatalog.find("gates")
	Theater.prepare({"key": "gates", "opts": CutsceneCatalog.resolve(gates, {"kept": &"sword"})})
	assert_true(RunState.is_boss_stage())
	assert_eq(RunState.ring.ids(), [&"sword"] as Array[StringName])
	assert_false(Story.was_given(RunState.snapshots, &"sword"))


func test_theater_plays_scenes_whatever_the_setting() -> void:
	Render.cutscenes = false
	assert_false(Cutscene.enabled())
	var items: Array[Dictionary] = [{"key": "hearth", "opts": {}}]
	Theater.queue = items
	Theater.cursor = 0
	assert_true(Theater.requested())
	assert_true(Cutscene.enabled(), "в просмотре сцены идут и при выключенной настройке")
	Theater.close()
	assert_false(Theater.requested())
	assert_false(Cutscene.enabled())


func test_duration_text() -> void:
	assert_eq(CutsceneCatalog.duration_text(0), "")
	assert_eq(CutsceneCatalog.duration_text(11), "около 11 с")
	assert_eq(CutsceneCatalog.duration_text(120), "около 2 мин")
	assert_eq(CutsceneCatalog.duration_text(70), "около 1 мин 10 с")
