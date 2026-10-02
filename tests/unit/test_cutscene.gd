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
	for k in range(ActorModel.Kind.FRIEND, ActorModel.Kind.FATHER + 1):
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
