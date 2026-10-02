class_name GatesScene
extends RefCounted
## У ворот дворца (вступление босса). Все, кому Солдат отдал вещи, стоят у постаментов спиной к нему.
## Из ворот выходит Сигвард, говорит о зависти. Сольвейг подаёт ему вещи брата и признаётся,
## что любовь была наживкой. Вещи слетаются в Сигварда — и он становится рыцарем-боссом.
## Предатели отходят к воротам; к Солдату выходит только Ильва. Бой не изменён.

const GATE_ANGLE := -PI / 2
## Сигвард обходит первый постамент, который стоит ровно на пути от ворот.
const PATH_WAYPOINT := Vector3(1.7, 0, -10.2)
## Предатели у ворот смотрят на бой; Ильва ждёт у края арены за спиной Солдата.
const CROWD_LOOK := Vector3(0, 0, 2)
const IVA_SPOT := Vector3(3.2, 0, 12.6)


static func gate_position() -> Vector3:
	return Vector3(cos(GATE_ANGLE), 0, sin(GATE_ANGLE)) * (Combat.arena_radius + 1.2)


## Места предателей перед воротами: лицом к центру, во время боя они зрители.
static func crowd_slot(i: int) -> Vector3:
	var x := (-1.0 if i % 2 == 0 else 1.0) * (1.4 + (i / 2) * 1.25)
	return Vector3(x, 0, -13.4 + absf(x) * 0.12)


static func play(cs: Cutscene, game: Game, director: BossDirector) -> void:
	var gate := PalaceGate.new()
	gate.name = "PalaceGate"
	game.world.add_child(gate)
	gate.global_position = gate_position()
	var to_center := Combat.flat_dir(-gate.global_position)
	gate.rotation.y = atan2(to_center.x, to_center.z)
	game.arena.clear_edge_around(GATE_ANGLE, 0.5)
	cs.begin()
	Audio.stop_music(1.5)
	var present := _place_cast(cs, game)
	await _body(cs, game, director, gate, present)
	_finalize(cs, game, director, gate, present)
	game.banner.emit(Story.TYRANT_NAME, Story.GATES["banner_sub"])
	cs.end()
	director.start_fight()


## Получатели отданных вещей встают у своих постаментов, Сигвард — в проёме ворот, Ильва — за Солдатом.
static func _place_cast(cs: Cutscene, game: Game) -> Array[StringName]:
	var snaps := RunState.snapshots
	var n := maxi(snaps.size(), 1)
	var gate := gate_position()
	var present: Array[StringName] = []
	for i in snaps.size():
		var who: StringName = Story.gift(snaps[i].def_id).get("who", &"")
		if who == &"" or who == &"beloved" or present.has(who):
			continue
		var a := -PI / 2 + TAU * i / n
		var pos := Vector3(cos(a), 0, sin(a)) * (BossDirector.PEDESTAL_RADIUS + 1.3)
		cs.spawn(who, pos, gate)
		present.append(who)
	cs.spawn(&"brother", gate - Vector3(0, 0, 0.1), game.hero.global_position)
	var sol := cs.spawn(&"beloved", gate - Vector3(0, 0, 0.7), game.hero.global_position)
	sol.fade(0.0, 0.0)
	cs.spawn(&"faithful", game.hero.global_position + Vector3(0.9, 0, 1.6), BossDirector.BOSS_POS)
	return present


