extends GutTest

var _xp: Dictionary
var _choices: Dictionary
var _run_xp: Dictionary
var _run_start_xp: Dictionary
var _memory: bool
var _hero: Actor
var _running: bool


func before_each() -> void:
	_xp = Mastery.xp.duplicate()
	_choices = Mastery.choices.duplicate()
	_run_xp = Mastery.run_xp.duplicate()
	_run_start_xp = Mastery.run_start_xp.duplicate()
	_memory = Mastery.memory_only
	_hero = Combat.hero
	_running = RunState.running
	Mastery.memory_only = true
	Mastery.xp.clear()
	Mastery.choices.clear()
	Mastery.run_xp.clear()
	Mastery.run_start_xp.clear()
	RunState.running = true


func after_each() -> void:
	Mastery.xp = _xp
	Mastery.choices = _choices
	Mastery.run_xp = _run_xp
	Mastery.run_start_xp = _run_start_xp
	Mastery.memory_only = _memory
	Mastery.save_error = false
	Combat.hero = _hero
	RunState.running = _running
	TestHelpers.clear_projectiles(get_tree())


func hero_with(id: StringName, tier: int = 1) -> Actor:
	var item := ItemState.create(id)
	item.appearance = tier
	var hero := TestHelpers.hero(self, [item])
	Combat.hero = hero
	return hero


func test_kill_rewards_all_equipped_once_including_passives() -> void:
	var items: Array[ItemState] = []
	for id in Db.ITEM_IDS:
		items.append(ItemState.create(id))
	var hero := TestHelpers.hero(self, items)
	Combat.hero = hero
	var target := TestHelpers.dummy(self, Vector3(0, 0, -2), 1)
	target.set_meta(&"mastery_xp", 18)
	var ctx := ActionContext.make(hero, null)
	ctx.from_property = true
	Combat.deal(ctx, target, 10)
	target.die(hero)
	for id in Db.ITEM_IDS:
		assert_eq(Mastery.xp[id], 18)
		assert_eq(Mastery.run_xp[id], 18)


func test_debug_death_and_enemy_kills_do_not_reward() -> void:
	hero_with(&"boots")
	var target := TestHelpers.dummy(self, Vector3.ZERO, 1)
	target.set_meta(&"mastery_xp", 100)
	target.die()
	var enemy := TestHelpers.dummy(self, Vector3.ZERO)
	var other := TestHelpers.dummy(self, Vector3.ZERO, 1)
	other.set_meta(&"mastery_xp", 100)
	Combat.deal(ActionContext.make(enemy, null), other, 10)
	assert_true(Mastery.xp.is_empty())


func test_sacrifice_stops_xp_even_when_properties_remain() -> void:
	RunState.new_run(123)
	var hero := TestHelpers.hero(self, RunState.ring.items)
	var victim := RunState.ring.items[0].def_id
	Mastery.award(hero, 20)
	RunState.sacrifice(0)
	hero.set_items(RunState.ring.items)
	Mastery.award(hero, 30)
	assert_eq(Mastery.xp[victim], 20)
	for item in hero.items:
		assert_eq(Mastery.xp[item.def_id], 50)


func test_thresholds_upgrade_live_without_resetting_cooldown_and_snapshot() -> void:
	var hero := hero_with(&"boots")
	var comp := hero.component(&"boots")
	comp.start_cooldown(0.7)
	Mastery.award(hero, 249)
	assert_eq(Mastery.level(&"boots"), 1)
	Mastery.award(hero, 1)
	assert_eq(hero.items[0].appearance, 2)
	assert_eq(comp.cooldown_left, 0.7)
	var snapshot := hero.items[0].snapshot()
	Mastery.award(hero, 750)
	assert_eq(hero.items[0].appearance, 3)
	assert_eq(snapshot.appearance, 2)
	assert_eq(float(comp.def.stat("distance")), 5.0)
	assert_eq(float(Db.item(&"boots").stat("distance")), 4.0)
	Mastery.award(hero, 100)
	assert_eq(Mastery.xp[&"boots"], 1000)
	assert_eq(Mastery.run_xp[&"boots"], 1100)


