extends GutTest
## Сюжетные сцены: флаги включения, мгновенный пропуск, марионетки вне боя, наряды людей, перстень отца.

var _old_cutscenes: bool


func before_each() -> void:
	_old_cutscenes = Render.cutscenes


func after_each() -> void:
	Render.cutscenes = _old_cutscenes
	RunState.skip_cutscenes = false


func _cutscene() -> Cutscene:
	var cs := Cutscene.new()
	cs.ui = CutsceneUi.new()
	add_child_autofree(cs)
	cs.add_child(cs.ui)
	return cs


func test_enabled_respects_setting_and_bot_flag() -> void:
	Render.cutscenes = true
	RunState.skip_cutscenes = false
	assert_true(Cutscene.enabled())
	RunState.skip_cutscenes = true
	assert_false(Cutscene.enabled(), "боты и скриншоты выключают сцены")
	RunState.skip_cutscenes = false
	Render.cutscenes = false
	assert_false(Cutscene.enabled(), "настройка игрока")


func test_cinematic_hides_and_restores_meta_tree_hint() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.set_process(false)
	hud._tree_hint = Control.new()
	hud.add_child(hud._tree_hint)
	hud.set_cinematic(true, 0.0)
	await wait_process_frames(2)
	assert_almost_eq(hud._tree_hint.modulate.a, 0.0, 0.001, "подсказка Tab не видна поверх сцены")
	hud.set_cinematic(false, 0.0)
	await wait_process_frames(2)
	assert_almost_eq(hud._tree_hint.modulate.a, 1.0, 0.001, "подсказка возвращается в бою")


func test_after_skip_steps_return_at_once() -> void:
	var cs := _cutscene()
	cs.active = true
	watch_signals(cs)
	cs.skip()
	assert_true(cs.skipped)
	assert_signal_emitted(cs, "skip_requested")
	var frame := Engine.get_process_frames()
	await cs.say(&"hero", "Эта реплика не должна ждать.")
	await cs.thought("И мысль тоже.")
	await cs.wait(10.0)
	assert_eq(Engine.get_process_frames(), frame, "ни одного кадра ожидания")


func test_cutscene_props_keep_run_and_sacrifice_appearances_after_menu_choice_changes() -> void:
	var old_ring := RunState.ring
	var old_snapshots := RunState.snapshots
	var old_xp := Mastery.xp
	var old_choices := Mastery.choices
	RunState.ring = Ring.generate(1234, Db.ITEM_IDS)
	var amulet: ItemState = RunState.ring.items[RunState.ring.index_of(&"amulet")]
	amulet.appearance = 3
	var result := RunState.ring.sacrifice(RunState.ring.index_of(&"amulet"))
	RunState.snapshots = [result["victim_snapshot"]]
	var sword: ItemState = RunState.ring.items[RunState.ring.index_of(&"sword")]
	sword.appearance = 2
	Mastery.xp = {&"amulet": 1000, &"sword": 1000}
	Mastery.choices = {&"amulet": 1, &"sword": 3}
	assert_eq(Cutscene.item_state(&"amulet").appearance, 3, "оберег у очага сохраняет облик подарка")
	assert_same(Cutscene.item_state(&"amulet"), result["victim_snapshot"])
	assert_eq(Cutscene.item_state(&"sword").appearance, 2, "реквизит берёт надетый облик забега")
	RunState.ring = old_ring
	RunState.snapshots = old_snapshots
	Mastery.xp = old_xp
	Mastery.choices = old_choices


func test_gallery_hero_uses_selected_mastery_forms_on_each_character() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	var old_xp := Mastery.xp
	var old_choices := Mastery.choices
	Mastery.xp = {}
	Mastery.choices = {}
	for id in Db.ITEM_IDS:
		Mastery.xp[id] = 1000
		Mastery.choices[id] = 3
	for variant in SkinnedActorModel.variants():
		SkinnedActorModel.select(variant["id"])
		var showcase := ItemShowcase.new()
		add_child_autofree(showcase)
		showcase.show_cast([&"hero"], 1.0)
		for child in showcase.viewport.get_children():
			if child is Puppet:
				assert_true(child.model is SkinnedActorModel)
				assert_eq(child.items.size(), 7)
				for state in child.items:
					assert_eq(state.appearance, 3, "галерея показывает выбранный облик, а не исходный")
	Mastery.xp = old_xp
	Mastery.choices = old_choices


