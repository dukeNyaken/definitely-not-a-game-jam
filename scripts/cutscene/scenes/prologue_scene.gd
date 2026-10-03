class_name PrologueScene
extends RefCounted
## Пролог перед первым этапом. Флешбэк на старой плёнке: двор крепости, ярл смотрит, как сыновья
## бьются на деревянных мечах; младший побеждает и подаёт руку — старший её отбивает. Годы спустя
## умирающий ярл при свече отдаёт родовой перстень младшему, старший уходит; свеча гаснет.
## Затем семь вещей Солдата, прощание Сольвейг и хлеб от Ильвы.
## Правило мира («отданное не ослабляет») звучит позже — у первого алтаря (RuleScene).

const KEYS: Array[StringName] = [&"young_hero", &"young_brother", &"father", &"prologue_beloved", &"prologue_iva"]
const RING_GLOW := Color(1.0, 0.8, 0.4)
const WOOD_CHIPS := Color(0.95, 0.8, 0.55)


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
	await cs.wait(0.6)
	var ch := Story.chapter("prologue")
	await cs.chapter(ch[0], ch[1])
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
	cs.mood(&"scene", 0.0)
	hero.visible = true
	await cs.narrate(P["tyrant"])
	if cs.skipped:
		return
	await _present(cs, game, c, up, right)


## Флешбэк, часть 1: двор крепости. Ярл смотрит, как сыновья бьются на деревянных мечах.
## Младший побеждает, бросает меч и подаёт брату руку; старший её отбивает.
static func _flashback_spar(cs: Cutscene, game: Game, c: Vector3, up: Vector3, right: Vector3) -> void:
	var P := Story.PROLOGUE
	var world := game.world
	var father := cs.spawn(&"father", c + up * 2.1, c, &"father")
	var yh := cs.spawn(&"hero", c - right * 1.0, c + right, &"young_hero")
	var ys := cs.spawn(&"brother", c + right * 1.0, c - right, &"young_brother", &"young")
	var yh_sword := NpcLooks.wooden_sword()
	yh.hold(yh_sword, &"r_hand", 1.0)
	ys.hold(NpcLooks.wooden_sword(), &"r_hand", 1.0)
	# Двор: стойка с мечами за ярлом, чучело сбоку, пыль в солнечном воздухе.
	var rack := cs.prop(SetPieces.weapon_rack())
	rack.global_position = c + up * 3.4 - right * 1.6
	rack.look_at(rack.global_position + up, Vector3.UP)
	var post := cs.prop(SetPieces.training_post())
	post.global_position = c + up * 2.6 + right * 2.8
	cs.motes(c + Vector3(0, 1.4, 0), Vector3(4.0, 1.4, 4.0), Color(1.0, 0.9, 0.7, 0.8), 50, 0.08)
	# Полуденное солнце над двором: воспоминание светлее настоящего.
	cs.light(c + Vector3(0, 6.0, 0) + up * 1.0, Color(1.0, 0.92, 0.75), 3.2, 16.0)
	cs.cam(c + up * 0.7 + Vector3(0, 0.9, 0), 6.4, 0.0)
	cs.mood(&"flashback", 0.0)
	cs.ui.black(0.0, 1.4)
	cs.cam(c + up * 0.5 + Vector3(0, 0.9, 0), 5.6, 3.5)
	await cs.wait(1.0)
	# Кто есть кто: таблички над головами.
	cs.tag(ys, &"brother", 5.5, "", P["young_brother_role"])
	cs.tag(yh, &"hero", 5.5, P["young_hero_name"], P["young_hero_role"])
	await cs.wait(1.0)
	cs.tag(father, &"father", 4.5)
	await cs.wait(0.8)
	# Обмен ударами: старший дважды наседает, младший отбивает — и сам переходит в атаку.
	var exchanges := [[ys, yh, &"chop"], [ys, yh, &"slash"], [yh, ys, &"slash"]]
	for e in exchanges:
		if cs.skipped:
			return
		var attacker: Puppet = e[0]
		var defender: Puppet = e[1]
		cs.walk(attacker, attacker.global_position + Combat.flat_dir(defender.global_position - attacker.global_position) * 0.3, 4.5)
		attacker.gesture(e[2], 0.3)
		Audio.play(&"fist_swing", -8.0)
		await cs.wait(0.3)
		defender.gesture(&"slash_back", 0.25)
		var contact := (yh.global_position + ys.global_position) * 0.5 + Vector3(0, 1.15, 0)
		Audio.play(&"block", -6.0)
		CutsceneFx.sparks(world, contact, WOOD_CHIPS, 14, 3.0)
		cs.shake(0.12)
		await cs.wait(0.2)
		cs.face(yh, ys.global_position)
		cs.face(ys, yh.global_position)
		await cs.wait(0.35)
	# Последний удар младшего — замедленно; старший падает в пыль.
	cs.cam((yh.global_position + ys.global_position) * 0.5 + Vector3(0, 1.0, 0), 4.0, 0.6)
	yh.gesture(&"chop", 0.45)
	cs.slowmo(0.3, 0.9)
	await cs.wait(0.35)
	cs.flash(Color(1.0, 0.92, 0.75), 0.35, 0.5)
	ys.set_pose(&"sit")
	Audio.play(&"fist_hit", -4.0)
	CutsceneFx.dust(world, ys.global_position, 1.0)
	CutsceneFx.sparks(world, ys.global_position + Vector3(0, 0.9, 0), WOOD_CHIPS, 18, 3.5)
	cs.shake(0.3)
	await cs.wait(0.9)
	# Младший бросает меч и подаёт брату руку.
	cs.drop(yh_sword)
	await cs.wait(0.4)
	yh.set_pose(&"offer")
	cs.cam((yh.global_position + ys.global_position) * 0.5 + Vector3(0, 0.8, 0), 3.4, 1.4)
	await cs.say(&"hero", P["spar_rise"])
	# Старший отбивает протянутую руку и встаёт сам.
	ys.set_pose(&"")
	ys.gesture(&"punch", 0.2)
	Audio.play(&"fist_hit", -8.0)
	cs.shake(0.1)
	await cs.wait(0.25)
	yh.set_pose(&"")
	await cs.say(&"brother", P["spar_refuse"])
	cs.walk(ys, ys.global_position + right * 0.9 + up * 0.3)
	cs.cam(father.global_position + Vector3(0, 1.2, 0), 4.0, 1.2)
	await cs.say(&"father", P["father_spar"])


