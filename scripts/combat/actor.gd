class_name Actor
extends CharacterBody3D
## Персонаж: здоровье, броня, статусы, шина событий и компоненты-действия.
## Им управляет PlayerController или AIController через move_input / aim_point / use_*.

signal damaged(amount: float, ctx: ActionContext)
signal hit_received(amount: float, crit: bool, ctx: ActionContext)
signal blocked(ctx: ActionContext)
signal died(actor: Actor)
signal health_changed
signal crit_dealt(ctx: ActionContext, target: Actor)
signal attack_started
signal items_changed

enum Faction { HERO, ENEMY }
enum HitResult { MISS, IMMUNE, BLOCKED, HIT }

const ACTION_KEYS: Array[StringName] = [&"attack", &"block", &"dash", &"grab", &"volley"]

@export var faction: int = Faction.HERO
var display_name: String = ""
var max_hp: float = 100.0
var hp: float = 100.0
var armor: float = 0.0
var max_armor: float = 0.0
var base_speed: float = 6.0
var speed_mult: float = 1.0
var body_radius: float = 0.45
var knockback_immune: bool = false
var immortal: bool = false
## Множитель урона действий и свойств вещей (у элит и босса меньше 1).
var item_damage_mult: float = 1.0

## Управление.
var move_input: Vector3 = Vector3.ZERO
var aim_point: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3.FORWARD
var turn_with_aim: bool = true

## Статусы.
var invuln_time: float = 0.0
var reflect_time: float = 0.0
var stun_time: float = 0.0
var open_time: float = 0.0
var busy_time: float = 0.0
var last_attack_time: float = -100.0
var dash_velocity: Vector3 = Vector3.ZERO
var dash_time: float = 0.0
var forced_velocity: Vector3 = Vector3.ZERO
var forced_time: float = 0.0
var block_arc_degrees: float = 0.0
var dead: bool = false

var bus: EventBus
var items: Array[ItemState] = []
## def_id -> ActionComponent
var components: Dictionary = {}
## input action -> ActionComponent
var slots: Dictionary = {}
## Компонент «врождённой» атаки (кулак героя, атака врага, удар босса).
var innate: ActionComponent


func _init() -> void:
	bus = EventBus.new()
	bus.name = "EventBus"
	add_child(bus)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _ready() -> void:
	add_to_group(&"actors")


func clock() -> float:
	return bus.clock


# --- Вещи и компоненты ------------------------------------------------------

## Пересобирает компоненты под набор вещей. Свойства живут в ItemState.
func set_items(states: Array[ItemState]) -> void:
	var keep: Dictionary = {}
	for s in states:
		keep[s.def_id] = s
	for id in components.keys():
		var comp: ActionComponent = components[id]
		if not keep.has(id) or comp.item != keep[id]:
			comp.on_removed()
			components.erase(id)
			comp.queue_free()
	items = states.duplicate()
	for s in items:
		if components.has(s.def_id):
			continue
		var def := s.def()
		var comp: ActionComponent = def.component_script.new()
		comp.name = "Action_%s" % s.def_id
		add_child(comp)
		comp.setup(self, s)
		components[s.def_id] = comp
	_rebuild_slots()
	items_changed.emit()
	health_changed.emit()


func set_innate(comp: ActionComponent) -> void:
	if innate != null:
		innate.on_removed()
		innate.queue_free()
	innate = comp
	if comp != null:
		comp.name = "Innate"
		add_child(comp)
		comp.setup(self, null)
	_rebuild_slots()


func _rebuild_slots() -> void:
	slots.clear()
	for comp in components.values():
		var c: ActionComponent = comp
		if not c.def.is_passive():
			slots[c.def.input_action] = c
	if innate != null and not slots.has(innate.input_action()):
		slots[innate.input_action()] = innate


func component(id: StringName) -> ActionComponent:
	return components.get(id)


func has_item(id: StringName) -> bool:
	return components.has(id)


func slot(action: StringName) -> ActionComponent:
	return slots.get(action)


func press(action: StringName) -> bool:
	var c := slot(action)
	return c.press() if c != null else false


func release(action: StringName) -> void:
	var c := slot(action)
	if c != null:
		c.release()


func helmet_window() -> float:
	var h := component(&"helmet")
	return float(h.def.stat("window", 0.8)) if h != null else 0.0


func crit_multiplier() -> float:
	var h := component(&"helmet")
	return float(h.def.stat("crit_multiplier", 2.0)) if h != null else Db.balance.crit_multiplier


func notify_crit(ctx: ActionContext, target: Actor) -> void:
	crit_dealt.emit(ctx, target)


func mark_attack() -> void:
	last_attack_time = clock()
	attack_started.emit()


func time_since_attack() -> float:
	return clock() - last_attack_time


# --- Статусы ----------------------------------------------------------------

func can_act() -> bool:
	return not dead and stun_time <= 0.0


func can_move() -> bool:
	return can_act() and busy_time <= 0.0 and dash_time <= 0.0


func is_invulnerable() -> bool:
	return invuln_time > 0.0


