class_name IlvaSongScene
extends RefCounted
## Песня Ильвы «Я просто иду с тобою» — музыкальная сцена после второго дара. В сцене дара Ильва говорит:
## «Я клясться не умею — я просто иду рядом», и песня начинается с этих слов. Ночь, привал у костра:
## Солдат спит, Ильва поёт о том, чего не скажет ему вслух.
##
## Сцена идёт по часам песни (SongTrack): кадры сменяются на строках, свет и тропа — на долях такта.
## Места действия стоят далеко от арены, каждое — своя маленькая декорация:
##   привал       — костёр, бревно, ели; здесь песня начинается и кончается;
##   фьорд        — лёд и вмёрзшие ладьи: двое детей бегут по льду (воспоминание — светящиеся тени);
##   пожар        — юноша отдаёт плащ мальчишке; девочка с фонарём идёт за ним;
##   обещание     — Солдат отдаёт оберег Сольвейг, Ильва стоит в стороне;
##   клятвы       — трое кланяются в столбах света, Ильва проходит мимо, не кланяясь;
##   дорога       — припевы: они идут рядом, тропа загорается под ногами на каждую долю;
##   щит          — Солдат закрывает щитом вдову и детей;
##   предчувствие — мост песни: безликие тёмные тени уходят к высокой фигуре в лиловом свете.
##
## Предчувствие сыграно тенями без лиц: зритель ещё не знает, чем всё кончится, и песня не показывает
## ворота дворца — только страх Ильвы и её обещание: «Я выйду из тьмы с фонарём». В конце песни —
## «Пойдём? — Пойдём»: те же слова прозвучат в финале.

const AUDIO := "res://assets/audio/ilva_musicle_files/Я просто иду с тобою.wav"
const SYNC := "res://assets/audio/ilva_musicle_files/Я просто иду с тобою.sync.json"
## Доли такта, замеренные по записи: 75.6 уд/мин, первая доля на 0.58 с.
const BEAT := 0.794
const BEAT_PHASE := 0.58
## С какой секунды песни идут слова, сказанные вслух («Пойдём?»): их показывает сцена, а не строка песни.
const SPOKEN_FROM := 137.0
const GO_AT := 137.74
const GO_REPLY_AT := 140.75

const ORIGIN := Vector3(150, 0, 150)
const CAMP := Vector3(0, 0, 0)
const FJORD := Vector3(70, 0, 0)
const BLAZE := Vector3(140, 0, 0)
const PROMISE := Vector3(210, 0, 0)
const OATH := Vector3(280, 0, 0)
const SHIELD := Vector3(350, 0, 0)
const DREAD := Vector3(420, 0, 0)
const ROAD := Vector3(0, 0, 90)

const GOLD := Color(1.0, 0.82, 0.45)
const PALE := Color(0.8, 0.88, 1.0)
const COLD := Color(0.6, 0.76, 1.0)
const ROSE := Color(1.0, 0.5, 0.55)
const EMBER := Color(1.0, 0.5, 0.18)
const CRIMSON := Color(0.95, 0.16, 0.1)
const PURPLE := Color(0.7, 0.45, 1.0)
const CLOAK := Color(0.9, 0.1, 0.08)
const BLANKET := Color(0.78, 0.58, 0.38)
const SNOWFLAKE := Color(0.82, 0.9, 1.0, 0.9)
## Снег ночью — тёмный: на светлом светящиеся тени воспоминаний выгорали бы в белое.
const NIGHT_SNOW := Color(0.34, 0.39, 0.53)
const CAMP_SNOW := Color(0.58, 0.64, 0.78)
const DARK_ICE := Color(0.16, 0.28, 0.45)
const UP := Vector3(0, 1.0, 0)
const SHADE := 0.55
const SHADE_GLOW := 0.8
const ROAD_SPEED := 1.5

var cs: Cutscene
var game: Game
var song: SongTrack
var stage: Node3D
var ilva: Puppet
var sol: Puppet
## Тени воспоминаний: Солдат (в разном возрасте), Ильва в детстве, Сольвейг, трое клянущихся, вдова, двое детей, высокая фигура.
var shade_sol: Puppet
var shade_ilva: Puppet
var solveig: Puppet
var others: Array[Puppet] = []
var tall: Puppet
var mats: Dictionary = {}
var puppets: Array[Puppet] = []
var glow: OmniLight3D
## Сила её света без биения; сам свет вздрагивает вокруг неё на каждую долю (_on_tick).
var glow_base: float = 0.0
var sparkle: CPUParticles3D
var fire_light: OmniLight3D
var fire: CPUParticles3D
var blanket: WornCloak
var road_snow: CPUParticles3D


static func play(p_cs: Cutscene, p_game: Game) -> void:
	var s := IlvaSongScene.new()
	s.cs = p_cs
	s.game = p_game
	await s._play()


func _play() -> void:
	var moon := game.rig.camera.get_node_or_null("RingMoon") as Node3D
	cs.ui.black(1.0, 0.0)
	game.hud.fade(false, 0.01)
	cs.begin()
	if moon != null:
		moon.visible = false
	game.arena.set_indoor(true)
	Audio.stop_music(0.6)
	_build()
	song = SongTrack.load_track(SYNC, AUDIO)
	song.beat_period = BEAT
	song.beat_phase = BEAT_PHASE
	song.lyrics_until = SPOKEN_FROM
	cs.add_child(song)
	song.tick.connect(_on_tick)
	song.start(cs)
	await _body()
	cs.ui.black(1.0, 0.0 if cs.skipped else 0.6)
	song.stop(0.25 if cs.skipped else 1.2)
	await cs.wait(0.7)
	_finalize(moon)
	game.hud.fade(true, 0.01)
	cs.end()
	cs.ui.black(0.0, 0.0)


func _body() -> void:
	for part in [_intro, _verse_one, _pre_chorus, _chorus_one, _verse_two, _bridge, _final_chorus, _outro]:
		await (part as Callable).call()
		if cs.skipped:
			return


# --- Части песни -------------------------------------------------------------

