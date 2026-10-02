class_name Shrine
extends Node3D
## Святилище (этапы 3 и 5): один раз меняет местами двух соседей в кольце.

signal stepped_on

var active: bool = false
var _armed: bool = true
var _orb: MeshInstance3D
var _t: float = 0.0


func _ready() -> void:
	var c := Color(0.45, 0.85, 1.0)
	add_child(LowPoly.cyl(0.9, 1.1, 0.3, 6, Color(0.32, 0.32, 0.36), Vector3(0, 0.15, 0)))
	for k in 3:
		var a := TAU * k / 3.0
		var pillar := LowPoly.cyl(0.12, 0.16, 1.6, 5, Color(0.42, 0.42, 0.48), Vector3(cos(a) * 0.7, 1.0, sin(a) * 0.7))
		add_child(pillar)
	_orb = LowPoly.sphere(0.32, 8, 4, c, Vector3(0, 1.9, 0), 0.2, 0.0, 3.0)
	add_child(_orb)
	var ring := MeshInstance3D.new()
	ring.mesh = Vfx.ring_mesh(1.6, 0.1, 32)
	ring.material_override = Vfx.material(Color(c, 0.7), 1.5, true)
	ring.position.y = 0.05
	add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 1.8
	light.omni_range = 5.0
	light.position = Vector3(0, 2.0, 0)
	add_child(light)
	scale = Vector3(1, 0.01, 1)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): active = true)


func _process(delta: float) -> void:
	_t += delta
	_orb.position.y = 1.9 + sin(_t * 2.0) * 0.12
	if not active or Combat.hero == null:
		return
	var d := Combat.flat(Combat.hero.global_position - global_position).length()
	if d > 2.4:
		_armed = true
	elif d < 1.5 and _armed:
		_armed = false
		stepped_on.emit()


func vanish() -> void:
	active = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.4)
	tw.tween_callback(queue_free)
