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
	Mastery.xp = {&"amulet": Mastery.xp_cap(), &"sword": Mastery.xp_cap()}
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
		Mastery.xp[id] = Mastery.xp_cap()
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
		assert_gt(p.model._meshes.size(), 0, "у вида %d есть видимая модель" % l[0])
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
	var mother := Puppet.make(ActorModel.Kind.MOTHER)
	mother.procedural = true
	add_child_autofree(mother)
	assert_eq(mother.offer_hand(), &"r_hand", "процедурная модель протягивает правую")
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


## Плащ идёт за плечами того, на ком надет; снятый — остаётся там, где его оставили.
func test_cloak_follows_the_shoulders_of_its_wearer() -> void:
	var a := Puppet.make(ActorModel.Kind.FRIEND)
	var b := Puppet.make(ActorModel.Kind.REFUGEE)
	add_child_autofree(a)
	add_child_autofree(b)
	b.global_position = Vector3(3, 0, 0)
	var cloak := WornCloak.make(Color.RED)
	add_child_autofree(cloak)
	cloak.put_on(a)
	assert_almost_eq(cloak.global_position, WornCloak.shoulders(a), Vector3.ONE * 0.001)
	assert_gt(cloak.global_position.y, 1.0, "на плечах, а не у ног")
	cloak.take_off()
	var left := cloak.global_position
	a.global_position = Vector3(-4, 0, 0)
	cloak._follow()
	assert_eq(cloak.global_position, left, "снятый плащ за актёром не идёт")
	cloak.put_on(b)
	assert_almost_eq(cloak.global_position.x, 3.0, 0.3)
	assert_almost_eq(cloak.scale.y, b.model.scale.y, 0.001, "плащ садится по росту")
	cloak.drop = 0.5
	cloak._follow()
	assert_almost_eq(cloak.scale.y, b.model.scale.y * 0.5, 0.001, "сидящему — короче")
	assert_almost_eq(cloak.scale.x, b.model.scale.y, 0.001)


## Части ели стоят край в край: ни одна не входит в другую (иначе в PS1 линия пересечения рябит).
func test_fir_parts_are_stacked_edge_to_edge() -> void:
	var fir := SetPieces.fir(3.36)
	add_child_autofree(fir)
	var top := 0.0
	var top_radius := INF
	for i in fir.get_child_count():
		var mi := fir.get_child(i) as MeshInstance3D
		var box := mi.mesh.get_aabb()
		var from := mi.position.y + box.position.y
		assert_almost_eq(from, top, 0.001, "часть %d начинается там, где кончилась прежняя" % i)
		if i >= 2 and i % 2 == 0:
			assert_almost_eq(_ring_radius(mi.mesh, box.position.y), top_radius, 0.001, "снежный верх — край в край с зелёным низом")
		top = from + box.size.y
		top_radius = _ring_radius(mi.mesh, box.end.y)
	assert_almost_eq(top, 3.36, 0.01, "высота ели — заданная")
	assert_almost_eq(top_radius, 0.0, 0.001, "макушка острая")


## Радиус сетки на высоте y: самая дальняя от оси вершина на этой высоте.
func _ring_radius(mesh: Mesh, y: float) -> float:
	var out := 0.0
	for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(v.y - y) < 0.001:
			out = maxf(out, Vector2(v.x, v.z).length())
	return out


## Замёрзший: стоит, сжавшись, руки крест-накрест на груди. Поза — только у процедурных моделей.
func test_huddle_pose_hunches_and_crosses_the_arms() -> void:
	# поза процедурной модели; у сгенерированных она запечена (test_skinned_model)
	var p := Puppet.make(ActorModel.Kind.MOTHER)
	p.procedural = true
	add_child_autofree(p)
	p.model.rest_pose = &""  # своя поза покоя у неё — руки у пояса; отсчёт — от опущенных
	p.model._animate(0.016)
	var straight: float = p.model.torso.rotation.x
	var hands_apart: float = p.hand_position(&"l_hand").distance_to(p.hand_position(&"r_hand"))
	p.set_pose(&"huddle")
	p.model._animate(0.016)
	assert_lt(p.model.torso.rotation.x, straight - 0.2, "спина согнута вперёд")
	assert_lt(p.model.head.rotation.x, 0.0, "голова втянута")
	assert_gt(p.hand_position(&"l_hand").y, 0.75, "руки подняты к груди")
	assert_lt(p.hand_position(&"l_hand").distance_to(p.hand_position(&"r_hand")), hands_apart, "руки сведены")
	var refugee := Puppet.make(ActorModel.Kind.REFUGEE)
	add_child_autofree(refugee)
	assert_not_null(refugee.model.find_child("Bundle", true, false), "узелок сцена правила убирает сама")


