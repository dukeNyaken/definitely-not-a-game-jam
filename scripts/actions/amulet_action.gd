class_name AmuletAction
extends ActionComponent
## Амулет, E: волна вокруг героя, 20 урона, 8 м, откат 3 с. Событие — Залп.


func press() -> bool:
	if not can_use():
		return false
	var ctx := new_context()
	var radius: float = def.stat("radius", 8.0)
	var duration: float = def.stat("expand_time", 0.35)
	var wave := Shockwave.new()
	wave.setup(ctx, radius, float(def.stat("damage", 20.0)) * ctx.damage_mult, duration, def.color)
	var parent := Vfx.root_for(actor)
	if parent != null:
		parent.add_child(wave)
		wave.global_position = ctx.origin
	actor.mark_attack()
	start_cooldown(float(def.stat("cooldown", 3.0)))
	Audio.play(&"amulet_wave")
	used.emit(ctx)
	emit_native(ctx)
	return true