func test_skipped_walk_teleports() -> void:
	var cs := _cutscene()
	cs.active = true
	cs.skip()
	var p := Puppet.make(ActorModel.Kind.FRIEND)
	add_child_autofree(p)
	await cs.walk(p, Vector3(3, 0, 4))
	assert_almost_eq(p.global_position, Vector3(3, 0, 4), Vector3.ONE * 0.001)


func test_skip_needs_an_active_scene() -> void:
	var cs := _cutscene()
	cs.skip()
	assert_false(cs.skipped, "вне сцены пропускать нечего")


func test_every_npc_kind_builds_and_stays_out_of_combat() -> void:
	var looks := []
	for k in range(ActorModel.Kind.FRIEND, ActorModel.Kind.MOTHER + 1):
		looks.append([k, &""])
	looks.append([ActorModel.Kind.TYRANT, &"young"])
	for l in looks:
		var p := Puppet.make(l[0], l[1])
		add_child_autofree(p)
		assert_not_null(p.model)
		assert_gt(p.model._meshes.size(), 10, "у вида %d есть наряд" % l[0])
		assert_true(p.model.is_npc())
		assert_false(p.is_in_group(&"actors"), "марионетка вне боя")
		assert_false(Combat.living_actors(get_tree()).has(p))


func test_tag_shows_name_and_role_and_clears() -> void:
	var cs := _cutscene()
	var p := Puppet.make(ActorModel.Kind.FRIEND)
	add_child_autofree(p)
	cs.tag(p, &"friend", 0.0)
	assert_eq(cs.ui._tags.size(), 1)
	var box: Control = cs.ui._tags[0]["box"]
	var texts := []
	for l in box.get_children():
		texts.append((l as Label).text)
	assert_eq(texts, [Story.speaker(&"friend")["name"], Story.speaker(&"friend")["role"]])
	cs.ui.clear_tags()
	assert_eq(cs.ui._tags.size(), 0)


func test_every_speaker_has_a_role() -> void:
	for who in Story.SPEAKERS:
		assert_ne(str(Story.SPEAKERS[who].get("role", "")), "", str(who))


func test_faithful_carries_a_lantern() -> void:
	var p := Puppet.make(ActorModel.Kind.FAITHFUL)
	add_child_autofree(p)
	assert_not_null(p.model.find_child("Lantern", true, false))


func test_captain_has_a_shield_to_drop() -> void:
	var p := Puppet.make(ActorModel.Kind.CAPTAIN)
	add_child_autofree(p)
	assert_not_null(p.model.sockets[&"l_hand"].get_node_or_null("CaptainShield"))


func test_father_ring_on_right_gauntlet_only() -> void:
	var rings := 0
	for part in ItemVisuals.build(ItemState.create(&"gloves")):
		var node: Node3D = part["node"]
		if node.find_child("FatherRing", true, false) != null:
			rings += 1
			assert_eq(part["socket"], &"r_hand")
		node.free()
	assert_eq(rings, 1)


## Мысли наклонены, а не повёрнуты: верх буквы уходит вправо (x.y), ось y не сдвинута.
## Сдвиг y.x скашивает глифы по вертикали — буквы выглядят повёрнутыми.
func test_thought_font_is_slanted_not_rotated() -> void:
	var cs := _cutscene()
	var t: Transform2D = cs.ui._thought_font.variation_transform
	assert_gt(t.x.y, 0.0)
	assert_eq(t.y, Vector2(0, 1))


func test_moods_are_complete() -> void:
	for key in Cutscene.MOODS:
		assert_eq((Cutscene.MOODS[key] as Array).size(), 5, str(key))


func test_chapter_card_shows_and_hides() -> void:
	var cs := _cutscene()
	cs.ui.chapter("Пролог", "Два сына", false, 0.1)
	assert_eq(cs.ui._chapter_title.text, "Пролог")
	assert_true(cs.ui._chapter_sub.visible)
	cs.ui.chapter("Дар первый", "", true, 0.1)
	assert_false(cs.ui._chapter_sub.visible, "пустой подзаголовок скрыт")


