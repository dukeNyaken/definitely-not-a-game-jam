extends GutTest

func _features(node: Node, type: StringName = &"") -> Array:
	var found := []
	if node.has_meta(&"appearance_feature") and (type == &"" or node.get_meta(&"appearance_feature") == type):
		found.append(node)
	for child in node.get_children():
		found.append_array(_features(child, type))
	return found


func test_relic_horns_have_distinct_tiers_and_correct_locations_on_every_character() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for variant in SkinnedActorModel.variants():
		SkinnedActorModel.select(variant["id"])
		for tier in [1, 2, 3]:
			for slot in [&"helmet", &"shield", &"gloves", &"boots"]:
				var state := ItemState.create(slot)
				state.appearance = tier
				var display := ItemVisuals.build_display(state)
				if tier == 1:
					assert_eq(_features(display).size(), 0)
				elif slot == &"helmet" or slot == &"shield":
					var horns := _features(display, &"head_horn" if slot == &"helmet" else &"shield_horn")
					assert_eq(horns.size(), 1 if tier == 2 else 2)
					if tier == 2 and slot == &"helmet":
						assert_almost_eq((horns[0].get_meta(&"attachment_point") as Vector3).x, 0.0, 0.025, "один рог по центральной оси")
				elif slot == &"gloves":
					assert_eq(_features(display, &"phalanx_horn").size(), 6)
					assert_eq(_features(display, &"wrist_horn").size(), 0 if tier == 2 else 4, "запястья только на III")
				elif slot == &"boots":
					var toes := _features(display, &"toe_horn")
					assert_eq(toes.size(), 2 if tier == 2 else 4)
					for horn in toes:
						var point: Vector3 = horn.get_meta(&"attachment_point")
						assert_gt(point.z, 0.05, "шипы на носках, а не пятках")
						assert_lt(point.y, 0.16, "шипы ниже щиколоток")
				display.free()


func test_generated_relics_follow_skin_bindings_and_hide_with_sacrificed_items() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for variant in SkinnedActorModel.variants():
		for kind in [ActorModel.Kind.HERO, ActorModel.Kind.BOSS]:
			var model := _model(variant["id"], kind, SLOTS)
			for state in model.actor.items:
				state.appearance = 3
			model.refresh_items()
			model._collect_meshes()
			for flame: MeshInstance3D in model.find_children("RelicFlame", "MeshInstance3D", true, false):
				assert_eq((flame.material_override as ShaderMaterial).shader, ItemAppearance.FLAME, "контур героя не заменяет материал пламени")
			for slot in SLOTS:
				assert_gt(model._appearances.get(slot, []).size(), 0)
				for attachment: BoneAttachment3D in model._appearances[slot]:
					assert_gte(attachment.bone_idx, 0, "крепление на существующей кости")
					var feature: Node3D = attachment.get_child(0)
					assert_true(feature.has_meta(&"attachment_point"))
			model.hide_all_items()
			for nodes in model._appearances.values():
				for attachment in nodes:
					assert_false(attachment.visible)
			model.reveal_item(&"helmet")
			for attachment in model._appearances[&"helmet"]:
				assert_true(attachment.visible)
			model.actor.set_items([])
			assert_eq(model._appearances.size(), 0, "жертва убирает и рога, и пламя")


func test_relic_attachments_follow_animated_hands_and_feet() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for variant in SkinnedActorModel.variants():
		var model := _model(variant["id"], ActorModel.Kind.HERO, SLOTS)
		for state in model.actor.items:
			state.appearance = 3
		model.refresh_items()
		model.set_process(false)
		model._tree.active = false
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		player.play(model._cfg["locomotion"][1])
		var previous := {}
		for time in [0.15, 0.55]:
			player.seek(time, true)
			await get_tree().process_frame
			await get_tree().process_frame
			for slot in [&"gloves", &"boots"]:
				for attachment: BoneAttachment3D in model._appearances[slot]:
					var skeleton := attachment.get_parent() as Skeleton3D
					var feature := attachment.get_child(0) as Node3D
					var expected := skeleton.global_transform * skeleton.get_bone_global_pose(attachment.bone_idx) * feature.position
					assert_lt(feature.global_position.distance_to(expected), 0.001, "рог следует анимации кости")
					if previous.has(feature):
						assert_gt(feature.global_position.distance_to(previous[feature]), 0.005, "деталь двигается с кистью или стопой")
					previous[feature] = feature.global_position
