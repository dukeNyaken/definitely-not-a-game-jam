class_name GustEffect
extends EssenceEffect
## Порыв: рывок 4 м к курсору.


func apply(essence: EssenceDef, ctx: ActionContext) -> void:
	var actor := ctx.actor
	if not is_instance_valid(actor):
		return
	var dir := Combat.flat_dir(ctx.aim_point - ctx.origin, ctx.direction)
	var dist: float = essence.stat("distance", 4.0)
	actor.start_dash(dir, dist, float(essence.stat("duration", 0.16)))
	# Хлопок воздуха на старте и широкий закрученный след ветра за персонажем.
	Vfx.ring(actor, ctx.origin, 1.5, essence.color, 0.3)
	Vfx.streak(actor, ctx.origin, ctx.origin + dir * dist, essence.color, &"gust_lines", 1.6)
	play_sound(essence)
