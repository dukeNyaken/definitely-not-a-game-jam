class_name EnemyAttack
extends ActionComponent
## Врождённая атака врага (и удар босса): замах с телеграфом → удар → восстановление.
## После удара враг 0,8 с уязвим для крита (окно шлема).

enum State { IDLE, WINDUP, RECOVERY }

var edef: EnemyDef
var damage: float = 10.0
var state: int = State.IDLE
var timer: float = 0.0
var locked_point: Vector3
var locked_dir: Vector3 = Vector3.FORWARD
var _telegraph: Telegraph
## Серия шута: [{ "t": секунды от удара, "kind": &"stab" | &"retreat" }].
var _combo: Array[Dictionary] = []
var _combo_t: float = 0.0
var _combo_ctx: ActionContext

signal stabbed
signal flipped


func configure(p_def: EnemyDef, p_damage: float) -> void:
	edef = p_def
	damage = p_damage


func input_action() -> StringName:
	return &"attack"


func windup_progress() -> float:
	if state != State.WINDUP or edef.windup <= 0.0:
		return 0.0
	return clampf(1.0 - timer / edef.windup, 0.0, 1.0)


func is_idle() -> bool:
	return state == State.IDLE


## Дистанция, с которой имеет смысл начинать атаку.
func reach() -> float:
	match edef.behavior:
		EnemyDef.Behavior.BRUTE:
			return edef.aoe_radius + 0.4
		EnemyDef.Behavior.SLIME:
			return edef.aoe_radius * 0.8
		_:
			return edef.attack_range


func press() -> bool:
	if state != State.IDLE or not can_use():
		return false
	var target := Combat.hero
	var target_pos := target.global_position if target != null else actor.global_position + actor.facing
	locked_dir = Combat.flat_dir(target_pos - actor.global_position, actor.facing)
	actor.facing = locked_dir
	locked_point = target_pos
	state = State.WINDUP
	timer = edef.windup
	if edef.behavior != EnemyDef.Behavior.SWARM:
		actor.busy_time = edef.windup + 0.05
	_spawn_telegraph()
	match edef.behavior:
		EnemyDef.Behavior.JESTER:
			Audio.play(&"jester_giggle", -4.0, 0.12)
		EnemyDef.Behavior.SLIME:
			Audio.play(&"slime_squish", -8.0, 0.15)
		_:
			Audio.play(&"enemy_windup", -10.0)
	return true


func _spawn_telegraph() -> void:
	var parent := Vfx.root_for(actor)
	match edef.behavior:
		EnemyDef.Behavior.MELEE:
			_telegraph = Telegraph.create(parent, Telegraph.Shape.SECTOR, edef.attack_range, Color(1, 0.3, 0.15), edef.attack_arc_degrees)
			_telegraph.place(actor.global_position, locked_dir)
		EnemyDef.Behavior.BRUTE:
			_telegraph = Telegraph.create(parent, Telegraph.Shape.CIRCLE, edef.aoe_radius, Color(1, 0.22, 0.1))
			_telegraph.place(_brute_center(), locked_dir)
		EnemyDef.Behavior.RANGED:
			_telegraph = Telegraph.create(parent, Telegraph.Shape.LINE, 9.0, Color(1, 0.35, 0.2))
			_telegraph.width = 0.18
			_telegraph.place(actor.global_position, locked_dir)
		EnemyDef.Behavior.SLIME:
			_telegraph = Telegraph.create(parent, Telegraph.Shape.CIRCLE, edef.aoe_radius, Color(0.55, 1.0, 0.2))
			_telegraph.place(actor.global_position, locked_dir)
		EnemyDef.Behavior.JESTER:
			# Линия выпада: куда шут прыгнет и где ударит ножами.
			_telegraph = Telegraph.create(parent, Telegraph.Shape.LINE, edef.lunge_distance + 1.0, Color(1, 0.3, 0.15))
			_telegraph.width = 0.5
			_telegraph.place(actor.global_position, locked_dir)


func _brute_center() -> Vector3:
	return actor.global_position + locked_dir * edef.aoe_radius * 0.55


func _tick(delta: float) -> void:
	match state:
		State.WINDUP:
			if actor.dead:
				interrupt()
				return
			timer -= delta
			# Лучник ведёт цель во время натяжения.
			if edef.behavior == EnemyDef.Behavior.RANGED and Combat.hero != null:
				locked_dir = Combat.flat_dir(Combat.hero.global_position - actor.global_position, locked_dir)
				actor.facing = locked_dir
				if _telegraph != null:
					_telegraph.place(actor.global_position, locked_dir)
			if _telegraph != null:
				_telegraph.set_progress(windup_progress())
			if timer <= 0.0:
				_release()
		State.RECOVERY:
			timer -= delta
			_tick_combo(delta)
			if timer <= 0.0 and _combo.is_empty():
				state = State.IDLE