## Сгенерированные герои и босс (assets/characters/, SkinnedActorModel): в каждом варианте есть все
## семь вещей, надеть/снять переключает вещь и часть тела под ней, ходьба выбирается по скорости.
## Без собранных моделей тесты пропускаются — игра тогда на процедурной модели.

const SLOTS := [&"sword", &"shield", &"armor", &"helmet", &"gloves", &"boots", &"amulet"]

var _actors: Array[Actor] = []


func after_each() -> void:
	for a in _actors:
		a.queue_free()
	_actors.clear()


func _model(variant: String, kind: int, items: Array) -> SkinnedActorModel:
	SkinnedActorModel.select(variant)
	var hero := Actor.new()
	hero.set_physics_process(false)
	add_child(hero)
	_actors.append(hero)
	var states: Array[ItemState] = []
	for id in items:
		states.append(ItemState.create(id))
	hero.set_items(states)
	var m := (SkinnedActorModel.for_boss() if kind == ActorModel.Kind.BOSS else SkinnedActorModel.for_hero()) as SkinnedActorModel
	hero.add_child(m)
	m.setup(hero, kind)
	return m


func test_every_variant_has_all_items_on_hero_and_boss() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for v in SkinnedActorModel.variants():
		for kind in [ActorModel.Kind.HERO, ActorModel.Kind.BOSS]:
			var m := _model(v["id"], kind, SLOTS)
			for slot in SLOTS:
				assert_true(m._gen_items.has(slot), "%s/%d: нет вещи %s" % [v["id"], kind, slot])


func test_equip_toggles_item_and_body_under_it() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	var v: Dictionary = SkinnedActorModel.variants()[0]
	var m := _model(v["id"], ActorModel.Kind.HERO, SLOTS)
	# у слота может быть несколько сеток: доспех — кираса и поножи, каждая со своей частью тела
	assert_gt(m._gen_items[&"armor"].size(), 1, "у доспеха есть поножи")
	for slot in m._hidden_body:
		for mi in m._hidden_body[slot]:
			assert_false(mi.visible, "%s надет — тело под ним (%s) спрятано" % [slot, mi.name])
	var keep: Array[ItemState] = [ItemState.create(&"sword")]
	m.actor.set_items(keep)
	m.refresh_items()
	assert_true(m._gen_items[&"sword"][0].visible, "меч остался")
	for slot in m._gen_items:
		if slot != &"sword":
			for mi in m._gen_items[slot]:
				assert_false(mi.visible, "%s снят (%s)" % [slot, mi.name])
	for slot in m._hidden_body:
		for mi in m._hidden_body[slot]:
			assert_true(mi.visible, "%s снят — тело под ним (%s) видно" % [slot, mi.name])


func test_mastery_trim_survives_generated_geometry_and_updates_on_upgrade() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for v in SkinnedActorModel.variants():
		for kind in [ActorModel.Kind.HERO, ActorModel.Kind.BOSS]:
			var m := _model(v["id"], kind, SLOTS)
			for tier in [2, 3, 1]:
				for state in m.actor.items:
					state.appearance = tier
				m.refresh_items()
				for slot in SLOTS:
					var trims := 0
					for child in m._appearances.get(slot, []):
						if child.has_meta(&"mastery_trim"):
							trims += 1
							assert_true(child.is_visible_in_tree(), "%s/%d/%s/%d: украшение видно" % [v["id"], kind, slot, tier])
					if tier == 1:
						assert_eq(trims, 0, "возврат к исходному облику убирает украшения")
					else:
						assert_gt(trims, 0, "у улучшенного облика есть украшения")


func test_generated_menu_items_show_selected_mastery_appearance() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	var states: Array[ItemState] = []
	for slot in SLOTS:
		var state := ItemState.create(slot)
		state.appearance = 3
		states.append(state)
	for v in SkinnedActorModel.variants():
		SkinnedActorModel.select(v["id"])
		var shown := GeneratedItemDisplay.build(states)
		for slot in SLOTS:
			var display: Node3D = shown[slot]
			add_child_autofree(display)
			var trim := display.find_child("AppearanceTrim", true, false)
			assert_not_null(trim, "%s/%s: выбранный облик на сгенерированной вещи" % [v["id"], slot])
			if trim != null:
				assert_gt(_features(display).size(), 0, "новая геометрия на исходной вещи")
				assert_almost_eq((display.scale * trim.scale).x, 1.0, 0.001, "украшения сохраняют размер на маленьких исходных сетках")


