class_name ActorModel
extends Node3D
## Лоу-поли гуманоид с сокетами под вещи и процедурной анимацией.
## Читает состояние своего Actor каждый кадр; разовые анимации — по сигналам.

enum Kind { HERO, INFANTRY, ARCHER, BRUTE, CASTER, BOSS, SWARM }

const SKIN := Color(0.86, 0.66, 0.52)

var actor: Actor
var kind: int = Kind.HERO
var body_color: Color = SKIN
var accent: Color = Color(0.92, 0.9, 0.84)

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var sockets: Dictionary = {}
var _item_nodes: Dictionary = {}
var _meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D
var _open_mat: StandardMaterial3D
var _flash: float = 0.0
var _walk: float = 0.0
var _swing_t: float = 99.0
var _swing_dur: float = 0.2
var _swing_kind: StringName = &""
var _windup: float = 0.0
var _yaw: float = 0.0
var _dying: bool = false
var _base_y: float = 0.0


func setup(p_actor: Actor, p_kind: int, p_body: Color = SKIN, p_accent: Color = Color(0.92, 0.9, 0.84)) -> void:
	actor = p_actor
	kind = p_kind
	body_color = p_body
	accent = p_accent
	_build_body()
	_flash_mat = Vfx.material(Color(1, 1, 1, 0.75), 2.0, true)
	_open_mat = Vfx.material(Color(0.68, 0.32, 0.98, 0.45), 1.6, true)
	actor.hit_received.connect(_on_hit)
	actor.items_changed.connect(refresh_items)
	actor.died.connect(_on_died)
	refresh_items()


func _build_body() -> void:
	if kind == Kind.SWARM:
		_build_swarm()
		return
	var dark := Color(0.08, 0.07, 0.08)
	hips = LowPoly.pivot("Hips", Vector3(0, 0.9, 0))
	add_child(hips)
	var shorts_color := accent if kind == Kind.HERO else body_color.darkened(0.3)
	hips.add_child(LowPoly.box(Vector3(0.46, 0.26, 0.3), shorts_color))
	leg_l = _limb("LegL", Vector3(-0.13, -0.08, 0), Vector3(0.18, 0.82, 0.2), body_color)
	leg_r = _limb("LegR", Vector3(0.13, -0.08, 0), Vector3(0.18, 0.82, 0.2), body_color)
	hips.add_child(leg_l)
	hips.add_child(leg_r)
	sockets[&"l_foot"] = _socket(leg_l, Vector3(0, -0.82, 0))
	sockets[&"r_foot"] = _socket(leg_r, Vector3(0, -0.82, 0))
	torso = LowPoly.pivot("Torso", Vector3(0, 0.12, 0))
	hips.add_child(torso)
	torso.add_child(LowPoly.box(Vector3(0.5, 0.58, 0.28), body_color, Vector3(0, 0.3, 0)))
	sockets[&"chest"] = _socket(torso, Vector3(0, 0.32, 0))
	sockets[&"neck"] = _socket(torso, Vector3(0, 0.62, 0))
	head = LowPoly.pivot("Head", Vector3(0, 0.62, 0))
	torso.add_child(head)
	head.add_child(LowPoly.box(Vector3(0.34, 0.36, 0.34), body_color.lightened(0.05) if kind == Kind.HERO else body_color, Vector3(0, 0.2, 0)))
	sockets[&"head"] = _socket(head, Vector3(0, 0.2, 0))
	match kind:
		Kind.HERO:
			head.add_child(LowPoly.box(Vector3(0.36, 0.1, 0.36), Color(0.25, 0.16, 0.1), Vector3(0, 0.4, 0.02)))
			head.add_child(LowPoly.box(Vector3(0.05, 0.05, 0.02), dark, Vector3(-0.08, 0.22, -0.17)))
			head.add_child(LowPoly.box(Vector3(0.05, 0.05, 0.02), dark, Vector3(0.08, 0.22, -0.17)))
		Kind.BOSS:
			var glow := Color(0.75, 0.45, 1.0)
			head.add_child(LowPoly.box(Vector3(0.07, 0.04, 0.02), glow, Vector3(-0.08, 0.22, -0.18), 0.5, 0.0, 4.0))
			head.add_child(LowPoly.box(Vector3(0.07, 0.04, 0.02), glow, Vector3(0.08, 0.22, -0.18), 0.5, 0.0, 4.0))
		_:
			var eye := Color(1.0, 0.3, 0.15)
			head.add_child(LowPoly.box(Vector3(0.06, 0.04, 0.02), eye, Vector3(-0.08, 0.22, -0.18), 0.5, 0.0, 3.0))
			head.add_child(LowPoly.box(Vector3(0.06, 0.04, 0.02), eye, Vector3(0.08, 0.22, -0.18), 0.5, 0.0, 3.0))
	arm_l = _limb("ArmL", Vector3(-0.34, 0.55, 0), Vector3(0.15, 0.62, 0.15), body_color)
	arm_r = _limb("ArmR", Vector3(0.34, 0.55, 0), Vector3(0.15, 0.62, 0.15), body_color)
	torso.add_child(arm_l)
	torso.add_child(arm_r)
	sockets[&"l_hand"] = _socket(arm_l, Vector3(0, -0.66, 0))
	sockets[&"r_hand"] = _socket(arm_r, Vector3(0, -0.66, 0))
	_build_kind_extras()
	_collect_meshes()