## 0:00 — привал. Солдат спит у костра; Ильва стоит в стороне с фонарём. Зов — фонарь над головой.
func _intro() -> void:
	_put(sol, P(CAMP, 1.25, 0.35), P(CAMP, -0.6, 1.4))
	sol.set_pose(&"sit")
	_put(ilva, P(CAMP, -4.8, -0.4), P(CAMP, 1.25, 0.35))
	cs.mood(&"hearth", 0.0)
	_frame(CAMP, 0.0, -0.3, 10.5, -16.0)
	await song.until(0.4)
	cs.ui.black(0.0, 3.0)
	cs.cam(P(CAMP, 0.0, 0.0) + UP, 7.0, 13.5)
	cs.orbit(0.0, 13.5)
	await song.until(2.6)
	var ch := Story.chapter("song")
	cs.chapter(ch[0], ch[1], true, 4.2)
	await song.until(8.4)
	cs.walk(ilva, P(CAMP, -2.3, 0.8), 0.9)
	await song.until(13.8)
	ilva.set_pose(&"lantern_high")
	await song.until(14.46)
	_pulse(ilva.global_position, 7.0)
	_glow(2.6, 0.4)
	await song.until(15.5)


## 0:15 — воспоминания: фьорд, пожар, обещание Сольвейг. «А я тихо скажу: береги себя. Иди».
func _verse_one() -> void:
	# «Мы росли, где фьорд замерзает к зиме» — двое детей бегут по льду.
	_glow(0.0, 0.0)
	_size(shade_sol, 0.62)
	_size(shade_ilva, 0.6)
	_put(shade_sol, P(FJORD, -7.0, 0.6), P(FJORD, 4.0, -1.0))
	_put(shade_ilva, P(FJORD, -8.3, 1.3), P(FJORD, 4.0, -1.0))
	_show(shade_sol, GOLD)
	_show(shade_ilva, GOLD.lerp(Color.WHITE, 0.35))
	cs.flash(PALE, 0.5, 0.4)
	cs.mood(&"legend_cold", 0.0)
	game.rig.cine_track(func(): return (shade_sol.global_position + shade_ilva.global_position) * 0.5 + UP * 0.7, 6.4, 0.0)
	cs.orbit(-8.0, 0.0)
	cs.orbit(6.0, 6.5)
	cs.walk_then_face(shade_sol, P(FJORD, 3.4, -1.3), P(FJORD, 7.0, -3.4), 3.4)
	cs.walk_then_face(shade_ilva, P(FJORD, 2.2, -0.5), P(FJORD, 7.0, -3.4), 3.4)
	await song.until(19.05)
	# «Где ладьи до весны засыпают во льду».
	cs.cam(P(FJORD, 6.6, -3.0) + UP * 1.2, 9.6, 3.0)
	cs.orbit(14.0, 3.4)
	await song.until(22.2)
	if cs.skipped:
		return
	# «Ты отдал свой плащ мальчишке в огне».
	var kid := others[4]
	_size(shade_sol, 0.88)
	_size(shade_ilva, 0.82)
	_put(shade_sol, P(BLAZE, 3.4, 0.6), P(BLAZE, -0.4, 0.5))
	_put(shade_ilva, P(BLAZE, 4.8, 2.2), P(BLAZE, 0.0, 0.5))
	_put(kid, P(BLAZE, -0.5, 0.5), P(BLAZE, 2.0, 2.0))
	kid.set_pose(&"huddle")
	_show(kid, COLD)
	var cloak := _cloak(CLOAK)
	cloak.put_on(shade_sol)
	cs.flash(EMBER, 0.45, 0.4)
	cs.mood(&"legend", 0.0)
	_frame(BLAZE, 0.9, 0.3, 6.4, 10.0)
	cs.cam(P(BLAZE, 0.2, 0.4) + UP, 5.0, 3.0)
	cs.orbit(-4.0, 6.0)
	cs.walk_then_face(shade_sol, P(BLAZE, 0.8, 0.5), kid.global_position, 2.8)
	await song.until(23.4)
	_wrap(cloak, shade_sol, kid)
	await song.until(25.7)
	# «Я тогда поняла: за тобой я пойду» — в её фонаре загорается свет.
	cs.walk(shade_sol, P(BLAZE, 7.0, -1.0), 1.5)
	game.rig.cine_track(func(): return shade_ilva.global_position + UP * 0.8, 4.4, 1.4)
	await song.until(27.0)
	_pulse(shade_ilva.global_position, 3.5)
	_fade(mats[shade_ilva], 0.95, 0.5)
	cs.walk(shade_ilva, P(BLAZE, 5.8, 0.5), 1.5)
	await song.until(28.7)
	if cs.skipped:
		return
	# «Ей — твой оберег и «вернусь, только жди».
	cloak.visible = false
	_hide(kid)
	_size(shade_sol, 1.0)
	_put(shade_sol, P(PROMISE, 0.5, -0.4), P(PROMISE, -0.8, -0.4))
	_put(solveig, P(PROMISE, -0.8, -0.4), P(PROMISE, 0.5, -0.4))
	_put(ilva, P(PROMISE, -5.0, 1.9), P(PROMISE, 0.0, -0.4))
	ilva.set_pose(&"")
	_show(shade_sol, GOLD)
	_show(solveig, ROSE)
	_hide(shade_ilva)
	var amulet := cs.prop(ItemVisuals.build_display(ItemState.create(&"amulet")))
	shade_sol.hold(amulet, shade_sol.offer_hand(), 0.9)
	shade_sol.set_pose(&"offer")
	cs.flash(PALE, 0.4, 0.3)
	cs.mood(&"hurt", 0.0)
	_frame(PROMISE, -0.1, -0.3, 4.4, 6.0)
	await song.until(29.5)
	_hand_amulet(amulet)
	await song.until(30.4)
	cs.cam(P(PROMISE, -2.2, 0.5) + UP, 7.6, 1.5)
	await song.until(31.8)
	# «А я тихо скажу: «Береги себя. Иди» — он уходит; она тянет руку ему вслед. Оба в кадре.
	amulet.visible = false
	_fade(mats[solveig], 0.0, 0.9)
	var away := P(PROMISE, 5.0, -1.5)
	cs.walk(shade_sol, away, 0.8)
	_fade(mats[shade_sol], 0.0, 5.6)
	cs.walk_then_face(ilva, P(PROMISE, -1.9, 0.8), away, 1.4)
	cs.cam(P(PROMISE, 1.0, -0.2) + UP, 5.6, 4.0)
	cs.orbit(-10.0, 6.0)
	cs.mood(&"hearth", 3.0)
	await song.until(34.1)
	ilva.set_pose(&"offer")
	await song.until(36.8)
	ilva.set_pose(&"")
	await song.until(37.8)


