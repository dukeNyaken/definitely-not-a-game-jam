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
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


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
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Vfx.sector_mesh(radius, 360.0, 0.0, 9)
	_mat = Vfx.material(Color(COLOR, 0.42), 1.0, false)
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.position.y = 0.03 + randf() * 0.004
	_mesh.rotation.y = randf() * TAU
	_mesh.scale = Vector3(randf_range(0.85, 1.15), 1.0, randf_range(0.85, 1.15)) * 0.3
	add_child(_mesh)
	create_tween().tween_property(_mesh, "scale", Vector3(_mesh.scale.x, 1.0, _mesh.scale.z) / 0.3, 0.25)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_t -= delta
	var k := clampf((lifetime - _t) / 1.2, 0.0, 1.0)
	_mat.albedo_color.a = 0.42 * k * (0.85 + 0.15 * sin(_t * 6.0))
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