## Рой: жук на шести лапках. Пустые узлы конечностей нужны общей анимации.
func _build_swarm() -> void:
	var c := body_color
	hips = LowPoly.pivot("Hips", Vector3(0, 0.9, 0))
	add_child(hips)
	torso = LowPoly.pivot("Torso")
	hips.add_child(torso)
	head = LowPoly.pivot("Head")
	torso.add_child(head)
	arm_l = LowPoly.pivot("ArmL")
	arm_r = LowPoly.pivot("ArmR")
	leg_l = LowPoly.pivot("LegL")
	leg_r = LowPoly.pivot("LegR")
	for n in [arm_l, arm_r, leg_l, leg_r]:
		torso.add_child(n)
	var body := LowPoly.pivot("Body", Vector3(0, -0.55, 0))
	torso.add_child(body)
	var shell := LowPoly.sphere(0.42, 7, 4, c, Vector3(0, 0.05, 0.05), 0.4, 0.3)
	shell.scale = Vector3(1.0, 0.6, 1.25)
	body.add_child(shell)
	body.add_child(LowPoly.sphere(0.22, 6, 3, c.darkened(0.35), Vector3(0, 0.02, -0.45)))
	var eye := Color(1.0, 0.85, 0.2)
	body.add_child(LowPoly.box(Vector3(0.07, 0.05, 0.03), eye, Vector3(-0.09, 0.08, -0.64), 0.5, 0.0, 3.5))
	body.add_child(LowPoly.box(Vector3(0.07, 0.05, 0.03), eye, Vector3(0.09, 0.08, -0.64), 0.5, 0.0, 3.5))
	for side in [-1.0, 1.0]:
		var mand := LowPoly.prism(Vector3(0.06, 0.22, 0.06), Color(0.9, 0.85, 0.75), Vector3(side * 0.1, -0.04, -0.68))
		mand.rotation.x = deg_to_rad(-90)
		body.add_child(mand)
		for k in 3:
			var leg := LowPoly.box(Vector3(0.36, 0.05, 0.05), c.darkened(0.5), Vector3(side * 0.42, -0.12, -0.2 + k * 0.22))
			leg.rotation.z = side * -0.5
			body.add_child(leg)
	sockets[&"chest"] = _socket(body, Vector3(0, 0.3, 0.05))
	for key in [&"head", &"neck", &"l_hand", &"r_hand", &"l_foot", &"r_foot"]:
		sockets[key] = sockets[&"chest"]
	_collect_meshes()


