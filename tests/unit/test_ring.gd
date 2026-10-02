extends GutTest
## Кольцо, жертва, святилище, снимки, имена.


func test_generate_is_deterministic_and_complete() -> void:
	var a := Ring.generate(12345, Db.ITEM_IDS)
	var b := Ring.generate(12345, Db.ITEM_IDS)
	assert_eq(a.ids(), b.ids(), "один сид — одно кольцо")
	assert_eq(a.size(), 7)
	for id in Db.ITEM_IDS:
		assert_true(a.has_item(id), "в кольце есть %s" % id)


func test_different_seeds_give_different_rings() -> void:
	var seen := {}
	for s in 20:
		seen[str(Ring.generate(s, Db.ITEM_IDS).ids())] = true
	assert_gt(seen.size(), 10, "кольца по разным сидам различаются")


func test_victim_goes_to_clockwise_neighbor_and_ring_closes() -> void:
	var ring := Ring.from_ids([&"sword", &"shield", &"armor"])
	var res := ring.sacrifice(1)
	assert_eq((res["recipient"] as ItemState).def_id, &"armor", "получатель — ring[(i+1)%n]")
	assert_eq(ring.ids(), [&"sword", &"armor"] as Array[StringName], "кольцо сомкнулось")


func test_last_victim_wraps_to_first() -> void:
	var ring := Ring.from_ids([&"sword", &"shield", &"armor"])
	var res := ring.sacrifice(2)
	assert_eq((res["recipient"] as ItemState).def_id, &"sword")


func test_property_shape() -> void:
	var ring := Ring.from_ids([&"shield", &"boots"])
	var res := ring.sacrifice(0)
	var p: Property = res["property"]
	assert_eq(p.listen_event, &"dash", "слушает событие получателя")
	assert_eq(p.essence_id, &"bulwark", "эффект — сущность жертвы")
	assert_eq(p.emit_event, &"block", "порождает событие жертвы")
	assert_almost_eq(p.cooldown, 0.4, 0.0001)
	assert_eq(p.display_name(), "Неуязвимый рывок")


func test_all_victim_properties_move_to_recipient() -> void:
	var ring := Ring.from_ids([&"shield", &"boots", &"sword"])
	ring.sacrifice(0)
	ring.sacrifice(0)
	var sword := ring.get_item(&"sword")
	assert_eq(sword.properties.size(), 2)
	assert_eq(ring.size(), 1)


func test_snapshot_is_frozen_at_sacrifice() -> void:
	var ring := Ring.from_ids([&"shield", &"boots", &"sword"])
	ring.sacrifice(0)
	var res := ring.sacrifice(0)
	var snap: ItemState = res["victim_snapshot"]
	assert_eq(snap.def_id, &"boots")
	assert_eq(snap.property_names(), PackedStringArray(["Неуязвимый рывок"]), "снимок хранит свойства на момент жертвы")
	ring.get_item(&"sword").properties.clear()
	assert_eq(snap.properties.size(), 1, "снимок не зависит от живой вещи")


func test_preview_does_not_mutate() -> void:
	var ring := Ring.from_ids([&"shield", &"boots", &"sword"])
	var pv := ring.preview(0)
	assert_eq((pv["recipient_after"] as ItemState).properties.size(), 1)
	assert_eq(ring.size(), 3)
	assert_eq(ring.get_item(&"boots").properties.size(), 0)


func test_swap_neighbors() -> void:
	var ring := Ring.from_ids([&"sword", &"shield", &"armor"])
	ring.swap_neighbors(2)
	assert_eq(ring.ids(), [&"armor", &"shield", &"sword"] as Array[StringName], "последний меняется с первым")


func test_run_state_speed_and_artifact_name() -> void:
	RunState.new_run(777)
	var ring := RunState.ring
	assert_almost_eq(RunState.speed_multiplier(), 1.0, 0.0001)
	for i in 6:
		RunState.sacrifice(0)
	assert_eq(ring.size(), 1)
	assert_almost_eq(RunState.speed_multiplier(), 1.36, 0.0001, "+6% скорости за каждую жертву")
	assert_eq(RunState.snapshots.size(), 6)
	var holder := RunState.artifact_holder()
	var last: Property = RunState.last_property()
	var essence := Db.essence(last.essence_id)
	var expected := "%s %s" % [essence.adjective_plural if holder.def().plural else essence.adjective, holder.def().display_name.to_lower()]
	assert_eq(RunState.artifact_name(), expected)
	assert_eq(holder.properties.size(), 6, "финальная вещь — дерево из 6 свойств")


func test_plural_items_agree_adjective() -> void:
	RunState.new_run(1)
	RunState.ring = Ring.from_ids([&"armor", &"gloves"])
	RunState.snapshots.clear()
	RunState.sacrifice_log.clear()
	RunState.sacrifice(0)
	assert_eq(RunState.artifact_name(), "Таранные перчатки")
	RunState.ring = Ring.from_ids([&"sword", &"armor"])
	RunState.sacrifice_log.clear()
	RunState.sacrifice(0)
	assert_eq(RunState.artifact_name(), "Режущий доспех")


func test_threat_order_covers_all_threats() -> void:
	RunState.new_run(4242)
	var seen := {}
	for s in range(2, 7):
		seen[RunState.threat_for(s).id] = true
	assert_eq(seen.size(), 5, "этапы 2–6 получают все пять угроз")
	assert_eq(RunState.threat_for(1).id, &"tutorial")


func test_enemy_scaling_compounds_12_percent() -> void:
	assert_almost_eq(RunState.enemy_scale(1), 1.0, 0.0001)
	assert_almost_eq(RunState.enemy_scale(2), 1.12, 0.0001)
	assert_almost_eq(RunState.enemy_scale(3), 1.2544, 0.0001)


func test_damage_bonus_per_property() -> void:
	var state := ItemState.create(&"sword")
	var hero := TestHelpers.hero(self, [state] as Array[ItemState])
	var comp := hero.component(&"sword")
	assert_almost_eq(comp.damage_mult(), 1.0, 0.0001)
	state.properties.append(Property.create(&"hit", &"gust", &"dash", &"boots", 0.4))
	state.properties.append(Property.create(&"dash", &"bulwark", &"block", &"shield", 0.4))
	assert_almost_eq(comp.damage_mult(), 1.2, 0.0001, "+10% урона действия за каждое свойство")


func test_sacrificed_action_is_gone() -> void:
	var ring := Ring.from_ids([&"shield", &"boots"])
	var hero := TestHelpers.hero(self, ring.items.duplicate())
	assert_not_null(hero.slot(&"block"))
	ring.sacrifice(0)
	hero.set_items(ring.items.duplicate())
	assert_null(hero.slot(&"block"), "действие жертвы пропадает навсегда")
	assert_null(hero.component(&"shield"))