func test_new_run_keeps_unlocks_and_selected_old_appearance() -> void:
	Mastery.award(hero_with(&"sword"), 1000)
	Mastery.choose(&"sword", 2)
	Mastery.choose(&"boots", 3)
	RunState.new_run(234)
	assert_eq(Mastery.level(&"sword"), 3)
	assert_eq(RunState.ring.get_item(&"sword").appearance, 2)
	assert_eq(RunState.ring.get_item(&"boots").appearance, 1)
	assert_true(Mastery.run_xp.is_empty())
	assert_eq(Mastery.run_start_xp[&"sword"], 1000)


func test_run_baseline_survives_capped_rewards_and_next_run_resets_it() -> void:
	Mastery.xp[&"boots"] = 900
	RunState.new_run(234)
	var hero := hero_with(&"boots", 2)
	Mastery.award(hero, 450)
	assert_eq(Mastery.run_start_xp[&"boots"], 900)
	assert_eq(Mastery.xp[&"boots"], 1000)
	assert_eq(Mastery.run_xp[&"boots"], 450)
	RunState.new_run(235)
	assert_eq(Mastery.run_start_xp[&"boots"], 1000)
	assert_true(Mastery.run_xp.is_empty())


func test_rewards_scale_with_enemy_stage_and_elite() -> void:
	assert_eq(Mastery.reward(&"swarm", 1), 2)
	assert_eq(Mastery.reward(&"brute", 1), 18)
	assert_eq(Mastery.reward(&"brute", 1, true), 54)
	assert_gt(Mastery.reward(&"brute", 6), 18)
	assert_gt(Mastery.reward(&"boss", 7), Mastery.reward(&"brute", 7, true))


