class_name SwordAction
extends ActionComponent
## Меч, ЛКМ: комбо 10/10/20. Событие — Удар.

var combo_step: int = -1
var _last_swing: float = -100.0


func press() -> bool:
	if not can_use():
		return false
	var combo: PackedFloat32Array = def.stat("combo", PackedFloat32Array([10, 10, 20]))
	var now := actor.clock()
	if now - _last_swing <= float(def.stat("combo_reset", 0.9)) and combo_step < combo.size() - 1:
		combo_step += 1
	else:
		combo_step = 0
	_last_swing = now
	var finisher := combo_step == combo.size() - 1
	var ctx := new_context()
	ctx.tag = &"finisher" if finisher else &"swing"
	var radius: float = def.stat("range", 2.3)
	var arc: float = def.stat("arc", 120.0)
	var dmg := combo[combo_step] * ctx.damage_mult
	actor.mark_attack()
	var any := false
	for t in Combat.targets_in_arc(actor, ctx.origin, ctx.direction, radius, arc):
		var res := Combat.deal(ctx, t, dmg, {"knockback": def.stat("knockback", 0.5) * (2.0 if finisher else 1.0)})
		any = any or res == Actor.HitResult.HIT
	start_cooldown(float(def.stat("finisher_time" if finisher else "swing_time", 0.3)))
	# Взмахи комбо чередуются: слева направо, справа налево.
	Vfx.slash(actor, ctx.origin, ctx.direction, radius, arc, Color(1, 1, 1) if not finisher else Color(1, 0.9, 0.6), 0.22, combo_step % 2 == 1)
	Audio.play(&"sword_hit" if any else &"sword_swing", -2.0 if any else -6.0)
	used.emit(ctx)
	emit_native(ctx)
	return true
