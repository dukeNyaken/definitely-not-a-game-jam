class_name PalaceScene
extends RefCounted
## Голос из дворца между этапами: тронный зал Сигварда в багровом свете жаровен и зарева за окнами.
## После каждого дара брат говорит одну реплику и что-то делает: смотрит в окно на зарево, идёт по ковру,
## бросает в огонь детский деревянный меч, роняет письмо Сольвейг, смотрит на пустую руку без перстня,
## встаёт перед троном — и жаровни вспыхивают. Зал строится далеко от арены и убирается после сцены.

## Зал стоит за пределами арены: камера уезжает туда, пока экран тёмный.
const ORIGIN := Vector3(-150, 0, -150)
const EMBER := Color(1.0, 0.45, 0.18)
const CRIMSON := Color(0.9, 0.2, 0.12)


static func play(cs: Cutscene, game: Game, n: int) -> void:
	var text := Story.brother_line(n, RunState.snapshots)
	if text == "":
		return
	var moon := game.rig.camera.get_node_or_null("RingMoon") as Node3D
	cs.ui.black(1.0, 0.0)
	game.hud.fade(false, 0.01)
	cs.begin()
	if moon != null:
		moon.visible = false
	var hall := build_hall(cs, game)
	await _body(cs, game, hall, n, text)
	cs.ui.black(1.0, 0.0 if cs.skipped else 0.6)
	await cs.wait(0.6)
	_finalize(cs, game, moon)
	game.hud.fade(true, 0.01)
	cs.end()
	cs.ui.black(0.0, 0.0)


## Зал: пол, ковёр, окна в зареве, колонны, трон, стяги и две жаровни с живым огнём.
## В том же зале идёт TemptationScene.
static func build_hall(cs: Cutscene, game: Game) -> Node3D:
	var hall := SetPieces.throne_hall()
	cs.prop(hall)
	hall.global_position = ORIGIN
	hall.rotation.y = deg_to_rad(game.rig.yaw_degrees)
	var lights: Array[OmniLight3D] = []
	for br in hall.get_meta(&"braziers"):
		lights.append(SetPieces.brazier_fire(br))
	hall.set_meta(&"lights", lights)
	cs.light(hall.to_global(Vector3(0, 3.0, -3.4)), CRIMSON, 2.0, 10.0)
	cs.motes(hall.to_global(Vector3(0, 1.5, -0.5)), Vector3(5.0, 1.5, 3.0), EMBER, 34, 0.35)
	return hall


