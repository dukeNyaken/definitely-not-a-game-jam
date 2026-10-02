class_name Combat
extends RefCounted
## Общие боевые запросы: поиск целей, урон, крит.

static var arena_radius: float = 15.0
## Текущий герой (для подсветки окна уязвимости и ИИ).
static var hero: Actor


static func living_actors(tree: SceneTree) -> Array[Actor]:
	var out: Array[Actor] = []
	if tree == null:
		return out
	for node in tree.get_nodes_in_group(&"actors"):
		var a := node as Actor
		if a != null and not a.dead and a.is_inside_tree():
			out.append(a)
	return out


static func hostiles_of_faction(tree: SceneTree, faction: int) -> Array[Actor]:
	var out: Array[Actor] = []
	for a in living_actors(tree):
		if a.faction != faction:
			out.append(a)
	return out


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func flat_dir(v: Vector3, fallback: Vector3 = Vector3.FORWARD) -> Vector3:
	var f := flat(v)
	return f.normalized() if f.length_squared() > 0.0001 else fallback


static func targets_in_radius(actor: Actor, center: Vector3, radius: float) -> Array[Actor]:
	var out: Array[Actor] = []
	for a in hostiles_of_faction(actor.get_tree(), actor.faction):
		if flat(a.global_position - center).length() <= radius + a.body_radius:
			out.append(a)
	return out


## Цели в секторе: радиус от center, полный угол arc_degrees вокруг dir.
static func targets_in_arc(actor: Actor, center: Vector3, dir: Vector3, radius: float, arc_degrees: float) -> Array[Actor]:
	var out: Array[Actor] = []
	var fwd := flat_dir(dir)
	var half := deg_to_rad(arc_degrees) * 0.5
	for a in hostiles_of_faction(actor.get_tree(), actor.faction):
		var to := flat(a.global_position - center)
		var dist := to.length()
		if dist > radius + a.body_radius:
			continue
		if dist <= a.body_radius + 0.1:
			out.append(a)
			continue
		var angle := fwd.angle_to(to / dist)
		# Учитываем размер цели, чтобы крупные враги на краю сектора тоже попадали.
		var slack := atan2(a.body_radius, dist)
		if angle <= half + slack:
			out.append(a)
	return out


static func is_crit(attacker: Actor, target: Actor) -> bool:
	if target.open_time > 0.0:
		return true
	if is_instance_valid(attacker):
		var window := attacker.helmet_window()
		if window > 0.0 and target.time_since_attack() <= window:
			return true
	return false


## Урон от действия. Возвращает Actor.HitResult.
static func deal(ctx: ActionContext, target: Actor, amount: float, opts: Dictionary = {}) -> int:
	if target == null or target.dead:
		return Actor.HitResult.MISS
	var attacker: Actor = ctx.actor if is_instance_valid(ctx.actor) else null
	var crit := is_crit(attacker, target)
	var dmg := amount
	if ctx.item != null and attacker != null:
		dmg *= attacker.item_damage_mult
	if crit:
		dmg *= attacker.crit_multiplier() if attacker != null else Db.balance.crit_multiplier
	var o := opts.duplicate()
	o["crit"] = crit
	if not o.has("source_pos"):
		o["source_pos"] = ctx.origin
	var res := target.receive_hit(dmg, ctx, o)
	if res == Actor.HitResult.HIT:
		ctx.landed_hit = true
		if crit and attacker != null:
			attacker.notify_crit(ctx, target)
	return res
