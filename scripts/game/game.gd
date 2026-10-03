class_name Game
extends Node3D
## Режиссёр забега: этапы 1–6 (3 волны + элитная волна → алтарь), этап 7 — босс.

signal state_changed(state: int)
signal wave_started(index: int, total: int)
signal banner(title: String, subtitle: String)

enum State { INTRO, WAVES, WAVE_PAUSE, SHRINE, CLEARED, ALTAR, SACRIFICE, TRANSITION, BOSS_INTRO, BOSS, OVER, CUTSCENE }

const ELITE_WAVE := 3
## Музыка битвы: «Ferrum et Sanguis», «Sacrificium», «Circulus», «Ultima Res» — в случайном порядке,
## каждый трек до конца, к этапам не привязаны (у босса свой трек).
const BATTLE_MUSIC: Array[StringName] = [&"music_battle_1", &"music_battle_2", &"music_battle_3", &"music_battle_4"]

var state: int = State.INTRO
var world: Node3D
var arena: Arena
var rig: CameraRig
var hero: Actor
var hero_model: ActorModel
var controller: PlayerController
var hud: Hud
var altar: Altar
var shrine: Shrine
var boss_director: BossDirector
## Сюжетные сцены: пролог, дары, дом Сольвейг, тронный зал, голос из дворца, ворота, реплики в бою, финал.
var cutscene: Cutscene
## Просмотр сцены из меню «Катсцены»: после неё игра не идёт дальше, а возвращает зрителя в галерею.
var theater: Theater
var wave: int = -1
var rng := RandomNumberGenerator.new()
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _pending_portals: int = 0
var _state_timer: float = 0.0
var _wave_time: float = 0.0
var _shrine_timer: float = 0.0
var _ui_lock: int = 0
var _hitstop_end: int = 0
var _mastery_unlocks: PackedStringArray = []


func _ready() -> void:
	add_to_group(&"game")
	rng.seed = RunState.seed_value + RunState.stage * 101
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	arena = Arena.new()
	arena.name = "Arena"
	world.add_child(arena)
	arena.build(Db.balance.arena_radius)
	Combat.arena_radius = Db.balance.arena_radius
	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	_spawn_hero()
	rig.target = hero
	rig.snap()
	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(self)
	Mastery.unlocked.connect(_on_mastery_unlocked)
	cutscene = Cutscene.new()
	add_child(cutscene)
	cutscene.setup(self)
	if Theater.requested():
		theater = Theater.new()
		theater.name = "Theater"
		add_child(theater)
		theater.run(self)
		return
	RunState.running = true
	start_stage(RunState.stage)


func _spawn_hero() -> void:
	var b := Db.balance
	hero = Actor.new()
	hero.name = "Hero"
	hero.faction = Actor.Faction.HERO
	hero.display_name = "Герой"
	hero.max_hp = b.hero_hp
	hero.hp = b.hero_hp
	hero.base_speed = b.hero_speed
	hero.speed_mult = RunState.speed_multiplier()
	hero.body_radius = 0.4
	hero.collision_layer = EnemyFactory.LAYER_HERO
	hero.collision_mask = EnemyFactory.LAYER_ENEMY
	hero.immortal = RunState.debug_immortal
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	hero.add_child(shape)
	world.add_child(hero)
	hero.set_items(RunState.ring.items.duplicate())
	hero.set_innate(FistAction.new())
	hero_model = SkinnedActorModel.for_hero()
	hero_model.name = "Model"
	hero.add_child(hero_model)
	hero_model.setup(hero, ActorModel.Kind.HERO)
	hero.add_child(HeroMarker.new())
	controller = PlayerController.new()
	controller.name = "PlayerController"
	hero.add_child(controller)
	controller.setup(hero, rig)
	hero.died.connect(_on_hero_died)
	hero.hit_received.connect(_on_hero_hit)
	hero.crit_dealt.connect(func(_ctx, _target): hitstop(0.045))
	Combat.hero = hero


func _on_hero_hit(amount: float, _crit: bool, ctx: ActionContext) -> void:
	if amount > 0.0:
		rig.shake(0.25)
		Audio.play(&"hero_hurt")
		var from := ctx.origin if ctx != null else hero.global_position
		BloodFx.spurt(world, hero.global_position + Vector3(0, 1.0, 0), hero.global_position - from, 6)
	if amount >= 15.0:
		hitstop(0.06)