## 0:38 — «А я клясться не умею»: трое кланяются в столбах света, она проходит мимо.
func _pre_chorus() -> void:
	_put(shade_sol, P(OATH, 3.8, -1.6), P(OATH, -3.0, -1.6))
	shade_sol.set_pose(&"")
	_show(shade_sol, GOLD)
	var hues := [Color(1.0, 0.7, 0.4), Color(0.6, 0.85, 1.0), Color(0.75, 1.0, 0.6)]
	for i in 3:
		var p := others[i]
		_put(p, P(OATH, 1.4 - i * 2.2, -1.6), P(OATH, 6.0, -1.6))
		p.set_pose(&"")
		_show(p, GOLD)
		song.at(38.6 + i * BEAT, func():
			p.set_pose(&"bow")
			_beam(p.global_position, hues[i], 1.6))
	_put(ilva, P(OATH, -6.6, 1.1), P(OATH, 6.0, 1.1))
	cs.flash(PALE, 0.4, 0.3)
	cs.mood(&"legend", 0.0)
	game.rig.cine_track(func(): return ilva.global_position + UP + stage.global_basis.x * 1.4, 7.0, 0.0)
	game.rig.cine_track(func(): return ilva.global_position + UP + stage.global_basis.x * 1.0, 5.6, 5.5)
	cs.orbit(9.0, 0.0)
	cs.orbit(-8.0, 6.0)
	cs.walk(ilva, P(OATH, 5.4, 1.1), 1.9)
	await song.until(41.3)
	# «Я просто иду. И не жаль» — клятвы гаснут у неё за спиной.
	for i in 3:
		_fade(mats[others[i]], 0.15, 2.0)
	await song.until(43.3)
	ilva.set_pose(&"lantern_high")
	_glow(3.0, 0.9)
	await song.until(44.25)


## 0:44 — припев: дорога. Они идут рядом; тропа загорается под ногами на каждую долю.
func _chorus_one() -> void:
	for i in 3:
		_hide(others[i])
	_hide(shade_sol)
	cs.flash(GOLD, 0.8, 0.65)
	cs.mood(&"scene", 0.0)
	_walk_road(48.0)
	ilva.set_pose(&"sing")
	game.rig.cine_track(_road_focus, 9.6, 0.0)
	game.rig.cine_track(_road_focus, 6.6, 6.0)
	cs.orbit(-14.0, 0.0)
	cs.orbit(12.0, 24.0)
	_glow(2.0, 0.0)
	await song.until(51.3)
	# «Горит над твоей тропою мой свет среди зимы».
	ilva.set_pose(&"lantern_high")
	_glow(3.4, 1.0)
	for bt in song.beats(51.34, 73.5):
		song.at(bt, _ignite_ahead)
	await song.until(55.2)
	sparkle.emitting = true
	await song.until(57.6)
	ilva.set_pose(&"sing")
	await song.until(58.3)
	# «Раздай им всё, что есть» — семь огней его вещей уходят в темноту.
	for k in Db.ITEM_IDS.size():
		song.at(58.4 + k * BEAT * 0.5, _give_away.bind(k))
	await song.until(64.4)
	# «Мой дар — лишь то, что я здесь» — тише и ближе.
	game.rig.cine_track(_road_focus, 4.6, 2.6)
	await song.until(67.7)
	ilva.set_pose(&"lantern_high")
	await song.until(69.6)
	# Проигрыш: общий план, свет бежит по всей дороге.
	_pulse(ilva.global_position, 9.0)
	_glow(4.2, 0.3)
	game.rig.cine_track(_road_focus, 13.0, 2.6)
	cs.orbit(-18.0, 4.8)
	var here := sol.global_position
	for k in 16:
		song.at(69.9 + k * 0.16, _ignite.bind(here + stage.global_basis.x * (3.0 + k * 1.3)))
	await song.until(74.6)


## 1:15 — привал: «Ты кормишь других», щит, фляга и плед на его плечи.
func _verse_two() -> void:
	sparkle.emitting = false
	_glow(1.2, 0.0)
	_put(sol, P(CAMP, 1.25, 0.35), P(CAMP, -0.6, 1.4))
	sol.set_pose(&"sit")
	_put(ilva, P(CAMP, -2.8, -1.2), P(CAMP, 1.25, 0.35))
	ilva.set_pose(&"")
	# У костра — те, кого он накормил: светящиеся тени с хлебом в руках.
	for i in 3:
		var p := others[3 + i]
		_put(p, P(CAMP, -1.5 + i * 1.0, -1.7 + absf(i - 1.0) * 0.35), P(CAMP, 0.0, 0.0))
		p.set_pose(&"hold")
		_show(p, GOLD)
	cs.flash(PALE, 0.5, 0.4)
	cs.mood(&"hearth", 0.0)
	_frame(CAMP, 0.2, -0.3, 6.6, -10.0)
	cs.cam(P(CAMP, 0.4, 0.0) + UP, 5.6, 5.0)
	cs.orbit(6.0, 6.0)
	cs.walk_then_face(ilva, P(CAMP, -0.7, 1.3), sol.global_position, 1.1)
	await song.until(78.3)
	if cs.skipped:
		return
	# «Ты каждому — брат, ты для каждого — щит» — удары на каждую долю.
	shade_sol.set_items([ItemState.create(&"shield")] as Array[ItemState])
	_gild(shade_sol, mats[shade_sol])
	_put(shade_sol, P(SHIELD, 0.0, 0.0), P(SHIELD, -4.0, 0.3))
	shade_sol.set_pose(&"shield_up")
	_show(shade_sol, GOLD)
	for i in 3:
		var p := others[3 + i]
		_put(p, P(SHIELD, 1.4 + i * 0.6, -0.7 + i * 0.75), P(SHIELD, -4.0, 0.3))
		p.set_pose(&"huddle")
		_show(p, COLD)
	cs.flash(CRIMSON, 0.35, 0.3)
	cs.mood(&"blood", 0.0)
	_frame(SHIELD, 0.7, 0.1, 6.2, -12.0)
	cs.cam(P(SHIELD, 0.5, 0.1) + UP, 5.0, 3.0)
	cs.orbit(8.0, 3.2)
	for bt in song.beats(78.5, 81.2):
		song.at(bt, _strike)
	await song.until(81.5)
	if cs.skipped:
		return
	# «Возьми мою флягу. Не спорь. Пора».
	for i in 3:
		_hide(others[3 + i])
	_hide(shade_sol)
	_put(ilva, P(CAMP, 0.15, 1.15), sol.global_position)
	ilva.set_pose(&"offer")
	cs.flash(PALE, 0.4, 0.3)
	cs.mood(&"hearth", 0.0)
	_frame(CAMP, 0.8, 0.5, 4.8, 6.0)
	cs.orbit(-6.0, 7.0)
	await song.until(82.4)
	cs.fly_to_hand(SetPieces.flask(), ilva.hand_position(), sol.model.sockets[&"l_hand"], 0.7, 0.4)
	await song.until(84.1)
	# «Пусть хоть кто-то тебя самого защитит» — она укрывает его.
	ilva.set_pose(&"")
	await song.until(84.8)
	_cover(sol)
	await song.until(86.3)
	cs.walk_then_face(ilva, P(CAMP, 2.0, -0.6), sol.global_position, 1.6)
	cs.cam(P(CAMP, 0.7, 0.0) + UP, 7.0, 2.2)
	await song.until(87.5)
	ilva.set_pose(&"lantern_high")
	await song.until(88.55)


