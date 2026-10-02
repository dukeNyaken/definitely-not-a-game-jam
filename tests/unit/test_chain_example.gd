extends GutTest
## Пример из дизайна: Щит уходит в Сапоги («Неуязвимый рывок»), затем Сапоги уходят в Меч
## («Стремительный удар»): удар мечом даёт выпад, и в выпаде герой неуязвим.

var _events: Array[StringName] = []


func _record(event_id: StringName, _ctx: ActionContext) -> void:
	_events.append(event_id)


func after_each() -> void:
	TestHelpers.clear_projectiles(get_tree())
	_events.clear()


func _example_ring() -> Ring:
	var ring := Ring.from_ids([&"shield", &"boots", &"sword", &"armor"])
	var first := ring.sacrifice(0)
	assert_eq((first["property"] as Property).display_name(), "Неуязвимый рывок")
	var second := ring.sacrifice(0)
	assert_eq((second["property"] as Property).display_name(), "Стремительный удар")
	return ring


func test_sword_inherits_the_whole_tree() -> void:
	var ring := _example_ring()
	var sword := ring.get_item(&"sword")
	var names := sword.property_names()
	assert_true(names.has("Стремительный удар"))
	assert_true(names.has("Неуязвимый рывок"), "свойства жертвы переехали к получателю")
	assert_eq(ring.ids(), [&"sword", &"armor"] as Array[StringName])


func test_sword_swing_lunges_and_hero_is_invulnerable() -> void:
	var ring := _example_ring()
	var hero := TestHelpers.hero(self, ring.items.duplicate())
	hero.aim_point = Vector3(3, 0, -4)
	hero.bus.event_fired.connect(_record)
	assert_null(hero.slot(&"dash"), "сапог больше нет — рывок только из свойства")
	assert_null(hero.slot(&"block"), "щита больше нет — блок только из свойства")

	assert_true(hero.press(&"attack"), "удар мечом")
	assert_eq(_events, [&"hit", &"dash", &"block"] as Array[StringName], "удар → рывок → блок")
	assert_gt(hero.dash_time, 0.0, "выпад")
	var aim_dir := Vector3(3, 0, -4).normalized()
	assert_gt(hero.dash_velocity.normalized().dot(aim_dir), 0.99, "выпад к курсору")
	assert_gt(hero.invuln_time, 0.0, "в выпаде герой неуязвим")
	var enemy := TestHelpers.dummy(self, Vector3(0, 0, 5))
	var res := hero.receive_hit(30.0, ActionContext.make(enemy, null))
	assert_eq(res, Actor.HitResult.IMMUNE)
	assert_eq(hero.hp, 100.0)


func test_event_fires_once_per_action_not_per_target() -> void:
	var ring := _example_ring()
	var hero := TestHelpers.hero(self, ring.items.duplicate())
	for x in [-0.8, 0.0, 0.8]:
		TestHelpers.dummy(self, Vector3(x, 0, -1.5))
	var triggered := []
	hero.bus.property_triggered.connect(func(prop, _c): triggered.append(prop))
	hero.bus.event_fired.connect(_record)
	hero.press(&"attack")
	assert_eq(_events.count(&"hit"), 1, "одно действие — одно событие удара")
	assert_eq(triggered.size(), 2, "каждое свойство цепочки сработало один раз")


func test_crit_fires_once_per_action() -> void:
	var sword := ItemState.create(&"sword")
	var helmet := ItemState.create(&"helmet")
	var hero := TestHelpers.hero(self, [sword, helmet] as Array[ItemState])
	var dummies: Array[Actor] = []
	for x in [-0.8, 0.0, 0.8]:
		var d := TestHelpers.dummy(self, Vector3(x, 0, -1.5))
		d.mark_attack()
		dummies.append(d)
	hero.bus.event_fired.connect(_record)
	hero.press(&"attack")
	assert_eq(_events.count(&"crit"), 1, "три крита одним ударом — одно событие")
	for d in dummies:
		assert_almost_eq(d.hp, 1000.0 - 20.0, 0.01, "крит ×2 в окно уязвимости")