## Короткая остановка кадра на сильных ударах. Таймер в реальном времени и идёт даже на паузе.
func hitstop(sec: float) -> void:
	if state == State.OVER or get_tree().paused or _hitstop_end > 0:
		return
	Engine.time_scale = 0.05
	_hitstop_end = 1
	get_tree().create_timer(sec, true, false, true).timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	_hitstop_end = 0
	if state != State.OVER:
		Engine.time_scale = 1.0


func set_state(s: int) -> void:
	state = s
	_state_timer = 0.0
	state_changed.emit(s)


## Ввод в героя блокируется, пока открыт хоть один экран (алтарь, пауза, дерево...).
func lock_input(on: bool) -> void:
	_ui_lock = maxi(_ui_lock + (1 if on else -1), 0)
	controller.enabled = _ui_lock == 0 and state != State.OVER


# --- Этапы ------------------------------------------------------------------

func start_stage(s: int) -> void:
	RunState.stage = s
	_clear_world()
	hero.global_position = Vector3(0, 0, 3)
	hero.heal_full()
	hero.speed_mult = RunState.speed_multiplier()
	hero.bus.reset_cooldowns()
	rig.snap()
	wave = -1
	var sigil: Array = []
	if RunState.is_boss_stage(s):
		for snap in RunState.snapshots:
			sigil.append(Db.item(snap.def_id).essence.color)
	arena.show_boss_sigil(sigil)
	if RunState.is_boss_stage(s):
		arena.set_tint(Color(0.24, 0.2, 0.22))
		_start_boss()
		return
	var threat := RunState.threat_for(s)
	arena.set_tint(threat.floor_tint)
	if s == 1 and RunState.sacrifices_count() == 0 and Cutscene.enabled():
		set_state(State.CUTSCENE)
		await PrologueScene.play(cutscene, self)
	set_state(State.INTRO)
	banner.emit("Этап %d" % s, "%s — %s" % [threat.display_name, threat.description])
	# После алтаря зажёванная лента битвы раскручивается с того же места.
	Audio.play_playlist(BATTLE_MUSIC)


func _clear_world() -> void:
	for ch in world.get_children():
		if ch == arena or ch == hero:
			continue
		ch.queue_free()
	_spawn_queue.clear()
	_pending_portals = 0
	altar = null
	shrine = null
	boss_director = null


func current_wave_total() -> int:
	return ELITE_WAVE + 1


func _count_scale() -> float:
	return 1.0 + Db.balance.wave_count_growth * maxi(RunState.stage - 2, 0)


func start_wave(index: int) -> void:
	wave = index
	_wave_time = 0.0
	var threat := RunState.current_threat()
	var comp: Dictionary = threat.waves[index] if index < threat.waves.size() else threat.elite_escort
	var list: Array[Dictionary] = []
	if index == ELITE_WAVE:
		comp = threat.elite_escort
		for i in threat.elite_count:
			var base: StringName = threat.elite_bases[rng.randi_range(0, threat.elite_bases.size() - 1)]
			var def := Db.enemy(base)
			list.append({"def": def, "items": _elite_items(def)})
	for id in comp.keys():
		var count := int(round(int(comp[id]) * _count_scale()))
		for k in count:
			list.append({"def": Db.enemy(StringName(id)), "items": [] as Array[ItemState]})
	# Перемешиваем, но элиты идут первыми.
	var elites := list.filter(func(e): return not (e["items"] as Array).is_empty())
	var rest := list.filter(func(e): return (e["items"] as Array).is_empty())
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Dictionary = rest[i]
		rest[i] = rest[j]
		rest[j] = t
	_spawn_queue.append_array(elites)
	_spawn_queue.append_array(rest)
	_spawn_timer = 0.3
	set_state(State.WAVES)
	wave_started.emit(index, current_wave_total())
	if index == ELITE_WAVE:
		banner.emit("Элитная волна", "враги с вещами героя")
		Audio.play(&"elite_horn")


## Вещи элиты: сначала уже пожертвованные (со свойствами на момент жертвы), потом любые.
func _elite_items(def: EnemyDef) -> Array[ItemState]:
	var pool := EnemyFactory.elite_item_pool(def)
	var n := rng.randi_range(1, Db.balance.elite_item_count_max)
	var sacrificed: Array[ItemState] = []
	for snap in RunState.snapshots:
		if snap.def_id in pool:
			sacrificed.append(snap)
	var out: Array[ItemState] = []
	while out.size() < n and not sacrificed.is_empty():
		var snap: ItemState = sacrificed.pop_at(rng.randi_range(0, sacrificed.size() - 1))
		out.append(snap.snapshot())
		pool.erase(snap.def_id)
	while out.size() < n and not pool.is_empty():
		var id: StringName = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		out.append(ItemState.create(id))
	return out