## 1:29 — мост: предчувствие. Барабаны — тени уходят; арфа — «Я выйду из тьмы с фонарём: я здесь».
func _bridge() -> void:
	var dark := others
	for i in dark.size():
		var p := dark[i]
		_put(p, P(DREAD, -5.0 + i * 2.0, -2.2), P(DREAD, 0.0, 3.0))
		p.set_pose(&"")
		_darken(p)
	_put(tall, P(DREAD, 0.0, -5.4), P(DREAD, 0.0, 3.0))
	_darken(tall)
	shade_sol.set_items([] as Array[ItemState])
	_gild(shade_sol, mats[shade_sol])
	_put(shade_sol, P(DREAD, 0.0, 2.2), P(DREAD, 0.0, -6.0))
	shade_sol.set_pose(&"")
	_show(shade_sol, COLD)
	var red := cs.light(P(DREAD, 0.0, -3.0) + UP * 5.0, CRIMSON, 3.4, 20.0, 0.08)
	var spot := cs.light(P(DREAD, 0.0, 2.2) + UP * 4.0, COLD, 0.0, 6.5)
	cs.flash(CRIMSON, 0.3, 0.55)
	cs.mood(&"blood", 0.0)
	_frame(DREAD, 0.0, -1.4, 9.8, -10.0)
	cs.orbit(5.0, 5.0)
	# «Все, кого ты спас, — за братом твоим» — на каждую долю одна тень отворачивается и уходит.
	var turns := song.beats(89.2, 93.6)
	for i in mini(turns.size(), dark.size()):
		song.at(turns[i], _turn_away.bind(dark[i]))
	for bt in song.beats(88.9, 93.4):
		song.at(bt, func():
			cs.shake(0.22)
			cs.flash(CRIMSON, 0.25, 0.14))
	await song.until(93.7)
	# «Ты стоишь один» — один луч в темноте.
	CutsceneFx.light_to(red, 0.5, 1.5)
	CutsceneFx.light_to(spot, 2.6, 1.2)
	for p in dark:
		_fade(mats[p], 0.3, 1.5)
	cs.mood(&"hurt", 1.2)
	cs.cam(P(DREAD, 0.0, 2.0) + UP, 5.2, 2.0)
	await song.until(95.2)
	# «Ты — не один»: тёплый свет из-за спины.
	_put(ilva, P(DREAD, 6.6, 4.8), shade_sol.global_position)
	ilva.set_pose(&"")
	_glow(2.2, 0.0)
	cs.walk_then_face(ilva, P(DREAD, 1.5, 3.0), shade_sol.global_position, 2.3)
	cs.cam(P(DREAD, 0.9, 2.5) + UP, 6.0, 2.6)
	await song.until(98.5)
	ilva.set_pose(&"lantern_high")
	await song.until(98.95)
	# «Я здесь» — её свет разгоняет тени.
	_pulse(ilva.global_position, 11.0)
	_glow(4.0, 0.4)
	cs.flash(GOLD, 0.6, 0.35)
	cs.mood(&"legend", 1.0)
	CutsceneFx.light_to(red, 0.0, 1.0)
	CutsceneFx.light_to(spot, 0.0, 1.0)
	for p in dark:
		_fade(mats[p], 0.0, 1.0)
		CutsceneFx.dust(game.world, p.global_position, 0.8, Color(0.3, 0.1, 0.12, 0.6), 14)
	_fade(mats[tall], 0.0, 1.2)
	await song.until(100.0)
	# «Я знаю», — ответишь» — он оборачивается, холодная тень теплеет.
	cs.face(shade_sol, ilva.global_position)
	_tint(mats[shade_sol], GOLD * SHADE_GLOW, 1.4)
	ilva.set_pose(&"")
	cs.cam((shade_sol.global_position + ilva.global_position) * 0.5 + UP, 4.2, 1.6)
	cs.orbit(-12.0, 8.0)
	await song.until(104.5)
	# Подъём к последнему припеву.
	cs.cam((shade_sol.global_position + ilva.global_position) * 0.5 + UP, 8.6, 3.9)
	_glow(5.0, 3.8)
	sparkle.emitting = true
	await song.until(108.5)


## 1:49 — последний припев: вся дорога в её свете. «Пусть мир тебя предал весь».
func _final_chorus() -> void:
	_hide(shade_sol)
	cs.flash(GOLD, 0.9, 0.85)
	cs.mood(&"legend", 0.0)
	_walk_road(31.4)
	ilva.set_pose(&"sing")
	_glow(5.0, 0.0)
	game.rig.cine_track(_road_focus, 10.6, 0.0)
	game.rig.cine_track(_road_focus, 7.4, 5.0)
	cs.orbit(-22.0, 0.0)
	cs.orbit(20.0, 20.0)
	for bt in song.beats(108.6, 129.0):
		song.at(bt, _ignite_ahead)
	for bt in song.beats(108.6, 129.0, 2, 0):
		song.at(bt, _pillars)
	await song.until(113.5)
	# «Пусть мир тебя предал весь» — тени стоят у дороги спиной; её свет проходит мимо, и они тают.
	var from_x := stage.to_local(sol.global_position).x - ROAD.x
	for i in others.size():
		var p := others[i]
		var x := from_x + 4.5 + i * 2.6
		var side := -2.6 if i % 2 == 0 else 2.7
		_put(p, P(ROAD, x, side), P(ROAD, x, side * 4.0))
		p.set_pose(&"downcast")
		_darken(p)
		_fade(mats[p], 0.85, 0.5)
		song.at(113.6 + (4.5 + i * 2.6) / ROAD_SPEED - 0.5, _fade.bind(mats[p], 0.0, 1.4))
	await song.until(115.95)
	# «Горит над твоей тропою» — свет убегает вперёд.
	var here := sol.global_position
	for k in 16:
		song.at(116.0 + k * 0.18, _ignite.bind(here + stage.global_basis.x * (5.0 + k * 1.3)))
	await song.until(119.7)
	# «Мой свет. Я здесь. Я здесь».
	ilva.set_pose(&"lantern_high")
	for hit in [[120.0, 6.0], [120.86, 9.0], [121.56, 12.0]]:
		song.at(hit[0], func():
			_pulse(ilva.global_position, hit[1])
			cs.flash(GOLD, 0.35, 0.16))
	await song.until(122.9)
	# «Раздал ты всё, что есть».
	ilva.set_pose(&"sing")
	for k in Db.ITEM_IDS.size():
		song.at(122.95 + k * 0.26, _give_away.bind(k))
	await song.until(129.4)
	if cs.skipped:
		return
	# «Мой дар — лишь то, что я здесь» — они останавливаются; она встаёт перед ним.
	var front := sol.global_position + stage.global_basis.x * 1.25 + stage.global_basis.z * 0.25
	cs.walk_then_face(ilva, front, sol.global_position, 1.5)
	ilva.set_pose(&"")
	cs.cam((sol.global_position + front) * 0.5 + UP * 1.1, 4.4, 3.0)
	cs.orbit(6.0, 6.0)
	_glow(1.6, 3.0)
	sparkle.emitting = false
	await song.until(131.6)
	cs.face(sol, ilva.global_position)
	await song.until(134.4)
	# «И свет я тебе несу».
	ilva.set_pose(&"lantern_high")
	await song.until(135.2)
	_pulse(ilva.global_position, 4.5)
	await song.until(136.3)
	cs.ui.black(1.0, 0.8)
	await song.until(137.2)


