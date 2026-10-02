class_name BossDirector
extends Node3D
## Босс — Тиран (Сигвард, старший брат героя): носит снимки шести пожертвованных вещей.
## Вступление: вещи слетаются с постаментов по кругу арены и собирают рыцаря.
## Фазы: 100–60% — все шесть вещей; 60–25% — три первые жертвы; 25–0% — только первая.

signal intro_finished
signal boss_defeated
signal phase_changed(phase: int)

const PEDESTAL_RADIUS := 9.0
const BOSS_POS := Vector3(0, 0, -3)
## Вступление без сюжетных сцен: герой на одной вертикали кадра с боссом (камера смотрит вдоль (-1, 0, -1)).
const HERO_POS_SOLO := BOSS_POS + Vector3(6, 0, 6)

var game: Game
var boss: Actor
var boss_model: ActorModel
var phase: int = 0
var _pedestals: Array[Node3D] = []
var _displays: Array[Node3D] = []
var _assembly_aborted: bool = false
var _fight_started: bool = false


## cinematic — вступление ведёт сюжетная сцена (GatesScene) через assemble_items / reveal_boss / start_fight.
func setup(p_game: Game, cinematic: bool = false) -> void:
	game = p_game
	game.hero.global_position = Vector3(0, 0, 7) if cinematic else HERO_POS_SOLO
	game.hero.aim_point = BOSS_POS
	game.hero.facing = Combat.flat_dir(BOSS_POS - game.hero.global_position)
	game.rig.snap()
	game.lock_input(true)
	_build_pedestals()
	if not cinematic:
		_intro()


func _build_pedestals() -> void:
	var snaps := RunState.snapshots
	var n := maxi(snaps.size(), 1)
	for i in snaps.size():
		var a := -PI / 2 + TAU * i / n
		var pos := Vector3(cos(a), 0, sin(a)) * PEDESTAL_RADIUS
		var ped := Node3D.new()
		add_child(ped)
		ped.global_position = pos
		# Каменный алтарь со свечами и подтёками крови.
		ped.add_child(LowPoly.box(Vector3(1.2, 1.0, 1.2), Color(0.8, 0.75, 0.72), Vector3(0, 0.5, 0), 0.95, 0.0, 0.0, &"brick"))
		ped.add_child(LowPoly.box(Vector3(1.35, 0.14, 1.35), Color(0.7, 0.66, 0.64), Vector3(0, 1.07, 0), 0.95, 0.0, 0.0, &"stone"))
		ped.add_child(LowPoly.box(Vector3(0.3, 0.9, 0.02), Color(0.4, 0.03, 0.03), Vector3(0.2, 0.55, -0.61)))
		for c in 3:
			var cx := -0.45 + c * 0.45
			ped.add_child(LowPoly.cyl(0.04, 0.05, 0.22 + c * 0.06, 5, Color(0.9, 0.86, 0.76), Vector3(cx, 1.25 + c * 0.03, 0.5)))
			ped.add_child(LowPoly.prism(Vector3(0.05, 0.1, 0.05), Color(1.0, 0.55, 0.2), Vector3(cx, 1.42 + c * 0.06, 0.5), 0.5, 0.0, 4.0))
		var display := ItemVisuals.build_display(snaps[i])
		display.scale = Vector3.ONE * 1.4
		add_child(display)
		display.global_position = pos + Vector3(0, 1.8, 0)
		var glow := OmniLight3D.new()
		glow.light_color = Db.item(snaps[i].def_id).essence.color
		glow.light_energy = 1.2
		glow.omni_range = 3.0
		glow.position = Vector3(0, 2.2, 0)
		ped.add_child(glow)
		_pedestals.append(ped)
		_displays.append(display)


func _process(delta: float) -> void:
	for d in _displays:
		if is_instance_valid(d):
			d.rotation.y += delta * 0.8


