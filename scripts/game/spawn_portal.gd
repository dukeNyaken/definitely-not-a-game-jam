class_name SpawnPortal
extends Node3D
## Разлом на полу (пиксельный лист): растёт за delay, затем из него с выбросом поднимается враг.

signal opened(portal: SpawnPortal)

var delay: float = 0.8
var color: Color = Color(0.75, 0.08, 0.05)
var payload: Dictionary = {}
var _t: float = 0.0
## Кольцо рун — 19 px из 24 половины листа: квадрат, чтобы руны легли на радиус 1 м.
const SIZE := 2.0 * 24.0 / 19.0

var _fx: FlipbookFx


func _ready() -> void:
	_fx = FlipbookFx.attach(self, &"spawn_portal", Vector3(0, 0.04, 0), color, SIZE,
		{"billboard": false, "loop": true, "additive": false, "energy": 2.4, "random_start": true})
	_fx.scale = Vector3.ONE * SIZE * 0.05


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / delay, 0.0, 1.0)
	_fx.scale = Vector3.ONE * SIZE * (0.05 + k * 0.95)
	_fx.rotation.y += delta * 1.2
	if _t >= delay and not payload.is_empty():
		opened.emit(self)
		payload = {}
		FlipbookFx.eruption(self, global_position, 1.5, color)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.35).set_delay(0.2)
		tw.tween_callback(queue_free)