## 2:17 — привал под утро. «Пойдём?» — «Пойдём». Они уходят вместе.
func _outro() -> void:
	fire.emitting = false
	CutsceneFx.light_to(fire_light, 0.9, 0.0)
	blanket.drop = 1.0
	# Они стоят в стороне от костра и бревна — на тропе, по которой уйдут.
	_put(sol, P(CAMP, 4.4, 2.2), P(CAMP, 10.0, 2.0))
	sol.set_pose(&"")
	_put(ilva, P(CAMP, 3.1, 2.9), sol.global_position)
	ilva.set_pose(&"")
	_glow(1.4, 0.0)
	cs.mood(&"scene", 0.0)
	_frame(CAMP, 3.7, 2.4, 5.2, -6.0)
	cs.orbit(4.0, 6.0)
	cs.ui.black(0.0, 0.7)
	await song.until(GO_AT)
	_speak(&"faithful", Story.SONG["go"])
	ilva.set_pose(&"offer")
	await song.until(GO_REPLY_AT - 0.3)
	cs.ui.hide_line()
	ilva.set_pose(&"")
	cs.face(sol, ilva.global_position)
	await song.until(GO_REPLY_AT)
	_speak(&"hero", Story.SONG["go_2"])
	await song.until(142.0)
	if cs.skipped:
		return
	# Оркестр: уходят рядом, тропа загорается под ногами, камера поднимается.
	_pulse((sol.global_position + ilva.global_position) * 0.5, 8.0)
	cs.walk(sol, P(CAMP, 18.0, 1.6), ROAD_SPEED)
	cs.walk(ilva, P(CAMP, 16.7, 2.6), ROAD_SPEED)
	game.rig.cine_track(func(): return (sol.global_position + ilva.global_position) * 0.5 + UP, 11.5, 9.0)
	cs.orbit(18.0, 10.0)
	cs.mood(&"legend", 4.0)
	_glow(3.4, 2.0)
	for bt in song.beats(142.6, 154.0):
		song.at(bt, _ignite_ahead)
	await song.until(142.9)
	cs.ui.hide_line()
	await song.until(152.6)
	cs.ui.black(1.0, 4.2)
	await song.until(157.6)


# --- Действия ----------------------------------------------------------------

## Оба встают в начале дороги и идут по ней до to_x: он впереди, она на шаг позади, ближе к зрителю.
func _walk_road(to_x: float) -> void:
	_put(sol, P(ROAD, 0.0, 0.0), P(ROAD, 6.0, 0.0))
	sol.set_pose(&"")
	_put(ilva, P(ROAD, -1.4, 0.95), P(ROAD, 6.0, 0.95))
	road_snow.global_position = P(ROAD, 4.0, 0.0) + UP * 3.5
	road_snow.restart()
	cs.walk(sol, P(ROAD, to_x, 0.0), ROAD_SPEED)
	cs.walk(ilva, P(ROAD, to_x - 1.4, 0.95), ROAD_SPEED)


func _road_focus() -> Vector3:
	return (sol.global_position + ilva.global_position) * 0.5 + UP + stage.global_basis.x * 1.0


## Плита света на тропе — в шаге перед Солдатом.
func _ignite_ahead() -> void:
	_ignite(sol.global_position + sol.facing * 1.9)


## Плита света: вспыхивает, держится и гаснет сама.
func _ignite(at: Vector3) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.56, 0.4)
	# Не «сложением»: на светлом снегу золото стало бы белым.
	var mat := Vfx.material(Color(GOLD, 0.82), 1.1)
	# Плита рисуется раньше теней под ногами: иначе тень и плита менялись бы местами на ходу.
	mat.render_priority = -1
	var tile := MeshInstance3D.new()
	tile.mesh = plane
	tile.material_override = mat
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(tile)
	tile.global_position = Vector3(at.x, 0.05, at.z)
	tile.global_rotation.y = atan2(sol.facing.x, sol.facing.z) + PI / 2
	tile.scale = Vector3(0.2, 1.0, 0.2)
	var tw := tile.create_tween().set_ignore_time_scale(true)
	tw.tween_property(tile, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.0)
	tw.tween_callback(tile.queue_free)
	CutsceneFx.flare(game.world, tile.global_position + UP * 0.5, GOLD, 0.8, 2.8, 0.9)


## Лучи света по обе стороны дороги — на сильную долю.
func _pillars() -> void:
	var ahead := sol.global_position + sol.facing * 4.0
	for s in [-1.0, 1.0]:
		_beam(ahead + stage.global_basis.z * s * 2.4, GOLD, 0.9)


## Тонкий луч света от земли: встаёт, держится hold секунд и гаснет.
func _beam(at: Vector3, color: Color, hold: float) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.17
	cyl.height = 4.6
	cyl.radial_segments = 6
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := Vfx.material(Color(color, 0.62), 1.15)
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(mi)
	mi.global_position = Vector3(at.x, 2.3, at.z)
	mi.scale = Vector3(1.0, 0.05, 1.0)
	var tw := mi.create_tween().set_ignore_time_scale(true)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.tween_callback(mi.queue_free)
	CutsceneFx.flare(game.world, Vector3(at.x, 0.8, at.z), color, 1.2, 3.2, hold + 0.8)


