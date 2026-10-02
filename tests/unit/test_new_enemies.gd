extends GutTest
## Слизень (ядовитый след, деление) и шут (выпад с серией ножей, уворот).


func after_each() -> void:
	for n in get_tree().get_nodes_in_group(&"projectiles"):
		n.free()


func test_poison_puddle_ticks_damage_on_hostiles_inside() -> void:
	var hero := TestHelpers.hero(self, [] as Array[ItemState])
	var slime := TestHelpers.dummy(self, Vector3(3, 0, 0))
	var def := Db.enemy(&"slime")
	var ctx := ActionContext.make(slime, null)
	ctx.from_property = true
	var puddle := PoisonPuddle.spawn(ctx, hero.global_position, def, def.trail_damage)
	autofree(puddle)
	puddle._physics_process(0.01)
	assert_almost_eq(hero.hp, 100.0 - def.trail_damage, 0.01, "лужа жжёт стоящего в ней")
	# Часы героя идут вместе с лужей (в игре оба тикают в одном кадре).
	hero.bus.clock += def.trail_tick * 0.5
	puddle._physics_process(def.trail_tick * 0.5)
	assert_almost_eq(hero.hp, 100.0 - def.trail_damage, 0.01, "урон раз в тик, а не каждый кадр")
	hero.bus.clock += def.trail_tick * 0.6
	puddle._physics_process(def.trail_tick * 0.6)
	assert_almost_eq(hero.hp, 100.0 - def.trail_damage * 2.0, 0.01, "следующий тик")
	hero.global_position = Vector3(5, 0, 5)
	hero.bus.clock += def.trail_tick + 0.01
	puddle._physics_process(def.trail_tick + 0.01)
	assert_almost_eq(hero.hp, 100.0 - def.trail_damage * 2.0, 0.01, "вне лужи не жжёт")


func test_slime_defines_split_into_smaller_slimes() -> void:
	var def := Db.enemy(&"slime")
	assert_eq(def.split_into, &"slime_small")
	assert_eq(def.split_count, 2)
	assert_eq(Db.enemy(&"slime_small").split_count, 0, "слизнёныши дальше не делятся")


func test_jester_lunges_and_stabs_combo_hits() -> void:
	var hero := TestHelpers.hero(self, [] as Array[ItemState])
	Combat.hero = hero
	var def := Db.enemy(&"jester")
	var jester := EnemyFactory.create(def, 1)
	add_child_autofree(jester)
	# Рывок двигает физика, которой в тесте нет, — ставим шута сразу на дистанцию удара.
	jester.global_position = Vector3(0, 0, -1.0)
	jester.get_node("AI").set_physics_process(false)
	var atk := jester.innate as EnemyAttack
	assert_true(atk.press(), "замах")
	atk._tick(def.windup + 0.01)
	assert_gt(jester.dash_time, 0.0, "выпад к цели")
	for i in 40:
		atk._tick(0.02)
	assert_almost_eq(hero.hp, 100.0 - def.damage * def.combo_hits, 0.01, "серия из %d ударов ножами" % def.combo_hits)
	assert_true(atk.is_idle() or atk.state == EnemyAttack.State.RECOVERY)


func test_jester_combo_is_cancelled_by_stun() -> void:
	var hero := TestHelpers.hero(self, [] as Array[ItemState])
	Combat.hero = hero
	var jester := EnemyFactory.create(Db.enemy(&"jester"), 1)
	add_child_autofree(jester)
	jester.global_position = Vector3(0, 0, -1.0)
	jester.get_node("AI").set_physics_process(false)
	var atk := jester.innate as EnemyAttack
	atk.press()
	atk._tick(Db.enemy(&"jester").windup + 0.01)
	jester.stun(0.5)
	for i in 40:
		atk._tick(0.02)
	assert_eq(hero.hp, 100.0, "оглушённый шут не добивает серию")


func test_overlapping_puddles_do_not_stack() -> void:
	var hero := TestHelpers.hero(self, [] as Array[ItemState])
	var slime := TestHelpers.dummy(self, Vector3(3, 0, 0))
	var def := Db.enemy(&"slime")
	var ctx := ActionContext.make(slime, null)
	ctx.from_property = true
	hero.bus.clock = 100.0
	var a := PoisonPuddle.spawn(ctx, hero.global_position, def, def.trail_damage)
	var b := PoisonPuddle.spawn(ctx, hero.global_position + Vector3(0.2, 0, 0), def, def.trail_damage)
	autofree(a)
	autofree(b)
	a._physics_process(0.01)
	b._physics_process(0.01)
	assert_almost_eq(hero.hp, 100.0 - def.trail_damage, 0.01, "две лужи под ногами — один удар за тик")