## Вступление без сюжетных сцен: камера отъезжает к центру, из тёмного вихря проступает пустой рыцарь,
## вещи по одной слетаются с постаментов прямо на свои места, над головой загорается корона.
func _intro() -> void:
	game.rig.cine_to(BOSS_POS + Vector3(1.7, 0, 1.7), 15.5, 1.4)
	game.hud.set_cinematic(true)
	game.hud.letterbox(true)
	Audio.play(&"boss_phase", -6.0)
	await get_tree().create_timer(1.1, false).timeout
	_spawn_boss(false)
	boss_model.hide_all_items()
	_vortex()
	# Наезд: пока рыцарь собирается, камера подъезжает к нему. Точка чуть «за» боссом:
	# рыцарь ростом под четыре метра встаёт в центр кадра, под титр.
	var assembly := 1.7 + _displays.size() * 0.5 + 0.8
	game.rig.cine_to(BOSS_POS + Vector3(-1.1, 0, -1.1), 10.0, assembly)
	await get_tree().create_timer(1.7, false).timeout
	for i in _displays.size():
		_fly_to_boss(_displays[i], RunState.snapshots[i].def_id)
		await get_tree().create_timer(0.5, false).timeout
	await get_tree().create_timer(0.8, false).timeout
	_displays.clear()
	Vfx.ring(self, BOSS_POS, 7.0, Color(0.7, 0.8, 1.0, 0.7), 0.8, 0.35)
	Vfx.ring(self, BOSS_POS, 4.0, Color(0.6, 0.05, 0.04, 0.8), 0.6, 0.5)
	Audio.play(&"boss_roar")
	game.rig.shake(0.9)
	game.banner.emit(Story.TYRANT_NAME, "собран из всего, что ты отдал")
	await get_tree().create_timer(1.6, false).timeout
	game.hud.set_cinematic(false)
	game.hud.letterbox(false)
	game.rig.cine_release(0.9)
	await get_tree().create_timer(0.5, false).timeout
	start_fight()


