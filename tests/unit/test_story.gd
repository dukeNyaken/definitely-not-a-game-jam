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
		"Отданное не ослабляет: сила меча перешла в сапоги — «Режущий рывок».")
	assert_string_contains(Story.light_caption(&"boots", &"amulet", "Х"), "в оберег", "амулет в сюжете — оберег")


func test_item_names_for_every_item() -> void:
	for id in Db.ITEM_IDS:
		assert_true(Story.ITEM_NAMES.has(id), str(id))


func test_brother_line_ring_variant() -> void:
	var no_gloves := _snaps([&"sword", &"boots", &"armor", &"helmet", &"shield"])
	var gloves := _snaps([&"sword", &"gloves", &"armor", &"helmet", &"shield"])
	var i := Story.RING_LINE_INDEX
	assert_eq(Story.brother_line(i, no_gloves), Story.BROTHER_LINES[i - 1])
	assert_eq(Story.brother_line(i, gloves), Story.BROTHER_RING_LINE)
	assert_eq(Story.brother_line(1, gloves), Story.BROTHER_LINES[0], "остальные реплики не зависят от перстня")
	assert_eq(Story.brother_line(0, gloves), "")
	assert_eq(Story.brother_line(Story.BROTHER_LINES.size() + 1, gloves), "")


## Сцены Сольвейг: сначала страх (дом, разговор с матерью), потом искушение (тронный зал) —
## и обе раньше дара, после которого Сигвард читает её письмо.
func test_bride_scenes_have_their_place_and_lines() -> void:
	var gifts := Db.balance.stage_count - 1
	assert_between(Story.HEARTH_AFTER_GIFT, 1, gifts)
	assert_between(Story.TEMPTATION_AFTER_GIFT, 1, gifts)
	assert_lt(Story.HEARTH_AFTER_GIFT, Story.TEMPTATION_AFTER_GIFT)
	for section in [Story.HEARTH, Story.TEMPTATION]:
		for key in section:
			assert_ne(str(section[key]), "", key)
	assert_eq(Story.kind_of(&"mother"), ActorModel.Kind.MOTHER)


func test_hearth_lists_what_was_given_to_strangers() -> void:
	assert_eq(Story.hearth_given_line(_snaps([])), "")
	assert_eq(Story.hearth_given_line(_snaps([&"amulet"])), "", "оберег у самой Сольвейг — не в счёт")
	assert_string_contains(Story.hearth_given_line(_snaps([&"sword", &"amulet"])), "отдал меч.")
	assert_string_contains(Story.hearth_given_line(_snaps([&"sword", &"boots"])), "меч и сапоги")
	assert_eq(Story.list_text(["меч", "сапоги", "щит"] as Array[String]), "меч, сапоги и щит")


func test_rule_moved_from_prologue_to_the_first_altar() -> void:
	assert_false(Story.PROLOGUE.has("rule"), "в прологе правила больше нет")
	assert_string_contains(Story.RULE["law"], "отданная добровольно, не ослабляет")
	assert_string_contains(Story.RULE["light"], "осветить твой путь")
	assert_ne(str(Story.RULE["hero"]), "", "после предания — мысль Солдата")
	assert_ne(str(Story.speaker(&"chronicle")["name"]), "", "у предания есть подпись")
	assert_false(Story.SPEAKERS.has(&"chronicle"), "предание — не персонаж: у него нет модели и роли")
	RunState.new_run(1)
	assert_true(RuleScene.due(), "первый алтарь забега")
	RunState.sacrifice(0)
	assert_false(RuleScene.due(), "после первой жертвы правило уже сказано")
	RunState.new_run(0)
	RunState.running = false


func test_sigvard_jokes_about_gum_only_where_it_shows() -> void:
	for n in [3, 6]:
		assert_string_contains(Story.brother_gum(n), "жвачк", "дар №%d" % n)
	for n in [1, 2, 4, 5]:
		assert_eq(Story.brother_gum(n), "", "дар №%d — без шутки" % n)
	assert_string_contains(Story.brother_gum(3), "только самое нужное")


## Песня начинается со слов, которые Ильва говорит в сцене своего дара, и кончается словами финала.
func test_song_grows_from_ilva_lines() -> void:
	assert_string_contains(Story.IVA_LINES[Story.SONG_AFTER_GIFT - 1], "клясться не умею")
	assert_eq(Story.SONG["go"], Story.FINALE["lets_go"], "«Пойдём?» вернётся в финале теми же словами")
	assert_eq(Story.SONG["go_2"], Story.FINALE["lets_go_2"])
	assert_ne(str(Story.SONG["quote"]), "")


## Песня Сигварда — после последнего дара, вместо шестого голоса из дворца: его «Во всём» и шутка про карманы —
## это конец песни (текст песни — в разметке дорожки, см. test_cutscene).
func test_brother_song_takes_the_place_of_the_last_palace_voice() -> void:
	assert_eq(Story.BROTHER_SONG_AFTER_GIFT, Db.balance.stage_count - 1, "после последнего дара, накануне ворот")
	assert_string_contains(Story.BROTHER_LINES[Story.BROTHER_SONG_AFTER_GIFT - 1], "Во всём")
	assert_string_contains(Story.brother_gum(Story.BROTHER_SONG_AFTER_GIFT), "кроме карманов")
	for key in Story.BROTHER_SONG:
		assert_ne(str(Story.BROTHER_SONG[key]), "", key)


func test_chapters() -> void:
	for key in ["prologue", "rule", "song", "hearth", "temptation", "brother_song", "gates", "epilogue"]:
		assert_ne(str(Story.chapter(key)[0]), "", key)
	assert_eq(Story.gift_chapter(1, &"sword"), ["Дар первый", "Меч · Торстейн"])
	assert_eq(Story.gift_chapter(6, &"amulet")[1], "Оберег · Сольвейг")
	assert_eq(Story.ORDINALS.size(), Db.balance.stage_count - 1, "порядковое слово на каждый дар")


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
