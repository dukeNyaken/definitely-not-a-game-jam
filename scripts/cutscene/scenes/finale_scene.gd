class_name FinaleScene
extends RefCounted
## Финал после победы. Рыцарь рассыпается в замедлении — на коленях остаётся Сигвард, просто человек,
## похожий на брата. Солдат узнаёт каждую отданную вещь: она вспыхивает своим цветом, пока он вспоминает,
## где она подвела. Последний дар: Солдат сам отдаёт брату отцовский перстень — золотой столб света.
##
## Кто входит в кадр и зачем:
## - Бьёрн, капитан гвардии (если ему отданы перчатки с перстнем). Солдат идёт к брату за перстнем —
##   Бьёрн думает, что добивать, и выбегает из толпы у ворот закрыть нового ярла щитом. Камера сначала
##   показывает его у ворот с табличкой, и только потом он вбегает. Солдат выбивает щит (он знает, что
##   слева Бьёрн опаздывает) и говорит, зачем пришёл; Бьёрн отходит в сторону.
## - Те, кого Солдат спас: стоят у ворот, один делает шаг вперёд — «Прости…».
## - Сольвейг: выходит из толпы и встаёт сбоку от его пути. Он молча проходит мимо.
## - Ильва: ждёт у края арены и идёт навстречу. Они уходят вместе, и кадр теплеет, как на рассвете.
## Все расходятся; последний кадр — Сигвард один, со всеми вещами мира. Дальше темнота и карточка.

const GOLD := Color(1.0, 0.8, 0.35)
const TYRANT_GLOW := Color(0.75, 0.55, 1.0)
## Ближе этого к середине постамента не подходим: камень со свечами шире, чем кажется сверху.
const PEDESTAL_CLEAR := 1.7
## Солдат проходит мимо Сольвейг на таком расстоянии: рядом, но не задевая её протянутую руку.
const PASS_BY := 1.25


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
	# Перстень — в той руке, которую Солдат протянет брату.
	var give_hand: Node3D = hm.sockets[hm.pose_hand(&"offer")]
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
	cs.cam((boss_pos + stand) * 0.5 + up, 4.6, 1.0)
	await cs.say(&"hero", F["never_helped"])
	cs.cam(boss_pos + up * 0.9, 3.4, 0.8)
	await cs.say(&"brother", F["father_knew"])
	if cs.skipped:
		return
	# Последний дар: перстень отца — добровольно.
	var ring := cs.prop(NpcLooks.father_ring(true))
	if Story.was_given(snaps, &"gloves"):
		# Перстень лежит на камнях за спиной Сигварда. Солдат идёт за ним — мимо брата.
		var gpos: Vector3 = spots.get(&"gloves", boss_pos + side * 1.4 + to_b * 0.6)
		var out_sign := -1.0 if (gpos - boss_pos).dot(side) < 0.0 else 1.0
		ring.global_position = gpos + Vector3(0, 0.1, 0)
		await _captain(cs, game, boss_pos, stand, boss_pos - side * out_sign * 2.3 - to_b * 0.3)
		if cs.skipped:
			return
		# Он подходит к перстню с дальней от брата стороны.
		var near := gpos + side * out_sign * 0.8
		cs.cam(gpos + Vector3(0, 0.6, 0), 3.6, 1.0)
		await cs.walk(hero, near, 2.4)
		cs.face(hero, gpos)
		hm.pose = &"bow"
		await cs.wait(0.7)
		_to_hand(ring, give_hand)
		Vfx.burst(hero, give_hand.global_position, GOLD, 0.5, 0.4)
		hm.pose = &""
		await cs.wait(0.3)
		await cs.walk(hero, stand)
	else:
		# Перстень всё ещё на перчатке Солдата: он снимает его сам.
		var worn := hm.find_child("FatherRing", true, false) as Node3D
		if worn != null:
			worn.visible = false
		_to_hand(ring, give_hand)
		Vfx.burst(hero, give_hand.global_position, GOLD, 0.6, 0.4)
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
	# Куда Солдат уйдёт: к Ильве у края арены. Сольвейг встанет сбоку от этого пути.
	var iva := _ensure(cs, &"faithful", GatesScene.IVA_SPOT, hero.global_position)
	var sol := _ensure(cs, &"beloved", GatesScene.crowd_slot(0), hero.global_position)
	var iva_home := Combat.flat(iva.global_position)
	var dir := Combat.flat_dir(iva_home - stand, Vector3.BACK)
	var perp := Vector3(dir.z, 0, -dir.x)
	var pass_point := _clear(game, stand + dir * 2.6)
	var sol_spot := _clear(game, pass_point + perp * PASS_BY)
	# От ворот она идёт в обход Сигварда и вещей — с той стороны, где встанет.
	var lat := side if (sol_spot - boss_pos).dot(side) >= 0.0 else -side
	await _saved(cs, game, sol, [boss_pos + lat * 3.6, sol_spot])
	if cs.skipped:
		return
	await _leave(cs, game, boss_pos, pass_point, sol_spot)
	if cs.skipped:
		return
	var ch := Story.chapter("epilogue")
	await cs.chapter(ch[0], ch[1])
	await cs.narrate(F["end_1"])
	await cs.narrate(F["end_2"])
	await cs.narrate(F["end_3"])


