class_name BossDirector
extends Node3D
## Босс «Отвергнутый»: носит снимки шести пожертвованных вещей.
## Вступление: вещи слетаются с постаментов по кругу арены и собирают рыцаря.
## Фазы: 100–60% — все шесть вещей; 60–25% — три первые жертвы; 25–0% — только первая.

signal intro_finished
signal boss_defeated
signal phase_changed(phase: int)

const PEDESTAL_RADIUS := 9.0
const BOSS_POS := Vector3(0, 0, -3)

var game: Game
var boss: Actor
var boss_model: ActorModel
var phase: int = 0
var _pedestals: Array[Node3D] = []
var _displays: Array[Node3D] = []


func setup(p_game: Game) -> void:
	game = p_game
	game.hero.global_position = Vector3(0, 0, 7)
	game.rig.snap()
	game.lock_input(true)
	_build_pedestals()
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
		ped.add_child(LowPoly.cyl(0.6, 0.75, 1.0, 6, Color(0.3, 0.27, 0.3), Vector3(0, 0.5, 0)))
		ped.add_child(LowPoly.cyl(0.75, 0.75, 0.1, 6, Color(0.5, 0.42, 0.6), Vector3(0, 1.05, 0), 0.5, 0.3))
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


func _intro() -> void:
	await get_tree().create_timer(1.6, false).timeout
	var center := BOSS_POS + Vector3(0, 1.6, 0)
	for i in _displays.size():
		var d := _displays[i]
		var tw := d.create_tween().set_parallel(true)
		var mid := (d.global_position + center) * 0.5 + Vector3(0, 3.0, 0)
		tw.tween_method(_bezier.bind(d, d.global_position, mid, center), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(d, "scale", Vector3.ONE * 0.8, 0.7)
		Audio.play(&"item_fly", -4.0)
		await get_tree().create_timer(0.32, false).timeout
	await get_tree().create_timer(0.6, false).timeout
	for d in _displays:
		if is_instance_valid(d):
			d.queue_free()
	_displays.clear()
	_spawn_boss()
	Vfx.ring(self, BOSS_POS, 6.0, Color(0.7, 0.4, 1.0), 0.6, 0.5)
	Vfx.burst(self, BOSS_POS + Vector3(0, 1.5, 0), Color(0.7, 0.4, 1.0), 3.0, 0.4)
	Audio.play(&"boss_roar")
	game.rig.shake(0.8)
	await get_tree().create_timer(1.0, false).timeout
	game.lock_input(false)
	boss.get_node("AI").set_physics_process(true)
	intro_finished.emit()


func _bezier(t: float, node: Node3D, a: Vector3, b: Vector3, c: Vector3) -> void:
	if is_instance_valid(node):
		node.global_position = a.lerp(b, t).lerp(b.lerp(c, t), t)


func _spawn_boss() -> void:
	var b := Db.balance
	var def: EnemyDef = load("res://data/enemies/boss.tres")
	boss = Actor.new()
	boss.name = "Boss"
	boss.faction = Actor.Faction.ENEMY
	boss.display_name = "Отвергнутый"
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
	boss_model = ActorModel.new()
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
	ai.set_physics_process(false)
	game.world.add_child(boss)
	boss.global_position = BOSS_POS
	boss.facing = Vector3.BACK
	boss.damaged.connect(_on_boss_damaged)
	boss.died.connect(_on_boss_died)
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
	Vfx.ring(self, boss.global_position, 5.0, Color(0.7, 0.4, 1.0), 0.5, 0.6)
	Audio.play(&"boss_phase")
	game.rig.shake(0.7)
	phase_changed.emit(p)
	game.banner.emit("Фаза %d" % (p + 1), "Отвергнутый сбрасывает вещи и ускоряется")


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
	Vfx.burst(self, boss.global_position + Vector3(0, 1.5, 0), Color(0.75, 0.45, 1.0), 4.0, 0.6)
	Audio.play(&"boss_death")
	game.rig.shake(1.0)
	boss_defeated.emit()