func test_mesh_names_map_to_slots() -> void:
	# item_<слот>[__<часть>][_L|_R|_under]: часть вещи и подложка — тот же слот
	for n in ["armor", "armor__legs", "armor_under", "armor__legs_under"]:
		assert_eq(SkinnedActorModel._slot_of(n), &"armor", n)
	assert_eq(SkinnedActorModel._slot_of("boots_L"), &"boots")
	assert_eq(SkinnedActorModel._slot_of("gloves_R"), &"gloves")


func test_story_npcs_keep_props_and_support_story_poses() -> void:
	for spec in [
		[ActorModel.Kind.TYRANT, &"young", "", [&"kneel", &"offer"]],
		[ActorModel.Kind.FATHER, &"", "l_hand/Staff", [&"frail", &"frail_offer", &"kneel", &"slump"]],
		[ActorModel.Kind.BELOVED, &"", "", [&"offer", &"arms_up"]],
		[ActorModel.Kind.FAITHFUL, &"", "l_hand/Lantern", [&"lantern", &"offer", &"sing", &"lantern_high"]],
		[ActorModel.Kind.FRIEND, &"", "", [&"sling", &"offer"]],
		[ActorModel.Kind.REFUGEE, &"", "r_hand/Bundle", [&"offer", &"kneel"]],
		[ActorModel.Kind.CAPTAIN, &"", "l_hand/CaptainShield", [&"shield_up", &"bow"]],
		[ActorModel.Kind.WIDOW, &"", "chest/Baby", [&"hold", &"offer"]],
		[ActorModel.Kind.SMITH, &"", "", [&"offer", &"kneel"]],
		[ActorModel.Kind.NOVICE, &"", "r_hand/Staff", [&"offer", &"bow"]],
		[ActorModel.Kind.MOTHER, &"", "", [&"offer", &"kneel"]],
	]:
		var p := Puppet.make(spec[0], spec[1])
		add_child_autofree(p)
		assert_true(p.model is SkinnedActorModel, "у персонажа пролога собственная модель")
		if not p.model is SkinnedActorModel:
			continue
		var m := p.model as SkinnedActorModel
		assert_true(m._gen_items.is_empty(), "одежда встроена в тело")
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		assert_true(ap.has_animation("npc/idle"))
		if spec[2] != "":
			var socket: Node3D = m.sockets[StringName(spec[2].get_slice("/", 0))]
			assert_not_null(socket.get_node_or_null(spec[2].get_slice("/", 1)), "реквизит на сокете %s" % spec[2])
		for pose_name in spec[3] + [&"wring", &"downcast", &"huddle"]:
			p.set_pose(pose_name)
			m._animate_pose(1.0)
			assert_true(m._cfg["poses"].has(String(pose_name)), String(pose_name))
			assert_true(ap.has_animation(m._cfg["poses"][String(pose_name)]["anim"]), String(pose_name))
		var ring := NpcLooks.father_ring()
		p.hold(ring)
		assert_eq(ring.get_parent(), m.sockets[&"r_hand"], "передаваемый предмет остаётся на правой кисти")
		p.fade(0.0, 0.0)
		assert_false(p.visible)
		p.fade(1.0, 0.0)
		assert_true(p.visible)


func test_humanoid_enemies_use_generated_bodies_with_their_weapons() -> void:
	for spec in [["infantry", "r_hand", "Katana"], ["archer", "l_hand", "Crossbow"], ["brute", "r_hand", "Cleaver"],
			["caster", "r_hand", "Staff"], ["jester", "r_hand", "Knife"]]:
		var e := EnemyFactory.create(Db.enemy(StringName(spec[0])), 1)
		add_child_autofree(e)
		var m := e.get_node("Model") as SkinnedActorModel
		assert_not_null(m, "%s: собственное тело" % spec[0])
		if m == null:
			continue
		var weapon := m.sockets[StringName(spec[1])].get_node_or_null(spec[2]) as Node3D
		assert_not_null(weapon, "%s: оружие на сокете" % spec[0])
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		if m.rest_pose != &"":
			assert_true(ap.has_animation(m._cfg["poses"][String(m.rest_pose)]["anim"]), "%s: стойка" % spec[0])
			# на замахе стойка отпускает руки
			m._windup = 0.5
			m._animate_pose(1.0)
			assert_eq(m._pose_now, "", "%s: замах поверх стойки" % spec[0])
			m._windup = 0.0
	var elite := EnemyFactory.create(Db.enemy(&"infantry"), 1, [ItemState.create(&"sword")] as Array[ItemState])
	add_child_autofree(elite)
	var em := elite.get_node("Model") as SkinnedActorModel
	assert_false((em.sockets[&"r_hand"].get_node("Katana") as Node3D).visible, "элита с мечом героя прячет катану")
	var jester := EnemyFactory.create(Db.enemy(&"jester"), 1)
	add_child_autofree(jester)
	assert_almost_eq((jester.get_node("Model") as SkinnedActorModel)._holder.scale.y, 0.55, 0.001, "шут-карлик")


