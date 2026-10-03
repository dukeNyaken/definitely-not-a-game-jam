class_name Altar
extends Node3D
## Алтарь жертвы: большое кольцо на полу со стрелками по часовой. Встань в центр — откроется выбор.

signal stepped_on

var radius: float = 3.2
var active: bool = false
var _spin: Node3D
var _t: float = 0.0
var _armed: bool = false


func _ready() -> void:
	var gold := Color(1.0, 0.78, 0.35)
	var base := LowPoly.cyl(1.3, 1.5, 0.25, 8, Color(0.3, 0.27, 0.27), Vector3(0, 0.12, 0))
	add_child(base)
	add_child(LowPoly.cyl(0.9, 1.1, 0.15, 8, Color(0.4, 0.35, 0.33), Vector3(0, 0.32, 0)))
	# Круг семи (пиксельный лист): внешнее кольцо — 62 px из 64 половины листа, стрелки по часовой.
	_spin = FlipbookFx.attach(self, &"altar_circle", Vector3(0, 0.06, 0), gold, radius * 2.0 * 64.0 / 62.0,
		{"billboard": false, "loop": true, "energy": 1.9, "pull": 0.05})
	var light := OmniLight3D.new()
	light.light_color = gold
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position = Vector3(0, 1.5, 0)
	add_child(light)
	scale = Vector3(1, 0.01, 1)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): active = true)


func _process(delta: float) -> void:
	_t += delta
	_spin.rotation.y = -_t * 0.35
	if not active or Combat.hero == null:
		return
	var d := Combat.flat(Combat.hero.global_position - global_position).length()
	if d > 2.2:
		_armed = true
	elif d < 1.4 and _armed:
		_armed = false
		stepped_on.emit()


func vanish() -> void:
	active = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.5)
	tw.tween_callback(queue_free)
