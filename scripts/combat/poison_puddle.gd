class_name PoisonPuddle
extends Node3D
## Лужа яда за слизнем: жжёт врагов слизня, пока они в ней стоят, затем высыхает.

const MAX_PUDDLES := 70
const COLOR := Color(0.32, 0.8, 0.16)

static var _alive: Array[Node3D] = []
## Яд бьёт цель не чаще раза за тик, сколько бы луж ни перекрывалось: id цели → время по её часам.
static var _next_hit: Dictionary = {}

var ctx: ActionContext
var faction: int
var damage: float = 4.0
var tick: float = 0.5
var radius: float = 0.6
var lifetime: float = 5.0
var _t: float = 0.0
var _tick_t: float = 0.0
var _fx: FlipbookFx


static func spawn(p_ctx: ActionContext, pos: Vector3, def: EnemyDef, dmg: float) -> PoisonPuddle:
	var p := PoisonPuddle.new()
	p.ctx = p_ctx
	p.faction = p_ctx.actor.faction
	p.damage = dmg
	p.tick = def.trail_tick
	p.radius = def.trail_radius
	p.lifetime = def.trail_lifetime
	var parent := Vfx.root_for(p_ctx.actor)
	if parent != null:
		parent.add_child(p)
		p.global_position = Vector3(pos.x, 0.0, pos.z)
	_alive = _alive.filter(func(n): return is_instance_valid(n))
	_alive.append(p)
	while _alive.size() > MAX_PUDDLES:
		var old: Node3D = _alive.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return p


func _ready() -> void:
	# Клякса занимает ~85% листа: размер квадрата — чтобы лужа совпала с радиусом урона.
	var size := radius * 2.0 / 0.85
	_fx = FlipbookFx.attach(self, &"poison_puddle", Vector3(0, 0.03 + randf() * 0.004, 0), Color(COLOR, 0.9), size,
		{"billboard": false, "loop": true, "additive": false, "energy": 1.1, "random_start": true})
	_fx.rotation.y = randf() * TAU
	var full := Vector3(size * (-1.0 if randf() < 0.5 else 1.0), 1.0, size) * Vector3(randf_range(0.9, 1.1), 1.0, randf_range(0.9, 1.1))
	_fx.scale = full * 0.3
	create_tween().tween_property(_fx, "scale", full, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_t -= delta
	_fx.set_fade(clampf((lifetime - _t) / 1.2, 0.0, 1.0))
	if _tick_t <= 0.0:
		_tick_t = tick
		for a in Combat.hostiles_of_faction(get_tree(), faction):
			if Combat.flat(a.global_position - global_position).length() > radius + a.body_radius * 0.3:
				continue
			var id := a.get_instance_id()
			if a.clock() < float(_next_hit.get(id, -1.0)):
				continue
			_next_hit[id] = a.clock() + tick * 0.95
			Combat.deal(ctx, a, damage, {"source_pos": global_position, "blockable": false})
	if _t >= lifetime:
		queue_free()