func alive_enemies() -> int:
	var n := 0
	for a in Combat.living_actors(get_tree()):
		if a.faction == Actor.Faction.ENEMY:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	_state_timer += delta
	match state:
		State.INTRO:
			if _state_timer > 2.2:
				start_wave(0)
		State.WAVES:
			_wave_time += delta
			_process_spawns(delta)
			var done_spawning := _spawn_queue.is_empty() and _pending_portals == 0
			if done_spawning and alive_enemies() == 0:
				_wave_cleared()
			elif done_spawning and wave < ELITE_WAVE and _wave_time > Db.balance.wave_timeout and alive_enemies() <= 2:
				_wave_cleared()
		State.WAVE_PAUSE:
			if _state_timer > Db.balance.wave_pause:
				start_wave(wave + 1)
		State.SHRINE:
			_shrine_timer -= delta
			if _shrine_timer <= 0.0 and _ui_lock == 0:
				shrine_done(false)
				start_wave(wave + 1)


func _process_spawns(delta: float) -> void:
	if _spawn_queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or alive_enemies() + _pending_portals >= Db.balance.max_alive_enemies:
		return
	_spawn_timer = 0.28 if RunState.stage > 1 else 0.45
	var entry: Dictionary = _spawn_queue.pop_front()
	var portal := SpawnPortal.new()
	portal.payload = entry
	world.add_child(portal)
	portal.global_position = _spawn_point()
	portal.opened.connect(_on_portal_opened)
	_pending_portals += 1


func _spawn_point() -> Vector3:
	var r := Combat.arena_radius - 2.0
	for attempt in 12:
		var a := rng.randf() * TAU
		var d := rng.randf_range(r * 0.55, r)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if Combat.flat(p - hero.global_position).length() > 6.5:
			return p
	return -Combat.flat_dir(hero.global_position, Vector3.FORWARD) * r


func _on_portal_opened(portal: SpawnPortal) -> void:
	_pending_portals = maxi(_pending_portals - 1, 0)
	var entry: Dictionary = portal.payload
	var items: Array[ItemState] = []
	items.assign(entry["items"])
	var enemy := EnemyFactory.create(entry["def"], RunState.stage, items)
	world.add_child(enemy)
	enemy.global_position = portal.global_position
	enemy.facing = Combat.flat_dir(hero.global_position - enemy.global_position)
	enemy.died.connect(_on_enemy_died)
	enemy.hit_received.connect(_on_enemy_hit.bind(enemy))
	portal.emerge(enemy)
	Audio.play(&"enemy_spawn", -12.0)


func _on_enemy_hit(amount: float, crit: bool, ctx: ActionContext, enemy: Actor) -> void:
	if amount <= 0.0 or not is_instance_valid(enemy):
		return
	var from := ctx.origin if ctx != null else hero.global_position
	BloodFx.spurt(world, enemy.global_position + Vector3(0, 0.9, 0), enemy.global_position - from, 14 if crit else 8, BloodFx.color_for(enemy))


func _on_enemy_died(enemy: Actor) -> void:
	Audio.play(&"enemy_death", -4.0)
	var col := BloodFx.color_for(enemy)
	BloodFx.spurt(world, enemy.global_position + Vector3(0, 0.8, 0), Vector3.UP, 18, col)
	if col == BloodFx.BLOOD:
		BloodFx.decal(world, enemy.global_position, 1.2 + enemy.body_radius * 1.6)
	_split(enemy)


## Слизень распадается на слизнёнышей.
func _split(enemy: Actor) -> void:
	if not enemy.has_meta(&"enemy_def"):
		return
	var def: EnemyDef = enemy.get_meta(&"enemy_def")
	if def.split_into == &"" or def.split_count <= 0:
		return
	Audio.play(&"slime_squish", 0.0)
	var child_def := Db.enemy(def.split_into)
	for i in def.split_count:
		var a := TAU * i / def.split_count + rng.randf() * 0.6
		var off := Vector3(cos(a), 0, sin(a)) * 0.7
		var child := EnemyFactory.create(child_def, RunState.stage)
		world.add_child(child)
		child.global_position = enemy.global_position + off
		child.facing = Combat.flat_dir(hero.global_position - child.global_position)
		child.force_move(off * 1.5, 0.2)
		child.died.connect(_on_enemy_died)
		child.hit_received.connect(_on_enemy_hit.bind(child))
	get_tree().create_timer(1.2).timeout.connect(_free_corpse.bind(enemy))


