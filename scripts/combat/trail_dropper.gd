class_name TrailDropper
extends Node
## Роняет лужи яда по пути слизня: одна лужа на каждые trail_spacing метров.

var actor: Actor
var def: EnemyDef
var damage: float = 4.0
var _last: Vector3
var _acc: float = 0.0


func setup(p_actor: Actor, p_def: EnemyDef, dmg: float) -> void:
	actor = p_actor
	def = p_def
	damage = dmg


func _physics_process(_delta: float) -> void:
	if actor == null or actor.dead or not actor.is_inside_tree():
		return
	var pos := actor.global_position
	if _last == Vector3.ZERO:
		_last = pos
		return
	_acc += Combat.flat(pos - _last).length()
	_last = pos
	if _acc >= def.trail_spacing:
		_acc = 0.0
		var ctx := ActionContext.make(actor, null)
		ctx.from_property = true
		PoisonPuddle.spawn(ctx, pos, def, damage)