## Флешбэк, часть 2: годы спустя ярл слёг и при свече отдаёт родовой перстень младшему.
## Старший уходит в темноту. Ярл угасает вместе со свечой.
static func _flashback_ring(cs: Cutscene, game: Game, c: Vector3, up: Vector3, right: Vector3) -> void:
	var P := Story.PROLOGUE
	var world := game.world
	var father := cs.actor(&"father")
	var yh := cs.actor(&"young_hero")
	var ys := cs.actor(&"young_brother")
	cs.ui.black(1.0, 0.7)
	await cs.wait(0.7)
	# Пока темно: покои ярла. Двор и мечи убраны, у ложа — свеча; сыновья стоят перед отцом.
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
	var stand := cs.prop(SetPieces.candle_stand())
	stand.global_position = father.global_position + right * 0.9 + up * 0.4
	var flame_at := stand.global_position + Vector3(0, SetPieces.flame_height() + 0.1, 0)
	var candle := cs.light(flame_at, Color(1.0, 0.7, 0.4), 2.4, 6.0, 0.18)
	cs.prop(CutsceneFx.fire(world, flame_at - Vector3(0, 0.05, 0), 0.12))
	cs.motes(father.global_position + Vector3(0, 1.4, 0), Vector3(2.0, 1.0, 2.0), Color(1.0, 0.85, 0.6, 0.7), 22, 0.05)
	var ring := NpcLooks.father_ring(true)
	father.hold(ring, &"r_hand", 2.4)
	await cs.narrate(P["ring_intro"])
	if cs.skipped:
		return
	# Крупно: перстень в протянутой руке ярла.
	father.set_pose(&"frail_offer")
	cs.cam(father.global_position + Vector3(0, 1.3, 0) - up * 0.4, 2.8, 0.0)
	cs.orbit(-12.0, 0.0)
	cs.ui.black(0.0, 1.1)
	cs.cam(father.global_position + Vector3(0, 1.2, 0) - up * 0.4, 2.2, 3.5)
	cs.orbit(0.0, 4.0)
	await cs.wait(1.0)
	CutsceneFx.flare(world, ring.global_position, RING_GLOW, 2.0, 2.5, 1.2)
	Vfx.burst(father, ring.global_position, RING_GLOW, 0.6, 0.4)
	Audio.play(&"absorb", -10.0)
	await cs.say(&"father", P["father_ring"])
	# Ярл поворачивается к младшему — перстень переходит из руки в руку.
	cs.cam((father.global_position + yh.global_position) * 0.5 + Vector3(0, 1.0, 0), 3.6, 1.0)
	cs.face(father, yh.global_position)
	await cs.wait(0.6)
	await cs.say(&"father", P["father_ring_2"])
	var from := ring.global_position
	var xf := ring.global_transform
	ring.get_parent().remove_child(ring)
	world.add_child(ring)
	ring.global_transform = xf
	cs.props.append(ring)
	father.set_pose(&"frail")
	Audio.play(&"item_fly", -8.0)
	await cs.fly(ring, from, yh.hand_position(), 1.2, 0.5, RING_GLOW)
	yh.hold(ring, &"r_hand", 2.2)
	yh.set_pose(&"hold")
	Vfx.burst(yh, yh.hand_position(), RING_GLOW, 1.1, 0.5)
	CutsceneFx.pillar(world, yh.global_position, RING_GLOW, 4.0, 0.5, 1.4)
	cs.flash(RING_GLOW, 0.5, 0.35)
	Audio.play(&"absorb", -4.0)
	await cs.wait(1.2)
	# Старший видит, кому достался перстень. Крупно, медленный наезд.
	cs.face(ys, yh.global_position)
	cs.cam(ys.global_position + Vector3(0, 1.3, 0), 3.0, 0.8)
	cs.cam(ys.global_position + Vector3(0, 1.35, 0), 2.4, 3.5)
	await cs.wait(0.6)
	await cs.say(&"brother", P["brother_envy"])
	cs.walk(ys, ys.global_position + right * 6.0 + up * 1.5)
	ys.fade(0.0, 2.4)
	cs.cam((father.global_position + yh.global_position) * 0.5 + Vector3(0, 1.0, 0), 4.2, 1.6)
	await cs.wait(1.4)
	# Ярл угасает — и свеча гаснет вместе с ним.
	yh.set_pose(&"")
	cs.face(yh, father.global_position)
	cs.cam(father.global_position + Vector3(0, 0.9, 0), 3.8, 1.2)
	father.set_pose(&"kneel")
	Audio.play(&"defeat_sting", -14.0)
	await cs.wait(1.2)
	father.set_pose(&"slump")
	father.fade(0.0, 2.6)
	CutsceneFx.light_to(candle, 0.0, 2.4)
	await cs.wait(1.6)
	for n in cs.props:
		if is_instance_valid(n) and n is CPUParticles3D:
			(n as CPUParticles3D).emitting = false
	cs.ui.black(0.7, 1.2)
	await cs.wait(1.0)
	await cs.narrate(P["father_death"])


