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
	# Три кольца вздыбленной земли расходятся от героя одно за другим, каждое слабее и короче.
	# Лист цветной — оттенок белый, прозрачность гасит отзвуки.
	for i in 3:
		Vfx.ring(actor, ctx.origin, radius * (1.0 - 0.15 * i), Color(1, 1, 1, 1.0 - 0.25 * i), 0.5, 0.6, &"mass_wave", 0.12 * i)
	play_sound(essence)
