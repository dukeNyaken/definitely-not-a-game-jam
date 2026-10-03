class_name FinaleScene
extends RefCounted
## Финал после победы. Рыцарь рассыпается в замедлении — на коленях остаётся Сигвард, просто человек,
## похожий на брата. Солдат узнаёт каждую отданную вещь: она вспыхивает своим цветом, пока он вспоминает,
## где она подвела. Бьёрн закрывает Тирана щитом — и не успевает левой. Последний дар: Солдат сам
## отдаёт брату отцовский перстень — золотой столб света. Сольвейг остаётся позади; Солдат уходит
## с Ильвой, и кадр теплеет, как на рассвете. Сцена заканчивается в темноте — дальше карточка.

const GOLD := Color(1.0, 0.8, 0.35)
const TYRANT_GLOW := Color(0.75, 0.55, 1.0)
const EXIT := Vector3(0.6, 0, 14.2)


static func play(cs: Cutscene, game: Game) -> void:
	cs.clear_barks()
	cs.begin()
	await _body(cs, game)
	_finalize(cs, game)
	cs.end(false)


static func _ensure(cs: Cutscene, key: StringName, pos: Vector3, look: Vector3) -> Puppet:
	var p := cs.actor(key)
	if p == null:
		p = cs.spawn(key, pos, look)
		p.set_meta(&"home", pos)
	return p


