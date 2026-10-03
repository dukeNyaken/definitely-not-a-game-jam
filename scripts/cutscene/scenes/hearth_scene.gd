class_name HearthScene
extends RefCounted
## Дом Сольвейг между этапами — после второго дара (Story.HEARTH_AFTER_GIFT). Ночь, очаг, мать за прялкой;
## Сольвейг стоит у окна. Она любит Солдата — и боится его щедрости: он раздаст всё, и они останутся
## в нищете, всеми брошенные. Пока она говорит о страхе, тёплый кадр холодеет, огонь в очаге садится;
## под конец она возвращается к окну, и свеча на столе гаснет. Если оберег уже отдан ей — он у неё
## в руках. Дом строится далеко от арены и убирается после сцены.

## Дом стоит за пределами арены, в стороне от тронного зала: камера уезжает туда, пока экран тёмный.
const ORIGIN := Vector3(150, 0, -150)
const KEYS: Array[StringName] = [&"hearth_mother", &"hearth_beloved"]
const HEAD := Vector3(0, 1.15, 0)
const FIRE := Color(1.0, 0.6, 0.3)
const CANDLE := Color(1.0, 0.78, 0.5)
const NIGHT := Color(0.45, 0.6, 1.0)


static func play(cs: Cutscene, game: Game) -> void:
	var moon := game.rig.camera.get_node_or_null("RingMoon") as Node3D
	cs.ui.black(1.0, 0.0)
	game.hud.fade(false, 0.01)
	cs.begin()
	if moon != null:
		moon.visible = false
	game.arena.set_indoor(true)
	var room := _build(cs, game)
	await _body(cs, game, room)
	cs.ui.black(1.0, 0.0 if cs.skipped else 0.8)
	await cs.wait(0.8)
	_finalize(cs, game, moon)
	game.hud.fade(true, 0.01)
	cs.end()
	cs.ui.black(0.0, 0.0)


## Дом: огонь в очаге, свеча на столе, холодный свет из окна, искры над огнём.
static func _build(cs: Cutscene, game: Game) -> Node3D:
	var room := SetPieces.cottage()
	cs.prop(room)
	room.global_position = ORIGIN
	room.rotation.y = deg_to_rad(game.rig.yaw_degrees)
	var fireplace: Node3D = room.get_meta(&"hearth")
	var fire_at := fireplace.to_global(SetPieces.hearth_fire_point())
	cs.prop(CutsceneFx.fire(game.world, fire_at, 0.5))
	# Свет очага стоит перед топкой: внутри камня он осветил бы только сам очаг.
	room.set_meta(&"fire_light", cs.light(fire_at + room.global_basis.z * 1.0 + Vector3(0, 0.8, 0), FIRE, 3.0, 8.5, 0.16))
	var desk: Node3D = room.get_meta(&"table")
	room.set_meta(&"candle_light", cs.light(desk.to_global(SetPieces.table_wick_point()) + Vector3(0, 0.2, 0), CANDLE, 1.4, 4.0, 0.1))
	var window: Node3D = room.get_meta(&"window")
	cs.light(window.to_global(Vector3(0.4, 2.0, 1.1)), NIGHT, 1.6, 5.5)
	# Отсвет от потолка и мягкий свет со стороны зрителя: все огни дома стоят у дальней стены и ниже
	# лиц — без них головы остались бы тёмными, а лицо, обращённое к камере, ушло бы в тень.
	cs.light(room.to_global(Vector3(0.6, 3.3, -0.8)), Color(1.0, 0.8, 0.6), 1.1, 9.0)
	cs.light(room.to_global(Vector3(1.2, 2.0, 2.2)), Color(1.0, 0.86, 0.72), 1.0, 7.0)
	cs.motes(room.to_global(Vector3(-2.0, 1.5, -1.8)), Vector3(1.6, 1.0, 1.2), Color(1.0, 0.6, 0.3, 0.8), 18, 0.2)
	return room


