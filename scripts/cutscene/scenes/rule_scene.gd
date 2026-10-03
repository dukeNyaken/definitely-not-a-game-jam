class_name RuleScene
extends RefCounted
## Правило мира — у первого алтаря забега, перед первым выбором жертвы. Раньше эта фраза шла в прологе
## текстом на чёрном фоне; здесь она нужна игроку и сыграна сценой.
##
## Свет алтаря поднимается столбом, арена темнеет, и в зимней стуже встают две тени прошлого: замёрзший
## стоит в снегу, сжавшись и дрожа, бледный от холода; воин в багровом плаще идёт мимо — и останавливается.
## Он снимает плащ и укрывает им чужого человека. Тот согревается и распрямляется. Тепло плаща не пропало: оно светом возвращается
## к отдавшему, снег стихает, кадр теплеет, и от ног воина загорается дорога из света. Они уходят по ней
## вдвоём. Солдат смотрит на отцовский перстень — и остаётся перед алтарём со своим выбором.
##
## Отдают плащ, а не меч: меч — первый дар самого Солдата, и сцена дара показала бы то же самое дважды.
## Плащ — не одна из семи вещей, поэтому предание остаётся преданием; а отдать его в стужу — значит
## по-настоящему рискнуть собой, и правило «не ослабляет» видно без слов.

const GOLD := Color(1.0, 0.82, 0.45)
const COLD := Color(0.62, 0.78, 1.0)
const CRIMSON := Color(0.9, 0.1, 0.08)
const SNOW := Color(0.82, 0.9, 1.0, 0.9)
const KEYS: Array[StringName] = [&"rule_giver", &"rule_taker"]
## Сколько плит света в дороге и на каком расстоянии от алтаря останавливается Солдат:
## дальше кольца, чтобы алтарь не открылся посреди сцены.
const PATH_STEPS := 7
const HERO_DISTANCE := 3.6
const SHADE_ALPHA := 0.55
## Яркость теней. Ниже единицы: части тела накладываются друг на друга, и ярче они выгорали бы в белое —
## золотой и бледно-синий стали бы неотличимы.
const SHADE_GLOW := 0.8
## Отдавший светится ярче прежнего, когда сила вещи возвращается к нему.
const BLAZE_ALPHA := 0.9
## Тени играют за алтарём, на таком расстоянии от него (вглубь кадра): дальше его кольца,
## иначе яркая дуга кольца прошла бы прямо по их ногам.
const STAGE_DEPTH := 4.6


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
	# Свет алтаря поднимается столбом, арена темнеет: стужа, снег. Замёрзший сидит в снегу.
	CutsceneFx.pillar(world, c, GOLD, 7.0, 0.95, 2.2)
	Vfx.ring(hero, c, 3.2, GOLD, 1.0, 0.3)
	cs.flash(GOLD, 0.8, 0.35)
	Audio.play(&"altar_open", -4.0)
	game.arena.set_indoor(true)
	cs.mood(&"legend_cold", 1.2)
	var stage := c + up * STAGE_DEPTH
	var snow := cs.motes(stage + Vector3(0, 2.8, 0), Vector3(5.5, 1.2, 3.0), SNOW, 90, -0.6)
	var taker_at := stage + right * 1.0
	var giver_at := stage - right * 0.7
	# Замёрзший стоит вполоборота от дороги: он никого не ждёт. Узелок на палке убран — в силуэте он читался бы как оружие.
	var taker := cs.spawn(&"refugee", taker_at, taker_at - up * 2.0 + right * 1.0, KEYS[1])
	var giver := cs.spawn(&"hero", stage - right * 6.2, taker_at, KEYS[0])
	var bundle := taker.model.find_child("Bundle", true, false)
	if bundle != null:
		bundle.free()
	taker.set_pose(&"huddle")
	var warm := _gild(giver, Vfx.material(Color(GOLD, 0.0), SHADE_GLOW, true))
	var chilled := _gild(taker, Vfx.material(Color(COLD, 0.0), SHADE_GLOW, true))
	var cloth := Vfx.material(Color(CRIMSON, 0.0), 1.0)
	var cloak := WornCloak.make(CRIMSON)
	_gild(cloak, cloth)
	cs.prop(cloak)
	cloak.put_on(giver)
	var state := {"given": false, "snow": snow}
	_fade(cs, chilled, SHADE_ALPHA, 1.2)
	# Воин в багровом плаще идёт сквозь снег — мимо.
	cs.after(0.9, func():
		_fade(cs, warm, SHADE_ALPHA, 1.0)
		_fade(cs, cloth, 1.0, 1.0)
		cs.walk_then_face(giver, giver_at, taker_at, 2.2))
	cs.cam(stage + top, 7.0, 2.4)
	await cs.wait(1.8)
	# Он останавливается. Замёрзший оборачивается к нему. Крупнее: плащ переходит с плеч на плечи.
	cs.cam((giver_at + taker_at) * 0.5 + top * 1.05, 4.6, 3.0)
	cs.after(1.7, func(): cs.face(taker, giver_at))
	cs.after(2.6, func(): _give(cs, game, giver, taker, cloak, chilled, state))
	await cs.say(&"chronicle", R["law"])
	if cs.skipped:
		return
	await _give(cs, game, giver, taker, cloak, chilled, state)
	# Тепло плаща не пропало: оно светом возвращается к отдавшему. Снег стихает, кадр теплеет.
	SacrificeFx.play(world, giver.model, WornCloak.shoulders(taker), &"armor", GOLD)
	Audio.play(&"sacrifice", -6.0)
	snow.emitting = false
	cs.mood(&"legend", 1.6)
	var path := Vfx.material(Color(GOLD, 0.8), 1.6, true)
	cs.after(0.9, func():
		CutsceneFx.pillar(world, giver.global_position, GOLD, 5.0, 0.7, 1.8)
		Vfx.ring(giver, giver.global_position, 2.0, GOLD, 0.7, 0.2)
		cs.flash(GOLD, 0.5, 0.18)
		_fade(cs, warm, BLAZE_ALPHA, 0.5))
	# От его ног загорается дорога — и они уходят по ней вдвоём.
	cs.after(1.7, func(): _light_path(cs, giver, taker, up, right, path))
	cs.cam(stage + up * 2.6 + top, 9.5, 4.5)
	await cs.say(&"chronicle", R["light"])
	if cs.skipped:
		return
	await cs.wait(0.8)
	# Тени тают, дорога гаснет; арена светлеет. Свет возвращается в алтарь.
	for m in [warm, chilled, cloth, path]:
		_fade(cs, m, 0.0, 1.4)
	cs.mood(&"scene", 1.4)
	cs.cam(c + top * 0.8, 8.0, 1.6)
	await cs.wait(1.3)
	game.arena.set_indoor(false)
	Vfx.ring(hero, c, 3.2, GOLD, 0.9, 0.3)
	CutsceneFx.flare(world, c + top, GOLD, 3.0, 7.0, 1.2)
	Audio.play(&"absorb", -8.0)
	await cs.wait(0.7)
	if cs.skipped:
		return
	# Солдат: отцовский перстень на его руке отзывается светом. Предание он слышал от отца.
	# Он оборачивается от алтаря вполоборота к зрителю: мысль читается по лицу, а не по затылку.
	cs.face(hero, hero.global_position + right * 1.0 - up * 0.7)
	cs.cam(hero.global_position + top * 1.1, 4.2, 1.2)
	cs.orbit(-10.0, 5.0)
	await cs.wait(0.9)
	var ring_at := game.hero_model.socket_position(&"gloves")
	CutsceneFx.flare(world, ring_at, GOLD, 2.2, 3.0, 1.6)
	Vfx.burst(hero, ring_at, GOLD, 0.6, 0.4)
	Audio.play(&"absorb", -12.0)
	await cs.thought(R["hero"])
	cs.orbit(0.0, 1.0)
	cs.cam(c + top * 0.8, 8.5, 1.2)
	await cs.wait(0.9)


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


