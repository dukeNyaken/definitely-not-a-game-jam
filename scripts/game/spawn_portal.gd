class_name SpawnPortal
extends Node3D
## Призывной круг на полу: пентаграмма прорисовывается и пульсирует, пока идёт задержка, затем вспыхивает
## и выгорает, а на её месте разверзается тёмная яма — враг поднимается из неё (emerge), и яма затягивается.
## Элиты (несут вещи героя) призываются большим золотым кругом и ямой пошире.

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
## Яма: радиус (м) для обычного врага и элиты, доля листа под чёрным ядром, время подъёма врага.
const POOL_RADIUS := 0.8
const POOL_RADIUS_ELITE := 1.15
const POOL_EDGE := 17.0 / 24.0
const RISE_TIME := 0.6
const POOL_COLOR := Color(0.75, 0.1, 0.06)

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
var _elite: bool = false
var _pool: FlipbookFx
var _pool_size: float = 1.0
var _burnt: bool = false


func _ready() -> void:
	var elite := not (payload.get("items", []) as Array).is_empty()
	_elite = elite
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
		_open_pool()
		opened.emit(self)
		payload = {}
		_play(BURST_FRAMES)
		Vfx.ring(self, global_position, _radius * 1.5, color, 0.35, 0.3)


## Яма раскрывается на месте пентаграммы; затягивается, когда враг поднялся.
func _open_pool() -> void:
	_pool_size = (POOL_RADIUS_ELITE if _elite else POOL_RADIUS) * 2.0 / POOL_EDGE
	_pool = FlipbookFx.attach(self, &"dark_pool", Vector3(0, 0.05, 0), POOL_COLOR, _pool_size,
		{"billboard": false, "loop": true, "additive": false, "energy": 1.6, "pull": 0.08, "random_start": true})
	_pool.rotation.y = randf() * TAU
	_pool.scale = Vector3.ONE * _pool_size * 0.15
	var tw := _pool.create_tween()
	tw.tween_property(_pool, "scale", Vector3.ONE * _pool_size, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(RISE_TIME)
	tw.tween_property(_pool, "scale", Vector3.ONE * _pool_size * 0.05, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## Враг поднимается из ямы: модель уходит под пол (его скрывает сам пол) и выезжает вверх.
## ИИ ждёт, пока враг не выйдет целиком.
func emerge(enemy: Actor) -> void:
	var model := enemy.get_node_or_null(^"Model") as Node3D
	if model == null:
		return
	var ai := enemy.get_node_or_null(^"AI") as AIController
	if ai != null:
		ai.active = false
	model.position.y = -2.1 * model.scale.y
	var tw := model.create_tween()
	tw.tween_property(model, "position:y", 0.0, RISE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.08)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ai):
			ai.active = true)


## Листает текущую последовательность по длительностям листа: прорисовка → петля; вспышка → удаление.
func _advance(delta: float) -> void:
	if _burnt:
		return
	_frame_t += delta * 1000.0
	while _frame_t >= float(_ms[_seq[_seq_i]]):
		_frame_t -= float(_ms[_seq[_seq_i]])
		_seq_i += 1
		if _seq_i >= _seq.size():
			if _seq == BURST_FRAMES:
				# Пентаграмма выгорела; круг гаснет, яма живёт своим твином и удалит портал.
				_burnt = true
				_fx.visible = false
				return
			_play(LOOP_FRAMES)
	_fx.set_frame(_seq[_seq_i])


func _play(seq: Array) -> void:
	_seq = seq
	_seq_i = 0
	_frame_t = 0.0
