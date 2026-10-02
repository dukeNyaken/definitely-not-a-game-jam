class_name PrologueScene
extends RefCounted
## Пролог перед первым этапом. Флешбэк в сепии: ярл смотрит, как сыновья бьются на деревянных мечах;
## годы спустя умирающий ярл отдаёт родовой перстень младшему, старший уходит. Затем правило мира,
## семь вещей Солдата, прощание Сольвейг и хлеб от Ильвы.

const KEYS: Array[StringName] = [&"young_hero", &"young_brother", &"father", &"prologue_beloved", &"prologue_iva"]


static func play(cs: Cutscene, game: Game) -> void:
	cs.ui.black(1.0, 0.0)
	cs.begin()
	Audio.play_music(&"music_calm", 2.0)
	game.hero.visible = false
	await _body(cs, game)
	_finalize(cs, game)
	cs.end()


static func _body(cs: Cutscene, game: Game) -> void:
	var P := Story.PROLOGUE
	var hero := game.hero
	var c := hero.global_position
	var axes := game.rig.ground_axes()
	var up: Vector3 = axes[0]
	var right: Vector3 = axes[1]
	await cs.wait(0.8)
	await cs.narrate(P["two_sons"])
	if cs.skipped:
		return
	await _flashback_spar(cs, game, c, up, right)
	if cs.skipped:
		return
	await _flashback_ring(cs, game, c, up, right)
	if cs.skipped:
		return
	cs.ui.black(1.0, 1.0)
	await cs.wait(1.1)
	_free_flashback(cs)
	cs.ui.tint(CutsceneUi.SEPIA, 0.0, 0.0)
	hero.visible = true
	await cs.narrate(P["tyrant"])
	await cs.narrate(P["rule"])
	if cs.skipped:
		return
	# Настоящее: Солдат и семь его вещей.
	cs.cam(c + Vector3(0, 1.0, 0), 4.6, 0.0)
	cs.ui.black(0.0, 1.6)
	cs.cam(c + Vector3(0, 1.0, 0), 3.7, 4.5)
	await cs.wait(0.8)
	cs.tag(hero, &"hero", 3.5)
	await cs.wait(0.6)
	for state in hero.items:
		if cs.skipped:
			return
		var ess := Db.item(state.def_id).essence
		Vfx.burst(hero, game.hero_model.socket_position(state.def_id), ess.color, 0.7, 0.45)
		Audio.play(StringName("essence_%s" % ess.id), -12.0)
		await cs.wait(0.38)
	if hero.has_item(&"gloves"):
		Vfx.burst(hero, game.hero_model.socket_position(&"gloves"), Color(1.0, 0.8, 0.35), 1.1, 0.6)
		Audio.play(&"absorb", -8.0)
	await cs.wait(0.8)
	# Сольвейг.
	var sol := cs.spawn(&"beloved", c - right * 6.0 - up * 1.5, c, &"prologue_beloved")
	cs.cam(c - right * 0.6 + Vector3(0, 1.0, 0), 4.8, 2.0)
	await cs.walk(sol, c - right * 1.3 - up * 0.3)
	cs.face(sol, c)
	cs.face(hero, sol.global_position)
	cs.tag(sol, &"beloved")
	await cs.say(&"beloved", P["beloved_1"])
	await cs.say(&"hero", P["hero_1"])
	await cs.say(&"beloved", P["beloved_2"])
	if cs.skipped:
		return
	# Сольвейг уходит в темноту; из-за спины выходит Ильва с фонарём.
	cs.walk(sol, c - right * 8.0 - up * 3.0)
	sol.fade(0.0, 3.2)
	var iva := cs.spawn(&"faithful", c + right * 4.5 + up * 3.0, c, &"prologue_iva")
	cs.cam(c + right * 0.5 + Vector3(0, 1.0, 0), 4.8, 1.6)
	await cs.walk(iva, c + right * 1.2 + up * 0.8)
	cs.face(iva, c)
	cs.face(hero, iva.global_position)
	cs.tag(iva, &"faithful")
	await cs.say(&"faithful", P["faithful_1"])
	await cs.say(&"beloved", P["beloved_3"])
	await cs.say(&"hero", P["hero_2"])
	cs.walk(iva, c + right * 7.0 + up * 4.0)
	iva.fade(0.0, 2.6)
	cs.cam(c + Vector3(0, 0.8, 0), 7.0, 2.5)
	cs.ui.black(0.6, 1.0)
	await cs.narrate(P["learn"])
	cs.ui.black(0.0, 0.8)
	Audio.play(&"elite_horn", -6.0)
	await cs.wait(0.9)


