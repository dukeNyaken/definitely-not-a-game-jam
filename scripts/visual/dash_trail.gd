class_name DashTrail
extends Node3D
## След рывка, который тянется за персонажем: пока идёт рывок, лента линий скорости растёт от точки
## старта до него (первый кадр листа), когда рывок кончился — лист доигрывает, хвосты втягиваются.

const LIFT := Vector3(0, 0.45, 0)
## Страховка: рывок, который почему-то не кончается, не держит след вечно.
const MAX_HOLD := 0.5

var actor: Actor
var start: Vector3
var width: float = 1.0
var _fx: FlipbookFx
var _t: float = 0.0
var _released: bool = false


static func follow(p_actor: Actor, from: Vector3, color: Color, sheet: StringName = &"speed_lines", p_width: float = 1.0) -> void:
	var parent := Vfx.root_for(p_actor)
	if parent == null:
		return
	var trail := DashTrail.new()
	trail.actor = p_actor
	trail.start = from
	trail.width = p_width
	parent.add_child(trail)
	trail._fx = FlipbookFx.make(sheet, color, 1.0, {"billboard": false, "manual": true, "energy": 1.6, "pull": 0.2})
	trail.add_child(trail._fx)
	trail._fx.visible = false


func _process(delta: float) -> void:
	if not is_instance_valid(_fx):
		queue_free()
		return
	if _released:
		return
	_t += delta
	var head := actor.global_position + LIFT if is_instance_valid(actor) else start
	_fx.visible = Combat.flat(head - start).length() > 0.3
	Vfx.span(_fx, start, head, width)
	if not is_instance_valid(actor) or not actor.is_dashing() or _t > MAX_HOLD:
		_released = true
		_fx.visible = true
		_fx.play_from(1)