## Заставка и реплики стоят в слое, который сдвигается дробно: без рывков по пикселю.
func test_big_text_moves_without_pixel_steps() -> void:
	var ui := CutsceneUi.new()
	add_child_autofree(ui)
	ui.chapter("Пролог", "Два сына", false, 2.0)
	assert_gt(ui._chapter_float.scale.x, 1.0, "заставка появляется чуть крупнее")
	assert_eq(ui._chapter_font.spacing_glyph, 3, "разрядка букв не меняется на экране — она целая, буквы прыгали бы")
	assert_true(ui._chapter_box.get_parent() == ui._chapter_float.frame)
	# Слой растёт вокруг середины экрана, рамка внутри совпадает с экраном.
	assert_almost_eq(ui._chapter_float.position, (ui.root.size * 0.5).round(), Vector2(0.01, 0.01))
	assert_almost_eq(ui._chapter_float.frame.position, -ui._chapter_float.position, Vector2(0.01, 0.01))
	assert_eq(ui._chapter_float.frame.size, ui.root.size)
	ui.chapter("Дар первый", "Меч · Торстейн", true, 2.0)
	assert_almost_eq(ui._chapter_float.position.y, CutsceneUi.BAR_H + 84.0, 0.01, "компактная заставка растёт вокруг своей середины")
	ui._line_float.shift = Vector2(0, 2.5)
	assert_almost_eq(ui._line_float.position.y + ui._line_float.frame.position.y, 2.5, 0.001, "сдвиг реплики — дробный")
	ui.hide_chapter(0.0)


func test_offer_hand_follows_the_model() -> void:
	var friend := Puppet.make(ActorModel.Kind.FRIEND)
	add_child_autofree(friend)
	assert_eq(friend.offer_hand(), &"r_hand", "процедурная модель протягивает правую")
	var sig := Puppet.make(ActorModel.Kind.TYRANT)
	add_child_autofree(sig)
	if sig.model is SkinnedActorModel:
		assert_eq(sig.offer_hand(), &"l_hand", "клип Interact тянется левой — вещь кладём в неё")
	else:
		assert_eq(sig.offer_hand(), &"r_hand")


func test_gum_shows_only_when_the_hand_is_away_from_the_pocket() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var pocket := Node3D.new()
	var hand := Node3D.new()
	world.add_child(pocket)
	world.add_child(hand)
	var gum := GumStrand.stretch(world, pocket, hand)
	assert_false(gum.stretched(), "рука в кармане — жвачки не видно")
	hand.global_position = Vector3(0.3, 0.6, 0.0)
	gum._update()
	assert_true(gum.stretched())
	assert_true(gum.visible)
	gum.snap()
	assert_false(gum.stretched(), "лопнула — больше не тянется")
	assert_false(gum.visible)


func test_set_pieces_build() -> void:
	var hall := SetPieces.throne_hall()
	add_child_autofree(hall)
	assert_eq((hall.get_meta(&"braziers") as Array).size(), 2)
	assert_not_null(hall.find_child("Throne", true, false))
	for make in [SetPieces.weapon_rack, SetPieces.training_post, SetPieces.candle_stand, SetPieces.letter, SetPieces.bread, SetPieces.flask,
			SetPieces.hearth, SetPieces.night_window, SetPieces.spinning_wheel, SetPieces.chest, SetPieces.purse]:
		var n: Node3D = make.call()
		assert_gt(n.get_child_count(), 0)
		n.free()


func test_cottage_has_what_the_hearth_scene_needs() -> void:
	var room := SetPieces.cottage()
	add_child_autofree(room)
	for key in [&"hearth", &"window", &"table", &"wheel", &"chest"]:
		assert_true(room.get_meta(key) is Node3D, str(key))
	assert_not_null((room.get_meta(&"table") as Node3D).get_node_or_null("Flame"), "пламя свечи, которое гаснет в конце")


## Позы сомнения: руки сцеплены у пояса; у downcast ещё и опущена голова (отрицательный наклон — вниз).
func test_doubt_poses() -> void:
	var p := Puppet.make(ActorModel.Kind.BELOVED)
	add_child_autofree(p)
	p.set_pose(&"wring")
	p.model._animate(0.016)
	assert_almost_eq(p.model.head.rotation.x, 0.0, 0.001)
	assert_ne(p.model.arm_l.basis, Basis())
	p.set_pose(&"downcast")
	p.model._animate(0.016)
	assert_lt(p.model.head.rotation.x, 0.0)


func test_flicker_light_and_fire() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var l := CutsceneFx.light(root, Vector3.ZERO, Color.ORANGE, 2.0, 5.0, 0.2)
	assert_true(l is CutsceneFx.FlickerLight)
	CutsceneFx.light_to(l, 0.5, 0.0)
	assert_eq((l as CutsceneFx.FlickerLight).base, 0.5)
	var f := CutsceneFx.fire(root, Vector3.ZERO, 0.5)
	assert_true(f.emitting)