## Бьёрн, капитан гвардии. Солдат делает шаг к брату — за перстнем; Бьёрн у ворот решает, что добивать,
## поднимает щит и вбегает между братьями. Солдат заходит слева, где Бьёрн со щитом опаздывает,
## выбивает щит и говорит, зачем пришёл. Бьёрн отходит на aside и опускает голову.
static func _captain(cs: Cutscene, game: Game, boss_pos: Vector3, stand: Vector3, aside: Vector3) -> void:
	var F := Story.FINALE
	var hero := game.hero
	var up := Vector3(0, 1.0, 0)
	var bjorn := _ensure(cs, &"captain", GatesScene.crowd_slot(0), boss_pos)
	var to_b := Combat.flat_dir(boss_pos - stand, Vector3.FORWARD)
	# Шаг к брату.
	cs.cam((boss_pos + stand) * 0.5 + up, 5.0, 0.8)
	cs.walk(hero, stand + to_b * 0.5, 1.4)
	await cs.wait(0.7)
	# У ворот: Бьёрн видит это и поднимает щит. Сначала — кто он, потом — зачем бежит.
	bjorn.set_pose(&"")
	bjorn.look_toward(hero.global_position)
	cs.cam(bjorn.global_position + up * 1.1, 4.2, 0.7)
	await cs.wait(0.7)
	cs.tag(bjorn, &"captain", 5.0)
	bjorn.set_pose(&"shield_up")
	Audio.play(&"shield_raise", -4.0)
	await cs.say(&"captain", F["captain_guard"])
	if cs.skipped:
		return
	# Вбегает между братьями; Солдат отшатывается на шаг, не отворачиваясь.
	var guard := boss_pos - to_b * 1.1
	var back := boss_pos - to_b * 3.1
	cs.cam((guard + back) * 0.5 + up, 5.8, 1.0)
	var run := Combat.flat(guard - bjorn.global_position).length()
	await cs.walk(bjorn, guard, clampf(run / 2.0, 4.5, 9.0))
	cs.face(bjorn, back)
	cs.ui.untag(bjorn)
	CutsceneFx.dust(game.world, guard, 0.9)
	cs.shake(0.2)
	Audio.play(&"block", -8.0)
	_recoil(cs, hero, back)
	cs.face(hero, guard)
	await cs.wait(0.5)
	cs.cam(guard + up * 1.2, 4.2, 0.8)
	await cs.thought(F["captain"])
	if cs.skipped:
		return
	# Слева Бьёрн опаздывает: щит летит на камни.
	var f := Combat.flat_dir(back - guard, Vector3.BACK)
	var left := Vector3(f.z, 0, -f.x)
	await cs.walk(hero, guard + left * 1.0 + f * 0.6, 3.2)
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
	cs.face(bjorn, hero.global_position)
	await cs.wait(0.8)
	# Не добивать. Бьёрн отходит в сторону — ему нечего закрывать.
	cs.cam((hero.global_position + guard) * 0.5 + up * 1.1, 3.8, 0.8)
	await cs.say(&"hero", F["captain_calm"])
	cs.walk_then_face(bjorn, aside, boss_pos, 1.6)
	cs.after(1.6, func(): bjorn.set_pose(&"downcast"))
	cs.cam((boss_pos + stand) * 0.5 + up, 5.2, 1.2)
	await cs.walk(hero, stand)
	cs.face(hero, boss_pos)


## Те, кого он спас, стоят у ворот. Они оборачиваются к Солдату; один делает шаг вперёд.
## Пока они говорят, Сольвейг выходит из толпы и идёт (по точкам sol_route) туда, где он пройдёт.
static func _saved(cs: Cutscene, game: Game, sol: Puppet, sol_route: Array[Vector3]) -> void:
	var F := Story.FINALE
	var hero := game.hero
	var up := Vector3(0, 1.0, 0)
	sol.fade(1.0, 0.3)
	_follow(cs, sol, sol_route, hero.global_position)
	var sorry := _sorry_speaker(cs)
	if sorry == &"":
		return
	var sp := cs.actor(sorry)
	# Общий план — на тех, кто стоит рядом с говорящим (Бьёрн мог отойти к братьям).
	var center := Vector3.ZERO
	var near := 0
	for p in _crowd(cs):
		p.look_toward(hero.global_position)
		if p.global_position.distance_to(sp.global_position) < 6.0:
			center += p.global_position
			near += 1
	center /= maxi(near, 1)
	cs.face(hero, center)
	cs.cam(center + up, 7.0, 1.4)
	await cs.wait(1.6)
	var step := sp.global_position + Combat.flat_dir(hero.global_position - sp.global_position) * 1.2
	cs.cam(step + up * 1.1, 4.2, 1.0)
	await cs.walk(sp, step, 1.6)
	cs.face(sp, hero.global_position)
	cs.tag(sp, sorry, 3.5)
	await cs.say(sorry, F["sorry"])
	sp.set_pose(&"downcast")
	cs.cam(hero.global_position + up * 1.1, 4.0, 0.8)
	await cs.say(&"hero", F["not_for_thanks"])