func _free_corpse(enemy: Actor) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()


func _wave_cleared() -> void:
	hero.restore_armor()
	var s := RunState.stage
	if wave == 1 and s in Db.balance.shrine_stages and not RunState.shrine_used.get(s, false):
		_spawn_shrine()
		return
	if wave < ELITE_WAVE:
		set_state(State.WAVE_PAUSE)
		return
	_stage_cleared()


func _spawn_shrine() -> void:
	shrine = Shrine.new()
	world.add_child(shrine)
	var a := rng.randf() * TAU
	shrine.global_position = Vector3(cos(a), 0, sin(a)) * 6.0
	shrine.stepped_on.connect(_on_shrine_stepped)
	_shrine_timer = Db.balance.shrine_wait
	set_state(State.SHRINE)
	banner.emit("Святилище", "один раз поменяет местами двух соседей в кольце")
	Audio.play(&"shrine_appear")


func _on_shrine_stepped() -> void:
	if RunState.shrine_used.get(RunState.stage, false):
		return
	hud.open_shrine()


## Святилище закрыто: обменом или отказом — в обоих случаях оно исчезает до конца этапа.
func shrine_done(swapped: bool) -> void:
	RunState.shrine_used[RunState.stage] = true
	if shrine != null:
		shrine.vanish()
		shrine = null
	if swapped:
		hero.set_items(RunState.ring.items.duplicate())
		Audio.play(&"shrine_swap")
	if state == State.SHRINE:
		_shrine_timer = minf(_shrine_timer, 1.0)


func _stage_cleared() -> void:
	set_state(State.CLEARED)
	if shrine != null:
		shrine.vanish()
		shrine = null
	Audio.play(&"stage_clear")
	spawn_altar()
	# Первый алтарь забега: правило мира — сценой, перед первым выбором жертвы; сцена идёт под музыку алтаря.
	if RuleScene.due() and Cutscene.enabled():
		Audio.tape_switch(&"music_altar")
		set_state(State.CUTSCENE)
		await RuleScene.play(cutscene, self)
		set_state(State.CLEARED)
	banner.emit("Этап пройден", "встаньте на алтарь")


func spawn_altar() -> void:
	altar = Altar.new()
	world.add_child(altar)
	altar.global_position = Vector3.ZERO
	altar.stepped_on.connect(_on_altar_stepped)


func _on_altar_stepped() -> void:
	if state != State.CLEARED:
		return
	set_state(State.ALTAR)
	hud.open_altar()
	# Музыку битвы зажёвывает, как плёнку, — играет алтарь.
	Audio.tape_switch(&"music_altar")


## Ушли с алтаря без жертвы — лента битвы раскручивается обратно.
func altar_closed() -> void:
	if state == State.ALTAR:
		set_state(State.CLEARED)
		Audio.tape_resume()


## Подтверждённая жертва ring[index].
func do_sacrifice(index: int) -> void:
	var victim_id := RunState.ring.items[index].def_id
	var victim_socket := hero_model.socket_position(victim_id)
	var old_count := RunState.ring.items[RunState.ring.recipient_index(index)].properties.size()
	var res := RunState.sacrifice(index)
	var recipient: ItemState = res["recipient"]
	set_state(State.SACRIFICE)
	if Cutscene.enabled():
		hero.speed_mult = RunState.speed_multiplier()
		if altar != null:
			altar.vanish()
			altar = null
		# Вещь уходит из рук героя внутри сцены — в тот момент, когда её передают получателю.
		await GiftScene.play(cutscene, self, {
			"victim": victim_id,
			"snapshot": res["victim_snapshot"],
			"recipient": recipient.def_id,
			"old_count": old_count,
			"property": res["property"],
			"ordinal": RunState.sacrifices_count(),
		})
		if theater != null:
			theater.leave()
			return
		_next_stage(true)
		return
	var victim_def := Db.item(victim_id)
	hero.set_items(RunState.ring.items.duplicate())
	var hidden := hero_model.hide_addons(recipient.def_id, old_count)
	SacrificeFx.play(world, hero_model, victim_socket, recipient.def_id, victim_def.essence.color, hidden)
	Audio.play(&"sacrifice")
	Audio.play(StringName("essence_%s" % victim_def.essence.id), -4.0)
	hero.speed_mult = RunState.speed_multiplier()
	if altar != null:
		altar.vanish()
		altar = null
	get_tree().create_timer(2.4, false).timeout.connect(_next_stage)