# --- Песня Ильвы ---------------------------------------------------------------

func _song_line(words: Array) -> Dictionary:
	var out := []
	for w in words:
		out.append({"text": w[0], "start_seconds": w[1], "end_seconds": w[2]})
	return {"display_text": "строка", "start_seconds": 10.0, "end_seconds": 14.0, "words": out}


## Словам, которых разметка не нашла, время даётся по соседям — строка закрашивается без провалов.
func test_song_words_without_timing_take_it_from_neighbours() -> void:
	var data := {"alignment": {"lines": [
		_song_line([["Мне", null, null], ["клятвы", 11.0, 12.0], ["не", null, null], ["очень", null, null], ["нужны.", 13.0, 14.0]]),
		{"display_text": "без времени", "start_seconds": null, "end_seconds": null, "words": []},
	]}}
	var lines := SongTrack.parse(data)
	assert_eq(lines.size(), 1, "строка без времени пропущена")
	var w: Array = lines[0]["words"]
	assert_almost_eq(float(w[0]["start"]), 10.0, 0.001, "первое слово — от начала строки")
	assert_almost_eq(float(w[0]["end"]), 11.0, 0.001)
	assert_almost_eq(float(w[2]["end"]), 12.5, 0.001, "два слова делят промежуток поровну")
	assert_almost_eq(float(w[3]["start"]), 12.5, 0.001)
	assert_almost_eq(float(w[3]["end"]), 13.0, 0.001)


func test_song_line_is_coloured_as_it_is_sung() -> void:
	var lines := SongTrack.parse({"alignment": {"lines": [_song_line([["Я", 10.0, 11.0], ["просто", 11.0, 12.0], ["иду", 12.0, 14.0]])]}})
	var code := SongTrack.bbcode(lines[0], 11.5)
	assert_string_contains(code, "[color=#%s]Я[/color]" % SongTrack.SUNG)
	assert_string_contains(code, "[color=#%s]просто[/color]" % SongTrack.NOW)
	assert_string_contains(code, "[color=#%s]иду[/color]" % SongTrack.AHEAD)


func test_song_track_reads_the_real_markup() -> void:
	var song := SongTrack.load_track(IlvaSongScene.SYNC, IlvaSongScene.AUDIO)
	add_child_autofree(song)
	assert_gt(song.lines.size(), 30, "строки песни прочитаны")
	assert_almost_eq(song.duration, 159.68, 0.5)
	for l in song.lines:
		assert_lt(float(l["start"]), float(l["end"]), l["text"])
		for w in l["words"]:
			assert_not_null(w["start"], "%s: у слова «%s» есть время" % [l["text"], w["text"]])
	# Слова вслух («Пойдём?») показывает сцена, а не строка песни.
	song.lyrics_until = IlvaSongScene.SPOKEN_FROM
	assert_eq(song.line_index(IlvaSongScene.GO_AT + 0.5), -1)
	assert_eq(song.lines[song.line_index(16.5)]["text"], "Мы росли, где фьорд замерзает к зиме,")
	assert_eq(song.line_index(5.0), -1, "во вступлении слов нет")


func test_song_beats_follow_the_measured_grid() -> void:
	var song := SongTrack.new()
	add_child_autofree(song)
	song.beat_period = 0.5
	song.beat_phase = 0.25
	assert_eq(song.beats(1.0, 2.3), [1.25, 1.75, 2.25] as Array[float])
	assert_eq(song.beats(0.0, 2.3, 2, 0), [0.25, 1.25, 2.25] as Array[float], "каждая вторая доля")
	assert_eq(song.beats(0.0, 2.3, 2, 1), [0.75, 1.75] as Array[float])


func test_song_poses_lift_the_lantern() -> void:
	# поза процедурной модели; у сгенерированной Ильвы она запечена (ниже и в test_skinned_model)
	var p := Puppet.make(ActorModel.Kind.FAITHFUL)
	p.procedural = true
	add_child_autofree(p)
	p.model._animate(0.016)
	var rest: float = p.hand_position(&"l_hand").y
	p.set_pose(&"lantern_high")
	p.model._animate(0.016)
	assert_gt(p.hand_position(&"l_hand").y, rest + 0.5, "фонарь поднят над головой")
	p.set_pose(&"sing")
	p.model._animate(0.016)
	assert_gt(p.model.head.rotation.x, 0.0, "поёт — голова поднята")