static func _body(cs: Cutscene, game: Game) -> void:
	var F := Story.FINALE
	var hero := game.hero
	var hm := game.hero_model
	var world := game.world
	var d := game.boss_director
	var snaps := RunState.snapshots
	var boss_pos := BossDirector.BOSS_POS
	if d != null and d.boss != null and is_instance_valid(d.boss):
		boss_pos = Combat.flat(d.boss.global_position)
	var up := Vector3(0, 1.0, 0)
	# Замедление: рыцарь рассыпается.
	cs.cam(boss_pos + Vector3(0, 1.2, 0), 6.5, 0.8)
	cs.slowmo(0.35, 1.4)
	cs.flash(Color.WHITE, 0.9, 0.6)
	Vfx.ring(hero, boss_pos, 7.0, TYRANT_GLOW, 1.0, 0.4)
	CutsceneFx.dust(world, boss_pos, 2.5, Color(0.5, 0.42, 0.45, 0.7), 40)
	await cs.wait(1.4)
	# На его месте — человек на коленях.
	var brother := _ensure(cs, &"brother", boss_pos, hero.global_position)
	brother.global_position = boss_pos
	brother.look_toward(hero.global_position)
	brother.set_pose(&"kneel")
	brother.fade(0.0, 0.0)
	brother.fade(1.0, 0.9)
	if d != null and d.boss != null and is_instance_valid(d.boss):
		d.boss.visible = false
	Vfx.burst(brother, boss_pos + Vector3(0, 1.0, 0), TYRANT_GLOW, 2.6, 0.6)
	cs.motes(boss_pos + Vector3(0, 1.0, 0), Vector3(1.2, 0.8, 1.2), TYRANT_GLOW, 24, 0.4)
	Audio.play(&"absorb", -4.0)
	await cs.wait(0.8)
	var to_b := Combat.flat_dir(boss_pos - hero.global_position, Vector3.FORWARD)
	var side := Vector3(to_b.z, 0, -to_b.x)
	var stand := boss_pos - to_b * 2.2
	cs.cam((boss_pos + stand) * 0.5 + up, 6.0, 1.6)
	await cs.walk(hero, stand)
	cs.face(hero, boss_pos)
	cs.cam(boss_pos + up * 0.9, 3.4, 1.2)
	cs.orbit(-10.0, 5.0)
	await cs.say(&"brother", F["how"])
	cs.orbit(0.0, 1.0)
	if cs.skipped:
		return
	# Монтаж: отданные вещи лежат вокруг Сигварда. Солдат знает каждую — и каждая вспыхивает.
	var ids := Story.finale_items(snaps, 4)
	var spots := {}
	for k in ids.size():
		var off := k - (ids.size() - 1) * 0.5
		var pos := boss_pos + to_b * 1.1 + side * off * 1.2
		var disp := cs.prop(ItemVisuals.build_display(_snapshot(snaps, ids[k])))
		disp.global_position = pos + Vector3(0, 0.15, 0)
		disp.rotation = Vector3(PI / 2, 0.0, randf_range(-0.6, 0.6))
		disp.scale = Vector3.ONE * 0.85
		spots[ids[k]] = pos
	var tilt := -8.0
	for id in ids:
		if cs.skipped:
			return
		var col := Db.item(id).essence.color
		cs.cam(spots[id] + Vector3(0, 0.4, 0), 2.6, 0.9)
		cs.orbit(tilt, 1.2)
		tilt = -tilt
		await cs.wait(0.6)
		CutsceneFx.flare(world, spots[id] + Vector3(0, 0.4, 0), col, 2.6, 2.6, 1.6)
		Vfx.burst(hero, spots[id] + Vector3(0, 0.2, 0), col, 0.7, 0.4)
		Audio.play(StringName("essence_%s" % Db.item(id).essence.id), -12.0)
		await cs.thought(Story.gift(id).get("payoff", ""))
	cs.orbit(0.0, 0.8)
	# Бьёрн закрывает Тирана щитом — и не успевает поднять его левой.
	if Story.was_given(snaps, &"gloves"):
		await _captain(cs, game, boss_pos, stand)
		if cs.skipped:
			return
	cs.cam((boss_pos + stand) * 0.5 + up, 4.6, 1.0)
	await cs.say(&"hero", F["never_helped"])
	cs.cam(boss_pos + up * 0.9, 3.4, 0.8)
	await cs.say(&"brother", F["father_knew"])
	if cs.skipped:
		return
	# Последний дар: перстень отца — добровольно.
	var ring := cs.prop(NpcLooks.father_ring(true))
	if Story.was_given(snaps, &"gloves"):
		var gpos: Vector3 = spots.get(&"gloves", boss_pos + side * 1.4 + to_b * 0.6)
		ring.global_position = gpos + Vector3(0, 0.1, 0)
		cs.cam(gpos + Vector3(0, 0.6, 0), 3.6, 1.0)
		await cs.walk(hero, gpos - to_b * 0.7, 2.4)
		cs.face(hero, gpos)
		hm.pose = &"bow"
		await cs.wait(0.7)
		_to_hand(ring, hm.sockets[&"r_hand"])
		Vfx.burst(hero, hm.sockets[&"r_hand"].global_position, GOLD, 0.5, 0.4)
		hm.pose = &""
		await cs.wait(0.3)
		await cs.walk(hero, stand)
	else:
		# Перстень всё ещё на перчатке Солдата: он снимает его сам.
		var worn := hm.find_child("FatherRing", true, false) as Node3D
		if worn != null:
			worn.visible = false
		_to_hand(ring, hm.sockets[&"r_hand"])
		Vfx.burst(hero, hm.sockets[&"r_hand"].global_position, GOLD, 0.6, 0.4)
	cs.face(hero, boss_pos)
	cs.cam((boss_pos + stand) * 0.5 + up * 1.0, 3.4, 1.0)
	cs.orbit(12.0, 6.0)
	hm.pose = &"offer"
	await cs.say(&"hero", F["ring_gift"])
	var from := ring.global_position
	_to_world(ring, world)
	Audio.play(&"item_fly", -6.0)
	await cs.fly(ring, from, brother.hand_position(&"r_hand"), 0.8, 0.3, GOLD)
	brother.hold(ring, &"r_hand", 1.0)
	Vfx.burst(brother, brother.hand_position(&"r_hand"), GOLD, 1.3, 0.5)
	Vfx.ring(brother, boss_pos, 2.4, GOLD, 0.7, 0.25)
	CutsceneFx.pillar(world, boss_pos, GOLD, 6.0, 0.8, 2.0)
	cs.flash(GOLD, 0.8, 0.35)
	cs.light(brother.hand_position(&"r_hand") + Vector3(0, 0.3, 0), GOLD, 1.4, 2.2)
	Audio.play(&"absorb")
	Audio.play(&"sacrifice", -10.0)
	hm.pose = &""
	await cs.wait(0.6)
	cs.cam(boss_pos + up * 0.9, 3.0, 1.0)
	await cs.say(&"brother", F["why"])
	cs.cam(stand + up * 1.1, 3.4, 0.8)
	await cs.say(&"hero", F["cant_otherwise"])
	cs.orbit(0.0, 1.0)
	brother.set_pose(&"slump")
	if cs.skipped:
		return
	# У ворот: те, кого он спас.
	var sorry := _sorry_speaker(cs)
	if sorry != &"":
		var sp := cs.actor(sorry)
		cs.cam(sp.global_position + up, 4.2, 1.2)
		sp.look_toward(hero.global_position)
		await cs.wait(0.6)
		await cs.say(sorry, F["sorry"])
		cs.cam(hero.global_position + up * 1.1, 4.0, 0.8)
		await cs.say(&"hero", F["not_for_thanks"])
	# Сольвейг встаёт у него на пути. Он молча проходит мимо — к Ильве.
	var iva := _ensure(cs, &"faithful", GatesScene.IVA_SPOT, hero.global_position)
	var sol := _ensure(cs, &"beloved", GatesScene.crowd_slot(0), hero.global_position)
	sol.fade(1.0, 0.3)
	var sol_spot := hero.global_position.lerp(EXIT, 0.3) + Vector3(-1.2, 0, 0)
	cs.cam(sol_spot + up, 5.0, 1.8)
	await cs.walk(sol, sol_spot, 3.2)
	cs.face(sol, hero.global_position)
	sol.set_pose(&"offer")
	await cs.say(&"beloved", F["my_soldier"])
	var hero_meet := Vector3(1.0, 0, 10.2)
	cs.cam(hero_meet + up, 6.5, 3.0)
	cs.mood(&"dawn", 4.0)
	cs.walk_then_face(iva, Vector3(2.0, 0, 10.9), hero_meet)
	await cs.walk(hero, hero_meet, 2.0)
	sol.set_pose(&"")
	cs.face(hero, iva.global_position)
	cs.face(sol, hero.global_position)
	cs.cam(hero_meet + Vector3(0.5, 1.1, 0.3), 3.6, 1.0)
	cs.orbit(-14.0, 6.0)
	await cs.say(&"faithful", F["lets_go"])
	await cs.say(&"hero", F["lets_go_2"])
	# Уходят вместе. Камера остаётся на брате: всё, что есть в мире, — и никого рядом.
	cs.orbit(0.0, 4.0)
	cs.walk(hero, EXIT, 1.8)
	cs.walk(iva, EXIT + Vector3(1.0, 0, 1.6), 1.8)
	cs.cam(boss_pos + Vector3(0, 1.2, 0), 8.5, 5.0)
	await cs.wait(4.2)
	cs.ui.black(1.0, 2.2)
	await cs.wait(2.4)
	cs.mood(&"none", 0.0)
	var ch := Story.chapter("epilogue")
	await cs.chapter(ch[0], ch[1])
	await cs.narrate(F["end_1"])
	await cs.narrate(F["end_2"])
	await cs.narrate(F["end_3"])


