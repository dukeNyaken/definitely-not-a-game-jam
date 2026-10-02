class_name BladeEffect
extends EssenceEffect
## Лезвие: разрез дугой 180°, 2,5 м, 15 урона.


func apply(essence: EssenceDef, ctx: ActionContext) -> void:
	var actor := ctx.actor
	if not is_instance_valid(actor):
		return
	var radius: float = essence.stat("radius", 2.5)
	var arc: float = essence.stat("arc", 180.0)
	var dmg: float = essence.stat("damage", 15.0)
	for t in Combat.targets_in_arc(actor, ctx.origin, ctx.direction, radius, arc):
		Combat.deal(ctx, t, dmg, {"knockback": essence.stat("knockback", 0.6)})
	Vfx.slash(actor, ctx.origin, ctx.direction, radius, arc, essence.color, 0.26)
	play_sound(essence)