## У сгенерированной Ильвы позы песни запечены под её тело (experiments/char3d/npc_poses.gd):
## в lantern_high кисть с фонарём — выше головы.
func test_generated_ilva_lifts_the_lantern_too() -> void:
	var p := Puppet.make(ActorModel.Kind.FAITHFUL)
	add_child_autofree(p)
	if not p.model is SkinnedActorModel:
		pass_test("у Ильвы процедурная модель — позы проверены выше")
		return
	var m := p.model as SkinnedActorModel
	var clip: Animation = load("res://assets/characters/anims/npc_faithful_lantern_high.tres")
	var skeleton: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	for t in clip.get_track_count():
		if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var bone := skeleton.find_bone(String(clip.track_get_path(t)).get_slice(":", 1))
			if bone >= 0:
				skeleton.set_bone_pose_rotation(bone, clip.rotation_track_interpolate(t, 0.0))
	skeleton.force_update_all_bone_transforms()
	var hand := skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin.y
	var head := skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin.y
	assert_gt(hand, head, "кисть с фонарём выше головы")
	assert_eq(m._cfg["poses"]["sing"]["anim"], "npc/sing")


## Камера ведёт идущих: фокус догоняет движущуюся точку.
func test_camera_tracks_a_moving_point() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	# Лямбда запоминает локальные переменные по значению — точку держим в узле.
	var target := Node3D.new()
	add_child_autofree(target)
	target.position = Vector3(8, 0, 0)
	rig.cine_track(func(): return target.position, 6.0, 0.0)
	assert_eq(rig._focus, Vector3(8, 0, 0), "без наезда — сразу на точке")
	target.position = Vector3(12, 0, 0)
	rig._process(0.1)
	assert_gt(rig._focus.x, 8.0)
	assert_lt(rig._focus.x, 12.0, "догоняет плавно")
	rig.cine_to(Vector3.ZERO, 6.0, 0.0)
	rig._process(0.1)
	assert_eq(rig._focus, Vector3.ZERO, "обычный кадр отменяет ведение")


func test_winter_ground_is_dense_enough_for_vertex_light() -> void:
	var g := SetPieces.snow_ground(Vector2(24, 12))
	add_child_autofree(g)
	assert_gte((g.mesh as PlaneMesh).subdivide_width, 16, "в PS1 свет считается по вершинам")
	# Земля не дрожит — иначе тени под ногами и тропа рябят; общий материал из кэша при этом не тронут.
	var mat := g.material_override as ShaderMaterial
	assert_eq(mat.get_shader_parameter(&"snap_vertices"), false)
	var shared := LowPoly.mat(SetPieces.SNOW, 0.95, 0.0, 0.1)
	assert_ne(mat, shared, "материал земли — своя копия")
	assert_ne(shared.get_shader_parameter(&"snap_vertices"), false, "остальной снег дрожит, как всё в PS1")
	var drift := SetPieces.snow_drift()
	add_child_autofree(drift)
	assert_eq(((drift.get_child(0) as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter(&"snap_vertices"), false)
	var hut := SetPieces.burning_hut()
	add_child_autofree(hut)
	assert_eq((hut.get_meta(&"fire_points") as Array).size(), 4)


func test_set_pieces_build() -> void:
	var hall := SetPieces.throne_hall()
	add_child_autofree(hall)
	assert_eq((hall.get_meta(&"braziers") as Array).size(), 2)
	assert_not_null(hall.find_child("Throne", true, false))
	for make in [SetPieces.weapon_rack, SetPieces.training_post, SetPieces.candle_stand, SetPieces.letter, SetPieces.bread, SetPieces.flask,
			SetPieces.hearth, SetPieces.night_window, SetPieces.spinning_wheel, SetPieces.chest, SetPieces.purse, SetPieces.cloak,
			SetPieces.fir, SetPieces.snow_drift, SetPieces.campfire, SetPieces.log_seat, SetPieces.stump, SetPieces.cairn, SetPieces.longship]:
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
	var p := Puppet.make(ActorModel.Kind.MOTHER)
	p.procedural = true
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
