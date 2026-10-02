class_name Projectile
extends Node3D
## Снаряд: стрела врага, волна-снаряд Энергии, отражённые снаряды.

var ctx: ActionContext
var faction: int
var velocity: Vector3
var damage: float = 10.0
var radius: float = 0.35
var pierce: bool = false
var max_distance: float = 20.0
var color: Color = Color.WHITE
var kind: StringName = &"arrow"
var reflected: bool = false
var _traveled: float = 0.0
var _hit: Dictionary = {}
var _visual: Node3D


static func spawn(p_ctx: ActionContext, from: Vector3, dir: Vector3, speed: float, p_damage: float, p_kind: StringName, p_color: Color) -> Projectile:
	var p := Projectile.new()
	p.ctx = p_ctx
	p.faction = p_ctx.actor.faction
	p.velocity = Combat.flat_dir(dir) * speed
	p.damage = p_damage
	p.kind = p_kind
	p.color = p_color
	var parent := Vfx.root_for(p_ctx.actor)
	if parent != null:
		parent.add_child(p)
		p.global_position = Vector3(from.x, 0.9, from.z)
	return p


func _ready() -> void:
	add_to_group(&"projectiles")
	_visual = _build_visual()
	add_child(_visual)
	_orient()


func _build_visual() -> Node3D:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == &"energy":
		mi.mesh = Vfx.sector_mesh(radius * 1.6, 120.0, radius * 1.0, 10)
		mi.material_override = Vfx.material(Color(color, 0.95), 2.0, true)
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.8)
		mi.mesh = box
		mi.material_override = Vfx.material(color, 1.4, false)
	return mi


func _orient() -> void:
	if velocity.length_squared() > 0.001:
		look_at(global_position + velocity, Vector3.UP)


func is_hostile_to(a: Actor) -> bool:
	return a.faction != faction


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	global_position += step
	_traveled += step.length()
	for a in Combat.hostiles_of_faction(get_tree(), faction):
		if _hit.has(a):
			continue
		if Combat.flat(a.global_position - global_position).length() > radius + a.body_radius:
			continue
		_hit[a] = true
		if a.reflect_time > 0.0:
			_reflect(a)
			return
		var res := Combat.deal(ctx, a, damage, {"source_pos": global_position - velocity.normalized(), "projectile": true})
		if res == Actor.HitResult.BLOCKED or res == Actor.HitResult.HIT and not pierce:
			queue_free()
			return
	if _traveled >= max_distance or Combat.flat(global_position).length() > Combat.arena_radius + 2.0:
		queue_free()


## Оплот: снаряд разворачивается и летит обратно, теперь он на стороне отразившего.
func _reflect(by: Actor) -> void:
	reflected = true
	faction = by.faction
	var shooter := ctx.actor if is_instance_valid(ctx.actor) else null
	var back := -velocity
	if shooter != null and not shooter.dead:
		back = Combat.flat_dir(shooter.global_position - global_position) * velocity.length()
	velocity = back
	var new_ctx := ActionContext.make(by, null)
	new_ctx.from_property = true
	ctx = new_ctx
	_hit.clear()
	_hit[by] = true
	_traveled = 0.0
	color = Db.essence(&"bulwark").color
	_orient()
	Vfx.burst(by, global_position, color, 0.6)
	Audio.play(&"reflect")
