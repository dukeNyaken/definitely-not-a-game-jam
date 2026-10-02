class_name EnergyEffect
extends EssenceEffect
## Энергия: волна-снаряд к курсору, проходит насквозь.


func apply(essence: EssenceDef, ctx: ActionContext) -> void:
	var actor := ctx.actor
	if not is_instance_valid(actor):
		return
	var dir := Combat.flat_dir(ctx.aim_point - ctx.origin, ctx.direction)
	var p := Projectile.spawn(ctx, ctx.origin + dir * 0.6, dir, essence.stat("speed", 18.0), essence.stat("damage", 15.0) * ctx.damage_mult, &"energy", essence.color)
	p.pierce = true
	p.radius = essence.stat("width", 0.8)
	p.max_distance = essence.stat("range", 12.0)
	play_sound(essence)
