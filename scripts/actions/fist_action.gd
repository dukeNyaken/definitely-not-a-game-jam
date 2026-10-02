class_name FistAction
extends ActionComponent
## ЛКМ без меча: удар кулаком на 5 урона. Не вещь — событий не порождает, но может критовать.


func input_action() -> StringName:
	return &"attack"


func press() -> bool:
	if not can_use():
		return false
	var b := Db.balance
	var ctx := new_context()
	ctx.color = Color(0.95, 0.85, 0.7)
	ctx.tag = &"fist"
	actor.mark_attack()
	var any := false
	for t in Combat.targets_in_arc(actor, ctx.origin, ctx.direction, b.fist_range, b.fist_arc_degrees):
		any = Combat.deal(ctx, t, b.fist_damage, {"knockback": 0.3}) == Actor.HitResult.HIT or any
	start_cooldown(b.fist_cooldown)
	Vfx.slash(actor, ctx.origin, ctx.direction, b.fist_range, b.fist_arc_degrees, ctx.color, 0.14)
	Audio.play(&"fist_hit" if any else &"fist_swing")
	used.emit(ctx)
	return true
