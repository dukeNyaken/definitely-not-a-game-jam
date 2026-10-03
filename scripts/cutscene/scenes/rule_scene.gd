class_name RuleScene
extends RefCounted
## Правило мира — у первого алтаря забега, перед первым выбором жертвы. Раньше эта фраза шла в прологе
## текстом на чёрном фоне; здесь она нужна игроку и сыграна сценой. Свет алтаря поднимается столбом,
## и в нём встают две золотые тени прошлого: воин отдаёт меч тому, кому он нужнее. Меч перелетает
## из рук в руки — и его сила светом возвращается к отдавшему. От его ног загорается дорога из света;
## он уходит по ней, и тени тают. Сразу после сцены Солдат встаёт на алтарь сам.

const GOLD := Color(1.0, 0.82, 0.45)
const KEYS: Array[StringName] = [&"rule_giver", &"rule_taker"]
## Сколько плит света в дороге и на каком расстоянии от алтаря останавливается Солдат:
## дальше кольца, чтобы алтарь не открылся посреди сцены.
const PATH_STEPS := 7
const HERO_DISTANCE := 3.6
const SHADE_ALPHA := 0.55
## Меч в руках теней крупнее обычного: издалека должно быть видно, что именно отдают.
const SWORD_SCALE := 1.1


## Сцена идёт один раз за забег: у первого алтаря, пока не отдана ни одна вещь.
static func due() -> bool:
	return RunState.stage == 1 and RunState.sacrifices_count() == 0


static func play(cs: Cutscene, game: Game) -> void:
	cs.begin()
	await _body(cs, game)
	_finalize(cs, game)
	cs.end()


static func _body(cs: Cutscene, game: Game) -> void:
	var R := Story.RULE
	var hero := game.hero
	var world := game.world
	var c := Combat.flat(game.altar.global_position) if game.altar != null else Vector3.ZERO
	var axes := game.rig.ground_axes()
	var up: Vector3 = axes[0]
	var right: Vector3 = axes[1]
	var top := Vector3(0, 1.0, 0)
	# Солдат подходит к алтарю и встаёт у кольца, спиной к зрителю: предание — перед ним.
	_approach(cs, hero, c, up, right)
	cs.cam(c + top, 9.0, 1.4)
	var ch := Story.chapter("rule")
	cs.chapter(ch[0], ch[1], true, 2.0)
	# Заставка успевает погаснуть до столба света: на его фоне золотой заголовок не читается.
	await cs.wait(3.2)
	if cs.skipped:
		return
	# Свет алтаря поднимается столбом; в нём встают две тени: воин с мечом и тот, кому меч нужнее.
	cs.mood(&"legend", 1.4)
	CutsceneFx.pillar(world, c, GOLD, 7.0, 0.95, 2.4)
	Vfx.ring(hero, c, 3.2, GOLD, 1.0, 0.3)
	cs.flash(GOLD, 0.7, 0.2)
	Audio.play(&"altar_open", -4.0)
	var giver_at := c + up * 2.4 - right * 1.3
	var taker_at := c + up * 2.4 + right * 1.3
	var giver := cs.spawn(&"hero", giver_at, taker_at, KEYS[0])
	var taker := cs.spawn(&"refugee", taker_at, giver_at, KEYS[1])
	var sword := ItemVisuals.build_display(ItemState.create(&"sword"))
	giver.hold(sword, giver.offer_hand(), SWORD_SCALE)
	giver.set_pose(&"hold")
	var shade := _gild(giver, _gild(taker, Vfx.material(Color(GOLD, 0.0), 1.3, true)))
	var state := {"handed": false}
	_fade(cs, shade, SHADE_ALPHA, 1.4)
	# Солдат остаётся в кадре снизу: он смотрит предание вместе со зрителем.
	cs.cam(c + top, 8.2, 2.0)
	await cs.wait(1.6)
	# Он протягивает меч — и отдаёт. Отданное добровольно.
	cs.after(1.0, func(): giver.set_pose(&"offer"))
	cs.after(2.6, func(): _hand_over(cs, game, giver, taker, sword, state))
	await cs.say(&"chronicle", R["law"])
	if cs.skipped:
		return
	await _hand_over(cs, game, giver, taker, sword, state)
	# Сила меча не пропала: она светом возвращается к отдавшему — и от его ног загорается дорога.
	taker.set_pose(&"bow")
	SacrificeFx.play(world, giver.model, taker.hand_position(), &"armor", GOLD)
	Audio.play(&"sacrifice", -6.0)
	var path := Vfx.material(Color(GOLD, 0.8), 1.6, true)
	cs.after(0.9, func():
		CutsceneFx.pillar(world, giver_at, GOLD, 5.0, 0.7, 1.8)
		cs.flash(GOLD, 0.5, 0.18))
	cs.after(1.6, func(): _light_path(cs, giver, giver_at, up, path))
	cs.cam(c + up * 2.0 + top, 11.0, 4.0)
	await cs.say(&"chronicle", R["light"])
	if cs.skipped:
		return
	# Тени тают, дорога гаснет; свет возвращается в алтарь — теперь очередь Солдата.
	_fade(cs, shade, 0.0, 1.4)
	_fade(cs, path, 0.0, 1.4)
	cs.mood(&"scene", 1.4)
	cs.cam(c + top * 0.6, 7.5, 1.6)
	await cs.wait(1.2)
	Vfx.ring(hero, c, 3.2, GOLD, 0.9, 0.3)
	CutsceneFx.flare(world, c + top, GOLD, 3.0, 7.0, 1.2)
	Audio.play(&"absorb", -8.0)
	await cs.wait(1.1)


