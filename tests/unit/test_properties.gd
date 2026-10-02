extends GutTest
## Все 42 свойства: 7 сущностей × 6 событий других вещей.
## Каждое свойство рождается жертвой, слушает событие получателя, применяет эффект сущности
## жертвы, порождает событие жертвы и уважает внутренний откат 0,4 с.

const ADJECTIVES := {
	&"blade": "Режущий", &"bulwark": "Неуязвимый", &"mass": "Таранный", &"gaze": "Зоркий",
	&"grip": "Цепкий", &"gust": "Стремительный", &"energy": "Сияющий",
}
const WORDS := {
	&"hit": "удар", &"block": "блок", &"response": "ответ", &"crit": "крит",
	&"grab": "захват", &"dash": "рывок", &"volley": "залп",
}

var _events: Array[StringName] = []


static func pairs() -> Array:
	var out := []
	for victim in Db.ITEM_IDS:
		for recipient in Db.ITEM_IDS:
			if victim != recipient:
				out.append([victim, recipient])
	return out


func after_each() -> void:
	TestHelpers.clear_projectiles(get_tree())
	_events.clear()


func _record(event_id: StringName, _ctx: ActionContext) -> void:
	_events.append(event_id)


func test_there_are_42_unique_properties() -> void:
	var names := {}
	for pair in pairs():
		var ring := Ring.from_ids([pair[0], pair[1]] as Array[StringName])
		var p: Property = ring.sacrifice(0)["property"]
		names[p.display_name()] = true
	assert_eq(pairs().size(), 42)
	assert_eq(names.size(), 42, "у всех 42 свойств разные имена")


func test_property(params = use_parameters(pairs())) -> void:
	var victim_id: StringName = params[0]
	var recipient_id: StringName = params[1]
	var victim := Db.item(victim_id)
	var recipient := Db.item(recipient_id)

	# Рождение: жертва уходит в соседа по часовой.
	var ring := Ring.from_ids([victim_id, recipient_id] as Array[StringName])
	var res := ring.sacrifice(0)
	var p: Property = res["property"]
	assert_eq(p.listen_event, recipient.event_id, "слушает событие получателя")
	assert_eq(p.essence_id, victim.essence.id, "эффект сущности жертвы")
	assert_eq(p.emit_event, victim.event_id, "порождает событие жертвы")
	var expected_name: String = "%s %s" % [ADJECTIVES[victim.essence.id], WORDS[recipient.event_id]]
	assert_eq(p.display_name(), expected_name)

	# Срабатывание: событие получателя → эффект → событие жертвы.
	var state: ItemState = res["recipient"]
	var hero := TestHelpers.hero(self, [state] as Array[ItemState])
	var near := TestHelpers.dummy(self, Vector3(0, 0, -1.6))
	var mid := TestHelpers.dummy(self, Vector3(0.4, 0, -2.4))
	var far := TestHelpers.dummy(self, Vector3(0, 0, 9.0))
	hero.bus.event_fired.connect(_record)
	var triggered := []
	hero.bus.property_triggered.connect(func(prop, _c): triggered.append(prop))

	hero.bus.emit_event(recipient.event_id, ActionContext.make(hero, state))
	assert_eq(_events, [recipient.event_id, victim.event_id] as Array[StringName], "%s: событие получателя порождает событие жертвы" % expected_name)
	assert_eq(triggered.size(), 1, "свойство сработало один раз")
	_assert_effect(victim.essence.id, hero, near, mid, far)

	# Внутренний откат 0,4 с.
	_events.clear()
	hero.bus.emit_event(recipient.event_id, ActionContext.make(hero, state))
	assert_eq(_events, [recipient.event_id] as Array[StringName], "в откате свойство молчит")
	hero.bus.clock += 0.39
	_events.clear()
	hero.bus.emit_event(recipient.event_id, ActionContext.make(hero, state))
	assert_eq(_events, [recipient.event_id] as Array[StringName], "откат ещё не прошёл")
	hero.bus.clock += 0.02
	_events.clear()
	hero.bus.emit_event(recipient.event_id, ActionContext.make(hero, state))
	assert_eq(_events, [recipient.event_id, victim.event_id] as Array[StringName], "после 0,4 с срабатывает снова")


func _assert_effect(essence: StringName, hero: Actor, near: Actor, mid: Actor, far: Actor) -> void:
	match essence:
		&"blade":
			assert_almost_eq(near.hp, 1000.0 - 15.0 * 1.1, 0.01, "Лезвие: 15 урона в дуге 2,5 м (+10% за свойство на вещи)")
			assert_almost_eq(mid.hp, 1000.0 - 15.0 * 1.1, 0.01, "Лезвие задевает всех в дуге")
			assert_eq(far.hp, 1000.0, "сзади не задевает")
		&"bulwark":
			assert_almost_eq(hero.invuln_time, 0.6, 0.001, "Оплот: 0,6 с неуязвимости")
			assert_almost_eq(hero.reflect_time, 0.6, 0.001, "Оплот: отражение снарядов")
			var ctx := ActionContext.make(near, null)
			assert_eq(hero.receive_hit(50.0, ctx), Actor.HitResult.IMMUNE)
		&"mass":
			assert_almost_eq(near.hp, 1000.0 - 5.0 * 1.1, 0.01, "Масса: 5 урона (+10% за свойство на вещи)")
			assert_almost_eq(near.stun_time, 0.5, 0.001, "Масса: оглушение 0,5 с")
			assert_gt(near.forced_time, 0.0, "Масса: толчок")
			assert_gt(near.forced_velocity.dot(Vector3(0, 0, -1)), 0.0, "толкает от героя")
			assert_eq(far.hp, 1000.0, "вне радиуса не задевает")
		&"gaze":
			assert_almost_eq(near.open_time, 1.5, 0.001, "Взор: открыт для крита 1,5 с")
			assert_almost_eq(mid.open_time, 1.5, 0.001)
			assert_eq(far.open_time, 0.0, "дальше 6 м не открывает")
		&"grip":
			assert_gt(mid.forced_time, 0.0, "Хватка: притягивает")
			assert_gt(mid.forced_velocity.dot(Vector3(0, 0, 1)), 0.0, "тянет к герою")
			assert_eq(far.forced_time, 0.0, "вне конуса не тянет")
		&"gust":
			assert_gt(hero.dash_time, 0.0, "Порыв: рывок")
			assert_gt(hero.dash_velocity.normalized().dot(Vector3(0, 0, -1)), 0.99, "рывок к курсору")
		&"energy":
			var projectiles := get_tree().get_nodes_in_group(&"projectiles")
			assert_eq(projectiles.size(), 1, "Энергия: волна-снаряд")
			if projectiles.size() == 1:
				var pr := projectiles[0] as Projectile
				assert_true(pr.pierce, "проходит насквозь")
				assert_almost_eq(pr.damage, 15.0 * 1.1, 0.01, "Энергия: 15 урона (+10% за свойство на вещи)")
				assert_eq(pr.faction, hero.faction)
				assert_gt(pr.velocity.normalized().dot(Vector3(0, 0, -1)), 0.99, "летит к курсору")
		_:
			fail_test("неизвестная сущность %s" % essence)