## Огонь одной из семи вещей уходит от Солдата в темноту: он отдаёт — и не становится слабее.
func _give_away(k: int) -> void:
	var id: StringName = Db.ITEM_IDS[k % Db.ITEM_IDS.size()]
	var color := Db.item(id).essence.color
	var from := sol.global_position + UP * 1.2
	var a := TAU * k / float(Db.ITEM_IDS.size()) + 0.4
	var to := from + (stage.global_basis.x * cos(a) + stage.global_basis.z * sin(a)) * 6.5 + UP * 1.6
	var orb := LowPoly.sphere(0.13, 6, 4, color, Vector3.ZERO, 0.5, 0.0, 3.0)
	stage.add_child(orb)
	orb.global_position = from
	CutsceneFx.trail(orb, color)
	CutsceneFx.flare(game.world, from, color, 1.8, 3.5, 0.6)
	var tw := orb.create_tween().set_ignore_time_scale(true)
	tw.tween_property(orb, "global_position", to, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(orb, "scale", Vector3.ONE * 0.2, 1.5)
	tw.tween_callback(orb.queue_free)


## Удар в щит: искры, багровая вспышка, тряска.
func _strike() -> void:
	var at := shade_sol.global_position - stage.global_basis.x * 0.75 + UP * 1.1
	CutsceneFx.sparks(game.world, at, Color(1.0, 0.45, 0.3), 18, 4.0)
	CutsceneFx.flare(game.world, at, CRIMSON, 2.6, 5.0, 0.4)
	cs.shake(0.18)


## Тень отворачивается от Солдата и уходит к высокой фигуре.
func _turn_away(p: Puppet) -> void:
	var to := tall.global_position + (p.global_position - tall.global_position) * 0.45
	cs.walk(p, to, 1.3)


## Плащ переходит с плеч на плечи; замёрзший теплеет и распрямляется.
func _wrap(cloak: WornCloak, from: Puppet, to: Puppet) -> void:
	from.set_pose(&"offer")
	cloak.take_off()
	await cs.fly(cloak, cloak.global_position, WornCloak.shoulders(to), 0.9, 0.8, CLOAK)
	if cs.skipped or not is_instance_valid(cloak):
		return
	cloak.put_on(to)
	from.set_pose(&"")
	to.set_pose(&"wring")
	_tint(mats[to], GOLD * SHADE_GLOW, 1.0)
	CutsceneFx.flare(game.world, to.global_position + UP, GOLD, 1.8, 3.5, 1.0)


## Оберег переходит из руки Солдата в руки Сольвейг.
func _hand_amulet(amulet: Node3D) -> void:
	var color := Db.item(&"amulet").essence.color
	var from := amulet.global_position
	var xf := amulet.global_transform
	amulet.get_parent().remove_child(amulet)
	game.world.add_child(amulet)
	amulet.global_transform = xf
	await cs.fly(amulet, from, solveig.hand_position(), 0.8, 0.6, color)
	if cs.skipped or not is_instance_valid(amulet):
		return
	solveig.hold(amulet, &"r_hand", 0.9)
	solveig.set_pose(&"hold")
	shade_sol.set_pose(&"")
	CutsceneFx.flare(game.world, solveig.hand_position(), color, 2.0, 3.0, 0.9)


## Ильва укрывает спящего пледом: теперь хоть кто-то защитит его самого.
func _cover(who: Puppet) -> void:
	blanket.visible = true
	blanket.take_off()
	blanket.scale = Vector3.ONE * 0.3
	blanket.create_tween().set_ignore_time_scale(true).tween_property(blanket, "scale", Vector3.ONE, 0.8)
	await cs.fly(blanket, ilva.hand_position(), WornCloak.shoulders(who), 0.9, 0.7, GOLD)
	if cs.skipped or not is_instance_valid(blanket):
		return
	# Он сидит: плед — на плечах, до бревна, а не сквозь него.
	blanket.drop = 0.5
	blanket.put_on(who)
	CutsceneFx.flare(game.world, who.global_position + UP, GOLD, 1.8, 4.0, 1.2)


## Слова вслух поверх музыки: строка с именем, напечатана сразу.
func _speak(who: StringName, text: String) -> void:
	if cs.skipped:
		return
	var sp := Story.speaker(who)
	cs.ui.show_line(sp["name"], sp["color"], text)
	cs.ui.set_typed(1.0)


## Круг света от фонаря по земле.
func _pulse(at: Vector3, radius: float) -> void:
	if cs.skipped:
		return
	Vfx.ring(ilva, Vector3(at.x, 0.0, at.z), radius, GOLD, 1.1, 0.3)
	CutsceneFx.flare(game.world, at + UP * 1.4, GOLD, 2.4, radius, 1.0)


## Сила её света: большой тёплый свет вокруг Ильвы.
func _glow(energy: float, dur: float) -> void:
	if dur <= 0.0 or cs.skipped:
		glow_base = energy
		return
	glow.create_tween().set_ignore_time_scale(true).tween_property(self, "glow_base", energy, dur)


## Каждый кадр: снег идёт за идущими по дороге; свет Ильвы вздрагивает на каждую долю.
func _on_tick(t: float) -> void:
	if is_instance_valid(road_snow) and is_instance_valid(sol):
		var here := stage.to_local(sol.global_position)
		if here.z > ROAD.z - 20.0:
			road_snow.global_position = sol.global_position + stage.global_basis.x * 3.0 + UP * 3.5
	if is_instance_valid(glow):
		var phase := fposmod(t - BEAT_PHASE, BEAT) / BEAT
		glow.light_energy = glow_base * (1.0 + 0.3 * (1.0 - phase) * (1.0 - phase))


# --- Тени и расстановка --------------------------------------------------------

## Точка места действия: x — вправо по кадру, z — к зрителю.
func P(place: Vector3, x: float, z: float) -> Vector3:
	return stage.to_global(place + Vector3(x, 0.0, z))


## Кадр сразу: без наезда.
func _frame(place: Vector3, x: float, z: float, zoom: float, yaw: float) -> void:
	cs.cam(P(place, x, z) + UP, zoom, 0.0)
	cs.orbit(yaw, 0.0)


func _put(a: Puppet, pos: Vector3, look: Vector3) -> void:
	cs._place(a, Vector3(pos.x, 0.0, pos.z))
	a.look_toward(look)
	a.visible = true


func _size(p: Puppet, k: float) -> void:
	p.model.scale = Vector3.ONE * k


## Тень: все сетки актёра — одним светящимся материалом.
func _gild(n: Node, mat: StandardMaterial3D) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gild(ch, mat)


## Тень появляется в цвете color.
func _show(p: Puppet, color: Color) -> void:
	var m: StandardMaterial3D = mats[p]
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r * SHADE_GLOW, color.g * SHADE_GLOW, color.b * SHADE_GLOW, 0.0)
	# У сгенерированной модели Солдата много наложенных сеток: при той же прозрачности она выгорает в белое.
	_fade(m, 0.36 if p == shade_sol else SHADE, 0.5)


