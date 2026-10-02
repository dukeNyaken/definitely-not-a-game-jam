class_name Shockwave
extends Node3D
## Расширяющаяся волна: бьёт каждую цель один раз, когда фронт до неё доходит.

var ctx: ActionContext
var faction: int
var radius: float = 8.0
var damage: float = 20.0
var duration: float = 0.35
var color: Color = Color.ORANGE
var knockback: float = 1.0
var _t: float = 0.0
var _hit: Dictionary = {}
var _visual: MeshInstance3D


func setup(p_ctx: ActionContext, p_radius: float, p_damage: float, p_duration: float, p_color: Color) -> void:
	ctx = p_ctx
	faction = p_ctx.actor.faction
	radius = p_radius
	damage = p_damage
	duration = maxf(p_duration, 0.05)
	color = p_color


func _ready() -> void:
	_visual = MeshInstance3D.new()
	_visual.mesh = Vfx.ring_mesh(1.0, 0.12)
	_visual.material_override = Vfx.material(Color(color, 0.9), 1.8, true)
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.position.y = 0.1
	_visual.scale = Vector3.ONE * 0.1
	add_child(_visual)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	var r := radius * k
	_visual.scale = Vector3.ONE * maxf(r, 0.1)
	var mat := _visual.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.9 * (1.0 - k * k)
	for a in Combat.hostiles_of_faction(get_tree(), faction):
		if _hit.has(a):
			continue
		var d := Combat.flat(a.global_position - global_position).length()
		if d <= r + a.body_radius:
			_hit[a] = true
			Combat.deal(ctx, a, damage, {"source_pos": global_position, "knockback": knockback})
			Vfx.burst(self, a.global_position + Vector3(0, 0.9, 0), color, 0.5)
	if k >= 1.0:
		queue_free()
