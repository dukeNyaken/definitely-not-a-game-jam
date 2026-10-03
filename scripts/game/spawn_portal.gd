class_name SpawnPortal
extends Node3D
## Призывной круг на полу: пентаграмма прорисовывается и пульсирует, пока идёт задержка, затем вспыхивает —
## и в круге появляется враг. Элиты (несут вещи героя) призываются большим золотым кругом.

signal opened(portal: SpawnPortal)

const OPEN_FRAMES := [0, 1, 2, 3]
const LOOP_FRAMES := [4, 5, 6, 7, 8]
const BURST_FRAMES := [9, 10, 11]
## Радиус круга, м, и доля листа, которую занимает внешний край (кольцо / зубцы венца).
const MINOR_RADIUS := 1.1
const MINOR_EDGE := 30.0 / 32.0
const MAJOR_RADIUS := 1.7
const MAJOR_EDGE := 62.0 / 64.0
const ELITE_COLOR := Color(1.0, 0.62, 0.2)

var delay: float = 0.8
var color: Color = Color(1.0, 0.16, 0.08)
var payload: Dictionary = {}
var _t: float = 0.0
var _fx: FlipbookFx
var _ms: Array
var _seq: Array = OPEN_FRAMES
var _seq_i: int = 0
var _frame_t: float = 0.0
var _radius: float = MINOR_RADIUS
var _spin: float = 0.5


func _ready() -> void:
	var elite := not (payload.get("items", []) as Array).is_empty()
	var id := &"summon_major" if elite else &"summon_minor"
	if elite:
		color = ELITE_COLOR
		_radius = MAJOR_RADIUS
		_spin = -0.3
	var size := _radius * 2.0 / (MAJOR_EDGE if elite else MINOR_EDGE)
	_ms = FlipbookFx.SHEETS[id]["ms"]
	_fx = FlipbookFx.attach(self, id, Vector3(0, 0.04, 0), color, size,
		{"billboard": false, "manual": true, "energy": 2.0 if elite else 2.6, "pull": 0.05})
	_fx.rotation.y = randf() * TAU


func _physics_process(delta: float) -> void:
	_t += delta
	_fx.rotation.y += delta * _spin
	_advance(delta)
	if _t >= delay and not payload.is_empty():
		opened.emit(self)
		payload = {}
		_play(BURST_FRAMES)
		Vfx.ring(self, global_position, _radius * 1.5, color, 0.35, 0.3)


## Листает текущую последовательность по длительностям листа: прорисовка → петля; вспышка → удаление.
func _advance(delta: float) -> void:
	_frame_t += delta * 1000.0
	while _frame_t >= float(_ms[_seq[_seq_i]]):
		_frame_t -= float(_ms[_seq[_seq_i]])
		_seq_i += 1
		if _seq_i >= _seq.size():
			if _seq == BURST_FRAMES:
				queue_free()
				return
			_play(LOOP_FRAMES)
	_fx.set_frame(_seq[_seq_i])


func _play(seq: Array) -> void:
	_seq = seq
	_seq_i = 0
	_frame_t = 0.0
