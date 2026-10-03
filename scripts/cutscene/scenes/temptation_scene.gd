class_name TemptationScene
extends RefCounted
## Тронный зал между этапами — после третьего дара (Story.TEMPTATION_AFTER_GIFT), перед голосом из дворца.
## Сигвард позвал невесту брата и склоняет её оставить Солдата: тот раздаст всё, а во дворце есть стены,
## хлеб и огонь. Он говорит вслух то, чего она боится, — и ей нечего ответить. Кошель с золотом летит к её
## ногам. Сольвейг отказывает и уходит, но оборачивается дважды: на золото и, у края ковра, на трон.
## Зал тот же, что в PalaceScene: он строится далеко от арены и убирается после сцены.

const KEYS: Array[StringName] = [&"temptation_brother", &"temptation_beloved"]
const HEAD := Vector3(0, 1.15, 0)
const GOLD := Color(1.0, 0.8, 0.35)


static func play(cs: Cutscene, game: Game) -> void:
	var moon := game.rig.camera.get_node_or_null("RingMoon") as Node3D
	cs.ui.black(1.0, 0.0)
	game.hud.fade(false, 0.01)
	cs.begin()
	if moon != null:
		moon.visible = false
	var hall := PalaceScene.build_hall(cs, game)
	await _body(cs, game, hall)
	cs.ui.black(1.0, 0.0 if cs.skipped else 0.8)
	await cs.wait(0.8)
	_finalize(cs, game, moon)
	game.hud.fade(true, 0.01)
	cs.end()
	cs.ui.black(0.0, 0.0)