## Флешбэк, часть 1: двор крепости. Ярл смотрит, как сыновья бьются на деревянных мечах.
## Младший побеждает, бросает меч и подаёт брату руку; старший её отбивает.
static func _flashback_spar(cs: Cutscene, game: Game, c: Vector3, up: Vector3, right: Vector3) -> void:
	var P := Story.PROLOGUE
	var father := cs.spawn(&"father", c + up * 2.1, c, &"father")
	var yh := cs.spawn(&"hero", c - right * 1.0, c + right, &"young_hero")
	var ys := cs.spawn(&"brother", c + right * 1.0, c - right, &"young_brother", &"young")
	var yh_sword := NpcLooks.wooden_sword()
	yh.hold(yh_sword, &"r_hand", 1.0)
	ys.hold(NpcLooks.wooden_sword(), &"r_hand", 1.0)
	cs.cam(c + up * 0.7 + Vector3(0, 0.9, 0), 5.8, 0.0)
	cs.ui.tint(CutsceneUi.SEPIA, 0.85, 0.0)
	cs.ui.black(0.0, 1.4)
	await cs.wait(1.0)
	# Кто есть кто: таблички над головами.
	cs.tag(ys, &"brother", 5.5, "", P["young_brother_role"])
	cs.tag(yh, &"hero", 5.5, P["young_hero_name"], P["young_hero_role"])
	await cs.wait(1.0)
	cs.tag(father, &"father", 4.5)
	await cs.wait(0.8)
	var contact := (yh.global_position + ys.global_position) * 0.5 + Vector3(0, 1.1, 0)
	for k in 3:
		if cs.skipped:
			return
		ys.gesture(&"chop", 0.3)
		Audio.play(&"fist_swing", -8.0)
		await cs.wait(0.35)
		yh.gesture(&"slash", 0.25)
		Audio.play(&"block", -8.0)
		Vfx.burst(yh, contact, Color(1.0, 0.85, 0.6), 0.35, 0.15)
		await cs.wait(0.55)
	# Последний удар младшего — старший падает.
	yh.gesture(&"chop", 0.3)
	await cs.wait(0.2)
	ys.set_pose(&"sit")
	Audio.play(&"fist_hit", -4.0)
	Vfx.burst(ys, ys.global_position + Vector3(0, 0.3, 0), Color(0.75, 0.65, 0.5), 0.9, 0.35)
	cs.cam((yh.global_position + ys.global_position) * 0.5 + Vector3(0, 0.8, 0), 4.2, 1.0)
	await cs.wait(0.7)
	# Младший бросает меч и подаёт брату руку.
	cs.drop(yh_sword)
	await cs.wait(0.4)
	yh.set_pose(&"offer")
	await cs.wait(1.1)
	# Старший отбивает протянутую руку и встаёт сам.
	ys.set_pose(&"")
	ys.gesture(&"punch", 0.2)
	Audio.play(&"fist_hit", -8.0)
	await cs.wait(0.3)
	yh.set_pose(&"")
	cs.cam(father.global_position + Vector3(0, 1.2, 0), 4.4, 1.0)
	await cs.say(&"father", P["father_spar"])