## Настоящее: Солдат и семь его вещей; Сольвейг провожает, Ильва приносит хлеб и остаётся рядом.
static func _present(cs: Cutscene, game: Game, c: Vector3, up: Vector3, right: Vector3) -> void:
	var P := Story.PROLOGUE
	var hero := game.hero
	var world := game.world
	cs.cam(c + Vector3(0, 1.0, 0), 4.8, 0.0)
	cs.orbit(18.0, 0.0)
	cs.ui.black(0.0, 1.6)
	cs.cam(c + Vector3(0, 1.0, 0), 3.6, 5.5)
	cs.orbit(0.0, 6.0)
	await cs.wait(0.8)
	cs.tag(hero, &"hero", 3.5)
	await cs.wait(0.6)
	# Вещи вспыхивают по очереди, каждая — цветом своей сущности. Последним — перстень.
	for state in hero.items:
		if cs.skipped:
			return
		var ess := Db.item(state.def_id).essence
		var at := game.hero_model.socket_position(state.def_id)
		Vfx.burst(hero, at, ess.color, 0.45, 0.4)
		CutsceneFx.flare(world, at, ess.color, 1.6, 2.5, 0.6)
		Audio.play(StringName("essence_%s" % ess.id), -12.0)
		await cs.wait(0.38)
	if hero.has_item(&"gloves"):
		var at := game.hero_model.socket_position(&"gloves")
		Vfx.burst(hero, at, RING_GLOW, 1.1, 0.6)
		CutsceneFx.flare(world, at, RING_GLOW, 2.4, 3.0, 1.0)
		Audio.play(&"absorb", -8.0)
	Vfx.ring(hero, c, 2.6, Color(1.0, 0.85, 0.55), 0.9, 0.25)
	await cs.wait(0.9)
	# Сольвейг.
	var sol := cs.spawn(&"beloved", c - right * 6.0 - up * 1.5, c, &"prologue_beloved")
	sol.fade(0.0, 0.0)
	sol.fade(1.0, 1.0)
	cs.cam(c - right * 0.6 + Vector3(0, 1.0, 0), 4.6, 2.0)
	await cs.walk(sol, c - right * 1.3 - up * 0.3)
	cs.face(sol, c)
	cs.face(hero, sol.global_position)
	cs.tag(sol, &"beloved")
	await cs.say(&"beloved", P["beloved_1"])
	await cs.say(&"hero", P["hero_1"])
	await cs.say(&"beloved", P["beloved_2"])
	if cs.skipped:
		return
	# Из-за спины выходит Ильва с фонарём — Сольвейг ещё здесь.
	var iva := cs.spawn(&"faithful", c + right * 4.5 + up * 3.0, c, &"prologue_iva")
	iva.fade(0.0, 0.0)
	iva.fade(1.0, 1.0)
	cs.cam(c + Vector3(0, 1.0, 0), 5.2, 1.6)
	await cs.walk(iva, c + right * 1.2 + up * 0.8)
	cs.face(iva, c)
	cs.face(hero, iva.global_position)
	cs.tag(iva, &"faithful")
	iva.set_pose(&"offer")
	await cs.say(&"faithful", P["faithful_1"])
	# Сольвейг бросает через плечо и уходит в темноту.
	cs.face(sol, iva.global_position)
	await cs.say(&"beloved", P["beloved_3"])
	cs.walk(sol, c - right * 8.0 - up * 3.0)
	sol.fade(0.0, 3.0)
	# Солдат берёт хлеб.
	await cs.fly_to_hand(SetPieces.bread(), iva.hand_position(), game.hero_model.sockets[&"l_hand"], 0.6, 0.3)
	iva.set_pose(&"")
	cs.cam(c + right * 0.6 + Vector3(0, 1.0, 0), 4.0, 1.2)
	await cs.say(&"hero", P["hero_2"])
	# Ильва не уходит — встаёт в паре шагов за его спиной.
	cs.walk_then_face(iva, c + right * 1.0 + up * 1.6, c - up * 3.0)
	cs.face(hero, c - up * 3.0)
	cs.cam(c + Vector3(0, 0.8, 0), 7.0, 3.0)
	cs.ui.black(0.6, 1.2)
	await cs.narrate(P["learn"])
	cs.ui.black(0.0, 0.8)
	Audio.play(&"elite_horn", -6.0)
	await cs.wait(0.9)


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
	cs.mood(&"none", 0.0)
	cs.ui.black(0.0, 0.5)
