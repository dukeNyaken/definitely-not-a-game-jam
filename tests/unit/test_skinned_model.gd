extends GutTest
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


func test_mesh_names_map_to_slots() -> void:
	# item_<слот>[__<часть>][_L|_R|_under]: часть вещи и подложка — тот же слот
	for n in ["armor", "armor__legs", "armor_under", "armor__legs_under"]:
		assert_eq(SkinnedActorModel._slot_of(n), &"armor", n)
	assert_eq(SkinnedActorModel._slot_of("boots_L"), &"boots")
	assert_eq(SkinnedActorModel._slot_of("gloves_R"), &"gloves")


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
