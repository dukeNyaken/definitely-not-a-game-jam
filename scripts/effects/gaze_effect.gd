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
		var model := target.get_node_or_null(^"Model") as Node3D
		var h := (model.scale.y if model != null else 1.0) * 2.05
		if target.is_inside_tree():
			FlipbookFx.attach(target, &"gaze_eye", Vector3(0, h, 0), essence.color, 0.95, {"additive": false, "energy": 1.3, "pull": 0.6, "speed": 0.75})
	Vfx.ring(actor, ctx.origin, radius, essence.color, 0.45, 0.25)
	play_sound(essence)