func test_ual_idle_keeps_feet_flat_like_bind_pose() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for v in SkinnedActorModel.variants():
		for kind in [ActorModel.Kind.HERO, ActorModel.Kind.BOSS]:
			var m := _model(v["id"], kind, [])
			m._tree.active = false
			var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
			var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
			ap.play(&"ual/Idle")
			ap.seek(0.3, true)
			for bone in ["LeftFoot", "LeftToes", "RightFoot", "RightToes"]:
				var i := sk.find_bone(bone)
				var off := sk.get_bone_pose_rotation(i).angle_to(SkinnedActorModel.bind_rotation(sk, i))
				assert_lt(rad_to_deg(off), 1.0, "%s/%d %s: стопа в Idle как в позе привязки" % [v["id"], kind, bone])


func test_single_mastery_previews_use_character_meshes_for_all_three_forms() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for variant in SkinnedActorModel.variants():
		SkinnedActorModel.select(variant["id"])
		var source: Node3D = (load(variant["model"]) as PackedScene).instantiate()
		var meshes := {}
		for mesh in source.find_children("item_*", "MeshInstance3D", true, false):
			meshes[mesh.name] = mesh.mesh
		for slot in SLOTS:
			for tier in [1, 2, 3]:
				var state := ItemState.create(slot)
				state.appearance = tier
				var display := ItemVisuals.build_display(state)
				assert_eq(display.get_meta(&"hero_variant"), variant["id"])
				assert_eq(display.scale, Vector3.ONE, "масштаб витрины не перезапишет нормализацию glb")
				var originals := display.find_children("item_*", "MeshInstance3D", true, false)
				assert_gt(originals.size(), 0)
				for mesh in originals:
					var original: Mesh = meshes[mesh.name]
					var arrays: Array = mesh.mesh.surface_get_arrays(0)
					assert_eq(arrays[Mesh.ARRAY_VERTEX], original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "геометрия выбранного персонажа сохранена")
					assert_eq(arrays[Mesh.ARRAY_TEX_UV], original.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV], "текстура выбранного персонажа сохранена")
					assert_null(arrays[Mesh.ARRAY_BONES], "витрина не зависит от скелета героя в другом viewport")
					assert_null(arrays[Mesh.ARRAY_WEIGHTS])
				var trim := display.find_child("AppearanceTrim", true, false)
				if tier == 1:
					assert_null(trim)
				else:
					assert_gt(_features(display).size(), 0, "улучшение имеет настоящую геометрию")
				display.free()
		source.free()


func test_generated_artifact_preserves_absorbed_property_effects() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for tier in [1, 3]:
		var state := ItemState.create(&"armor")
		state.appearance = tier
		state.properties.append(Property.create(&"on_hurt", &"bulwark", &"on_block", &"shield", 0.4))
		state.properties.append(Property.create(&"on_block", &"blade", &"on_hit", &"sword", 0.4))
		var display := ItemVisuals.build_display(state)
		var effects := display.find_child("AppearanceTrim", true, false)
		var properties: Array[int] = []
		for child in effects.get_children():
			if child.has_meta(&"prop_index"):
				properties.append(child.get_meta(&"prop_index"))
		assert_eq(properties, [0, 1], "у артефакта остались украшения обеих поглощённых сил")
		assert_eq(state.properties.size(), 2, "показ модели не меняет дерево свойств")
		display.free()


