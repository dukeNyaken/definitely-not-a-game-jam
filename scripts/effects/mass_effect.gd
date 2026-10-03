class_name MassEffect
extends EssenceEffect
## Масса: толчок врагов в радиусе 3 м на 3 м, оглушение 0,5 с, 5 урона.


func apply(essence: EssenceDef, ctx: ActionContext) -> void:
	var actor := ctx.actor
	if not is_instance_valid(actor):
		return
	var radius: float = essence.stat("radius", 3.0)
	var push: float = essence.stat("push", 3.0)
	for t in Combat.targets_in_radius(actor, ctx.origin, radius):
		var away := Combat.flat_dir(t.global_position - ctx.origin, ctx.direction)
		t.force_move(away * push, float(essence.stat("push_time", 0.2)))
		Combat.deal(ctx, t, essence.stat("damage", 5.0) * ctx.damage_mult, {"stun": essence.stat("stun", 0.5), "blockable": false})
	# Удар по земле: трещины с волной пыли и камнями, по кругу — столбы пыли (не на самом персонаже).
	Vfx.ring(actor, ctx.origin, radius, essence.color, 0.45, 0.6, &"mass_quake")
	FlipbookFx.eruption_field(actor, ctx.origin, radius * 0.75, essence.color.darkened(0.15), 4, false)
	play_sound(essence)
