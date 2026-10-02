class_name SpawnPortal
extends Node3D
## Тёмный круг на полу: через delay из него поднимается враг.

signal opened(portal: SpawnPortal)

var delay: float = 0.8
var color: Color = Color(0.75, 0.08, 0.05)
var payload: Dictionary = {}
var _t: float = 0.0
var _ring: MeshInstance3D
var _disc: MeshInstance3D


func _ready() -> void:
	_disc = MeshInstance3D.new()
	_disc.mesh = Vfx.sector_mesh(1.0, 360.0, 0.0, 20)
	_disc.material_override = Vfx.material(Color(0.02, 0.0, 0.0, 0.9), 1.0, false)
	_disc.position.y = 0.03
	_disc.scale = Vector3.ONE * 0.05
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	_ring = MeshInstance3D.new()
	_ring.mesh = Vfx.ring_mesh(1.0, 0.12, 20)
	_ring.material_override = Vfx.material(Color(color, 0.9), 1.8, true)
	_ring.position.y = 0.05
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / delay, 0.0, 1.0)
	var s := 0.05 + k * 0.95
	_disc.scale = Vector3.ONE * s
	_ring.scale = Vector3.ONE * s
	_ring.rotation.y += delta * 3.0
	if _t >= delay and not payload.is_empty():
		opened.emit(self)
		payload = {}
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.35).set_delay(0.2)
		tw.tween_callback(queue_free)