static func _body(cs: Cutscene, game: Game, d: BossDirector, gate: PalaceGate, present: Array[StringName]) -> void:
	var G := Story.GATES
	var hero := game.hero
	var hero_pos := hero.global_position
	var brother := cs.actor(&"brother")
	var sol := cs.actor(&"beloved")
	var iva := cs.actor(&"faithful")
	cs.face(hero, BossDirector.BOSS_POS)
	cs.cam(Vector3(0, 0.5, -2.0), 17.0, 0.0)
	cs.cam(Vector3(0, 0.5, -3.0), 14.5, 6.0)
	await cs.wait(1.6)
	await cs.thought(G["waited"])
	# Короткие реплики получателей — спиной к Солдату.
	var friend_spoke := false
	var spoke := 0
	for who in present:
		if spoke >= 3 or cs.skipped:
			break
		var line := _gate_line(who)
		var p := cs.actor(who)
		if line == "" or p == null:
			continue
		cs.cam(p.global_position + Vector3(0, 1.0, 0), 5.0, 1.1)
		await cs.wait(0.8)
		cs.tag(p, who, 3.5)
		await cs.say(who, line)
		friend_spoke = friend_spoke or who == &"friend"
		spoke += 1
	if cs.skipped:
		return
	# Ворота открываются.
	cs.cam(gate.global_position * 0.72 + Vector3(0, 1.6, 0), 9.0, 1.4)
	await cs.wait(1.2)
	gate.open(2.4)
	Audio.play(&"brute_slam", -2.0)
	Audio.play(&"zone_charge", -6.0)
	game.rig.shake(0.5)
	await cs.wait(2.2)
	cs.cam(Vector3(0.6, 1.2, -6.5), 8.0, 4.5)
	await cs.walk(brother, PATH_WAYPOINT, 2.0)
	await cs.walk(brother, BossDirector.BOSS_POS, 2.0)
	cs.face(brother, hero_pos)
	cs.tag(brother, &"brother", 4.0)
	if friend_spoke:
		await cs.say(&"brother", G["one_brother"])
	cs.cam((BossDirector.BOSS_POS + hero_pos) * 0.5 + Vector3(0, 1.0, 0), 8.5, 1.5)
	await cs.say(&"brother", G["hello"])
	# Монолог зависти: камера медленно наезжает на Сигварда.
	cs.cam(BossDirector.BOSS_POS + Vector3(0, 1.3, 0), 4.2, 9.0)
	await cs.say(&"brother", G["envy_1"])
	await cs.say(&"brother", G["envy_2"])
	await cs.say(&"brother", G["envy_3"])
	cs.cam(hero_pos + Vector3(0, 1.1, 0), 4.6, 0.8)
	await cs.say(&"hero", G["not_things"])
	cs.cam(BossDirector.BOSS_POS + Vector3(0, 1.2, 0), 5.0, 0.8)
	await cs.say(&"brother", G["we_will_see"])
	if cs.skipped:
		return
	# Сольвейг выходит из ворот и встаёт рядом с Сигвардом.
	sol.fade(1.0, 0.8)
	cs.cam(Vector3(0.8, 1.0, -5.5), 7.5, 2.4)
	await cs.walk(sol, PATH_WAYPOINT + Vector3(0.6, 0, 0))
	await cs.walk(sol, BossDirector.BOSS_POS + Vector3(1.5, 0, -0.5))
	cs.face(sol, hero_pos)
	cs.tag(sol, &"beloved", 3.0)
	await cs.wait(0.5)
	# Молча поднимает руку — вещи брата слетаются в Сигварда; получатели отворачиваются к нему.
	sol.set_pose(&"arms_up")
	brother.set_pose(&"arms_up")
	cs.cam(Vector3(0, 1.5, -3.0), 12.5, 1.0)
	var snaps := RunState.snapshots
	var on_item := func(i: int) -> void:
		var who: StringName = Story.gift(snaps[i].def_id).get("who", &"")
		var p := cs.actor(who)
		if p != null and who != &"beloved":
			p.look_toward(BossDirector.BOSS_POS)
	cs.skip_requested.connect(d.skip_assembly)
	await d.assemble_items(on_item)
	cs.skip_requested.disconnect(d.skip_assembly)
	sol.set_pose(&"")
	brother.set_pose(&"")
	if Story.was_given(snaps, &"gloves"):
		cs.cam(BossDirector.BOSS_POS + Vector3(0, 1.3, 0), 4.5, 0.8)
		await cs.say(&"brother", G["ring_at_last"])
	cs.cam(sol.global_position + Vector3(0, 1.1, 0), 4.4, 1.0)
	var confession: String = G["confess_given"] if Story.was_given(snaps, &"amulet") else G["confess_kept"]
	await cs.say(&"beloved", confession)
	if cs.skipped:
		return
	# Превращение: брат во всём, что отдал Солдат.
	cs.cam(BossDirector.BOSS_POS + Vector3(0, 1.6, 0), 9.0, 0.6)
	await cs.wait(0.4)
	Vfx.burst(brother, BossDirector.BOSS_POS + Vector3(0, 1.4, 0), Color(0.75, 0.55, 1.0), 3.2, 0.5)
	brother.fade(0.0, 0.25)
	d.reveal_boss()
	d.freeze_boss.call_deferred()
	Audio.play_music(&"music_boss")
	await cs.wait(1.3)
	await cs.say(&"brother", G["unbreakable"])
	# Предатели и Сольвейг отходят к воротам — встают рядом с врагом.
	var crowd := present.duplicate()
	crowd.append(&"beloved")
	for i in crowd.size():
		var p := cs.actor(crowd[i])
		if p != null:
			p.set_meta(&"home", crowd_slot(i))
			cs.walk_then_face(p, crowd_slot(i), CROWD_LOOK)
	# Ильва выходит из-за спины Солдата.
	cs.cam(hero_pos + Vector3(0.4, 1.0, 0), 4.6, 1.4)
	await cs.walk(iva, hero_pos + Vector3(1.0, 0, 0.4))
	cs.face(iva, hero_pos)
	await cs.say(&"faithful", G["here"])
	await cs.say(&"hero", G["i_know"])
	cs.walk_then_face(iva, IVA_SPOT, BossDirector.BOSS_POS)
	cs.cam(hero_pos + Vector3(0, 1.0, -2.0), 9.0, 1.6)
	await cs.thought(G["know_things"])


static func _gate_line(who: StringName) -> String:
	for id in Story.GIFTS:
		var g: Dictionary = Story.GIFTS[id]
		if g["who"] == who:
			return g.get("gate", "")
	return ""


## Конечное состояние, даже если сцену пропустили на любом шаге.
static func _finalize(cs: Cutscene, game: Game, d: BossDirector, gate: PalaceGate, present: Array[StringName]) -> void:
	if not gate.is_open():
		gate.open(0.0)
	d.skip_assembly()
	if cs.skip_requested.is_connected(d.skip_assembly):
		cs.skip_requested.disconnect(d.skip_assembly)
	var brother := cs.actor(&"brother")
	if brother != null:
		brother.set_pose(&"")
		brother.fade(0.0, 0.0)
	d.reveal_boss()
	d.freeze_boss()
	Audio.play_music(&"music_boss")
	var crowd := present.duplicate()
	crowd.append(&"beloved")
	for i in crowd.size():
		var p := cs.actor(crowd[i])
		if p != null:
			p.set_meta(&"home", crowd_slot(i))
			p.set_pose(&"")
			p.fade(1.0, 0.0)
			if cs.skipped:
				cs.walk(p, crowd_slot(i))
				p.look_toward(CROWD_LOOK)
	var iva := cs.actor(&"faithful")
	if iva != null and cs.skipped:
		cs.walk(iva, IVA_SPOT)
		iva.look_toward(BossDirector.BOSS_POS)
	cs.face(game.hero, BossDirector.BOSS_POS)