## Уход. Сольвейг просит подождать — он молча проходит мимо. Ильва идёт навстречу: «Пойдём?»
## Все расходятся; последний кадр — Сигвард один среди вещей.
static func _leave(cs: Cutscene, game: Game, boss_pos: Vector3, pass_point: Vector3, sol_spot: Vector3) -> void:
	var F := Story.FINALE
	var hero := game.hero
	var up := Vector3(0, 1.0, 0)
	var iva := cs.actor(&"faithful")
	var sol := cs.actor(&"beloved")
	var start := Combat.flat(hero.global_position)
	var iva_home := Combat.flat(iva.global_position)
	var dir := Combat.flat_dir(pass_point - start, Vector3.BACK)
	var perp := Combat.flat_dir(sol_spot - pass_point, Vector3.RIGHT)
	# Место встречи с Ильвой: Солдат не доходит до неё пару шагов, она идёт навстречу.
	var meet := _clear(game, iva_home + Combat.flat_dir(pass_point - iva_home, -dir) * 2.8)
	if Combat.flat(meet - pass_point).length() < 2.0:
		meet = _clear(game, pass_point + dir * 2.5)
	# Ильва встаёт сбоку от него по экрану — иначе в кадре они сольются в одну фигуру.
	var screen_right: Vector3 = game.rig.ground_axes()[1]
	var to_home := Combat.flat_dir(iva_home - meet, dir)
	var beside := screen_right * (1.0 if to_home.dot(screen_right) >= 0.0 else -1.0)
	var iva_meet := _clear(game, meet + beside * 1.3 + to_home * 0.5)
	var exit := Combat.flat_dir(iva_home, dir) * (Combat.arena_radius - 0.9)
	# Сольвейг уже на его пути — сбоку. Он смотрит туда, куда уйдёт.
	_place(cs, sol, sol_spot)
	cs.face(sol, start)
	cs.face(hero, pass_point)
	cs.cam((start + sol_spot) * 0.5 + up, 5.0, 1.4)
	await cs.wait(0.8)
	sol.set_pose(&"offer")
	await cs.say(&"beloved", F["my_soldier"])
	# Он проходит мимо — и на миг останавливается рядом. Молча.
	cs.cam((pass_point + sol_spot) * 0.5 + up * 1.1, 3.8, 1.6)
	await cs.walk(hero, pass_point, 1.6)
	cs.face(sol, pass_point)
	await cs.wait(0.9)
	sol.set_pose(&"downcast")
	await cs.wait(0.7)
	if cs.skipped:
		return
	# К Ильве. Кадр теплеет; остальные расходятся кто куда.
	cs.mood(&"dawn", 4.0)
	_scatter(cs)
	cs.cam((pass_point + meet) * 0.5 + up, 6.5, 2.0)
	cs.walk_then_face(iva, iva_meet, meet, 1.8)
	await _walk_around(cs, game, hero, meet, 2.0)
	cs.face(hero, iva_meet)
	cs.face(iva, meet)
	cs.face(sol, meet)
	cs.tag(iva, &"faithful", 3.5)
	cs.cam((meet + iva_meet) * 0.5 + up * 1.1, 3.6, 1.0)
	cs.orbit(-14.0, 6.0)
	await cs.say(&"faithful", F["lets_go"])
	await cs.say(&"hero", F["lets_go_2"])
	if cs.skipped:
		return
	# Уходят вместе. Сольвейг остаётся одна — и уходит в темноту своей дорогой.
	cs.orbit(0.0, 3.0)
	cs.walk(sol, sol_spot + perp * 6.0, 1.2)
	sol.fade(0.0, 3.0)
	cs.walk(hero, exit, 1.8)
	cs.walk(iva, exit + beside * 1.3, 1.8)
	# Камера провожает их до края арены.
	cs.cam((meet + exit) * 0.5 + up, 8.0, 3.0)
	await cs.wait(2.8)
	# Последний кадр: Сигвард. Всё, что есть в мире, — и никого рядом.
	cs.ui.black(1.0, 0.6)
	await cs.wait(0.7)
	if cs.skipped:
		return
	cs.cam(boss_pos + up, 4.4, 0.0)
	cs.ui.black(0.0, 1.0)
	cs.cam(boss_pos + up * 1.2, 9.0, 6.5)
	await cs.wait(4.8)
	cs.ui.black(1.0, 2.2)
	await cs.wait(2.4)
	cs.mood(&"none", 0.0)