## Тёмная тень без лица: не светится, а закрывает собой свет.
func _darken(p: Puppet) -> void:
	var m: StandardMaterial3D = mats[p]
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = Color(0.035, 0.0, 0.015, 0.92)


func _hide(p: Puppet) -> void:
	var m: StandardMaterial3D = mats[p]
	m.albedo_color.a = 0.0


func _fade(mat: StandardMaterial3D, alpha: float, dur: float) -> void:
	if cs.skipped or dur <= 0.0:
		mat.albedo_color.a = alpha
		return
	cs.create_tween().set_ignore_time_scale(true).tween_property(mat, "albedo_color:a", alpha, dur)


func _tint(mat: StandardMaterial3D, color: Color, dur: float) -> void:
	if cs.skipped:
		mat.albedo_color = Color(color, mat.albedo_color.a)
		return
	var from := mat.albedo_color
	cs.create_tween().set_ignore_time_scale(true).tween_method(func(k: float):
		mat.albedo_color = Color(from.lerp(color, k), mat.albedo_color.a), 0.0, 1.0, dur)


## Плащ ровного цвета, без теней: под ночным светом ткань стала бы тёмной доской за спиной.
## Материал непрозрачный: прозрачные части рисуются в порядке удалённости и мерцали бы, меняясь местами
## со светящейся тенью, на которой плащ надет.
func _cloak(color: Color) -> WornCloak:
	var c := WornCloak.make(color)
	var m := Vfx.material(Color(color, 1.0), 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_gild(c, m)
	cs.prop(c)
	return c


func _spawn(who: StringName, key: String, shade: bool) -> Puppet:
	var p := cs.spawn(who, P(CAMP, 0.0, -30.0), P(CAMP, 0.0, 0.0), StringName("song_" + key))
	puppets.append(p)
	if shade:
		for junk in ["Bundle", "CaptainShield", "Lantern"]:
			var n := p.model.find_child(junk, true, false)
			if n != null and who != &"faithful":
				n.free()
		var m := Vfx.material(Color(GOLD, 0.0), SHADE_GLOW, true)
		mats[p] = m
		_gild(p, m)
	return p


# --- Постройка ---------------------------------------------------------------

func _build() -> void:
	stage = Node3D.new()
	stage.name = "SongStage"
	game.world.add_child(stage)
	cs.prop(stage)
	stage.global_position = ORIGIN
	stage.rotation.y = deg_to_rad(game.rig.yaw_degrees)
	_build_camp()
	_build_fjord()
	_build_blaze()
	for place in [PROMISE, OATH, SHIELD, DREAD]:
		_ground(place, Vector2(46, 32), NIGHT_SNOW, 0.06)
		_firs(place, [[-7.5, -5.5, 3.4], [-4.0, -7.0, 2.8], [5.0, -6.5, 3.6], [8.5, -4.0, 3.0], [-10.0, 3.5, 3.2], [10.5, 4.5, 2.9]])
		_snow(place, 90)
		cs.light(P(place, 0.0, -1.0) + UP * 7.5, COLD, 0.9, 24.0)
	cs.light(P(PROMISE, -0.2, 0.6) + UP * 2.2, ROSE, 1.6, 5.0)
	cs.light(P(SHIELD, -5.0, 0.5) + UP * 2.0, CRIMSON, 2.6, 9.0, 0.1)
	cs.light(P(DREAD, 0.0, -6.6) + UP * 2.6, PURPLE, 3.4, 7.0)
	_build_road()
	_cast()


func _cast() -> void:
	ilva = _spawn(&"faithful", "ilva", false)
	sol = _spawn(&"hero", "hero", false)
	sol.set_items(RunState.ring.items.duplicate())
	shade_sol = _spawn(&"hero", "shade_hero", true)
	shade_ilva = _spawn(&"faithful", "shade_ilva", true)
	solveig = _spawn(&"beloved", "solveig", true)
	for who in [&"friend", &"smith", &"novice", &"widow", &"refugee", &"refugee"]:
		others.append(_spawn(who, "other_%d" % others.size(), true))
	_size(others[4], 0.62)
	_size(others[5], 0.7)
	tall = _spawn(&"brother", "tall", true)
	_size(tall, 1.3)
	# Её свет: большой тёплый огонь поверх фонаря и золотые искры в воздухе вокруг.
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.78, 0.46)
	glow.light_energy = 0.0
	glow.omni_range = 9.0
	glow.position = Vector3(0, 1.5, 0)
	ilva.add_child(glow)
	sparkle = CutsceneFx.motes(ilva, ilva.global_position + UP * 1.4, Vector3(2.6, 1.2, 2.6), GOLD, 46, 0.3)
	sparkle.emitting = false
	blanket = _cloak(BLANKET)
	blanket.visible = false


func _ground(place: Vector3, size: Vector2, color: Color = SetPieces.SNOW, emission: float = 0.1) -> void:
	var g := SetPieces.snow_ground(size, color, emission)
	stage.add_child(g)
	g.position = place


func _add(node: Node3D, place: Vector3, x: float, z: float, yaw: float = 0.0) -> Node3D:
	stage.add_child(node)
	node.position = place + Vector3(x, 0.0, z)
	node.rotation.y = yaw
	return node


func _firs(place: Vector3, spots: Array) -> void:
	for s in spots:
		_add(SetPieces.fir(s[2]), place, s[0], s[1], s[0] * 0.7)


func _snow(place: Vector3, amount: int) -> CPUParticles3D:
	return cs.motes(P(place, 0.0, 0.0) + UP * 3.5, Vector3(12.0, 1.6, 9.0), SNOWFLAKE, amount, -0.7)