## after_gift — после сцены дара: в затемнении — песня Ильвы и дом Сольвейг (после второго дара) или её разговор
## с Сигвардом (после третьего), затем тронный зал и голос Сигварда из дворца. После последнего дара
## вместо голоса из дворца — песня Сигварда (если её дорожка на месте).
func _next_stage(after_gift: bool = false) -> void:
	set_state(State.TRANSITION)
	hud.fade(true, 0.5)
	await get_tree().create_timer(0.55, false).timeout
	var n := RunState.sacrifices_count()
	if after_gift and Cutscene.enabled():
		if n == Story.SONG_AFTER_GIFT:
			await IlvaSongScene.play(cutscene, self)
		if n == Story.HEARTH_AFTER_GIFT:
			await HearthScene.play(cutscene, self)
		elif n == Story.TEMPTATION_AFTER_GIFT:
			await TemptationScene.play(cutscene, self)
		if n == Story.BROTHER_SONG_AFTER_GIFT and SigvardSongScene.available():
			await SigvardSongScene.play(cutscene, self)
		elif n >= 1 and n <= Story.BROTHER_LINES.size():
			await PalaceScene.play(cutscene, self, n)
	start_stage(RunState.stage + 1)
	hud.fade(false, 0.6)


## Отладка: пропустить этап (сразу к алтарю или к следующему этапу).
func debug_skip_stage() -> void:
	if state == State.OVER:
		return
	for a in Combat.living_actors(get_tree()):
		if a.faction == Actor.Faction.ENEMY:
			a.die()
	_spawn_queue.clear()
	if RunState.is_boss_stage():
		return
	if state in [State.CLEARED, State.ALTAR, State.SACRIFICE]:
		_next_stage()
	else:
		_stage_cleared()


func debug_refresh_hero() -> void:
	hero.set_items(RunState.ring.items.duplicate())
	hero.speed_mult = RunState.speed_multiplier()
	hero.immortal = RunState.debug_immortal


# --- Босс -------------------------------------------------------------------

func _start_boss() -> void:
	set_state(State.BOSS_INTRO)
	var cinematic := Cutscene.enabled()
	if not cinematic:
		Audio.play_music(&"music_boss")
		banner.emit("Этап 7", "всё, что ты отдал, вернётся")
	boss_director = BossDirector.new()
	boss_director.name = "BossDirector"
	world.add_child(boss_director)
	boss_director.setup(self, cinematic)
	boss_director.intro_finished.connect(func(): set_state(State.BOSS))
	boss_director.boss_defeated.connect(_on_boss_defeated)
	boss_director.phase_changed.connect(_on_boss_phase)
	if cinematic:
		GatesScene.play(cutscene, self, boss_director)


func _on_boss_phase(p: int) -> void:
	if Cutscene.enabled():
		BossBarks.play(cutscene, p)


func _on_boss_defeated() -> void:
	if state == State.OVER or state == State.CUTSCENE:
		return
	RunState.outcome = RunState.Outcome.VICTORY
	if Cutscene.enabled():
		set_state(State.CUTSCENE)
		await FinaleScene.play(cutscene, self)
		_finish(0.3)
		return
	_finish(3.0)


func _on_hero_died(_a: Actor) -> void:
	if state == State.OVER:
		return
	RunState.outcome = RunState.Outcome.DEATH
	Audio.play(&"defeat")
	_finish(2.2)


func _finish(delay: float) -> void:
	set_state(State.OVER)
	RunState.running = false
	controller.enabled = false
	Engine.time_scale = 0.4
	await get_tree().create_timer(delay * 0.4).timeout
	Engine.time_scale = 1.0
	hud.fade(true, 0.6)
	await get_tree().create_timer(0.65).timeout
	if theater != null:
		theater.leave()
		return
	get_tree().change_scene_to_file("res://scenes/final_card.tscn")


func _on_mastery_unlocked(id: StringName, tier: int) -> void:
	if _mastery_unlocks.is_empty():
		_show_mastery_unlocks.call_deferred()
	_mastery_unlocks.append("%s %d" % [Db.item(id).display_name, tier])


func _show_mastery_unlocks() -> void:
	banner.emit("Открыты новые облики", " · ".join(_mastery_unlocks))
	_mastery_unlocks.clear()