func is_dashing() -> bool:
	return dash_time > 0.0


func add_invulnerability(t: float) -> void:
	invuln_time = maxf(invuln_time, t)


func add_reflect(t: float) -> void:
	reflect_time = maxf(reflect_time, t)


func stun(t: float) -> void:
	if dead:
		return
	stun_time = maxf(stun_time, t)
	for c in components.values():
		(c as ActionComponent).interrupt()
	if innate != null:
		innate.interrupt()


func open_for_crit(t: float) -> void:
	open_time = maxf(open_time, t)


func is_open_for(attacker: Actor) -> bool:
	return Combat.is_crit(attacker, self)


func start_dash(dir: Vector3, distance: float, duration: float) -> void:
	if dead:
		return
	var d := Combat.flat_dir(dir, facing)
	dash_velocity = d * (distance / maxf(duration, 0.01))
	dash_time = duration
	facing = d


## Принудительное перемещение (толчок, притягивание). Громилы его игнорируют.
func force_move(offset: Vector3, duration: float) -> void:
	if dead or knockback_immune:
		return
	var o := Combat.flat(offset)
	forced_velocity = o / maxf(duration, 0.01)
	forced_time = duration


func current_speed() -> float:
	var f := 1.0
	for c in components.values():
		f *= (c as ActionComponent).speed_factor()
	if innate != null:
		f *= innate.speed_factor()
	return base_speed * speed_mult * f


func restore_armor() -> void:
	armor = max_armor
	health_changed.emit()


func heal_full() -> void:
	hp = max_hp
	armor = max_armor
	health_changed.emit()


# --- Урон -------------------------------------------------------------------

func is_blocking_from(pos: Vector3) -> bool:
	if block_arc_degrees <= 0.0 or not can_act():
		return false
	var to := Combat.flat(pos - global_position)
	if to.length_squared() < 0.0001:
		return true
	return facing.angle_to(to.normalized()) <= deg_to_rad(block_arc_degrees) * 0.5


func receive_hit(amount: float, ctx: ActionContext, opts: Dictionary = {}) -> int:
	if dead:
		return HitResult.MISS
	if is_invulnerable():
		return HitResult.IMMUNE
	var src: Vector3 = opts.get("source_pos", ctx.origin)
	if opts.get("blockable", true) and is_blocking_from(src):
		blocked.emit(ctx)
		return HitResult.BLOCKED
	var dmg := maxf(amount, 0.0)
	var absorbed := minf(armor, dmg)
	armor -= absorbed
	hp -= dmg - absorbed
	if immortal:
		hp = maxf(hp, 1.0)
	var knock: float = opts.get("knockback", 0.0)
	if knock > 0.0:
		var away := Combat.flat_dir(global_position - src, -facing)
		force_move(away * knock, 0.15)
	var stun_t: float = opts.get("stun", 0.0)
	if stun_t > 0.0:
		stun(stun_t)
	hit_received.emit(dmg, opts.get("crit", false), ctx)
	damaged.emit(dmg, ctx)
	health_changed.emit()
	if hp <= 0.0:
		die(ctx.actor if ctx != null and is_instance_valid(ctx.actor) else null)
	return HitResult.HIT


func die(killer: Actor = null) -> void:
	if dead:
		return
	dead = true
	if faction == Faction.ENEMY and is_instance_valid(killer) and killer == Combat.hero and RunState.running and not killer.dead:
		Mastery.award(killer, int(get_meta(&"mastery_xp", 0)))
	hp = 0.0
	move_input = Vector3.ZERO
	block_arc_degrees = 0.0
	collision_layer = 0
	collision_mask = 0
	health_changed.emit()
	died.emit(self)


# --- Движение ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_status(delta)
	if dead:
		return
	if turn_with_aim and can_act() and dash_time <= 0.0:
		var to_aim := Combat.flat(aim_point - global_position)
		if to_aim.length_squared() > 0.01:
			facing = to_aim.normalized()
	var v := Vector3.ZERO
	if dash_time > 0.0:
		v = dash_velocity
	elif can_move():
		var m := Combat.flat(move_input)
		if m.length_squared() > 1.0:
			m = m.normalized()
		v = m * current_speed()
	if forced_time > 0.0:
		v += forced_velocity
	velocity = v
	move_and_slide()
	_clamp_to_arena()


func _tick_status(delta: float) -> void:
	invuln_time = maxf(invuln_time - delta, 0.0)
	reflect_time = maxf(reflect_time - delta, 0.0)
	stun_time = maxf(stun_time - delta, 0.0)
	open_time = maxf(open_time - delta, 0.0)
	busy_time = maxf(busy_time - delta, 0.0)
	dash_time = maxf(dash_time - delta, 0.0)
	forced_time = maxf(forced_time - delta, 0.0)


## Все персонажи стоят на полу арены (y = 0) и не выходят за её край.
func _clamp_to_arena() -> void:
	var p := Combat.flat(global_position)
	var limit := Combat.arena_radius - body_radius
	if p.length() > limit:
		p = p.normalized() * limit
	global_position = Vector3(p.x, 0.0, p.z)