func test_amulet_preview_has_readable_height_for_every_character() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for variant in SkinnedActorModel.variants():
		SkinnedActorModel.select(variant["id"])
		for tier in [1, 2, 3]:
			var state := ItemState.create(&"amulet")
			state.appearance = tier
			var display := ItemVisuals.build_display(state)
			var meshes := display.find_children("item_*", "MeshInstance3D", true, false)
			var box := GeneratedItemDisplay._bounds(meshes, display)
			assert_gt(box.size.y, 0.5, "%s/%d: виден медальон, а не полоска" % [variant["id"], tier])
			assert_gt(box.size.y / box.size.x, 0.65)
			for feature in _features(display):
				var p := GeneratedItemDisplay._local_transform(feature, display).origin * display.scale
				assert_lt(p.length(), 1.0, "украшения плоского амулета остаются внутри витрины")
			display.free()


func test_flat_amulet_stays_facing_camera_after_switching_from_rotating_item() -> void:
	var showcase := ItemShowcase.new()
	add_child_autofree(showcase)
	showcase.show_single(ItemState.create(&"sword"))
	showcase.pivot.rotation.y = PI / 2
	showcase.show_single(ItemState.create(&"amulet"))
	assert_almost_eq(showcase.pivot.rotation.y, 0.0, 0.001)
	for step in 80:
		showcase._process(0.5)
		assert_lt(absf(showcase.pivot.rotation.y), 0.36, "амулет не поворачивается невидимым ребром")
	showcase.show_single(ItemState.create(&"shield"))
	showcase._process(1.0)
	assert_false(showcase._flat_preview, "остальные вещи сохраняют вращение")


func test_switching_relic_tiers_keeps_showcase_camera_size() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	var showcase := ItemShowcase.new()
	add_child_autofree(showcase)
	for variant in SkinnedActorModel.variants():
		SkinnedActorModel.select(variant["id"])
		for slot in SLOTS:
			var size := 0.0
			for tier in [1, 2, 3]:
				var state := ItemState.create(slot)
				state.appearance = tier
				showcase.show_single(state)
				var camera := showcase.viewport.get_camera_3d()
				if tier == 1:
					size = camera.size
				assert_almost_eq(camera.size, size, 0.001, "переключение облика сохраняет масштаб")


func test_locomotion_speeds_increase() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for v in SkinnedActorModel.variants():
		for kind in [ActorModel.Kind.HERO, ActorModel.Kind.BOSS]:
			var m := _model(v["id"], kind, [])
			for i in range(1, m._speeds.size()):
				assert_gt(m._speeds[i], m._speeds[i - 1], "%s/%d: скорости ходьбы растут" % [v["id"], kind])


func test_menu_showcase_has_every_item_of_the_hero() -> void:
	if not SkinnedActorModel.available():
		pending("модели героев не собраны")
		return
	for v in SkinnedActorModel.variants():
		SkinnedActorModel.select(v["id"])
		var shown := GeneratedItemDisplay.build()
		for slot in SLOTS:
			assert_true(shown.has(slot), "%s: на витрине нет %s" % [v["id"], slot])
			if not shown.has(slot):
				continue
			var d: Node3D = shown[slot]
			add_child_autofree(d)
			var size := 0.0
			for mi in d.find_children("*", "MeshInstance3D", true, false):
				var box: AABB = (d.global_transform.affine_inverse() * mi.global_transform) * mi.mesh.get_aabb()
				size = maxf(size, box.get_longest_axis_size() * d.scale.x)
			var fit: float = GeneratedItemDisplay.FIT.get(slot, GeneratedItemDisplay.FIT_DEFAULT)
			assert_almost_eq(size, fit, fit * 0.6, "%s/%s: размер на витрине" % [v["id"], slot])


func test_swarm_and_slime_use_generated_meshes() -> void:
	for spec in [[&"swarm", ActorModel.SWARM_GLB], [&"slime", ActorModel.SLIME_SKULL_GLB]]:
		var e := EnemyFactory.create(Db.enemy(spec[0]), 1)
		add_child_autofree(e)
		var found := e.get_node("Model").find_children("*", "Node3D", true, false).filter(
				func(n: Node) -> bool: return n.scene_file_path == spec[1])
		assert_eq(found.size(), 1, "%s: сгенерированная сетка" % spec[0])
		if spec[0] == &"swarm":
			var m := e.get_node("Model") as ActorModel
			assert_eq(m._quad_legs.size(), 4, "у беса четыре лапы на костях")
			var leg: Array = m._quad_legs[0]
			m._animate_quad(0.5)
			assert_gt(m._quad.get_bone_pose_rotation(leg[0]).angle_to(leg[1]), 0.1, "лапа шагает")