func _limb(n: String, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var p := LowPoly.pivot(n, pos)
	p.add_child(LowPoly.box(size, color, Vector3(0, -size.y * 0.5, 0)))
	return p


func _socket(parent: Node3D, pos: Vector3) -> Node3D:
	var s := LowPoly.pivot("Socket", pos)
	parent.add_child(s)
	return s


## Одежда и оружие рядовых врагов (не вещи героя).
func _build_kind_extras() -> void:
	var c := body_color
	match kind:
		Kind.INFANTRY:
			torso.add_child(LowPoly.box(Vector3(0.54, 0.4, 0.32), c.darkened(0.35), Vector3(0, 0.22, 0)))
			head.add_child(LowPoly.cyl(0.2, 0.24, 0.14, 6, Color(0.35, 0.33, 0.32), Vector3(0, 0.38, 0), 0.4, 0.6))
			var blade := LowPoly.box(Vector3(0.07, 0.6, 0.03), Color(0.55, 0.55, 0.58), Vector3(0, 0.35, 0), 0.3, 0.7)
			var sword := LowPoly.pivot("EnemySword")
			sword.add_child(blade)
			sword.add_child(LowPoly.box(Vector3(0.22, 0.04, 0.06), Color(0.3, 0.25, 0.2), Vector3(0, 0.05, 0)))
			sword.rotation.x = deg_to_rad(-90)
			sockets[&"r_hand"].add_child(sword)
		Kind.ARCHER:
			head.add_child(LowPoly.cyl(0.0, 0.26, 0.4, 6, c.darkened(0.3), Vector3(0, 0.42, 0.03)))
			torso.add_child(LowPoly.box(Vector3(0.12, 0.5, 0.12), Color(0.4, 0.28, 0.16), Vector3(0.12, 0.38, 0.2)))
			var bow := LowPoly.pivot("Bow")
			for k in 3:
				var seg := LowPoly.box(Vector3(0.05, 0.36, 0.05), Color(0.45, 0.3, 0.15), Vector3(0, (k - 1) * 0.33, 0.06 if k == 1 else 0.0))
				seg.rotation.x = (k - 1) * -0.35
				bow.add_child(seg)
			bow.position = Vector3(0, -0.02, -0.08)
			sockets[&"l_hand"].add_child(bow)
		Kind.BRUTE:
			torso.add_child(LowPoly.box(Vector3(0.7, 0.3, 0.4), c.darkened(0.3), Vector3(0, 0.55, 0)))
			hips.add_child(LowPoly.box(Vector3(0.5, 0.3, 0.34), c.darkened(0.45), Vector3(0, -0.1, 0)))
			var club := LowPoly.pivot("Club")
			club.add_child(LowPoly.cyl(0.05, 0.05, 0.6, 6, Color(0.4, 0.27, 0.15), Vector3(0, 0.25, 0)))
			club.add_child(LowPoly.cyl(0.16, 0.13, 0.45, 6, Color(0.36, 0.34, 0.33), Vector3(0, 0.7, 0), 0.6, 0.4))
			club.rotation.x = deg_to_rad(-90)
			sockets[&"r_hand"].add_child(club)
		Kind.CASTER:
			hips.add_child(LowPoly.cyl(0.24, 0.42, 0.85, 7, c.darkened(0.2), Vector3(0, -0.4, 0)))
			head.add_child(LowPoly.cyl(0.0, 0.25, 0.45, 6, c.darkened(0.35), Vector3(0, 0.44, 0.02)))
			var staff := LowPoly.pivot("Staff")
			staff.add_child(LowPoly.cyl(0.03, 0.03, 1.4, 5, Color(0.35, 0.24, 0.14), Vector3(0, 0.2, 0)))
			staff.add_child(LowPoly.sphere(0.1, 6, 3, Color(0.45, 0.6, 1.0), Vector3(0, 0.95, 0), 0.2, 0.0, 3.0))
			sockets[&"r_hand"].add_child(staff)
		Kind.BOSS:
			torso.add_child(LowPoly.box(Vector3(0.56, 0.62, 0.32), Color(0.12, 0.08, 0.16), Vector3(0, 0.3, 0)))


func _collect_meshes() -> void:
	_meshes.clear()
	_collect(self)


func _collect(n: Node) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			_meshes.append(ch)
		_collect(ch)


## Перевешивает меши вещей по текущему набору: пожертвованные исчезают, на получателе растут добавки.
func refresh_items() -> void:
	for nodes in _item_nodes.values():
		for n in nodes:
			(n as Node).queue_free()
	_item_nodes.clear()
	for state in actor.items:
		var nodes := []
		for part in ItemVisuals.build(state):
			var socket: Node3D = sockets.get(part["socket"])
			if socket == null:
				socket = sockets[&"chest"]
			socket.add_child(part["node"])
			nodes.append(part["node"])
		_item_nodes[state.def_id] = nodes
	_hide_kind_weapons()
	_connect_actions()
	_collect_meshes.call_deferred()


func _connect_actions() -> void:
	var comps: Array = actor.components.values()
	if actor.innate != null:
		comps.append(actor.innate)
	for c in comps:
		var comp := c as ActionComponent
		if not comp.used.is_connected(_on_action_used):
			comp.used.connect(_on_action_used.bind(comp))


func _on_action_used(_ctx: ActionContext, comp: ActionComponent) -> void:
	if comp is SwordAction:
		var step := (comp as SwordAction).combo_step
		play_swing([&"slash", &"slash_back", &"chop"][clampi(step, 0, 2)], 0.3 if step == 2 else 0.2)
	elif comp is FistAction:
		play_swing(&"punch", 0.18)
	elif comp is GlovesAction:
		play_swing(&"grab", 0.3)
	elif comp is AmuletAction:
		play_swing(&"cast", 0.32)
	elif comp is EnemyAttack:
		match (comp as EnemyAttack).edef.behavior:
			EnemyDef.Behavior.CASTER:
				play_swing(&"cast", 0.3)
			EnemyDef.Behavior.RANGED:
				play_swing(&"punch", 0.2)
			EnemyDef.Behavior.SWARM:
				pass
			_:
				play_swing(&"chop", 0.22)


## Элита с мечом/щитом героя прячет собственное оружие.
func _hide_kind_weapons() -> void:
	var r_hand: Node3D = sockets[&"r_hand"]
	for ch in r_hand.get_children():
		if ch.name in ["EnemySword", "Club", "Staff"]:
			(ch as Node3D).visible = not actor.has_item(&"sword")


## Позиция сокета в мире: откуда летят потоки при жертве.
func socket_position(id: StringName) -> Vector3:
	var socket_name: StringName = &"chest"
	match id:
		&"sword": socket_name = &"r_hand"
		&"shield": socket_name = &"l_hand"
		&"helmet": socket_name = &"head"
		&"gloves": socket_name = &"r_hand"
		&"boots": socket_name = &"r_foot"
		&"amulet": socket_name = &"neck"
	var s: Node3D = sockets.get(socket_name)
	return s.global_position if s != null else global_position + Vector3(0, 1, 0)


func play_swing(kind_name: StringName, duration: float = 0.2) -> void:
	_swing_kind = kind_name
	_swing_dur = duration
	_swing_t = 0.0


func set_windup(progress: float) -> void:
	_windup = progress


func _on_hit(_amount: float, _crit: bool, _ctx: ActionContext) -> void:
	_flash = 0.09


func _on_died(_a: Actor) -> void:
	_dying = true
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", deg_to_rad(80), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", -0.6, 0.8).set_delay(0.3)