static func _body(cs: Cutscene, game: Game, hall: Node3D, n: int, text: String) -> void:
	var at := func(x: float, z: float) -> Vector3: return hall.to_global(Vector3(x, 0, z))
	var lights: Array = hall.get_meta(&"lights")
	var braziers: Array = hall.get_meta(&"braziers")
	var sig := cs.spawn(&"brother", at.call(0.0, 0.0), at.call(0.0, 5.0), &"palace_brother")
	var toward_cam: Vector3 = at.call(0.0, 6.0)
	cs.mood(&"palace", 0.0)
	cs.chapter(Story.interlude_header(), "", true, 1.6)
	match n:
		1:
			# У окна: смотрит на зарево над городом, на середине реплики оборачивается.
			sig.global_position = at.call(2.2, -3.0)
			sig.look_toward(at.call(2.2, -6.0))
			_open(cs, at.call(1.6, -2.0) + Vector3(0, 1.4, 0), 4.6, 3.4)
			cs.after(1.6, func(): sig.look_toward(toward_cam))
			await cs.say(&"brother", text)
		2:
			# Идёт по ковру от трона прямо на нас, руки за спиной.
			sig.global_position = at.call(0.0, -1.6)
			sig.look_toward(toward_cam)
			_open(cs, at.call(0.0, -0.4) + Vector3(0, 1.3, 0), 5.2, 3.8)
			cs.walk(sig, at.call(0.0, 1.0), 1.1)
			game.rig.cine_to(at.call(0.0, 0.8) + Vector3(0, 1.3, 0), 3.8, 4.5)
			await cs.say(&"brother", text)
		3:
			# У жаровни, в руке детский деревянный меч. Потом — в огонь.
			var br: Node3D = braziers[0]
			sig.global_position = br.global_position + hall.global_basis.x * 0.9 + hall.global_basis.z * 0.5
			sig.look_toward(br.global_position)
			var sword := NpcLooks.wooden_sword()
			sig.hold(sword, &"r_hand", 1.0)
			sig.set_pose(&"offer")
			_open(cs, (sig.global_position + br.global_position) * 0.5 + Vector3(0, 1.2, 0), 4.4, 3.4)
			await cs.say(&"brother", text)
			if not cs.skipped:
				var top := br.global_position + Vector3(0, 1.2, 0)
				var from := sword.global_position
				cs.prop(sword)
				_to_world(sword, game.world)
				await cs.fly(sword, from, top, 0.5, 0.4)
				sword.visible = false
				_blaze(cs, game, lights[0], top)
				sig.set_pose(&"")
				await cs.wait(1.0)
		4:
			# Читает письмо Сольвейг. Дочитав — роняет его.
			sig.global_position = at.call(-0.6, -0.2)
			sig.look_toward(toward_cam)
			var letter := SetPieces.letter()
			sig.hold(letter, &"r_hand", 1.2)
			sig.set_pose(&"offer")
			_open(cs, sig.global_position + Vector3(0, 1.35, 0), 4.0, 3.0)
			await cs.say(&"brother", text)
			sig.set_pose(&"")
			cs.drop(letter)
			await cs.wait(0.8)
		5:
			# Смотрит на свою пустую руку — на ней нет перстня.
			sig.global_position = at.call(0.4, 0.0)
			sig.look_toward(toward_cam)
			sig.set_pose(&"offer")
			var hand_light := cs.light(sig.hand_position() + Vector3(0, 0.3, 0), CRIMSON, 0.0, 2.5)
			CutsceneFx.light_to(hand_light, 2.0, 2.0)
			_open(cs, sig.global_position + Vector3(0, 1.3, 0), 4.2, 2.6)
			await cs.say(&"brother", text)
			sig.set_pose(&"")
		_:
			# Встаёт перед троном, раскидывает руки — и обе жаровни вспыхивают.
			sig.global_position = at.call(0.0, -1.0)
			sig.look_toward(toward_cam)
			_open(cs, at.call(0.0, -0.8) + Vector3(0, 1.6, 0), 5.6, 4.2)
			cs.after(1.2, func():
				sig.set_pose(&"arms_up")
				for i in braziers.size():
					_blaze(cs, game, lights[i], (braziers[i] as Node3D).global_position + Vector3(0, 1.2, 0))
				cs.flash(CRIMSON, 0.6, 0.3)
				cs.shake(0.25))
			await cs.say(&"brother", text)
			await cs.wait(0.6)


## Начало кадра: из темноты, с лёгким облётом и медленным наездом от zoom_from к zoom_to.
static func _open(cs: Cutscene, focus: Vector3, zoom_from: float, zoom_to: float) -> void:
	cs.cam(focus, zoom_from, 0.0)
	cs.orbit(-14.0, 0.0)
	cs.ui.black(0.0, 0.9)
	cs.cam(focus, zoom_to, 6.0)
	cs.orbit(4.0, 7.0)


## Пламя жаровни взвивается: вспышка света, искры, треск.
static func _blaze(cs: Cutscene, game: Game, l: OmniLight3D, top: Vector3) -> void:
	if cs.skipped:
		return
	CutsceneFx.sparks(game.world, top, EMBER, 30, 4.5)
	CutsceneFx.flare(game.world, top + Vector3(0, 0.6, 0), EMBER, 5.0, 8.0, 1.2)
	CutsceneFx.light_to(l, 4.5, 0.15)
	l.create_tween().set_ignore_time_scale(true).tween_property(l, "base", 2.2, 1.6).set_delay(0.3)
	Audio.play(&"zone_charge", -10.0)


static func _to_world(node: Node3D, world: Node3D) -> void:
	var xf := node.global_transform
	node.get_parent().remove_child(node)
	world.add_child(node)
	node.global_transform = xf


static func _finalize(cs: Cutscene, game: Game, moon: Node3D) -> void:
	var p := cs.actor(&"palace_brother")
	if p != null:
		p.queue_free()
	cs.cast.erase(&"palace_brother")
	cs.clear_props()
	if moon != null:
		moon.visible = true
	cs.mood(&"none", 0.0)
	game.rig.cine_release(0.0)