## Бьёрн выбегает между братьями, подняв щит; Солдат заходит слева, и щит падает на камни.
static func _captain(cs: Cutscene, game: Game, boss_pos: Vector3, stand: Vector3) -> void:
	var hero := game.hero
	var bjorn := _ensure(cs, &"captain", GatesScene.crowd_slot(0), boss_pos)
	var home: Vector3 = bjorn.get_meta(&"home", bjorn.global_position)
	var guard := boss_pos + (stand - boss_pos) * 0.5
	bjorn.set_pose(&"")
	cs.cam(guard + Vector3(0, 1.0, 0), 5.0, 1.0)
	await cs.walk(bjorn, guard, 4.5)
	cs.face(bjorn, hero.global_position)
	bjorn.set_pose(&"shield_up")
	CutsceneFx.dust(game.world, guard, 0.8)
	cs.cam(guard + Vector3(0, 1.2, 0), 3.6, 0.6)
	await cs.say(&"captain", Story.FINALE["captain_guard"])
	await cs.thought(Story.FINALE["captain"])
	var f := Combat.flat_dir(hero.global_position - guard, Vector3.BACK)
	var left := Vector3(f.z, 0, -f.x)
	await cs.walk(hero, guard + left * 0.95 + f * 0.35, 3.2)
	cs.face(hero, guard)
	game.hero_model.play_swing(&"punch", 0.2)
	await cs.wait(0.12)
	Audio.play(&"fist_hit")
	CutsceneFx.sparks(game.world, guard + left * 0.4 + Vector3(0, 1.1, 0), Color(1.0, 0.85, 0.6), 20, 3.5)
	cs.shake(0.35)
	cs.flash(Color.WHITE, 0.25, 0.3)
	var shield := bjorn.model.sockets[&"l_hand"].get_node_or_null("CaptainShield") as Node3D
	if shield != null:
		cs.drop(shield)
	Audio.play(&"block", -4.0)
	bjorn.set_pose(&"")
	await cs.wait(0.8)
	cs.walk_then_face(bjorn, home, boss_pos)
	await cs.walk(hero, stand)
	cs.face(hero, boss_pos)


static func _sorry_speaker(cs: Cutscene) -> StringName:
	if cs.actor(&"refugee") != null:
		return &"refugee"
	for id in Story.GIFTS:
		var who: StringName = Story.GIFTS[id]["who"]
		if who != &"beloved" and cs.actor(who) != null:
			return who
	return &""


static func _snapshot(snaps: Array[ItemState], id: StringName) -> ItemState:
	for s in snaps:
		if s.def_id == id:
			return s
	return ItemState.create(id)


static func _to_hand(node: Node3D, socket: Node3D) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	socket.add_child(node)
	node.position = Vector3.ZERO
	node.rotation = Vector3.ZERO


static func _to_world(node: Node3D, world: Node3D) -> void:
	var xf := node.global_transform
	node.get_parent().remove_child(node)
	world.add_child(node)
	node.global_transform = xf


static func _finalize(cs: Cutscene, game: Game) -> void:
	Engine.time_scale = 1.0
	cs.ui.black(1.0, 0.0 if cs.skipped else 0.3)
	game.hero_model.pose = &""
	game.hud.fade(true, 0.01)