static func _body(cs: Cutscene, game: Game, room: Node3D) -> void:
	var H := Story.HEARTH
	var world := game.world
	var at := func(x: float, z: float) -> Vector3: return room.to_global(Vector3(x, 0, z))
	var fire: OmniLight3D = room.get_meta(&"fire_light")
	var candle: OmniLight3D = room.get_meta(&"candle_light")
	var wheel: Node3D = room.get_meta(&"wheel")
	var chest: Node3D = room.get_meta(&"chest")
	var window_at: Vector3 = at.call(3.0, -3.2)
	var window_spot: Vector3 = at.call(3.0, -2.3)
	var table_spot: Vector3 = at.call(1.5, -1.5)
	var centre: Vector3 = at.call(0.6, -1.6) + Vector3(0, 1.1, 0)
	# Мать за прялкой у огня; Сольвейг — у окна, спиной к дому.
	var mom := cs.spawn(&"mother", at.call(-0.2, -1.8), at.call(-0.9, -2.7), &"hearth_mother")
	var sol := cs.spawn(&"beloved", window_spot, window_at, &"hearth_beloved")
	mom.set_pose(&"hold")
	sol.set_pose(&"wring")
	var spin := wheel.create_tween().set_loops().set_ignore_time_scale(true)
	spin.tween_property(wheel, "rotation:z", -TAU, 2.4).as_relative()
	cs.mood(&"hearth", 0.0)
	# Общий план из темноты: огонь, прялка, окно в ночь.
	cs.cam(centre, 7.4, 0.0)
	cs.orbit(-10.0, 0.0)
	cs.ui.black(0.0, 1.6)
	cs.cam(centre, 6.2, 7.0)
	cs.orbit(3.0, 8.0)
	var ch := Story.chapter("hearth")
	cs.chapter(ch[0], ch[1], true, 2.2)
	await cs.wait(2.4)
	# Мать оставляет прялку и оборачивается к дочери.
	spin.kill()
	mom.set_pose(&"")
	mom.look_toward(sol.global_position)
	cs.tag(mom, &"mother", 4.0)
	cs.cam(mom.global_position + HEAD, 4.2, 1.4)
	await cs.say(&"mother", H["cant_sleep"])
	sol.look_toward(mom.global_position)
	cs.tag(sol, &"beloved", 3.5)
	cs.cam(sol.global_position + HEAD, 3.6, 1.2)
	cs.orbit(-8.0, 5.0)
	await cs.say(&"beloved", H["love"])
	cs.cam((mom.global_position + sol.global_position) * 0.5 + HEAD, 5.4, 1.2)
	cs.orbit(0.0, 1.2)
	await cs.say(&"mother", H["then_why"])
	if cs.skipped:
		return
	# Сольвейг идёт от окна к столу, к свече.
	cs.cam(table_spot + HEAD, 4.4, 2.0)
	sol.set_pose(&"")
	await cs.walk(sol, table_spot, 1.6)
	sol.look_toward(mom.global_position)
	sol.set_pose(&"wring")
	await cs.say(&"beloved", H["too_good"])
	await cs.say(&"beloved", Story.hearth_given_line(RunState.snapshots))
	if cs.skipped:
		return
	if Story.was_given(RunState.snapshots, &"amulet"):
		# Оберег Солдата — у неё в руках, и светится он по-прежнему.
		var amulet := cs.prop(ItemVisuals.build_display(Cutscene.item_state(&"amulet")))
		var glow := Db.item(&"amulet").essence.color
		sol.hold(amulet, &"r_hand", 0.9)
		sol.set_pose(&"hold")
		cs.cam(sol.hand_position() + Vector3(0, 0.15, 0), 2.4, 1.2)
		await cs.wait(0.7)
		CutsceneFx.flare(world, sol.hand_position(), glow, 1.6, 2.5, 1.4)
		Vfx.burst(sol, sol.hand_position(), glow, 0.5, 0.4)
		Audio.play(StringName("essence_%s" % Db.item(&"amulet").essence.id), -12.0)
		await cs.say(&"beloved", H["amulet"])
		sol.set_pose(&"wring")
	# «Пустит по ветру всё» — она оборачивается к сундуку с приданым.
	sol.look_toward(chest.global_position)
	cs.cam((sol.global_position + chest.global_position) * 0.5 + Vector3(0, 0.9, 0), 5.2, 1.4)
	await cs.say(&"beloved", H["squander"])
	if cs.skipped:
		return
	# Мать подходит к ней.
	var mom_spot: Vector3 = at.call(0.2, -1.1)
	cs.cam((mom_spot + table_spot) * 0.5 + HEAD, 4.4, 1.6)
	await cs.walk(mom, mom_spot, 1.5)
	mom.look_toward(sol.global_position)
	sol.look_toward(mom.global_position)
	await cs.say(&"mother", H["kindness"])
	# Страх вслух: она отворачивается от матери, кадр холодеет, огонь садится.
	sol.look_toward(at.call(1.9, 4.0))
	cs.mood(&"hurt", 3.0)
	CutsceneFx.light_to(fire, 1.7, 3.0)
	cs.cam(sol.global_position + HEAD, 3.4, 1.4)
	cs.orbit(8.0, 9.0)
	await cs.say(&"beloved", H["not_feed"])
	cs.cam(sol.global_position + Vector3(0, 1.25, 0), 2.7, 6.0)
	await cs.say(&"beloved", H["not_poverty"])
	sol.set_pose(&"downcast")
	await cs.say(&"beloved", H["alone"])
	if cs.skipped:
		return
	# Мать протягивает к ней руку.
	cs.orbit(0.0, 1.4)
	cs.cam((mom.global_position + sol.global_position) * 0.5 + HEAD, 4.0, 1.2)
	mom.set_pose(&"offer")
	await cs.say(&"mother", H["tell_him"])
	mom.set_pose(&"")
	sol.look_toward(mom.global_position)
	sol.set_pose(&"wring")
	await cs.say(&"beloved", H["wont_hear"])
	# Она возвращается к окну. Свеча на столе гаснет.
	cs.cam(centre, 6.8, 4.0)
	cs.walk_then_face(sol, window_spot, window_at, 1.4)
	await cs.wait(1.8)
	var flame := (room.get_meta(&"table") as Node3D).get_node_or_null("Flame") as Node3D
	if flame != null:
		flame.visible = false
	CutsceneFx.light_to(candle, 0.0, 0.5)
	await cs.wait(1.6)


static func _finalize(cs: Cutscene, game: Game, moon: Node3D) -> void:
	for key in KEYS:
		var p := cs.actor(key)
		if p != null:
			p.queue_free()
		cs.cast.erase(key)
	cs.clear_props()
	game.arena.set_indoor(false)
	if moon != null:
		moon.visible = true
	cs.mood(&"none", 0.0)
	game.rig.cine_release(0.0)