static func _body(cs: Cutscene, game: Game, hall: Node3D) -> void:
	var T := Story.TEMPTATION
	var world := game.world
	var at := func(x: float, z: float) -> Vector3: return hall.to_global(Vector3(x, 0, z))
	var lights: Array = hall.get_meta(&"lights")
	var exit: Vector3 = at.call(0.4, 8.6)
	var sig := cs.spawn(&"brother", at.call(0.0, -1.0), at.call(0.0, 6.0), &"temptation_brother")
	var sol := cs.spawn(&"beloved", at.call(0.5, 7.2), sig.global_position, &"temptation_beloved")
	sol.fade(0.0, 0.0)
	sol.fade(1.0, 1.2)
	cs.mood(&"palace", 0.0)
	# Общий план: она идёт по ковру к трону между жаровнями.
	cs.cam(at.call(0.0, 1.4) + Vector3(0, 1.2, 0), 10.0, 0.0)
	cs.orbit(-12.0, 0.0)
	cs.ui.black(0.0, 1.2)
	cs.cam(at.call(0.0, 0.6) + Vector3(0, 1.2, 0), 7.2, 6.0)
	cs.orbit(4.0, 7.0)
	var ch := Story.chapter("temptation")
	cs.chapter(ch[0], ch[1], true, 2.2)
	var sol_spot: Vector3 = at.call(0.9, 1.7)
	await cs.walk(sol, sol_spot, 1.7)
	sol.look_toward(sig.global_position)
	sol.set_pose(&"wring")
	cs.tag(sig, &"brother", 4.0)
	cs.tag(sol, &"beloved", 4.0)
	# Сигвард спускается к ней: они стоят лицом к лицу поперёк ковра.
	cs.walk_then_face(sig, at.call(-0.9, 1.4), sol_spot, 1.3)
	await cs.say(&"brother", T["summon"])
	cs.cam(sol_spot + HEAD, 3.6, 1.0)
	cs.orbit(-6.0, 4.0)
	await cs.say(&"beloved", T["speak"])
	cs.cam((sig.global_position + sol_spot) * 0.5 + HEAD, 4.6, 1.2)
	cs.orbit(6.0, 8.0)
	await cs.say(&"brother", T["gives_away"])
	await cs.say(&"beloved", T["needier"])
	if cs.skipped:
		return
	# Он обходит её и встаёт за плечом. Она отворачивается — и ей нечего ответить.
	cs.walk_then_face(sig, at.call(-0.5, 0.6), sol_spot, 1.2)
	sol.look_toward(at.call(1.2, 6.0))
	sol.set_pose(&"downcast")
	cs.cam(sol_spot + Vector3(0, 1.2, 0), 3.2, 1.4)
	cs.orbit(0.0, 1.4)
	await cs.say(&"brother", T["and_you"])
	cs.cam(sol_spot + Vector3(0, 1.25, 0), 2.6, 2.4)
	cs.mood(&"hurt", 1.6)
	await cs.wait(2.0)
	cs.mood(&"palace", 1.2)
	if cs.skipped:
		return
	# Кошель с золотом — к её ногам.
	var purse := cs.prop(SetPieces.purse())
	var purse_at: Vector3 = at.call(1.1, 2.6) + Vector3(0, 0.1, 0)
	sig.hold(purse, &"r_hand", 1.5)
	sig.set_pose(&"offer")
	cs.cam((sig.global_position + sol_spot) * 0.5 + Vector3(0, 1.0, 0), 4.4, 1.0)
	await cs.say(&"brother", T["leave_him"])
	var from := purse.global_position
	_to_world(purse, world)
	Audio.play(&"item_fly", -8.0)
	await cs.fly(purse, from, purse_at, 0.55, 0.5)
	purse.rotation = Vector3(1.2, 0.4, 0.0)
	CutsceneFx.sparks(world, purse_at + Vector3(0, 0.1, 0), GOLD, 12, 2.2)
	CutsceneFx.flare(world, purse_at + Vector3(0, 0.25, 0), GOLD, 1.6, 2.5, 0.9)
	Audio.play(&"block", -10.0)
	sig.set_pose(&"")
	await cs.wait(0.7)
	# Отказ.
	sol.set_pose(&"")
	sol.look_toward(sig.global_position)
	cs.cam(sol_spot + HEAD, 3.4, 0.8)
	await cs.say(&"beloved", T["no"])
	cs.cam(sig.global_position + Vector3(0, 1.3, 0), 3.6, 0.8)
	await cs.say(&"brother", T["love_winter"])
	if cs.skipped:
		return
	# Она уходит. У кошеля замедляет шаг и смотрит на золото — первый раз.
	cs.cam(purse_at + Vector3(0, 0.8, 0), 4.2, 1.6)
	await cs.walk(sol, at.call(0.6, 2.8), 1.2)
	sol.look_toward(purse_at)
	sol.set_pose(&"downcast")
	cs.cam(purse_at + Vector3(0, 0.45, 0), 2.8, 2.0)
	await cs.wait(0.8)
	CutsceneFx.flare(world, purse_at + Vector3(0, 0.25, 0), GOLD, 1.4, 2.2, 1.4)
	await cs.wait(1.4)
	if cs.skipped:
		return
	# Идёт дальше — и у края ковра оборачивается к трону. Второй раз.
	sol.set_pose(&"wring")
	cs.cam(at.call(0.6, 3.6) + Vector3(0, 1.1, 0), 5.6, 2.0)
	await cs.walk(sol, at.call(0.5, 4.9), 1.5)
	sol.look_toward(sig.global_position)
	await cs.wait(0.6)
	cs.cam(sol.global_position + HEAD, 3.6, 1.2)
	await cs.say(&"beloved", T["dont_call"])
	cs.walk(sol, exit, 1.7)
	sol.fade(0.0, 2.2)
	# Сигвард один над кошелем. Жаровни разгораются.
	cs.cam(at.call(0.3, 1.6) + Vector3(0, 1.3, 0), 5.0, 1.6)
	await cs.walk(sig, at.call(0.5, 1.9), 1.2)
	sig.look_toward(exit)
	cs.cam(sig.global_position + Vector3(0, 1.35, 0), 3.4, 4.0)
	cs.orbit(-8.0, 5.0)
	for l in lights:
		CutsceneFx.light_to(l, 3.4, 1.5)
	await cs.say(&"brother", T["looked_back"])
	await cs.wait(0.5)


static func _to_world(node: Node3D, world: Node3D) -> void:
	var xf := node.global_transform
	node.get_parent().remove_child(node)
	world.add_child(node)
	node.global_transform = xf


static func _finalize(cs: Cutscene, game: Game, moon: Node3D) -> void:
	for key in KEYS:
		var p := cs.actor(key)
		if p != null:
			p.queue_free()
		cs.cast.erase(key)
	cs.clear_props()
	if moon != null:
		moon.visible = true
	cs.mood(&"none", 0.0)
	game.rig.cine_release(0.0)
