class_name GripEffect
extends EssenceEffect
## Хватка: притягивает врагов в конусе (60°, 6 м).


func apply(essence: EssenceDef, ctx: ActionContext) -> void:
	var actor := ctx.actor
	if not is_instance_valid(actor):
		return
	var radius: float = essence.stat("range", 6.0)
	var arc: float = essence.stat("arc", 60.0)
	var pull_to: float = essence.stat("pull_to", 1.4)
	for t in Combat.targets_in_arc(actor, ctx.origin, ctx.direction, radius, arc):
		var to := Combat.flat(t.global_position - ctx.origin)
		var dist := to.length()
		if dist > pull_to:
			t.force_move(-to.normalized() * (dist - pull_to), float(essence.stat("pull_time", 0.22)))
		Vfx.beam(actor, ctx.origin + Vector3(0, 0.9, 0), t.global_position + Vector3(0, 0.9, 0), essence.color, 0.08, 0.3)
	Vfx.slash(actor, ctx.origin, ctx.direction, radius, arc, essence.color, 0.3)
	play_sound(essence)