## Все, кроме братьев, Сольвейг и Ильвы: те, кому Солдат отдал вещи.
static func _crowd(cs: Cutscene) -> Array[Puppet]:
	var out: Array[Puppet] = []
	for key in cs.cast:
		if key in [&"brother", &"beloved", &"faithful"]:
			continue
		var p := cs.actor(key)
		if p != null:
			out.append(p)
	return out


## Спасённые расходятся от ворот в темноту — каждый в свою сторону. У Сигварда не остаётся никого.
static func _scatter(cs: Cutscene) -> void:
	for p in _crowd(cs):
		var out := Combat.flat_dir(p.global_position, Vector3.FORWARD)
		var along := Vector3(-out.z, 0, out.x)
		if along.x * p.global_position.x < 0.0:
			along = -along
		p.set_pose(&"")
		cs.walk(p, p.global_position + along * 6.0 - out * 0.5, 1.8)
		p.fade(0.0, 3.2)


static func _sorry_speaker(cs: Cutscene) -> StringName:
	if cs.actor(&"refugee") != null:
		return &"refugee"
	for id in Story.GIFTS:
		var who: StringName = Story.GIFTS[id]["who"]
		if who != &"beloved" and cs.actor(who) != null:
			return who
	return &""


# --- Постаменты и шаги ------------------------------------------------------

## Где на арене стоят постаменты отданных вещей.
static func _pedestals(game: Game) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var d := game.boss_director
	if d == null:
		return out
	for ped in d._pedestals:
		if is_instance_valid(ped):
			out.append(Combat.flat(ped.global_position))
	return out


## Точка не ближе PEDESTAL_CLEAR к постаменту: если попала в камень — сдвигается от него наружу.
static func _clear(game: Game, point: Vector3) -> Vector3:
	var p := Combat.flat(point)
	for ped in _pedestals(game):
		var off := p - ped
		if off.length() < PEDESTAL_CLEAR:
			p = ped + Combat.flat_dir(off, Vector3.BACK) * PEDESTAL_CLEAR
	return p


## Идёт к точке в обход постамента: по прямой путь прошёл бы сквозь камень.
static func _walk_around(cs: Cutscene, game: Game, a: Actor, to: Vector3, speed: float) -> void:
	var from := Combat.flat(a.global_position)
	var seg := Combat.flat(to) - from
	for ped in _pedestals(game):
		var t := (ped - from).dot(seg) / maxf(seg.length_squared(), 0.001)
		if t <= 0.05 or t >= 0.95:
			continue
		var off := from + seg * t - ped
		if off.length() < PEDESTAL_CLEAR:
			var out := Combat.flat_dir(off, Vector3(seg.z, 0, -seg.x).normalized())
			await cs.walk(a, ped + out * (PEDESTAL_CLEAR + 0.3), speed)
			break
	await cs.walk(a, to, speed)


## Идёт по точкам и в конце поворачивается к look. Не ждать: актёр подходит, пока сцена идёт дальше.
static func _follow(cs: Cutscene, a: Actor, route: Array[Vector3], look: Vector3) -> void:
	var way := 0.0
	var at := Combat.flat(a.global_position)
	for p in route:
		way += Combat.flat(p - at).length()
		at = Combat.flat(p)
	# Успеть за шесть секунд — столько длится разговор у ворот.
	var speed := clampf(way / 6.0, 1.6, 3.6)
	for p in route:
		await cs.walk(a, p, speed)
	cs.face(a, look)


## Актёр уже на месте, даже если не успел дойти.
static func _place(cs: Cutscene, a: Actor, to: Vector3) -> void:
	if a != null and is_instance_valid(a) and Combat.flat(a.global_position - to).length() > 0.3:
		cs._place(a, to)


## Отшатнуться на шаг, не отворачиваясь: актёр скользит назад, лицом туда же.
static func _recoil(cs: Cutscene, a: Actor, to: Vector3) -> void:
	to.y = 0.0
	a.set_meta(&"cs_walk", int(a.get_meta(&"cs_walk", 0)) + 1)
	a.move_input = Vector3.ZERO
	if cs.skipped:
		a.global_position = to
		return
	a.create_tween().set_ignore_time_scale(true).tween_property(a, "global_position", to, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _snapshot(snaps: Array[ItemState], id: StringName) -> ItemState:
	for s in snaps:
		if s.def_id == id:
			return s
	return Mastery.make_item(id)


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
