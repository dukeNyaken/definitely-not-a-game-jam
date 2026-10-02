class_name AIController
extends Node
## ИИ врагов, элит и босса. Двигает Actor и жмёт его компоненты-действия.
## Вещи героя (у элит и босса) используются по правилам с реакцией 0,5 с.

var actor: Actor
var edef: EnemyDef
var is_boss: bool = false
var attack: EnemyAttack
var reaction: float = 0.5
var orbit_angle: float = 0.0
var _strafe: float = 1.0
var _strafe_timer: float = 0.0
## Время, с которого условие правила держится непрерывно.
var _since: Dictionary = {}
var _shield_raise_at: float = -1.0
var _shield_release_at: float = -1.0
var _shield_ready_at: float = 0.0
var _dodge_ready_at: float = 0.0
var _watched_target: Actor
## Пауза между действиями вещей (темп элит и фаз босса).
var action_gap: float = 1.0
## Выключенный ИИ стоит на месте (вступление босса, галерея). set_physics_process(false)
## до входа в дерево ненадёжен: Godot включает физику снова при готовности узла.
var active: bool = true
var _next_item_at: float = 0.0


func setup(p_actor: Actor, p_def: EnemyDef, p_attack: EnemyAttack) -> void:
	actor = p_actor
	edef = p_def
	attack = p_attack
	reaction = Db.balance.ai_reaction
	orbit_angle = randf() * TAU
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	if actor == null or actor.dead:
		return
	if not active:
		actor.move_input = Vector3.ZERO
		return
	var target := Combat.hero
	if target == null or not is_instance_valid(target) or target.dead:
		actor.move_input = Vector3.ZERO
		return
	_watch(target)
	actor.aim_point = target.global_position
	var to := Combat.flat(target.global_position - actor.global_position)
	var dist := to.length()
	var gap := dist - target.body_radius - actor.body_radius
	_move(target, to, dist, delta)
	if not actor.items.is_empty():
		_use_items(target, to, dist, gap)
	_use_attack(gap, dist)


func _busy() -> bool:
	return attack != null and not attack.is_idle()


# --- Движение ---------------------------------------------------------------

func _move(target: Actor, to: Vector3, dist: float, delta: float) -> void:
	var dir := Vector3.ZERO
	var toward := to / maxf(dist, 0.001)
	var behavior := edef.behavior if edef != null else EnemyDef.Behavior.MELEE
	var reach := attack.reach() if attack != null else 2.0
	match behavior:
		EnemyDef.Behavior.MELEE, EnemyDef.Behavior.BRUTE, EnemyDef.Behavior.SLIME:
			if dist > reach * 0.8 + target.body_radius:
				dir = toward
		EnemyDef.Behavior.JESTER:
			# Кружит вокруг цели на дистанции выпада, меняя направление.
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_timer = randf_range(1.2, 2.4)
				_strafe = -_strafe
			orbit_angle += delta * 1.5 * _strafe
			var spot := target.global_position + Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * edef.orbit_distance
			var to_spot := Combat.flat(spot - actor.global_position)
			if to_spot.length() > 0.25:
				dir = to_spot.normalized()
		EnemyDef.Behavior.SWARM:
			var spot := target.global_position + Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * 1.1
			var to_spot := Combat.flat(spot - actor.global_position)
			if to_spot.length() > 0.3:
				dir = to_spot.normalized()
			orbit_angle += delta * 0.4
		EnemyDef.Behavior.RANGED, EnemyDef.Behavior.CASTER:
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_timer = randf_range(1.5, 3.0)
				_strafe = -_strafe
			var pref := edef.preferred_distance
			if dist < pref - 1.5:
				dir = -toward
			elif dist > pref + 1.5:
				dir = toward
			else:
				dir = Vector3(-toward.z, 0, toward.x) * _strafe * 0.6
			# Не упираться в край арены.
			var p := Combat.flat(actor.global_position)
			if p.length() > Combat.arena_radius - 2.0:
				dir += -p.normalized() * 0.8
	dir += _separation() * 0.9
	actor.move_input = dir.limit_length(1.0)


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group(&"actors"):
		var a := other as Actor
		if a == actor or a == null or a.dead or a.faction != actor.faction:
			continue
		var d := Combat.flat(actor.global_position - a.global_position)
		var min_d := actor.body_radius + a.body_radius + 0.3
		var len := d.length()
		if len < min_d and len > 0.001:
			push += d / len * (1.0 - len / min_d)
	return push


# --- Врождённая атака -------------------------------------------------------

func _use_attack(gap: float, dist: float) -> void:
	if attack == null or actor.slot(&"attack") != attack:
		return
	if not attack.is_idle() or attack.cooldown_left > 0.0:
		return
	match attack.edef.behavior:
		EnemyDef.Behavior.RANGED, EnemyDef.Behavior.CASTER:
			if dist <= attack.edef.attack_range:
				attack.press()
		_:
			if gap <= attack.reach() * 0.9:
				attack.press()


# --- Вещи героя -------------------------------------------------------------

