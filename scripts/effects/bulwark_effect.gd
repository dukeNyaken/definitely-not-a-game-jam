class_name BulwarkEffect
extends EssenceEffect
## Оплот: 0,6 с неуязвимости и отражение снарядов.


func apply(essence: EssenceDef, ctx: ActionContext) -> void:
	var actor := ctx.actor
	if not is_instance_valid(actor):
		return
	var t: float = essence.stat("duration", 0.6)
	actor.add_invulnerability(t)
	actor.add_reflect(t)
	Vfx.dome(actor, essence.color, t)
	play_sound(essence)