func _release() -> void:
	_clear_telegraph()
	var ctx := new_context()
	ctx.direction = locked_dir
	ctx.color = Color(1, 0.3, 0.15)
	var dmg := damage
	match edef.behavior:
		EnemyDef.Behavior.MELEE, EnemyDef.Behavior.SWARM:
			for t in Combat.targets_in_arc(actor, actor.global_position, locked_dir, edef.attack_range, edef.attack_arc_degrees):
				Combat.deal(ctx, t, dmg, {"knockback": 0.5})
			if edef.behavior == EnemyDef.Behavior.MELEE:
				Vfx.slash(actor, actor.global_position, locked_dir, edef.attack_range, edef.attack_arc_degrees, Color(1, 0.45, 0.3), 0.18)
				Audio.play(&"enemy_slash", -3.0)
			else:
				Audio.play(&"swarm_bite", -6.0)
		EnemyDef.Behavior.BRUTE:
			var c := _brute_center()
			for t in Combat.targets_in_radius(actor, c, edef.aoe_radius):
				Combat.deal(ctx, t, dmg, {"knockback": 2.0, "source_pos": c})
			Vfx.ring(actor, c, edef.aoe_radius, Color(1, 0.5, 0.3), 0.3, 0.9)
			FlipbookFx.eruption_field(actor, c, edef.aoe_radius * 0.7, Color(0.8, 0.6, 0.4), 3)
			Audio.play(&"brute_slam")
			_shake(0.6)
		EnemyDef.Behavior.RANGED:
			var p := Projectile.spawn(ctx, actor.global_position + locked_dir * 0.6, locked_dir, edef.projectile_speed, dmg, &"arrow", Color(0.85, 0.75, 0.55))
			p.max_distance = edef.attack_range + 4.0
			Audio.play(&"arrow_shot", -3.0)
		EnemyDef.Behavior.SLIME:
			for t in Combat.targets_in_radius(actor, actor.global_position, edef.aoe_radius):
				Combat.deal(ctx, t, dmg, {"knockback": 1.2, "source_pos": actor.global_position})
			Vfx.ring(actor, actor.global_position, edef.aoe_radius, PoisonPuddle.COLOR, 0.3, 0.6)
			BloodFx.spurt(Vfx.root_for(actor), actor.global_position + Vector3(0, 0.4, 0), Vector3.UP, 12, PoisonPuddle.COLOR.darkened(0.3))
			PoisonPuddle.spawn(ctx, actor.global_position, edef, damage * 0.4)
			Audio.play(&"slime_squish", -2.0)
		EnemyDef.Behavior.JESTER:
			# Выпад к цели, затем удары ножами по одному и сальто назад.
			var target := Combat.hero
			if target != null:
				locked_dir = Combat.flat_dir(target.global_position - actor.global_position, locked_dir)
				actor.facing = locked_dir
			var lunge_time := 0.14
			actor.start_dash(locked_dir, edef.lunge_distance, lunge_time)
			_combo_ctx = ctx
			_combo_t = 0.0
			_combo.clear()
			for i in edef.combo_hits:
				_combo.append({"t": lunge_time + i * edef.combo_gap, "kind": &"stab"})
			_combo.append({"t": lunge_time + edef.combo_hits * edef.combo_gap + 0.08, "kind": &"retreat"})
		EnemyDef.Behavior.CASTER:
			var target := Combat.hero
			var pos := locked_point
			if target != null:
				# Ставит зону туда, где цель окажется, с небольшим упреждением.
				pos = target.global_position + Combat.flat(target.velocity) * 0.35
			DamageZone.spawn(ctx, pos, edef.aoe_radius, edef.zone_delay, dmg)
	if edef.behavior != EnemyDef.Behavior.JESTER:
		actor.mark_attack()
	state = State.RECOVERY
	timer = edef.recovery
	actor.busy_time = edef.recovery * 0.7
	start_cooldown(edef.attack_cooldown)
	used.emit(ctx)


func _tick_combo(delta: float) -> void:
	if _combo.is_empty() or actor.dead:
		_combo.clear()
		return
	_combo_t += delta
	while not _combo.is_empty() and _combo_t >= float(_combo[0]["t"]):
		var ev: Dictionary = _combo.pop_front()
		match ev["kind"]:
			&"stab":
				for t in Combat.targets_in_arc(actor, actor.global_position, actor.facing, 1.3, edef.attack_arc_degrees):
					Combat.deal(_combo_ctx, t, damage, {"knockback": 0.3})
				Vfx.slash(actor, actor.global_position, actor.facing, 1.3, edef.attack_arc_degrees, Color(1, 0.5, 0.35), 0.12)
				Audio.play(&"knife_slash", -3.0, 0.15)
				stabbed.emit()
			&"retreat":
				actor.start_dash(-actor.facing, edef.retreat_distance, 0.25)
				actor.mark_attack()
				flipped.emit()


func _shake(amount: float) -> void:
	var rig := actor.get_viewport().get_camera_3d()
	if rig != null and rig.get_parent() is CameraRig:
		(rig.get_parent() as CameraRig).shake(amount)


func interrupt() -> void:
	_combo.clear()
	if state == State.WINDUP:
		_clear_telegraph()
		state = State.IDLE
		start_cooldown(0.6)
		actor.busy_time = 0.0


func on_removed() -> void:
	_clear_telegraph()


func _clear_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _exit_tree() -> void:
	_clear_telegraph()
