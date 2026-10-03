class_name GiftScene
extends RefCounted
## Дар у алтаря: получатель отданной вещи выходит к Солдату, просит, получает вещь и клянётся в низком поклоне.
## Сила вещи не ослабла — столб света и поток из рук получателя уходят в соседнюю вещь Солдата
## (правило мира). Камера подходит к вещи вплотную, пока Солдат вспоминает её слабое место
## (закладка для финала). Ильва говорит свою строку — и делится своим.
##
## info: victim, snapshot, recipient, old_count, property, ordinal.


static func play(cs: Cutscene, game: Game, info: Dictionary) -> void:
	var state := {"handed": false, "fx": false, "hidden": [] as Array[Node3D], "display": null}
	cs.begin()
	await _body(cs, game, info, state)
	_finalize(cs, game, info, state)
	cs.end()


static func _body(cs: Cutscene, game: Game, info: Dictionary, state: Dictionary) -> void:
	var hero := game.hero
	var world := game.world
	var victim_id: StringName = info["victim"]
	var recipient_id: StringName = info["recipient"]
	var n: int = info["ordinal"]
	var g := Story.gift(victim_id)
	var who: StringName = g.get("who", &"friend")
	var color := Db.item(victim_id).essence.color
	var c := hero.global_position
	var axes := game.rig.ground_axes()
	var up: Vector3 = axes[0]
	var right: Vector3 = axes[1]
	var stand := c + right * 1.9
	var rec := cs.spawn(who, c + right * 8.5 - up * 1.2, c, &"gift_recipient")
	var iva := cs.spawn(&"faithful", c - right * 6.5 + up * 4.0, c, &"gift_iva")
	rec.fade(0.0, 0.0)
	rec.fade(1.0, 0.8)
	iva.fade(0.0, 0.0)
	iva.fade(1.0, 1.0)
	cs.cam(c + Vector3(0, 0.9, 0) + right * 0.6, 6.8, 0.0)
	cs.cam(c + Vector3(0, 0.9, 0) + right * 0.8, 6.0, 2.4)
	var ch := Story.gift_chapter(n, victim_id)
	cs.chapter(ch[0], ch[1], true, 2.0)
	cs.walk(iva, c - right * 1.4 + up * 1.1)
	await cs.walk(rec, stand)
	cs.face(rec, c)
	cs.face(hero, stand)
	cs.face(iva, c)
	cs.tag(rec, who)
	cs.cam(stand + Vector3(0, 1.15, 0) - right * 0.3, 3.6, 1.2)
	cs.orbit(-10.0, 5.0)
	await cs.say(who, g.get("plea", ""))
	cs.cam(c + right * 0.6 + Vector3(0, 1.1, 0), 3.8, 0.9)
	await cs.say(&"hero", g.get("reply", ""))
	if cs.skipped:
		return
	# Вещь уходит из рук Солдата в руки получателя — со шлейфом цвета своей сущности.
	cs.cam(c + right * 0.95 + Vector3(0, 1.0, 0), 4.4, 0.8)
	cs.orbit(0.0, 1.0)
	var from := game.hero_model.socket_position(victim_id)
	_hand_over(game, info, state)
	var display := ItemVisuals.build_display(info["snapshot"])
	state["display"] = display
	world.add_child(display)
	display.scale = Vector3.ONE * 0.75
	Audio.play(&"item_fly", -4.0)
	await cs.fly(display, from, rec.hand_position(), 0.9, 1.4, color)
	rec.hold(display)
	rec.set_pose(&"hold")
	Vfx.burst(rec, rec.hand_position(), color, 0.8, 0.4)
	CutsceneFx.flare(world, rec.hand_position(), color, 2.0, 3.0, 0.8)
	await cs.wait(0.5)
	# Клятва — в низком поклоне, вещь прижата к груди.
	rec.set_pose(&"bow")
	cs.cam(rec.global_position + Vector3(0, 1.05, 0) - right * 0.2, 3.0, 0.9)
	cs.orbit(12.0, 5.0)
	await cs.say(who, g.get("oath", ""))
	rec.set_pose(&"hold")
	if cs.skipped:
		return
	# Правило мира: сила не ослабла — она уходит соседней вещи Солдата столбом света.
	cs.orbit(0.0, 1.2)
	SacrificeFx.play(world, game.hero_model, rec.hand_position(), recipient_id, color, state["hidden"])
	state["fx"] = true
	CutsceneFx.pillar(world, c, color, 5.5, 0.7, 1.8)
	Vfx.ring(hero, c, 3.2, color, 1.0, 0.3)
	cs.flash(color, 0.6, 0.25)
	cs.shake(0.15)
	Audio.play(&"sacrifice")
	Audio.play(StringName("essence_%s" % Db.item(victim_id).essence.id), -4.0)
	cs.cam(c + right * 0.5 + Vector3(0, 1.0, 0), 5.0, 0.6)
	cs.cam(c + right * 0.4 + Vector3(0, 1.0, 0), 4.2, 4.0)
	await cs.wait(0.9)
	var prop: Property = info["property"]
	await cs.thought(Story.light_caption(victim_id, recipient_id, prop.display_name()))
	await cs.thought(g.get("extra", ""))
	# Крупно — вещь в чужих руках. Солдат знает её слабое место.
	cs.cam(rec.hand_position() + Vector3(0, 0.1, 0), 1.9, 1.2)
	await cs.wait(0.5)
	CutsceneFx.flare(world, rec.hand_position(), color, 1.2, 2.0, 1.5)
	await cs.thought(g.get("secret", ""))
	# Ильва — тоже отдаёт своё: флягу, хлеб или просто идёт рядом.
	cs.face(hero, iva.global_position)
	cs.face(iva, c)
	cs.cam((c + iva.global_position) * 0.5 + Vector3(0, 1.1, 0), 3.8, 1.2)
	var gift_back := _iva_gift(n)
	if gift_back != null:
		iva.set_pose(&"offer")
		cs.fly_to_hand(gift_back, iva.hand_position(), game.hero_model.sockets[&"l_hand"])
	if n >= 1 and n <= Story.IVA_LINES.size():
		await cs.say(&"faithful", Story.IVA_LINES[n - 1])
	iva.set_pose(&"")
	# Получатель уходит со своей вещью; Ильва остаётся.
	cs.walk(rec, c + right * 9.0 + up * 1.5)
	rec.fade(0.0, 1.8)
	cs.cam(c + Vector3(0, 0.9, 0), 6.5, 2.0)
	await cs.wait(1.4)


## Что Ильва отдаёт Солдату после дара: флягу после первого, хлеб после третьего.
static func _iva_gift(n: int) -> Node3D:
	match n:
		1:
			return SetPieces.flask()
		3:
			return SetPieces.bread()
	return null


## Вещь исчезает с Солдата; новые добавки получателя спрятаны, пока не долетит поток.
static func _hand_over(game: Game, info: Dictionary, state: Dictionary) -> void:
	if state["handed"]:
		return
	state["handed"] = true
	game.hero.set_items(RunState.ring.items.duplicate())
	state["hidden"] = game.hero_model.hide_addons(info["recipient"], int(info["old_count"]))


static func _finalize(cs: Cutscene, game: Game, info: Dictionary, state: Dictionary) -> void:
	_hand_over(game, info, state)
	if not state["fx"]:
		game.hero_model.reveal_addons(state["hidden"])
		Audio.play(&"absorb", -6.0)
	for key in [&"gift_recipient", &"gift_iva"]:
		var p := cs.actor(key)
		if p != null:
			p.queue_free()
		cs.cast.erase(key)
	cs.clear_props()
	var d: Node3D = state["display"]
	if d != null and is_instance_valid(d):
		d.queue_free()
