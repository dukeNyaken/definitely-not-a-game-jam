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
var _visual: FlipbookFx


func setup(p_ctx: ActionContext, p_radius: float, p_damage: float, p_duration: float, p_color: Color) -> void:
	ctx = p_ctx
	faction = p_ctx.actor.faction
	radius = p_radius
	damage = p_damage
	duration = maxf(p_duration, 0.05)
	color = p_color


func _ready() -> void:
	# Пиксельное кольцо: кадр по ходу волны, масштаб — чтобы фронт спрайта совпал с фронтом урона.
	_visual = FlipbookFx.attach(self, &"shock_ring", Vector3(0, 0.1, 0), color, 0.1, {"billboard": false, "manual": true, "energy": 1.9, "pull": 0.05})


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	var r := radius * k
	var spec: Dictionary = FlipbookFx.SHEETS[&"shock_ring"]
	var frames: Array = spec["radius_px"]
	var f := mini(int(k * frames.size()), frames.size() - 1)
	_visual.set_frame(f)
	_visual.scale = Vector3.ONE * maxf(r, 0.1) * float(spec["size_px"]) / float(frames[f])
	_visual.set_fade(1.0 - k * k)
	for a in Combat.hostiles_of_faction(get_tree(), faction):
		if _hit.has(a):
			continue
		var d := Combat.flat(a.global_position - global_position).length()
		if d <= r + a.body_radius:
			_hit[a] = true
			# Вспышку попадания рисует модель цели (FlipbookFx.impact).
			Combat.deal(ctx, a, damage, {"source_pos": global_position, "knockback": knockback})
	if k >= 1.0:
		queue_free()
