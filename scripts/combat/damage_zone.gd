class_name DamageZone
extends Node3D
## Зона заклинателя: круг на полу мигает 1 с, затем бьёт всех врагов кастера внутри.

var ctx: ActionContext
var faction: int
var radius: float = 2.0
var delay: float = 1.0
var damage: float = 14.0
var color: Color = Color(0.85, 0.12, 0.2)
var _t: float = 0.0
var _telegraph: Telegraph


static func spawn(p_ctx: ActionContext, pos: Vector3, p_radius: float, p_delay: float, p_damage: float) -> DamageZone:
	var z := DamageZone.new()
	z.ctx = p_ctx
	z.faction = p_ctx.actor.faction
	z.radius = p_radius
	z.delay = p_delay
	z.damage = p_damage
	var parent := Vfx.root_for(p_ctx.actor)
	if parent != null:
		parent.add_child(z)
		z.global_position = Vector3(pos.x, 0.0, pos.z)
	return z


func _ready() -> void:
	_telegraph = Telegraph.create(self, Telegraph.Shape.CIRCLE, radius, color)
	Audio.play(&"zone_charge", -6.0)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := _t / delay
	_telegraph.set_progress(k)
	# Мигание учащается к концу.
	_telegraph.visible = k < 0.6 or fmod(_t * (6.0 + 14.0 * k), 1.0) < 0.6
	if _t >= delay:
		for a in Combat.hostiles_of_faction(get_tree(), faction):
			if Combat.flat(a.global_position - global_position).length() <= radius + a.body_radius * 0.5:
				Combat.deal(ctx, a, damage, {"source_pos": global_position, "blockable": false})
		Vfx.ring(self, global_position, radius, color, 0.3, 0.8)
		FlipbookFx.eruption_field(self, global_position, radius, color)
		Audio.play(&"zone_blast", -2.0)
		queue_free()