func _watch(target: Actor) -> void:
	if _watched_target == target:
		return
	if _watched_target != null and is_instance_valid(_watched_target) and _watched_target.attack_started.is_connected(_on_target_attack):
		_watched_target.attack_started.disconnect(_on_target_attack)
	_watched_target = target
	target.attack_started.connect(_on_target_attack)


func _exit_tree() -> void:
	if _watched_target != null and is_instance_valid(_watched_target) and _watched_target.attack_started.is_connected(_on_target_attack):
		_watched_target.attack_started.disconnect(_on_target_attack)


## Щит: на замах цели рядом — с шансом 50%, после реакции. Шут — уворачивается прыжком.
func _on_target_attack() -> void:
	if actor == null or actor.dead:
		return
	var dist := Combat.flat(_watched_target.global_position - actor.global_position).length()
	if edef != null and edef.dodge_chance > 0.0 and dist <= 3.5 and actor.clock() >= _dodge_ready_at and _busy() == false:
		if randf() < edef.dodge_chance:
			_dodge_ready_at = actor.clock() + edef.dodge_cooldown
			var away := Combat.flat_dir(actor.global_position - _watched_target.global_position)
			var side := Vector3(-away.z, 0, away.x) * (1.0 if randf() < 0.5 else -1.0)
			actor.start_dash((side + away * 0.4).normalized(), edef.dodge_distance, 0.2)
			Audio.play(&"jester_giggle", -8.0, 0.2)
	if not actor.has_item(&"shield"):
		return
	if dist <= Db.balance.ai_shield_trigger_range:
		_maybe_raise_shield()


func _maybe_raise_shield() -> void:
	if _shield_raise_at > 0.0 or _shield_release_at > 0.0 or actor.clock() < _shield_ready_at:
		return
	if randf() < Db.balance.ai_shield_chance:
		_shield_raise_at = actor.clock() + reaction


## Условие должно держаться reaction секунд, прежде чем ИИ среагирует.
func _ready_after_reaction(rule: StringName, condition: bool) -> bool:
	var now := actor.clock()
	if not condition:
		_since.erase(rule)
		return false
	if not _since.has(rule):
		_since[rule] = now
	return now - float(_since[rule]) >= reaction


func _use_items(target: Actor, to: Vector3, dist: float, gap: float) -> void:
	if _busy():
		return
	var now := actor.clock()
	# Щит: замах (сигнал) или летящий в нас снаряд.
	if actor.has_item(&"shield"):
		if _incoming_projectile():
			_maybe_raise_shield()
		if _shield_raise_at > 0.0 and now >= _shield_raise_at:
			_shield_raise_at = -1.0
			if actor.press(&"block"):
				_shield_release_at = now + Db.balance.ai_shield_hold
		if _shield_release_at > 0.0 and now >= _shield_release_at:
			_shield_release_at = -1.0
			_shield_ready_at = now + Db.balance.ai_shield_cooldown
			actor.release(&"block")
	if now < _next_item_at:
		return
	var b := Db.balance
	# Меч: игрок ближе 2,5 м.
	if actor.has_item(&"sword") and _ready_after_reaction(&"sword", gap < b.ai_sword_range):
		if actor.press(&"attack"):
			var sword := actor.component(&"sword") as SwordAction
			if sword.combo_step >= 2:
				_since.erase(&"sword")
				_next_item_at = now + Db.balance.ai_sword_combo_pause
			return
	# Сапоги: сближение, если игрок дальше 6 м; отскок при HP ниже 30%.
	if actor.has_item(&"boots"):
		var boots := actor.component(&"boots") as BootsAction
		var low := actor.hp < actor.max_hp * b.ai_boots_retreat_hp
		if _ready_after_reaction(&"boots_retreat", low and dist < b.ai_boots_retreat_distance):
			boots.dash_direction = -to
			if boots.press():
				_used(&"boots_retreat", now)
				return
		elif _ready_after_reaction(&"boots_close", dist > b.ai_boots_close_distance):
			boots.dash_direction = to
			if boots.press():
				_used(&"boots_close", now)
				return
	# Перчатки: игрок в пределах 6 м.
	if actor.has_item(&"gloves") and _ready_after_reaction(&"gloves", dist <= b.ai_gloves_range):
		if actor.press(&"grab"):
			_used(&"gloves", now)
			return
	# Амулет: игрок на расстоянии 4–8 м.
	if actor.has_item(&"amulet") and _ready_after_reaction(&"amulet", dist >= b.ai_amulet_min and dist <= b.ai_amulet_max):
		if actor.press(&"volley"):
			_used(&"amulet", now)
			return


func _used(rule: StringName, now: float) -> void:
	_since.erase(rule)
	_next_item_at = now + action_gap


func _incoming_projectile() -> bool:
	for n in get_tree().get_nodes_in_group(&"projectiles"):
		var p := n as Projectile
		if p == null or p.faction == actor.faction:
			continue
		var to := Combat.flat(actor.global_position - p.global_position)
		if to.length() < 6.0 and p.velocity.dot(to) > 0.0:
			return true
	return false