func test_save_reload_replace_and_backup_recovery() -> void:
	var path := "res://.godot/mastery_test.cfg"
	Mastery.memory_only = false
	Mastery.xp[&"sword"] = 1000
	Mastery.choices[&"sword"] = 2
	assert_true(Mastery.save_progress(path))
	Mastery.xp[&"boots"] = 250
	assert_true(Mastery.save_progress(path))
	Mastery.load_progress(path)
	assert_eq(Mastery.level(&"boots"), 2)
	assert_eq(Mastery.selected(&"sword"), 2)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[meta]\nversion=0\n")
	file.close()
	Mastery.load_progress(path)
	assert_eq(Mastery.level(&"sword"), 3)
	assert_eq(Mastery.selected(&"sword"), 2)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func test_reset_persists_empty_profile_including_backup_recovery() -> void:
	var path := "res://.godot/mastery_reset_test.cfg"
	RunState.running = false
	Mastery.memory_only = false
	Mastery.xp = {&"sword": 1000, &"boots": 250}
	Mastery.choices = {&"sword": 3, &"boots": 2}
	assert_true(Mastery.save_progress(path))
	assert_true(Mastery.save_progress(path))
	Mastery.run_start_xp = {&"sword": 900}
	Mastery.run_xp = {&"sword": 450}
	watch_signals(Mastery)
	assert_true(Mastery.reset_progress(path))
	assert_signal_emit_count(Mastery, "progress_reset", 1)
	assert_signal_emit_count(Mastery, "changed", 1)
	assert_true(Mastery.run_start_xp.is_empty())
	assert_true(Mastery.run_xp.is_empty())
	Mastery.load_progress(path)
	for id in Db.ITEM_IDS:
		assert_eq(Mastery.level(id), 1)
		assert_eq(Mastery.selected(id), 1)
		assert_eq(int(Mastery.xp.get(id, 0)), 0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[meta]\nversion=0\n")
	file.close()
	Mastery.load_progress(path)
	for id in Db.ITEM_IDS:
		assert_eq(int(Mastery.xp.get(id, 0)), 0, "резервная копия не возвращает стёртый опыт")
		assert_eq(Mastery.selected(id), 1)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func test_reset_updates_live_forms_without_healing_or_losing_sacrifices() -> void:
	var previous_ring := RunState.ring
	var ring := Ring.from_ids([&"amulet", &"armor", &"shield", &"boots"])
	for item in ring.items:
		item.appearance = 3
	var snapshot: ItemState = ring.sacrifice(0)["victim_snapshot"]
	RunState.ring = ring
	var property := ring.get_item(&"armor").properties[0]
	var hero := TestHelpers.hero(self, ring.items)
	Combat.hero = hero
	hero.hp = 62
	hero.armor = 30
	var boots := hero.component(&"boots")
	boots.start_cooldown(0.7)
	var shield := hero.component(&"shield") as ShieldAction
	shield.press()
	Mastery.xp = {&"armor": 1000, &"shield": 1000, &"boots": 1000}
	Mastery.choices = {&"armor": 3, &"shield": 3, &"boots": 3}
	assert_true(Mastery.reset_progress())
	assert_eq(hero.hp, 62.0)
	assert_eq(hero.max_armor, 50.0)
	assert_eq(hero.armor, 10.0, "уменьшение ёмкости сохраняет полученный урон")
	assert_same(hero.component(&"boots"), boots)
	assert_eq(boots.cooldown_left, 0.7)
	assert_eq(float(boots.def.stat("distance")), 4.0)
	assert_true(shield.holding)
	assert_eq(hero.block_arc_degrees, 120.0)
	assert_eq(ring.ids(), [&"armor", &"shield", &"boots"] as Array[StringName])
	assert_same(ring.get_item(&"armor").properties[0], property)
	assert_eq(snapshot.appearance, 3, "снимок совершённой жертвы остаётся историей забега")
	for item in hero.items:
		assert_eq(item.appearance, 1)
	RunState.ring = previous_ring


func test_sword_relic_finisher_hits_behind() -> void:
	var hero := hero_with(&"sword", 3)
	var target := TestHelpers.dummy(self, Vector3(0, 0, 2.8))
	var sword := hero.component(&"sword") as SwordAction
	sword.combo_step = 1
	sword._last_swing = hero.clock()
	assert_true(sword.press())
	assert_lt(target.hp, target.max_hp)


func test_shield_and_boots_gain_protection() -> void:
	var hero := hero_with(&"shield", 3)
	hero.press(&"block")
	assert_eq(hero.block_arc_degrees, 180.0)
	assert_eq(hero.reflect_time, 0.7)
	var boots := ItemState.create(&"boots")
	boots.appearance = 3
	hero.set_items([boots])
	hero.press(&"dash")
	assert_eq(hero.invuln_time, 0.18)
	assert_almost_eq(hero.dash_velocity.length() * hero.dash_time, 5.0, 0.001)


func test_armor_upgrade_preserves_damage_and_retaliates_without_recursion() -> void:
	var hero := hero_with(&"armor")
	hero.armor = 10
	Mastery.award(hero, 1000)
	assert_eq(hero.max_armor, 70.0)
	assert_eq(hero.armor, 30.0)
	var enemy := TestHelpers.dummy(self, Vector3(0, 0, -2))
	Combat.deal(ActionContext.make(enemy, null), hero, 5)
	assert_eq(enemy.stun_time, 0.5)
	assert_gt(enemy.forced_time, 0.0)
	assert_eq(hero.hp, 100.0)


func test_gloves_and_helmet_open_targets() -> void:
	var hero := hero_with(&"gloves", 3)
	var enemy := TestHelpers.dummy(self, Vector3(0, 0, -3))
	hero.press(&"grab")
	assert_eq(enemy.open_time, 2.0)
	var helmet := ItemState.create(&"helmet")
	helmet.appearance = 3
	hero.set_items([helmet])
	var nearby := TestHelpers.dummy(self, Vector3(1, 0, -3))
	hero.notify_crit(ActionContext.make(hero, null), enemy)
	assert_eq(nearby.open_time, 1.8)


func test_amulet_wave_stuns() -> void:
	var hero := hero_with(&"amulet", 3)
	var target := TestHelpers.dummy(self, Vector3(0, 0, -2))
	hero.press(&"volley")
	await wait_physics_frames(12)
	assert_gt(target.stun_time, 0.0)
	assert_lt(target.hp, target.max_hp)


func test_reflected_projectile_credits_equipped_items() -> void:
	var hero := hero_with(&"shield", 2)
	var target := TestHelpers.dummy(self, Vector3(0, 0, -2), 1)
	target.set_meta(&"mastery_xp", 6)
	var projectile := Projectile.spawn(ActionContext.make(target, null), Vector3.ZERO, Vector3.BACK, 10, 10, &"arrow", Color.WHITE)
	projectile._reflect(hero)
	Combat.deal(projectile.ctx, target, projectile.damage)
	assert_eq(Mastery.xp[&"shield"], 6)