## Флешбэк, часть 2: годы спустя ярл слёг и отдаёт родовой перстень младшему. Старший уходит.
## Ярл умирает. Перстень — крупно и со светом, чтобы было видно, что именно передают.
static func _flashback_ring(cs: Cutscene, game: Game, c: Vector3, up: Vector3, right: Vector3) -> void:
	var P := Story.PROLOGUE
	var father := cs.actor(&"father")
	var yh := cs.actor(&"young_hero")
	var ys := cs.actor(&"young_brother")
	cs.ui.black(0.92, 0.7)
	await cs.wait(0.7)
	# Пока темно: сыновья стоят перед отцом, мечей больше нет.
	cs.clear_props()
	var ys_sword: Node = (ys.model.sockets[&"r_hand"] as Node3D).get_node_or_null("WoodenSword")
	if ys_sword != null:
		ys_sword.queue_free()
	father.global_position = c + up * 1.5
	yh.global_position = c - right * 0.8 - up * 0.2
	ys.global_position = c + right * 0.8 - up * 0.2
	cs.face(father, c - up * 0.2)
	cs.face(yh, father.global_position)
	cs.face(ys, father.global_position)
	var ring := NpcLooks.father_ring(true)
	father.hold(ring, &"r_hand", 2.4)
	await cs.narrate(P["ring_intro"])
	if cs.skipped:
		return
	# Крупно: перстень в протянутой руке ярла.
	father.set_pose(&"frail_offer")
	cs.cam(father.global_position + Vector3(0, 1.3, 0) - up * 0.4, 2.6, 0.0)
	cs.ui.black(0.0, 0.9)
	cs.cam(father.global_position + Vector3(0, 1.2, 0) - up * 0.4, 2.2, 3.0)
	await cs.wait(0.9)
	Vfx.burst(father, ring.global_position, Color(1.0, 0.82, 0.4), 0.6, 0.4)
	Audio.play(&"absorb", -10.0)
	await cs.say(&"father", P["father_ring"])
	# Ярл поворачивается к младшему — перстень переходит из руки в руку.
	cs.cam((father.global_position + yh.global_position) * 0.5 + Vector3(0, 1.0, 0), 3.8, 1.0)
	cs.face(father, yh.global_position)
	await cs.wait(0.9)
	var from := ring.global_position
	var xf := ring.global_transform
	ring.get_parent().remove_child(ring)
	game.world.add_child(ring)
	ring.global_transform = xf
	cs.props.append(ring)
	father.set_pose(&"frail")
	Audio.play(&"item_fly", -8.0)
	await cs.fly(ring, from, yh.hand_position(), 1.1, 0.5)
	yh.hold(ring, &"r_hand", 2.2)
	yh.set_pose(&"hold")
	Vfx.burst(yh, yh.hand_position(), Color(1.0, 0.82, 0.4), 1.1, 0.5)
	Audio.play(&"absorb", -4.0)
	await cs.wait(1.2)
	# Старший видит, кому достался перстень.
	cs.face(ys, yh.global_position)
	cs.cam(ys.global_position + Vector3(0, 1.1, 0), 3.6, 1.0)
	await cs.wait(0.6)
	await cs.say(&"brother", P["brother_envy"])
	cs.walk(ys, ys.global_position + right * 6.0 + up * 1.5)
	ys.fade(0.0, 2.4)
	await cs.wait(1.4)
	# Ярл угасает.
	yh.set_pose(&"")
	cs.face(yh, father.global_position)
	cs.cam(father.global_position + Vector3(0, 0.9, 0), 4.0, 1.2)
	father.set_pose(&"kneel")
	Audio.play(&"defeat_sting", -14.0)
	await cs.wait(1.2)
	father.set_pose(&"slump")
	father.fade(0.0, 2.6)
	cs.ui.black(0.6, 1.6)
	await cs.wait(1.0)
	await cs.narrate(P["father_death"])


static func _free_flashback(cs: Cutscene) -> void:
	cs.clear_props()
	for key in [&"young_hero", &"young_brother", &"father"]:
		var p := cs.actor(key)
		if p != null:
			p.queue_free()
		cs.cast.erase(key)


static func _finalize(cs: Cutscene, game: Game) -> void:
	cs.clear_props()
	for key in KEYS:
		var p := cs.actor(key)
		if p != null:
			p.queue_free()
		cs.cast.erase(key)
	game.hero.visible = true
	game.hero.global_position = Vector3(0, 0, 3)
	cs.ui.tint(CutsceneUi.SEPIA, 0.0, 0.0)
	cs.ui.black(0.0, 0.5)
