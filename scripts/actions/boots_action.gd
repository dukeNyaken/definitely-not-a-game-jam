class_name BootsAction
extends ActionComponent
## Сапоги, Пробел: рывок 4 м по направлению движения, откат 1 с. Событие — Рывок.

## Направление рывка задаёт контроллер; если пусто — по движению, иначе по взгляду.
var dash_direction: Vector3 = Vector3.ZERO


func press() -> bool:
	if not can_use():
		return false
	var dir := dash_direction
	if dir.length_squared() < 0.01:
		dir = actor.move_input
	if dir.length_squared() < 0.01:
		dir = actor.facing
	dash_direction = Vector3.ZERO
	var ctx := new_context()
	ctx.direction = Combat.flat_dir(dir, actor.facing)
	var from := actor.global_position
	var dist: float = def.stat("distance", 4.0)
	actor.start_dash(ctx.direction, dist, float(def.stat("duration", 0.18)))
	start_cooldown(float(def.stat("cooldown", 1.0)))
	Vfx.streak(actor, from, from + ctx.direction * dist, Color(0.8, 0.75, 0.6, 0.6))
	Audio.play(&"dash")
	used.emit(ctx)
	emit_native(ctx)
	return true
