class_name GiftScene
extends RefCounted
## Дар у алтаря: получатель отданной вещи выходит к Солдату, просит, получает вещь и клянётся.
## Сила вещи не ослабла — поток из рук получателя уходит в соседнюю вещь Солдата (правило мира).
## Солдат вспоминает, что знает об этой вещи (закладка для финала). Ильва говорит свою строку.
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
	var victim_id: StringName = info["victim"]
	var recipient_id: StringName = info["recipient"]
	var g := Story.gift(victim_id)
	var who: StringName = g.get("who", &"friend")
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
	cs.cam(c + Vector3(0, 0.9, 0) + right * 0.6, 6.5, 1.2)
	cs.walk(iva, c - right * 1.4 + up * 1.1)
	await cs.walk(rec, stand)
	cs.face(rec, c)
	cs.face(hero, stand)
	cs.cam(c + right * 0.95 + Vector3(0, 1.0, 0), 4.6, 1.4)
	cs.tag(rec, who)
	await cs.say(who, g.get("plea", ""))
	await cs.say(&"hero", g.get("reply", ""))
	if cs.skipped:
		return
	# Вещь уходит из рук Солдата в руки получателя.
	var from := game.hero_model.socket_position(victim_id)
	_hand_over(game, info, state)
	var display := ItemVisuals.build_display(info["snapshot"])
	state["display"] = display
	game.world.add_child(display)
	display.scale = Vector3.ONE * 0.75
	Audio.play(&"item_fly", -4.0)
	await cs.fly(display, from, rec.hand_position(), 0.9)
	rec.hold(display)
	rec.set_pose(&"hold")
	await cs.say(who, g.get("oath", ""))
	if cs.skipped:
		return
	# Правило мира: сила не ослабла — она уходит соседней вещи Солдата.
	var color := Db.item(victim_id).essence.color
	SacrificeFx.play(game.world, game.hero_model, rec.hand_position(), recipient_id, color, state["hidden"])
	state["fx"] = true
	Audio.play(&"sacrifice")
	Audio.play(StringName("essence_%s" % Db.item(victim_id).essence.id), -4.0)
	cs.cam(c + right * 0.5 + Vector3(0, 1.0, 0), 5.2, 1.0)
	await cs.wait(0.9)
	var prop: Property = info["property"]
	await cs.thought(Story.light_caption(victim_id, recipient_id, prop.display_name()))
	await cs.thought(g.get("extra", ""))
	await cs.thought(g.get("secret", ""))
	cs.face(hero, iva.global_position)
	cs.face(iva, c)
	var n: int = info["ordinal"]
	if n >= 1 and n <= Story.IVA_LINES.size():
		await cs.say(&"faithful", Story.IVA_LINES[n - 1])
	# Получатель уходит со своей вещью.
	cs.walk(rec, c + right * 9.0 + up * 1.5)
	rec.fade(0.0, 1.8)
	await cs.wait(1.4)


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
	var d: Node3D = state["display"]
	if d != null and is_instance_valid(d):
		d.queue_free()
