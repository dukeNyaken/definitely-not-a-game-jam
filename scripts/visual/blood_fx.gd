class_name BloodFx
extends RefCounted
## Брызги крови при попаданиях и лужи на полу после смерти.

const BLOOD := Color(0.42, 0.03, 0.03)
const BONE := Color(0.85, 0.82, 0.74)
const SLIME := Color(0.35, 0.8, 0.2)
const MAX_DECALS := 40

static var _decals: Array[Node3D] = []
static var _cube: BoxMesh


static func _mesh() -> BoxMesh:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	return _cube


## Одноразовый всплеск частиц из точки попадания.
static func spurt(parent: Node, pos: Vector3, dir: Vector3, amount: int = 10, color: Color = BLOOD) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.7
	p.direction = (Combat.flat_dir(dir) + Vector3(0, 0.9, 0)).normalized()
	p.spread = 38.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -14.0, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.13
	p.mesh = _mesh()
	p.material_override = LowPoly.mat(color, 0.6)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Лужа крови на полу; растворяется через lifetime секунд.
static func decal(parent: Node, pos: Vector3, size: float = 1.4, lifetime: float = 14.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var quad := BoxMesh.new()
	quad.size = Vector3(size, 0.004, size)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var m := LowPoly.unique(LowPoly.mat(Color(0.6, 0.5, 0.5), 0.95, 0.0, 0.0, &"blood"))
	m.set_shader_parameter(&"tex_scale", 1.0 / size)
	m.set_shader_parameter(&"tex_offset", Vector2(0.5, 0.5))
	m.set_shader_parameter(&"snap_vertices", false)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = randf() * TAU
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.02 + randf() * 0.004, pos.z)
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(lifetime)
	tw.tween_method(func(v: float): m.set_shader_parameter(&"fade", v), 1.0, 0.0, 2.0)
	tw.tween_callback(mi.queue_free)
	_decals = _decals.filter(func(d): return is_instance_valid(d))
	_decals.append(mi)
	while _decals.size() > MAX_DECALS:
		var old: Node3D = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func color_for(a: Actor) -> Color:
	var def = a.get_meta(&"enemy_def") if a.has_meta(&"enemy_def") else null
	if def != null and (def as EnemyDef).behavior == EnemyDef.Behavior.RANGED:
		return BONE
	if def != null and (def as EnemyDef).behavior == EnemyDef.Behavior.SLIME:
		return SLIME
	return BLOOD
