class_name SpawnPortal
extends Node3D
## Стоячий разлом: раскрывается из щели, держится, пока из него выходит враг, и схлопывается.
## Разлом — билборд чуть дальше от камеры, чем точка появления, поэтому враг шагает из него на зрителя.
## На полу под ним — малый круг рун: видно, где появится враг.

signal opened(portal: SpawnPortal)

const OPEN_FRAMES := [0, 1, 2, 3]
const LOOP_FRAMES := [4, 5, 6, 7]
const CLOSE_FRAMES := [8, 9, 10]
const RIFT_HEIGHT := 3.0
## Сколько разлом держится после появления врага, прежде чем схлопнуться.
const LINGER := 0.4
const BASE_SIZE := 1.4

var delay: float = 0.8
var color: Color = Color(0.75, 0.08, 0.05)
var payload: Dictionary = {}
var _t: float = 0.0
var _rift: FlipbookFx
var _base: FlipbookFx
var _ms: Array
var _seq: Array = OPEN_FRAMES
var _seq_i: int = 0
var _frame_t: float = 0.0
var _opened_at: float = -1.0
var _closing: bool = false


func _ready() -> void:
	_ms = FlipbookFx.SHEETS[&"spawn_rift"]["ms"]
	_rift = FlipbookFx.attach(self, &"spawn_rift", Vector3(0, RIFT_HEIGHT * 0.5, 0), color, RIFT_HEIGHT,
		{"manual": true, "additive": false, "energy": 2.4, "pull": -0.45})
	_base = FlipbookFx.attach(self, &"spawn_portal", Vector3(0, 0.04, 0), color, BASE_SIZE,
		{"billboard": false, "loop": true, "additive": false, "energy": 1.8, "random_start": true})
	_base.scale = Vector3.ONE * BASE_SIZE * 0.05


func _physics_process(delta: float) -> void:
	_t += delta
	_base.scale = Vector3.ONE * BASE_SIZE * (0.05 + clampf(_t / delay, 0.0, 1.0) * 0.95)
	_base.rotation.y += delta * 1.2
	_advance(delta)
	if _t >= delay and not payload.is_empty():
		opened.emit(self)
		payload = {}
		_opened_at = _t
		FlipbookFx.spawn(self, &"impact", global_position + Vector3(0, 1.2, 0), color, 1.6, {"energy": 2.4, "pull": 0.3})
	if _opened_at >= 0.0 and not _closing and _t - _opened_at >= LINGER:
		_closing = true
		_play(CLOSE_FRAMES)
		create_tween().tween_property(_base, "scale", Vector3.ONE * BASE_SIZE * 0.05, 0.25)


## Листает текущую последовательность кадров по длительностям листа; после раскрытия — петля.
func _advance(delta: float) -> void:
	_frame_t += delta * 1000.0
	while _frame_t >= float(_ms[_seq[_seq_i]]):
		_frame_t -= float(_ms[_seq[_seq_i]])
		_seq_i += 1
		if _seq_i >= _seq.size():
			if _seq == CLOSE_FRAMES:
				queue_free()
				return
			_play(LOOP_FRAMES)
	_rift.set_frame(_seq[_seq_i])


func _play(seq: Array) -> void:
	_seq = seq
	_seq_i = 0
	_frame_t = 0.0