## Солдат идёт к алтарю и останавливается у кольца снизу кадра. Если он стоял за алтарём —
## обходит его сбоку, а не идёт через середину. Не ждать: сцена начинается, пока он подходит.
static func _approach(cs: Cutscene, hero: Actor, c: Vector3, up: Vector3, right: Vector3) -> void:
	var v := Combat.flat(hero.global_position - c)
	var spot := c - up * HERO_DISTANCE + right * clampf(v.dot(right), -3.0, 3.0)
	if v.dot(up) > -1.0:
		var side := 1.0 if v.dot(right) >= 0.0 else -1.0
		spot = c - up * HERO_DISTANCE + right * side * 2.2
		await cs.walk(hero, c + right * side * 3.8 + up * minf(v.dot(up), 0.0), 4.0)
	await cs.walk(hero, spot, 4.0)
	cs.face(hero, c)


## Меч перелетает из рук в руки. Вызывается и посреди реплики, и после неё — срабатывает один раз.
static func _hand_over(cs: Cutscene, game: Game, giver: Puppet, taker: Puppet, sword: Node3D, state: Dictionary) -> void:
	if state["handed"] or not is_instance_valid(sword):
		return
	state["handed"] = true
	var from := sword.global_position
	var xf := sword.global_transform
	sword.get_parent().remove_child(sword)
	game.world.add_child(sword)
	sword.global_transform = xf
	cs.prop(sword)
	Audio.play(&"item_fly", -6.0)
	await cs.fly(sword, from, taker.hand_position(), 1.2, 1.6, GOLD)
	if not is_instance_valid(sword) or not is_instance_valid(taker):
		return
	cs.props.erase(sword)
	taker.hold(sword, &"r_hand", SWORD_SCALE)
	taker.set_pose(&"hold")
	giver.set_pose(&"")
	Vfx.burst(taker, taker.hand_position(), GOLD, 0.8, 0.4)


## Дорога из света: плиты загораются одна за другой, тень воина уходит по ним.
static func _light_path(cs: Cutscene, giver: Puppet, from: Vector3, dir: Vector3, mat: StandardMaterial3D) -> void:
	if not is_instance_valid(giver):
		return
	giver.set_pose(&"")
	cs.walk(giver, from + dir * (PATH_STEPS + 0.5), 1.5)
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.62, 0.8)
	for k in PATH_STEPS:
		if cs.skipped:
			return
		var at := from + dir * (1.0 + k)
		var tile := MeshInstance3D.new()
		tile.mesh = plane
		tile.material_override = mat
		tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cs.prop(tile)
		tile.global_position = at + Vector3(0, 0.05, 0)
		tile.rotation.y = atan2(dir.x, dir.z)
		tile.scale = Vector3(0.2, 1.0, 0.2)
		tile.create_tween().set_ignore_time_scale(true).tween_property(tile, "scale", Vector3.ONE, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if k % 2 == 0:
			cs.light(at + Vector3(0, 0.7, 0), GOLD, 1.1, 3.2)
		Audio.play(&"hold_tick", -10.0)
		await cs.wait(0.16)


## Тень: все сетки актёра и того, что у него в руках, — одним светящимся материалом. Возвращает его же.
static func _gild(n: Node, mat: StandardMaterial3D) -> StandardMaterial3D:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gild(ch, mat)
	return mat


static func _fade(cs: Cutscene, mat: StandardMaterial3D, alpha: float, dur: float) -> void:
	if cs.skipped:
		mat.albedo_color.a = alpha
		return
	cs.create_tween().set_ignore_time_scale(true).tween_property(mat, "albedo_color:a", alpha, dur)


static func _finalize(cs: Cutscene, game: Game) -> void:
	for key in KEYS:
		var p := cs.actor(key)
		if p != null:
			p.queue_free()
		cs.cast.erase(key)
	cs.clear_props()
	if game.altar != null:
		cs.face(game.hero, game.altar.global_position)