func test_no_crit_outside_window_without_gaze() -> void:
	var hero := TestHelpers.hero(self, [ItemState.create(&"sword"), ItemState.create(&"helmet")] as Array[ItemState])
	var d := TestHelpers.dummy(self, Vector3(0, 0, -1.5))
	hero.press(&"attack")
	assert_almost_eq(d.hp, 990.0, 0.01, "вне окна — обычный урон")


func test_gaze_opens_for_crit_even_without_helmet() -> void:
	var hero := TestHelpers.hero(self, [ItemState.create(&"sword")] as Array[ItemState])
	var d := TestHelpers.dummy(self, Vector3(0, 0, -1.5))
	d.open_for_crit(1.5)
	hero.press(&"attack")
	assert_almost_eq(d.hp, 980.0, 0.01, "открытая цель получает крит")


func test_fist_without_sword() -> void:
	var hero := TestHelpers.hero(self, [ItemState.create(&"armor")] as Array[ItemState])
	hero.set_innate(FistAction.new())
	var d := TestHelpers.dummy(self, Vector3(0, 0, -1.2))
	hero.bus.event_fired.connect(_record)
	assert_true(hero.press(&"attack"))
	assert_almost_eq(d.hp, 995.0, 0.01, "кулак — 5 урона")
	assert_eq(_events.size(), 0, "кулак не вещь и событий не порождает")


func test_armor_absorbs_and_emits_response() -> void:
	var hero := TestHelpers.hero(self, [ItemState.create(&"armor")] as Array[ItemState])
	hero.bus.event_fired.connect(_record)
	var enemy := TestHelpers.dummy(self, Vector3(0, 0, -2))
	hero.receive_hit(30.0, ActionContext.make(enemy, null))
	assert_eq(hero.hp, 100.0, "урон ушёл в броню")
	assert_eq(hero.armor, 20.0)
	assert_eq(_events, [&"response"] as Array[StringName])
	hero.receive_hit(30.0, ActionContext.make(enemy, null))
	assert_eq(hero.hp, 90.0)
	hero.restore_armor()
	assert_eq(hero.armor, 50.0, "броня восстанавливается")


func test_shield_blocks_front_only_and_slows() -> void:
	var hero := TestHelpers.hero(self, [ItemState.create(&"shield")] as Array[ItemState])
	var speed := hero.current_speed()
	hero.press(&"block")
	assert_almost_eq(hero.current_speed(), speed * 0.5, 0.001, "−50% скорости в блоке")
	var front := TestHelpers.dummy(self, Vector3(0, 0, -2))
	var back := TestHelpers.dummy(self, Vector3(0, 0, 2))
	assert_eq(hero.receive_hit(10.0, ActionContext.make(front, null)), Actor.HitResult.BLOCKED)
	assert_eq(hero.receive_hit(10.0, ActionContext.make(back, null)), Actor.HitResult.HIT)
	hero.release(&"block")
	assert_eq(hero.receive_hit(10.0, ActionContext.make(front, null)), Actor.HitResult.HIT)


func test_snapshot_items_stay_scoped_on_boss() -> void:
	# Босс носит снимки Сапог и Меча: «Неуязвимый рывок» есть в обоих, но срабатывает
	# только в дереве вещи, от которой пришло событие.
	var ring := Ring.from_ids([&"shield", &"boots", &"sword", &"armor"])
	ring.sacrifice(0)
	var boots_snap: ItemState = ring.sacrifice(0)["victim_snapshot"]
	var sword_snap: ItemState = ring.sacrifice(0)["victim_snapshot"]
	var boss := Actor.new()
	boss.faction = Actor.Faction.ENEMY
	add_child_autofree(boss)
	boss.set_items([boots_snap, sword_snap] as Array[ItemState])
	var triggered := []
	boss.bus.property_triggered.connect(func(prop, _c): triggered.append(prop))
	boss.press(&"dash")
	assert_eq(triggered.size(), 1, "рывок сапог запускает только их снимок")
