class_name GazeEffect
extends EssenceEffect
## Взор: враги в радиусе 6 м на 1,5 с открыты для крита.


func apply(essence: EssenceDef, ctx: ActionContext) -> void:
	var actor := ctx.actor
	if not is_instance_valid(actor):
		return
	var radius: float = essence.stat("radius", 6.0)
	var t: float = essence.stat("duration", 1.5)
	for target in Combat.targets_in_radius(actor, ctx.origin, radius):
		target.open_for_crit(t)
		Vfx.burst(actor, target.global_position + Vector3(0, 2.0, 0), essence.color, 0.45, 0.3)
	Vfx.ring(actor, ctx.origin, radius, essence.color, 0.45, 0.25)
	play_sound(essence)