func _process(delta: float) -> void:
	if actor == null or _dying:
		return
	if actor.innate is EnemyAttack:
		_windup = (actor.innate as EnemyAttack).windup_progress()
	_animate(delta)
	_update_overlay(delta)


func _animate(delta: float) -> void:
	# Поворот к взгляду.
	var target_yaw := atan2(-actor.facing.x, -actor.facing.z)
	_yaw = lerp_angle(_yaw, target_yaw, minf(1.0, delta * 18.0))
	rotation.y = _yaw
	var speed := Combat.flat(actor.velocity).length()
	var moving := clampf(speed / maxf(actor.base_speed, 0.1), 0.0, 1.0)
	_walk += delta * (4.0 + speed * 1.6)
	var swing := sin(_walk) * 0.7 * moving
	leg_l.rotation.x = swing
	leg_r.rotation.x = -swing
	hips.position.y = 0.9 + absf(cos(_walk)) * 0.05 * moving
	torso.rotation = Vector3(-0.12 * moving, 0, 0)
	if actor.is_dashing():
		torso.rotation.x = -0.45
	if actor.stun_time > 0.0:
		torso.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.15
	# Руки: базовая поза плюс ходьба.
	var arm_l_basis := Basis(Vector3.RIGHT, -swing * 0.6)
	var arm_r_basis := Basis(Vector3.RIGHT, swing * 0.6)
	if actor.has_item(&"sword") or kind != Kind.HERO:
		arm_r_basis = Basis(Vector3.RIGHT, 0.35 + swing * 0.3)
	if actor.block_arc_degrees > 0.0:
		arm_l_basis = Basis(Vector3.UP, -0.9) * Basis(Vector3.RIGHT, 1.25)
	elif actor.has_item(&"shield"):
		arm_l_basis = Basis(Vector3.UP, -0.2) * Basis(Vector3.RIGHT, 0.4)
	# Замах врага: рука уходит назад-вверх.
	if _windup > 0.0:
		arm_r_basis = Basis(Vector3.RIGHT, lerpf(0.35, 2.6, _windup))
		torso.rotation.y = lerpf(0.0, 0.5, _windup)
	# Удар.
	_swing_t += delta
	if _swing_t < _swing_dur:
		var k := _swing_t / _swing_dur
		var e := 1.0 - pow(1.0 - k, 3.0)
		match _swing_kind:
			&"slash":
				arm_r_basis = Basis(Vector3.UP, lerpf(1.3, -1.1, e)) * Basis(Vector3.RIGHT, 1.45)
				torso.rotation.y = lerpf(0.5, -0.45, e)
			&"slash_back":
				arm_r_basis = Basis(Vector3.UP, lerpf(-1.1, 1.2, e)) * Basis(Vector3.RIGHT, 1.45)
				torso.rotation.y = lerpf(-0.45, 0.45, e)
			&"chop":
				arm_r_basis = Basis(Vector3.RIGHT, lerpf(2.9, 0.9, e))
				torso.rotation.x = lerpf(0.1, -0.35, e)
			&"punch":
				arm_r_basis = Basis(Vector3.RIGHT, lerpf(0.4, 1.55, sin(k * PI)))
				torso.rotation.y = lerpf(0.0, -0.35, sin(k * PI))
			&"cast":
				arm_r_basis = Basis(Vector3.RIGHT, lerpf(0.4, 2.4, sin(k * PI)))
				arm_l_basis = Basis(Vector3.RIGHT, lerpf(0.4, 2.4, sin(k * PI)))
			&"grab":
				arm_r_basis = Basis(Vector3.RIGHT, lerpf(1.55, 1.2, e))
				arm_l_basis = Basis(Vector3.RIGHT, lerpf(1.55, 1.2, e))
	arm_l.basis = arm_l_basis
	arm_r.basis = arm_r_basis


func _update_overlay(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	var overlay: Material = null
	if _flash > 0.0:
		overlay = _flash_mat
	elif actor.faction != Actor.Faction.HERO and _is_open_to_hero():
		overlay = _open_mat
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = overlay


## Окно уязвимости подсвечено, только если у героя есть шлем (или враг открыт Взором).
func _is_open_to_hero() -> bool:
	if actor.open_time > 0.0:
		return true
	var hero := Combat.hero
	if hero == null or not is_instance_valid(hero) or hero.dead:
		return false
	var w := hero.helmet_window()
	return w > 0.0 and actor.time_since_attack() <= w
