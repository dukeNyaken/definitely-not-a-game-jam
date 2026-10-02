class_name GlovesAction
extends ActionComponent
## Перчатки, Q: хват — конус 60°, 6 м, откат 4 с. Притягивает и оглушает. Событие — Захват.


func press() -> bool:
	if not can_use():
		return false
	var ctx := new_context()
	var radius: float = def.stat("range", 6.0)
	var arc: float = def.stat("arc", 60.0)
	var pull_to: float = def.stat("pull_to", 1.4)
	actor.mark_attack()
	for t in Combat.targets_in_arc(actor, ctx.origin, ctx.direction, radius, arc):
		var to := Combat.flat(t.global_position - ctx.origin)
		var dist := to.length()
		if dist > pull_to:
			t.force_move(-to.normalized() * (dist - pull_to), float(def.stat("pull_time", 0.22)))
		Combat.deal(ctx, t, float(def.stat("damage", 6.0)) * ctx.damage_mult, {"stun": def.stat("stun", 0.8), "blockable": false})
		Vfx.beam(actor, ctx.origin + Vector3(0, 0.9, 0), t.global_position + Vector3(0, 0.9, 0), def.color, 0.1, 0.3)
	start_cooldown(float(def.stat("cooldown", 4.0)))
	Vfx.slash(actor, ctx.origin, ctx.direction, radius, arc, def.color, 0.25)
	Audio.play(&"grab")
	used.emit(ctx)
	emit_native(ctx)
	return true