func _build_camp() -> void:
	_ground(CAMP, Vector2(46, 34), CAMP_SNOW, 0.08)
	_add(SetPieces.campfire(), CAMP, 0.0, 0.0)
	# Солдат сидит на пне; бревно лежит по другую сторону костра, где никто не ходит.
	_add(SetPieces.stump(), CAMP, 1.36, 0.29)
	_add(SetPieces.log_seat(), CAMP, 2.7, -1.9, 0.5)
	# Справа от костра ели стоят только в глубине: там тропа, по которой они уйдут.
	_firs(CAMP, [[-6.0, -5.0, 3.6], [-3.4, -6.6, 3.0], [0.6, -7.2, 3.8], [4.2, -6.0, 3.1], [7.2, -4.4, 3.5], [-8.4, -1.8, 2.8],
			[10.5, -4.8, 3.2], [-10.0, 4.2, 3.4], [14.0, -5.5, 3.0], [17.5, -3.8, 3.4]])
	for d in [[-3.0, -3.4, 1.2], [3.6, -2.8, 1.0], [-5.2, 2.4, 1.4], [9.0, -2.2, 1.1]]:
		_add(SetPieces.snow_drift(d[2]), CAMP, d[0], d[1])
	fire = CutsceneFx.fire(game.world, P(CAMP, 0.0, 0.0) + UP * 0.25, 0.45)
	cs.prop(fire)
	fire_light = cs.light(P(CAMP, 0.0, 0.0) + UP * 0.9, EMBER, 2.8, 8.5, 0.16)
	cs.light(P(CAMP, 0.0, -2.0) + UP * 7.5, COLD, 1.2, 24.0)
	cs.motes(P(CAMP, 0.0, 0.0) + UP * 1.2, Vector3(0.5, 0.8, 0.5), EMBER, 14, 0.5)
	_snow(CAMP, 110)


func _build_fjord() -> void:
	_ground(FJORD, Vector2(48, 34), DARK_ICE, 0.12)
	for ship in [[6.8, -3.4, 0.25, 0.1], [12.0, -7.2, -0.15, -0.08]]:
		var s := _add(SetPieces.longship(), FJORD, ship[0], ship[1], ship[2])
		s.position.y = -0.12
		s.rotation.x = ship[3]
	for crack in [[-3.0, 2.0, 5.0, 0.5], [1.5, -1.0, 4.0, -0.7], [9.0, 0.5, 6.0, 0.2], [-6.0, -3.0, 3.5, -0.3]]:
		var c := LowPoly.box(Vector3(crack[2], 0.02, 0.06), SetPieces.ICE.lightened(0.2), Vector3.ZERO, 0.6, 0.0, 0.5)
		_add(SetPieces.steady(c), FJORD, crack[0], crack[1], crack[3]).position.y = 0.002
	for d in [[-9.0, -8.0, 2.4], [-2.0, -9.5, 2.8], [5.0, -10.0, 2.2], [15.0, -9.0, 2.6], [-12.0, 6.0, 2.0]]:
		_add(SetPieces.snow_drift(d[2]), FJORD, d[0], d[1])
	_firs(FJORD, [[-10.5, -9.0, 3.4], [-6.0, -10.5, 3.0], [17.0, -10.0, 3.6]])
	cs.light(P(FJORD, 2.0, -2.0) + UP * 8.5, COLD, 1.4, 28.0)
	_snow(FJORD, 110)


func _build_blaze() -> void:
	_ground(BLAZE, Vector2(46, 32), NIGHT_SNOW, 0.06)
	var hut := _add(SetPieces.burning_hut(), BLAZE, -2.4, -3.2, 0.2)
	var sizes := [1.4, 0.9, 1.0, 0.7]
	var points: Array = hut.get_meta(&"fire_points")
	for i in points.size():
		cs.prop(CutsceneFx.fire(game.world, hut.to_global(points[i]), sizes[i]))
	cs.light(P(BLAZE, -2.0, -2.0) + UP * 3.2, EMBER, 3.0, 15.0, 0.25)
	cs.light(P(BLAZE, 2.0, 2.0) + UP * 6.0, COLD, 0.8, 16.0)
	cs.motes(P(BLAZE, -1.5, -2.0) + UP * 3.0, Vector3(4.0, 2.4, 3.0), EMBER, 60, 0.9)
	_firs(BLAZE, [[4.5, -6.0, 3.4], [8.0, -3.5, 3.0], [-8.5, -4.5, 3.2]])


func _build_road() -> void:
	var g := SetPieces.snow_ground(Vector2(150, 30), CAMP_SNOW, 0.08)
	stage.add_child(g)
	g.position = ROAD + Vector3(40, 0, 0)
	# Тропа — ниже теней под ногами (2.5 см) и плит света (5 см), и не дрожит вместе с землёй.
	var path := LowPoly.box(Vector3(140, 0.02, 1.4), CAMP_SNOW.darkened(0.16), Vector3.ZERO, 0.95, 0.0, 0.06)
	_add(SetPieces.steady(path), ROAD, 40.0, 0.0).position.y = 0.002
	for k in 28:
		var x := -22.0 + k * 5.0
		_add(SetPieces.cairn(), ROAD, x, -1.7 if k % 2 == 0 else 1.7, k * 0.9)
		_add(SetPieces.fir(2.6 + (k * 7 % 5) * 0.28), ROAD, x + 1.7, -4.2 - (k * 5 % 4) * 1.3, k * 1.3)
		if k % 3 == 0:
			_add(SetPieces.fir(2.8 + (k % 4) * 0.25), ROAD, x - 1.2, 6.0 + (k % 2) * 1.6, k * 0.6)
		if k % 2 == 1:
			_add(SetPieces.snow_drift(1.0 + (k % 3) * 0.3), ROAD, x + 0.5, 3.4)
		if k % 4 == 0:
			cs.light(P(ROAD, x, -1.0) + UP * 8.0, COLD, 1.3, 26.0)
	road_snow = cs.motes(P(ROAD, 4.0, 0.0) + UP * 3.5, Vector3(14.0, 1.6, 9.0), SNOWFLAKE, 130, -0.7)


func _finalize(moon: Node3D) -> void:
	if song != null and is_instance_valid(song):
		if song.tick.is_connected(_on_tick):
			song.tick.disconnect(_on_tick)
		cs.get_tree().create_timer(1.6, true, false, true).timeout.connect(song.queue_free)
	for p in puppets:
		if is_instance_valid(p):
			p.queue_free()
	for key in cs.cast.keys():
		if String(key).begins_with("song_"):
			cs.cast.erase(key)
	cs.ui.hide_line()
	cs.clear_props()
	game.arena.set_indoor(false)
	if moon != null:
		moon.visible = true
	cs.mood(&"none", 0.0)
	game.rig.cine_release(0.0)
	Audio.play_music(&"music_calm", 2.0)