## Воин снимает плащ и укрывает им замёрзшего; тот согревается — из бледно-синего становится золотым —
## и распрямляется, сложив руки у пояса. Вызывается и посреди реплики, и после неё — срабатывает один раз.
static func _give(cs: Cutscene, game: Game, giver: Puppet, taker: Puppet, cloak: WornCloak, chilled: StandardMaterial3D, state: Dictionary) -> void:
	if state["given"] or not is_instance_valid(cloak) or not is_instance_valid(taker):
		return
	state["given"] = true
	cs.face(giver, taker.global_position)
	giver.set_pose(&"offer")
	cloak.take_off()
	Audio.play(&"item_fly", -6.0)
	await cs.fly(cloak, cloak.global_position, WornCloak.shoulders(taker), 1.1, 0.9, CRIMSON)
	if not is_instance_valid(cloak) or not is_instance_valid(taker):
		return
	cloak.put_on(taker)
	giver.set_pose(&"")
	Vfx.burst(taker, WornCloak.shoulders(taker), GOLD, 0.9, 0.4)
	CutsceneFx.flare(game.world, taker.global_position + Vector3(0, 1.0, 0), GOLD, 1.8, 3.5, 1.2)
	_tint(cs, chilled, GOLD * SHADE_GLOW, 1.2)
	await cs.wait(0.5)
	if is_instance_valid(taker):
		taker.set_pose(&"wring")
		cs.face(taker, giver.global_position)


## Дорога из света: плиты загораются одна за другой. Воин идёт по ним, согретый — рядом, на полшага позади.
static func _light_path(cs: Cutscene, giver: Puppet, taker: Puppet, dir: Vector3, side: Vector3, mat: StandardMaterial3D) -> void:
	if not is_instance_valid(giver) or not is_instance_valid(taker):
		return
	var from := Combat.flat(giver.global_position)
	var end := from + dir * (PATH_STEPS + 0.5)
	giver.set_pose(&"")
	taker.set_pose(&"")
	cs.walk(giver, end, 1.5)
	cs.after(0.5, func():
		if is_instance_valid(taker):
			cs.walk(taker, end + side * 0.95 - dir * 0.7, 1.7))
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
			cs.light(at + Vector3(0, 0.7, 0), GOLD, 1.4, 3.6)
		Audio.play(&"hold_tick", -10.0)
		await cs.wait(0.16)


## Тень: все сетки узла — одним светящимся материалом. Возвращает его же.
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


## Меняет цвет тени, не трогая её прозрачность.
static func _tint(cs: Cutscene, mat: StandardMaterial3D, color: Color, dur: float) -> void:
	if cs.skipped:
		mat.albedo_color = Color(color, mat.albedo_color.a)
		return
	var from := mat.albedo_color
	cs.create_tween().set_ignore_time_scale(true).tween_method(func(k: float):
		mat.albedo_color = Color(from.lerp(color, k), mat.albedo_color.a), 0.0, 1.0, dur)


static func _finalize(cs: Cutscene, game: Game) -> void:
	for key in KEYS:
		var p := cs.actor(key)
		if p != null:
			p.queue_free()
		cs.cast.erase(key)
	cs.clear_props()
	game.arena.set_indoor(false)
	if game.altar != null:
		cs.face(game.hero, game.altar.global_position)