## Тёмный вихрь: тело рыцаря поднимается из него.
func _vortex() -> void:
	var def: EnemyDef = load("res://data/enemies/boss.tres")
	boss_model.scale = Vector3(0.05, 0.05, 0.05)
	var tw := boss_model.create_tween()
	tw.tween_property(boss_model, "scale", Vector3.ONE * def.scale, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for k in 3:
		var ring := MeshInstance3D.new()
		ring.mesh = Vfx.ring_mesh(1.0, 0.18, 24)
		ring.material_override = Vfx.material(Color(0.05, 0.02, 0.06, 0.85), 1.0, false)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.global_position = BOSS_POS + Vector3(0, 0.05 + k * 0.6, 0)
		ring.scale = Vector3.ONE * (2.6 - k * 0.6)
		var rt := ring.create_tween().set_parallel(true)
		rt.tween_property(ring, "rotation:y", TAU * (2.0 if k % 2 == 0 else -2.0), 2.2)
		rt.tween_property(ring, "scale", Vector3.ONE * 0.2, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		rt.chain().tween_callback(ring.queue_free)
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.explosiveness = 0.2
	smoke.amount = 40
	smoke.lifetime = 1.6
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.2
	smoke.direction = Vector3.UP
	smoke.spread = 25.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.5
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.scale_amount_min = 0.15
	smoke.scale_amount_max = 0.35
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	smoke.mesh = cube
	smoke.material_override = Vfx.material(Color(0.08, 0.04, 0.1, 0.8), 1.0, false)
	add_child(smoke)
	smoke.global_position = BOSS_POS + Vector3(0, 0.6, 0)
	smoke.emitting = true
	get_tree().create_timer(3.0).timeout.connect(smoke.queue_free)


## Вещь слетает с постамента на своё место на теле рыцаря и проявляется там.
func _fly_to_boss(display: Node3D, id: StringName) -> void:
	if not is_instance_valid(display):
		return
	var from := display.global_position
	var color := Db.item(id).essence.color
	Audio.play(&"item_fly", -3.0)
	var tw := display.create_tween().set_parallel(true)
	tw.tween_method(func(t: float):
		if not is_instance_valid(display) or not is_instance_valid(boss_model):
			return
		var to := boss_model.socket_position(id)
		var mid := (from + to) * 0.5 + Vector3(0, 3.5, 0)
		display.global_position = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		display.rotation.y += 0.25
	, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(display, "scale", Vector3.ONE * 0.6, 0.6)
	tw.chain().tween_callback(func():
		if is_instance_valid(boss_model):
			var at := boss_model.socket_position(id)
			boss_model.reveal_item(id)
			Vfx.burst(self, at, Color(color, 0.6), 0.55, 0.25)
			Vfx.ring(self, Vector3(BOSS_POS.x, 0.0, BOSS_POS.z), 2.5, color, 0.4, 0.2)
			Audio.play(&"absorb", -4.0)
			game.rig.shake(0.25)
		display.queue_free()
	)


## Вещи по одной слетаются с постаментов в точку босса. on_item(i) — после вылета i-й вещи.
func assemble_items(on_item: Callable = Callable()) -> void:
	var center := BOSS_POS + Vector3(0, 1.6, 0)
	for i in _displays.size():
		if _assembly_aborted:
			break
		var d := _displays[i]
		var tw := d.create_tween().set_parallel(true)
		var mid := (d.global_position + center) * 0.5 + Vector3(0, 3.0, 0)
		tw.tween_method(_bezier.bind(d, d.global_position, mid, center), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(d, "scale", Vector3.ONE * 0.8, 0.7)
		Audio.play(&"item_fly", -4.0)
		if on_item.is_valid():
			on_item.call(i)
		await get_tree().create_timer(0.32, false).timeout
	if not _assembly_aborted:
		await get_tree().create_timer(0.6, false).timeout
	_clear_displays()


## Пропуск сцены посреди сборки: вещи исчезают сразу.
func skip_assembly() -> void:
	_assembly_aborted = true
	_clear_displays()


func _clear_displays() -> void:
	for d in _displays:
		if is_instance_valid(d):
			d.queue_free()
	_displays.clear()


## Босс появляется в точке сборки: кольцо, вспышка, рёв. Повторный вызов ничего не делает.
func reveal_boss() -> void:
	if boss != null:
		return
	_spawn_boss()
	Vfx.ring(self, BOSS_POS, 6.0, Color(0.9, 0.15, 0.08), 0.6, 0.5)
	Vfx.burst(self, BOSS_POS + Vector3(0, 1.5, 0), Color(0.9, 0.15, 0.08), 3.0, 0.4)
	Audio.play(&"boss_roar")
	game.rig.shake(0.8)


## Сюжетная сцена идёт после появления босса: он стоит и ждёт, пока не начнётся бой.
## (ИИ включается сам, когда босс входит в дерево, поэтому выключаем его уже после.)
func freeze_boss() -> void:
	if boss == null or _fight_started:
		return
	var ai := boss.get_node("AI") as AIController
	ai.active = false
	ai.set_physics_process(false)
	boss.move_input = Vector3.ZERO
	boss.global_position = BOSS_POS
	boss.facing = Vector3.BACK


func start_fight() -> void:
	if _fight_started:
		return
	_fight_started = true
	game.lock_input(false)
	var ai := boss.get_node("AI") as AIController
	ai.active = true
	ai.set_physics_process(true)
	boss.invuln_time = 0.0
	intro_finished.emit()


func _bezier(t: float, node: Node3D, a: Vector3, b: Vector3, c: Vector3) -> void:
	if is_instance_valid(node):
		node.global_position = a.lerp(b, t).lerp(b.lerp(c, t), t)


## pop — короткое «выпрыгивание» модели (сюжетная сцена); у сольного вступления свой вихрь.
func _spawn_boss(pop: bool = true) -> void:
	var b := Db.balance
	var def: EnemyDef = load("res://data/enemies/boss.tres")
	boss = Actor.new()
	boss.name = "Boss"
	boss.faction = Actor.Faction.ENEMY
	boss.display_name = Story.TYRANT_NAME
	boss.max_hp = b.boss_hp
	boss.hp = b.boss_hp
	boss.base_speed = b.boss_phase_speeds[0]
	boss.body_radius = def.body_radius
	boss.knockback_immune = true
	boss.collision_layer = EnemyFactory.LAYER_ENEMY
	boss.collision_mask = EnemyFactory.LAYER_HERO
	boss.set_meta(&"boss", true)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = def.body_radius
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	boss.add_child(shape)
	var atk := EnemyAttack.new()
	atk.configure(def, def.damage)
	boss.set_innate(atk)
	boss.set_items(_phase_items(0))
	boss.item_damage_mult = b.enemy_item_damage_mult
	boss_model = SkinnedActorModel.for_boss()
	boss_model.name = "Model"
	boss.add_child(boss_model)
	boss_model.setup(boss, ActorModel.Kind.BOSS, Color(0.16, 0.11, 0.2), Color(0.1, 0.07, 0.12))
	boss_model.scale = Vector3.ONE * def.scale
	var ai := AIController.new()
	ai.name = "AI"
	ai.is_boss = true
	boss.add_child(ai)
	ai.setup(boss, def, atk)
	ai.action_gap = b.boss_action_gaps[0]
	ai.active = false
	game.world.add_child(boss)
	boss.global_position = BOSS_POS
	boss.facing = Combat.flat_dir(game.hero.global_position - BOSS_POS, Vector3.BACK)
	# Пока вступление не кончилось, босса нельзя ранить.
	boss.add_invulnerability(999.0)
	boss.damaged.connect(_on_boss_damaged)
	boss.died.connect(_on_boss_died)
	if not pop:
		return
	boss_model.scale = Vector3.ONE * 0.2
	boss_model.create_tween().tween_property(boss_model, "scale", Vector3.ONE * def.scale, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Снимки вещей для фазы: все шесть, три первые жертвы, первая жертва.
func _phase_items(p: int) -> Array[ItemState]:
	var count: int = Db.balance.boss_phase_item_counts[p]
	var out: Array[ItemState] = []
	for i in mini(count, RunState.snapshots.size()):
		out.append(RunState.snapshots[i])
	return out


func _on_boss_damaged(_amount: float, _ctx: ActionContext) -> void:
	var ratio := boss.hp / boss.max_hp
	var th := Db.balance.boss_phase_thresholds
	var next := phase
	if phase == 0 and ratio <= th[0]:
		next = 1
	if next >= 1 and ratio <= th[1]:
		next = 2
	if next != phase and not boss.dead:
		_enter_phase(next)


func _enter_phase(p: int) -> void:
	var old_items := boss.items.duplicate()
	phase = p
	var keep := _phase_items(p)
	# Отброшенные вещи разлетаются.
	for s in old_items:
		if not keep.has(s):
			_fling(s)
	boss.set_items(keep)
	boss.base_speed = Db.balance.boss_phase_speeds[p]
	(boss.get_node("AI") as AIController).action_gap = Db.balance.boss_action_gaps[p]
	if Db.balance.boss_armor_restore_on_phase:
		boss.restore_armor()
	boss.add_invulnerability(1.0)
	for t in Combat.targets_in_radius(boss, boss.global_position, 4.0):
		t.force_move(Combat.flat_dir(t.global_position - boss.global_position) * 3.0, 0.2)
	Vfx.ring(self, boss.global_position, 5.0, Color(0.9, 0.15, 0.08), 0.5, 0.6)
	Audio.play(&"boss_phase")
	game.rig.shake(0.7)
	phase_changed.emit(p)
	game.banner.emit("Фаза %d" % (p + 1), "%s сбрасывает вещи и ускоряется" % Story.TYRANT_NAME)


func _fling(state: ItemState) -> void:
	var d := ItemVisuals.build_display(state)
	add_child(d)
	var from := boss_model.socket_position(state.def_id)
	d.global_position = from
	var away := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(5.0, 8.0)
	var tw := d.create_tween().set_parallel(true)
	tw.tween_property(d, "global_position", from + away + Vector3(0, -from.y + 0.3, 0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.8)
	tw.chain().tween_property(d, "scale", Vector3.ONE * 0.01, 1.5).set_delay(1.0)
	tw.chain().tween_callback(d.queue_free)


func _on_boss_died(_a: Actor) -> void:
	for s in boss.items:
		_fling(s)
	Vfx.burst(self, boss.global_position + Vector3(0, 1.5, 0), Color(0.9, 0.15, 0.08), 4.0, 0.6)
	Audio.play(&"boss_death")
	game.rig.shake(1.0)
	boss_defeated.emit()
