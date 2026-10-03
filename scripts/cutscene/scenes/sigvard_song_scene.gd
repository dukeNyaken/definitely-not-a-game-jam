class_name SigvardSongScene
extends RefCounted
## Песня Сигварда «Всё твоё — моё» — музыкальная сцена после последнего дара, вместо шестого голоса
## из дворца: «Теперь я — это он. Только лучше. Во всём» и шутка про карманы — это и есть конец песни.
## Злодейский номер накануне ворот: Сигвард репетирует встречу с братом — с соломенным чучелом в его
## плаще, — и хвастает всем, что заберёт.
##
## Сцена идёт по часам песни (SongTrack): кадры сменяются на строках, огонь жаровен бьёт в доли,
## снятые с ударных (*.beats.json). Места действия стоят далеко от арены:
##   тронный зал — шесть жаровен, хирд стражи, шут-скальд со скрипкой, чучело брата на ковре;
##   двор крепости — его память лиловыми тенями: деревянные мечи, отец смотрит на младшего;
##   покои ярла — мост песни: свеча догорает, перстень уходит младшему, отец так и не оборачивается.
##
## Цвет теней — чей человек: золотой — младший брат, каким его видели все; бледный — ещё ничей;
## лиловый — купленный Сигвардом. На «Продано!» тень лиловеет и кланяется. Тот, чью вещь Солдат
## оставил себе, Сигварду не продан: тень отворачивается — хвастовство повисает в воздухе.
##
## Жвачка (см. GumStrand, PalaceScene) — сквозная шутка песни: в конце первого припева он вскидывает
## руки и не замечает её, на «Во вс—» музыка обрывается, и он видит; на последнем «Во всё-ё-ём!»
## она снова тянется из карманов — «Ладно. Во всём, кроме карманов». Виноват, конечно, шут.
##
## Варианты забега: если сапоги остались у Солдата, «Сапоги-то ты отдал» было бы неправдой — песня
## начинается с «Скальд! Музыку.». У чучела в руках та вещь, что Солдат оставил себе; на «Ты уйдёшь —
## ни с чем» Сигвард забирает и её. Перстень на его руке — только если перчатки отданы Бьёрну.
## На последнем ударе иллюзия осыпается: вещи падают на пол, тени гаснут — у ворот всё будет всерьёз.

const AUDIO := "res://assets/audio/evel_brother_musicle/Всё твоё — моё.wav"
const SYNC := "res://assets/audio/evel_brother_musicle/Всё твоё — моё.sync.json"
const BEATS := "res://assets/audio/evel_brother_musicle/Всё твоё — моё.beats.json"

## Секунды записи — сняты по ней: громкость, атаки ударных, разметка слов.
## Без шутки про сапоги песня начинается здесь — с «Скальд!».
const SKALD_FROM := 10.3
const MUSIC_IN := 14.0
const VERSE_ONE := 21.1
const PRE_CHORUS := 47.4
const CHORUS := 65.89
const VERSE_TWO := 87.6
## «(Продано!)» — четыре раза в куплете торга.
const SOLD: Array[float] = [98.32, 101.64, 104.88, 108.06]
## «[стоп, тишина]» после «А невеста твоя?» и возвращение музыки.
const HUSH := 113.4
const MUSIC_BACK := 117.72
## «Во вс—»: музыка обрывается.
const CUT := 131.95
const HORN := 146.65
const POP := 152.45
const BRIDGE := 156.48
const ROAR := 179.5
const BUILD := 181.3
const FINAL := 188.18
const LAST_HIT := 209.7
const POP_LAST := 216.1
const END := 219.6

const ORIGIN := Vector3(-150, 0, 150)
const HALL := Vector3(0, 0, 0)
const YARD := Vector3(70, 0, 0)
const CHAMBER := Vector3(140, 0, 0)

const EMBER := Color(1.0, 0.45, 0.18)
const CRIMSON := Color(0.95, 0.18, 0.1)
const GOLD := Color(1.0, 0.8, 0.4)
const VIOLET := Color(0.72, 0.45, 1.0)
const PALE := Color(0.72, 0.82, 1.0)
const ROSE := Color(1.0, 0.5, 0.6)
const COLD := Color(0.6, 0.72, 1.0)
const DUSK := Color(1.0, 0.55, 0.28)
const STRAW := Color(0.85, 0.72, 0.42, 0.8)
const CLOAK := Color(0.55, 0.1, 0.08)
const UP := Vector3(0, 1.0, 0)
const SHADE := 0.55
const SHADE_GLOW := 0.8
## Старший в покоях отца — не светлая тень, а тусклая лиловая.
const DARK_SHADE := Color(0.36, 0.16, 0.55)
## Жвачка видна, когда рука дальше этого от кармана: только у вскинутых рук (см. GumStrand.min_length).
const GUM_REACH := 0.7
## Луч над Сигвардом: высота и угол — пятно на полу радиусом около двух метров.
const SPOT_H := 5.0
## Сила луча — в долях spot_base: так значения в сцене читаются как «слабый/сильный», а не в люменах.
const SPOT_GAIN := 2.6

## Где кто стоит в тронном зале (x — вправо по кадру, z — к зрителю).
const SIG_HOME := Vector2(0.0, -0.9)
const CENTER := Vector2(0.0, 1.0)
const EFFIGY_AT := Vector2(0.0, 4.2)
const SKALD_AT := Vector2(-1.2, -1.9)
## Предприпев: золотой брат — на ковре перед троном, Сигвард смотрит на него с края, ближе к нам.
const GOLDEN_AT := Vector2(0.0, -0.2)
const GOLDEN_WATCH := Vector2(-1.5, 2.6)
## Конец куплета-торга: Сигвард перед стеной купленных — левее чучела, чтобы оно не закрывало его в кадре.
const WALL_FRONT := Vector2(-1.4, 3.0)
const DOG_AT := Vector2(1.7, 0.45)
## Помосты торга — между рядами боковых жаровен.
const BLOCKS_Z := 2.2
const BLOCKS_X: Array[float] = [-2.25, -0.75, 0.75, 2.25]
## Кого продают на торгу — по строкам куплета: друг, мальчишка, капитан, вдова.
const AUCTION: Array[String] = ["friend", "refugee", "captain", "widow"]

var cs: Cutscene
var game: Game
var song: SongTrack
var stage: Node3D
var sig: Puppet
var hird: Array[Puppet] = []
var skald: Puppet
var bow: Node3D
var bubble: MeshInstance3D
var effigy: Node3D
var effigy_cloak: Node3D
var effigy_item: Node3D
var kept_id: StringName = &""
## Тени: ключ -> Puppet; материал каждой тени — в mats.
var shades: Dictionary = {}
var mats: Dictionary = {}
var puppets: Array[Puppet] = []
var dog: Node3D
var dog_mat: StandardMaterial3D
var shield: Node3D
var blocks: Array[Node3D] = []
var block_lights: Array[OmniLight3D] = []
var braziers: Array[Node3D] = []
## Свет жаровен: у трона — по лампе на жаровню, боковые — по одной на пару.
var flames: Array[OmniLight3D] = []
## Огонь каждой жаровни: [ровное пламя, большое — когда зал в огне].
var fires: Array[Array] = []
## Угли всех жаровен — один материал: тлеют тёмно-красным и разгораются с жаром зала.
var coal_mat: ShaderMaterial
## Лампы, которые гаснут до нуля: погасшая прячется и не занимает места — в GL Compatibility на объект
## действует не больше восьми ламп, лишние отбрасываются как попало.
var dim_lights: Array[OmniLight3D] = []
var key_light: OmniLight3D
var back_light: OmniLight3D
var gold_light: OmniLight3D
var candle: OmniLight3D
var candle_fire: CPUParticles3D
## Язычок пламени на самой свече: гаснет вместе с ней.
var candle_flame: Node3D
var spot: SpotLight3D
var orbit_light: OmniLight3D
var purse: Node3D
var horn: Node3D
var ring: Node3D
var pockets: Dictionary = {}
var gum: Array[GumStrand] = []
## Вещи вокруг Сигварда: по Db.ITEM_IDS. Видна ли вещь на орбите — orbit_on.
var orbit_items: Array[Node3D] = []
var orbit_on: Array[bool] = []
var orbit_trails: Array[CPUParticles3D] = []
var orbit_r: float = 1.9
var orbit_h: float = 1.5
var orbit_spin: float = 1.2
var orbit_angle: float = 0.0
## Жар зала: 0 — угли, 1 — всё в огне. Жаровни вздрагивают на каждую долю сильнее, чем жарче.
var heat: float = 0.0
var spot_base: float = 0.0
var skald_playing: bool = false
var dog_wag: bool = false
var _last_t: float = 0.0
var _heat_tw: Tween
var _spot_tw: Tween
var _orbit_tw: Tween


static func play(p_cs: Cutscene, p_game: Game) -> void:
	var s := SigvardSongScene.new()
	s.cs = p_cs
	s.game = p_game
	await s._play()


## Запись и разметка на месте — иначе после шестого дара идёт прежний голос из дворца.
static func available() -> bool:
	return ResourceLoader.exists(AUDIO) and FileAccess.file_exists(SYNC)


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
	# Модели встают в позу покоя за несколько кадров: только тогда видно, где у Сигварда карманы.
	for i in 6:
		await cs.get_tree().process_frame
	_make_pockets()
	song = SongTrack.load_track(SYNC, AUDIO, BEATS)
	cs.add_child(song)
	song.tick.connect(_on_tick)
	song.start(cs, 0.0 if Story.was_given(RunState.snapshots, &"boots") else SKALD_FROM)
	_last_t = song.now()
	await _body()
	cs.ui.black(1.0, 0.0 if cs.skipped else 0.5)
	song.stop(0.25 if cs.skipped else 1.0)
	await cs.wait(0.6)
	_finalize(moon)
	game.hud.fade(true, 0.01)
	cs.end()
	cs.ui.black(0.0, 0.0)


func _body() -> void:
	for part in [_intro, _verse_one, _pre_chorus, _chorus_one, _verse_two, _half_chorus, _gum_break,
			_bridge, _build_up, _final_chorus, _outro]:
		await (part as Callable).call()
		if cs.skipped:
			return


# --- Части песни -------------------------------------------------------------

## 0:00 — зал во тьме, тлеют угли. Сигвард репетирует встречу: «Ну здравствуй, младший» — чучелу в плаще брата.
## «Скальд! Музыку.» — шут вскидывает скрипку, и жаровни вспыхивают одна за другой.
func _intro() -> void:
	var greet := H(EFFIGY_AT.x, EFFIGY_AT.y - 1.7)
	var dummy := H(EFFIGY_AT.x, EFFIGY_AT.y)
	_put(sig, H(SIG_HOME.x, SIG_HOME.y), dummy)
	cs.mood(&"palace", 0.0)
	_heat_to(0.06, 0.0)
	_spot_to(1.8, 0.0)
	if song.now() < SKALD_FROM:
		# Из-за плеча чучела, низко: оно спиной к нам, Сигвард спускается от трона ему навстречу.
		_frame(HALL, EFFIGY_AT.x, EFFIGY_AT.y - 2.2, 6.2, 8.0, -16.0, 1.3)
		cs.ui.black(0.0, 2.4)
		cs.cam(H(EFFIGY_AT.x, EFFIGY_AT.y - 1.6) + UP * 1.3, 5.0, 6.5)
		cs.orbit(-6.0, 7.0)
		await song.until(1.2)
		cs.walk(sig, greet, 0.95)
		await song.until(2.85)
		# «…здравствуй, младший» — руки в стороны, как дорогому гостю.
		sig.set_pose(&"arms_up")
		_tag(effigy, Story.BROTHER_SONG["effigy"], Story.BROTHER_SONG["effigy_role"], Story.speaker(&"hero")["color"], 2.1, 3.0)
		await song.until(4.4)
		sig.set_pose(&"")
		await song.until(4.85)
		# «Вытирай ноги...» — палец в пол перед чучелом.
		sig.set_pose(&"point")
		cs.cam(H(EFFIGY_AT.x, EFFIGY_AT.y - 0.9) + UP * 1.0, 3.8, 2.4)
		cs.tilt(-8.0, 2.4)
		await song.until(6.3)
		sig.set_pose(&"")
		await song.until(7.6)
		if cs.skipped:
			return
		# «Ах да.» — взгляд вниз: у чучела вместо ног — столб на крестовине.
		cs.cam(dummy + UP * 0.35, 2.2, 0.35)
		cs.tilt(14.0, 0.35)
		await song.until(8.5)
		# «Сапоги-то ты отдал.» — сбоку и низко: двое друг против друга.
		_frame(HALL, EFFIGY_AT.x, EFFIGY_AT.y - 0.85, 4.2, 72.0, -12.0, 1.1)
		cs.orbit(60.0, 2.0)
		sig.set_pose(&"talk")
		await song.until(SKALD_FROM)
	else:
		_put(sig, greet, dummy)
		_frame(HALL, EFFIGY_AT.x, EFFIGY_AT.y - 0.85, 4.6, 40.0, -8.0, 1.1)
		cs.ui.black(0.0, 0.5)
	if cs.skipped:
		return
	# «Скальд!» — щелчок в сторону шута.
	await song.until(10.75)
	sig.set_pose(&"point")
	cs.face(sig, skald.global_position)
	cs.cam(skald.global_position + UP * 0.7, 2.8, 0.4)
	cs.orbit(-18.0, 0.4)
	cs.tilt(-6.0, 0.4)
	_tag(skald, Story.BROTHER_SONG["skald"], Story.BROTHER_SONG["skald_role"], Color(0.95, 0.55, 0.45), 1.35, 2.6)
	await song.until(12.55)
	# «Музыку.» — шут вскидывает скрипку.
	skald.set_pose(&"hold")
	skald_playing = true
	CutsceneFx.flare(game.world, skald.global_position + UP * 1.0, EMBER, 1.6, 3.0, 0.8)
	await song.until(MUSIC_IN)
	if cs.skipped:
		return
	# Музыка: жаровни вспыхивают одна за другой — от трона к нам, зал загорается. С этой минуты из карманов
	# тянется жвачка, стоит ему вскинуть руки, — он не замечает её до самого обрыва.
	sig.set_pose(&"")
	_gum_out()
	for i in braziers.size():
		song.at(MUSIC_IN + 0.1 + i * 0.12, _ignite.bind(i))
	_heat_to(0.55, 1.4)
	_spot_to(2.2, 1.0)
	cs.flash(EMBER, 0.6, 0.3)
	cs.cam(H(0.0, 0.8) + UP, 11.0, 4.5)
	cs.orbit(12.0, 7.0)
	cs.tilt(0.0, 3.0)
	cs.walk_then_face(sig, H(SIG_HOME.x, SIG_HOME.y + 0.3), H(0.0, 6.0), 1.4)
	var ch := Story.chapter("brother_song")
	song.at(MUSIC_IN + 1.2, func(): cs.chapter(ch[0], ch[1], true, 3.4))
	for b in song.bars(17.4, VERSE_ONE):
		song.at(b, _stomp)
	await song.until(19.6)
	cs.cam(H(0.0, -0.3) + UP * 1.3, 5.2, 1.5)
	await song.until(VERSE_ONE)


## 0:21 — его память, двор крепости на закате, лиловая плёнка. Старший — лиловая тень, младший — золотая,
## оба с деревянными мечами; отец смотрит только на младшего. Сам Сигвард стоит с краю и поёт.
func _verse_one() -> void:
	var yh: Puppet = shades["young_hero"]
	var ys: Puppet = shades["young_brother"]
	var father: Puppet = shades["father"]
	_put(sig, Y(-3.4, 1.7), Y(0.0, 0.4))
	sig.set_pose(&"talk")
	_put(yh, Y(-0.55, 0.4), Y(0.55, 0.4))
	_put(ys, Y(0.55, 0.4), Y(-0.55, 0.4))
	_put(father, Y(2.6, -1.4), Y(0.0, 0.4))
	father.set_pose(&"frail")
	yh.set_pose(&"hold")
	ys.set_pose(&"hold")
	_show(yh, GOLD)
	_show(ys, VIOLET)
	_show(father, Color(1.0, 0.9, 0.7), 0.42)
	cs.flash(VIOLET, 0.45, 0.4)
	cs.mood(&"envy", 0.0)
	_heat_to(0.2, 0.0)
	_spot_to(1.4, 0.0)
	_frame(YARD, -1.0, 0.0, 7.6, -12.0, -6.0)
	cs.cam(Y(-0.6, -0.2) + UP, 6.4, 7.0)
	cs.orbit(4.0, 9.0)
	await song.until(24.82)
	# «Я — первый по праву,» — старший выпячивает грудь.
	ys.set_pose(&"arms_up")
	await song.until(26.42)
	# «он — так, повезло.» — младший пожимает плечами.
	ys.set_pose(&"hold")
	yh.set_pose(&"offer")
	await song.until(27.7)
	yh.set_pose(&"hold")
	cs.cam((yh.global_position + ys.global_position) * 0.5 + UP * 0.9, 4.0, 1.2)
	cs.orbit(-8.0, 6.0)
	cs.tilt(-8.0, 2.0)
	# «Я раньше родился, я выше и злей,» — старший рубит, младший отбивает.
	for bt in song.beats(28.2, 30.9, 2, 0):
		song.at(bt, _spar.bind(ys, yh, &"chop"))
	await song.until(31.3)
	if cs.skipped:
		return
	# «Но меч у него почему-то быстрей!» — младший бьёт на каждую долю, старший пятится.
	for bt in song.beats(31.6, 33.8):
		song.at(bt, _spar.bind(yh, ys, &"slash"))
	song.at(32.4, cs.walk.bind(ys, Y(1.05, 0.5), 0.7))
	song.at(33.4, cs.face.bind(ys, Y(-0.55, 0.4)))
	await song.until(35.3)
	# «Он клал меня в грязь деревянным мечом» — удар, старший падает на колено.
	yh.gesture(&"chop", 0.3)
	await song.until(35.42)
	ys.set_pose(&"kneel")
	CutsceneFx.dust(game.world, ys.global_position, 1.0, Color(0.5, 0.4, 0.5, 0.7), 22)
	CutsceneFx.sparks(game.world, ys.global_position + UP * 0.9, GOLD, 16, 3.2)
	cs.shake(0.3)
	cs.flash(VIOLET, 0.3, 0.25)
	cs.cam(ys.global_position + UP * 0.8, 3.2, 0.5)
	cs.tilt(-10.0, 0.5)
	await song.until(37.9)
	# «И руку тянул мне —» — младший подаёт руку…
	yh.set_pose(&"offer")
	cs.cam((yh.global_position + ys.global_position) * 0.5 + UP * 0.8, 3.6, 1.0)
	await song.until(39.32)
	# «…мол, я ни при чём.» — старший отбивает её. Сигвард в настоящем отбивает её вместе с ним.
	ys.gesture(&"punch", 0.2)
	ys.set_pose(&"")
	sig.gesture(&"punch", 0.25)
	yh.set_pose(&"")
	cs.shake(0.12)
	cs.cam(Y(-1.6, 0.8) + UP, 6.4, 0.8)
	cs.tilt(-4.0, 0.8)
	await song.until(41.14)
	if cs.skipped:
		return
	# «Отец говорил: «Ты глядишь на клинок,» — отец указывает на старшего…
	cs.cam((father.global_position + ys.global_position + yh.global_position) / 3.0 + UP * 1.1, 5.4, 1.0)
	cs.orbit(-12.0, 3.0)
	father.set_pose(&"frail_offer")
	cs.face(father, ys.global_position)
	await song.until(44.3)
	# «А он — на тебя».» — …и поворачивается к младшему.
	cs.face(father, yh.global_position)
	_tint(mats[yh], GOLD * 1.3, 0.6)
	CutsceneFx.flare(game.world, yh.global_position + UP * 1.0, GOLD, 2.0, 3.0, 0.9)
	await song.until(45.7)
	# «Ну спасибо, урок!» — Сигвард кланяется отцовской тени. С издёвкой.
	sig.set_pose(&"bow")
	cs.cam(sig.global_position + UP * 1.1, 3.6, 0.5)
	cs.orbit(10.0, 1.5)
	await song.until(46.9)
	sig.set_pose(&"")
	for key in ["young_hero", "young_brother", "father"]:
		_vanish(shades[key], VIOLET)
	await song.until(PRE_CHORUS)


## 0:47 — предприпев в зале: «Кто первый в седле? (Он!)». Золотая тень брата в доспехах — у трона, где стоял
## бы наследник; двор поднимает его на щит, даже пёс виляет ему хвостом. Сигвард смотрит из-за края кадра.
## «Опять он. Всегда он. Во всём!» — крупно Сигвард, золотой брат светится у него за плечом.
func _pre_chorus() -> void:
	var golden: Puppet = shades["golden"]
	_put(sig, H(GOLDEN_WATCH.x, GOLDEN_WATCH.y), H(GOLDEN_AT.x, GOLDEN_AT.y))
	sig.set_pose(&"")
	_put(golden, H(GOLDEN_AT.x, GOLDEN_AT.y), H(0.0, 8.0))
	_show(golden, GOLD, 0.7)
	CutsceneFx.light_to(gold_light, 4.0, 0.4)
	gold_light.global_position = golden.global_position + UP * 3.0
	cs.flash(GOLD, 0.35, 0.3)
	cs.mood(&"palace", 0.0)
	_heat_to(0.45, 0.0)
	_spot_to(1.0, 0.0)
	_frame(HALL, -0.7, 1.1, 6.4, 8.0, -6.0, 1.3)
	cs.orbit(-4.0, 6.0)
	for p in hird:
		cs.face(p, golden.global_position)
	await song.until(47.6)
	# «Кто первый в седле?»
	golden.set_pose(&"triumph")
	await song.until(48.62)
	_on_him(golden)
	await song.until(49.2)
	# «Кто первый в бою?»
	golden.set_pose(&"")
	golden.gesture(&"slash", 0.3)
	CutsceneFx.sparks(game.world, golden.global_position + UP * 1.2 + stage.global_basis.z * 0.6, GOLD, 18, 3.5)
	await song.until(50.25)
	_on_him(golden)
	await song.until(50.84)
	if cs.skipped:
		return
	# «Кого на пиру поднимают на щит?» — двор подхватывает его на щит.
	var court: Array[Puppet] = []
	var spots := [[-0.75, -0.55], [0.75, -0.55], [-0.75, 0.6], [0.75, 0.6]]
	for i in 4:
		var p: Puppet = shades[["friend", "captain", "smith", "novice"][i]]
		court.append(p)
		_put(p, H(GOLDEN_AT.x + spots[i][0], GOLDEN_AT.y + spots[i][1]), golden.global_position)
		p.set_pose(&"")
		_show(p, PALE, 0.32)
	shield.visible = true
	shield.global_position = golden.global_position + UP * 0.06
	cs.cam(golden.global_position + UP * 1.4, 4.6, 1.0)
	await song.until(51.96)
	for p in court:
		p.set_pose(&"arms_up")
	var lift := golden.create_tween().set_ignore_time_scale(true).set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(golden.model, "position:y", 1.05, 0.8)
	lift.tween_property(shield, "global_position:y", 1.12, 0.8)
	CutsceneFx.flare(game.world, golden.global_position + UP * 2.4, GOLD, 2.6, 5.0, 1.2)
	cs.tilt(-12.0, 1.4)
	cs.orbit(10.0, 3.0)
	cs.cam(golden.global_position + UP * 1.8, 5.2, 1.4)
	await song.until(54.1)
	if cs.skipped:
		return
	# «Кому даже пёс у ворот не рычит?» — пёс лежит у порога и виляет хвостом.
	dog.visible = true
	dog_wag = true
	_fade(dog_mat, 0.75, 0.3)
	# Пёс в профиль у ног золотого брата, над ними — щит.
	cs.cam(dog.global_position.lerp(golden.global_position, 0.35) + UP * 0.9, 3.6, 0.0)
	cs.orbit(2.0, 0.0)
	cs.tilt(-8.0, 0.0)
	cs.orbit(10.0, 2.4)
	await song.until(56.36)
	cs.cam(golden.global_position + UP * 1.6, 5.0, 0.6)
	cs.orbit(6.0, 0.6)
	cs.tilt(-8.0, 0.6)
	await song.until(57.2)
	if cs.skipped:
		return
	# «Опять он.» — крупно Сигвард, к нам лицом; золотой брат — у него за плечом. «Всегда он.» — ещё ближе.
	cs.face(sig, H(GOLDEN_WATCH.x, 8.0))
	_frame(HALL, _lx(sig), _lz(sig) + 0.3, 3.2, -16.0, -2.0, 1.45)
	cs.mood(&"blood", 3.0)
	await song.until(58.05)
	cs.cam(sig.global_position + UP * 1.5, 2.5, 0.3)
	cs.shake(0.12)
	await song.until(59.2)
	# «Во всём!» — руки вверх, огонь растёт всю долгую ноту, а золотой брат тает лиловой пылью.
	sig.set_pose(&"triumph")
	_heat_to(1.0, 3.0)
	cs.cam(H(0.0, 1.0) + UP * 1.3, 9.0, 3.6)
	cs.orbit(24.0, 4.6)
	cs.tilt(0.0, 3.0)
	await song.until(61.8)
	_vanish(golden, VIOLET)
	for p in court:
		_vanish(p, VIOLET)
	CutsceneFx.light_to(gold_light, 0.0, 1.2)
	shield.create_tween().set_ignore_time_scale(true).tween_property(shield, "scale", Vector3.ONE * 0.01, 0.8)
	_fade(dog_mat, 0.0, 0.8)
	await song.until(63.0)
	# Нота стекает вниз — зал на миг гаснет перед припевом. Сигвард выходит на середину ковра.
	sig.set_pose(&"")
	_heat_to(0.12, 0.9)
	cs.mood(&"palace", 0.9)
	cs.walk_then_face(sig, H(CENTER.x, CENTER.y), H(0.0, 8.0), 1.2)
	for p in hird:
		cs.face(p, H(0.0, _lz(p)))
	await song.until(65.0)
	_hird_pose(&"arms_up")
	await song.until(CHORUS)


## 1:06 — припев: «Всё твоё — моё! (Хей!)». Зал в огне, хирд кричит «Хей!», вещи брата
## встают вокруг Сигварда — сначала меч, щит и шлем, по словам. «Во всём!» — руки вверх… и жвачка.
func _chorus_one() -> void:
	_burst(1.0)
	_hird_pose(&"")
	cs.mood(&"feast", 0.3)
	_spot_to(2.6, 0.3)
	_frame(HALL, 0.0, 1.4, 9.6, -16.0, -6.0)
	cs.cam(H(0.0, 1.2) + UP, 8.0, 9.0)
	cs.orbit(14.0, 10.0)
	cs.tilt(2.0, 8.0)
	await song.until(65.98)
	sig.set_pose(&"triumph")
	await song.until(67.25)
	_hey()
	sig.set_pose(&"talk")
	# «Меч, и щит, и шлем!»
	for word in [[67.58, &"sword"], [67.98, &"shield"], [68.36, &"helmet"]]:
		song.at(word[0], _claim.bind(word[1]))
	await song.until(68.85)
	_hey()
	await song.until(69.25)
	# «Всё твоё — моё —» — остальные отданные вещи встают в круг.
	var k := 0
	for id in Db.ITEM_IDS:
		if id in [&"sword", &"shield", &"helmet"]:
			continue
		song.at(69.25 + k * 0.2, _claim.bind(id))
		k += 1
	await song.until(70.8)
	# «Раздавай совсем!» — подзывает: давай-давай.
	sig.set_pose(&"offer")
	_orbit_to(1.9, 2.4, 0.6)
	await song.until(72.7)
	# «Ты отдашь — а я возьму,»
	sig.set_pose(&"talk")
	cs.cam(sig.global_position + UP * 1.3, 4.6, 1.4)
	await song.until(73.48)
	sig.gesture(&"grab", 0.3)
	await song.until(75.14)
	# «Ты посеешь — я пожну.» — взмах серпом: по полу бежит огненное кольцо.
	sig.gesture(&"slash", 0.3)
	Vfx.ring(sig, sig.global_position, 3.6, EMBER, 0.6)
	CutsceneFx.sparks(game.world, sig.global_position + UP * 0.3, EMBER, 20, 4.0)
	await song.until(75.54)
	if cs.skipped:
		return
	# «Кто поклялся поутру — К ночи у меня в строю!» — хирд сходится к ковру и строится коридором от трона.
	for i in hird.size():
		var p := hird[i]
		var row_z := -0.4 + (i % 3) * 1.3
		cs.walk_then_face(p, H(signf(_lx(p)) * 2.6, row_z), H(0.0, row_z), 1.5)
	cs.cam(H(0.0, 2.0) + UP, 9.0, 1.6)
	cs.orbit(-10.0, 3.0)
	await song.until(78.54)
	_hey()
	await song.until(79.14)
	if cs.skipped:
		return
	# «Я — это ты, только лучше.» — к чучелу, рука на плечо «брату».
	cs.walk(sig, H(0.0, 3.0), 1.4)
	cs.cam(H(0.0, 3.4) + UP * 1.3, 4.2, 1.2)
	cs.orbit(-26.0, 2.2)
	cs.tilt(-10.0, 1.2)
	await song.until(80.5)
	sig.set_pose(&"offer")
	await song.until(82.0)
	# «Во всём!» — руки вверх, и за ними из карманов тянется розовая жвачка. Он не замечает.
	cs.face(sig, H(0.0, 8.0))
	sig.set_pose(&"triumph")
	_heat_to(1.0, 0.3)
	_burst(0.8)
	cs.cam(H(0.0, 2.4) + UP * 1.2, 9.6, 3.4)
	cs.tilt(6.0, 3.4)
	cs.orbit(30.0, 3.6)
	_orbit_to(2.2, 3.4, 0.8)
	for b in song.bars(82.5, 85.6):
		song.at(b, _columns)
	await song.until(85.9)
	if cs.skipped:
		return
	# Скрипка коротко скрипит: он косится на бедро — и не замечает.
	cs.cam(_gum_focus(), 1.8, 0.25)
	cs.tilt(0.0, 0.25)
	cs.face(sig, sig.global_position + _side() * 2.0 + stage.global_basis.z * 2.0)
	await song.until(86.9)
	cs.face(sig, H(0.0, 8.0))
	cs.cam(sig.global_position + UP * 1.3, 4.6, 0.4)
	await song.until(87.3)
	sig.set_pose(&"")
	_orbit_to(1.9, 1.2, 0.6)
	await song.until(VERSE_TWO)


## 1:28 — куплет-торг: «Люди продаются, отец!». Кошель взлетает и рассыпается золотом; на четырёх
## помостах встают те, кому Солдат помог, и на каждое «Продано!» тень лиловеет и кланяется.
## «Все клялись: «Не предам!» — и стоят за мной стеной...» — и тишина: «А невеста твоя?»
func _verse_two() -> void:
	_orbit_hide()
	_heat_to(0.38, 1.2)
	_spot_to(2.0, 1.0)
	cs.mood(&"palace", 1.2)
	for i in blocks.size():
		var b := blocks[i]
		b.visible = true
		b.create_tween().set_ignore_time_scale(true).tween_property(b, "position:y", 0.0, 0.6).set_delay(i * 0.08)
		CutsceneFx.dust(game.world, b.global_position + Vector3(0, 0.3, 0), 0.7, Color(0.5, 0.42, 0.4, 0.6), 10)
	# Хирд отходит к стенам: место для торга.
	for p in hird:
		cs.walk_then_face(p, H(signf(_lx(p)) * 5.2, _lz(p)), H(0.0, _lz(p)), 1.4)
	cs.walk_then_face(sig, H(0.0, 0.5), H(0.0, 6.0), 1.4)
	await song.until(88.5)
	purse.visible = true
	sig.hold(purse, &"r_hand", 1.0)
	await song.until(88.9)
	# «Люди продаются, отец!» — кошель на ладони…
	cs.cam(sig.global_position + UP * 1.3, 3.8, 0.0)
	cs.orbit(10.0, 0.0)
	cs.orbit(-4.0, 1.6)
	await song.until(90.32)
	# «…отец!» — …и в воздух.
	var top := H(0.0, 1.4) + UP * 3.0
	var from := purse.global_position
	_to_stage(purse)
	cs.tilt(8.0, 0.6)
	cs.cam(H(0.0, 1.0) + UP * 1.8, 5.4, 0.6)
	await cs.fly(purse, from, top, 0.55, 0.6, Color(GOLD, 0.8))
	if cs.skipped:
		return
	purse.visible = false
	_coins(top, 14, 3.2, 0.6)
	cs.flash(GOLD, 0.3, 0.2)
	await song.until(91.14)
	# «А оптом — дешевле!» — на весь ряд помостов.
	sig.set_pose(&"point")
	cs.face(sig, H(-2.0, BLOCKS_Z))
	cs.tilt(0.0, 1.0)
	cs.cam(H(0.0, BLOCKS_Z) + UP, 7.2, 1.0)
	cs.orbit(0.0, 1.4)
	await song.until(92.6)
	sig.set_pose(&"")
	cs.walk_then_face(sig, H(BLOCKS_X[0] + 0.85, BLOCKS_Z - 1.0), H(BLOCKS_X[0], BLOCKS_Z + 3.0), 1.6)
	# Друг, мальчишка, капитан, вдова: каждый встаёт на свой помост к своей строке.
	var lines := [95.14, 98.74, 102.46, 105.46]
	for i in AUCTION.size():
		await song.until(lines[i])
		if cs.skipped:
			return
		_on_block(i)
		if i > 0:
			cs.walk_then_face(sig, H(BLOCKS_X[i] + 0.85, BLOCKS_Z - 1.0), H(BLOCKS_X[i], BLOCKS_Z + 3.0), 1.8)
		cs.cam(H(BLOCKS_X[i] + 0.3, BLOCKS_Z) + UP * 1.3, 4.0, 0.0)
		cs.orbit(-10.0 + i * 7.0, 0.0)
		cs.orbit(-4.0 + i * 7.0, 2.6)
		song.at(lines[i] + 0.6, sig.set_pose.bind(&"offer"))
		song.at(SOLD[i], _sold.bind(i))
		song.at(SOLD[i] + 0.25, sig.set_pose.bind(&""))
	await song.until(108.66)
	if cs.skipped:
		return
	# «Все клялись: «Не предам!» — и стоят за мной стеной...» — он выходит вперёд, за ним — стена купленных.
	cs.walk_then_face(sig, H(WALL_FRONT.x, WALL_FRONT.y), H(WALL_FRONT.x, 8.0), 1.8)
	for key in ["smith", "novice"]:
		var p: Puppet = shades[key]
		if not _bought(key):
			continue
		_put(p, H(-4.3 if key == "smith" else 4.3, BLOCKS_Z), H(0.0, 8.0))
		p.set_pose(&"")
		_show(p, VIOLET)
	_heat_to(0.6, 1.5)
	_frame(HALL, 0.0, 2.2, 8.2, 0.0, -9.0, 1.1)
	cs.cam(H(0.0, 2.4) + UP * 1.1, 6.8, 3.4)
	await song.until(112.28)
	# «А невеста твоя?»
	sig.set_pose(&"offer")
	cs.cam(sig.global_position + UP * 1.45, 3.0, 0.9)
	cs.tilt(-2.0, 0.9)
	await song.until(HUSH)
	if cs.skipped:
		return
	# Стоп. Тишина. Один холодный луч.
	sig.set_pose(&"")
	_heat_to(0.0, 0.25)
	_spot_to(3.4, 0.2, COLD)
	cs.mood(&"hush", 0.3)
	for key in _wall_keys():
		_fade(mats[shades[key]], 0.12, 0.3)
	await song.until(114.1)
	# «...Сказала мне «нет».» — Сольвейг уходит от него вглубь зала.
	var bride: Puppet = shades["bride"]
	_put(bride, H(3.2, 4.4), H(7.0, 5.4))
	bride.set_pose(&"")
	_show(bride, ROSE)
	_bride_light(bride)
	cs.walk(bride, H(6.4, 5.4), 0.7)
	_frame(HALL, 2.4, 3.8, 6.2, -28.0, -6.0, 1.2)
	cs.orbit(-20.0, 3.6)
	await song.until(116.1)
	# «И обернулась.»
	cs._place(bride, bride.global_position)
	cs.face(bride, sig.global_position)
	CutsceneFx.flare(game.world, bride.global_position + UP * 1.4, ROSE, 1.8, 3.0, 0.7)
	cs.cam(bride.global_position + UP * 1.4, 4.0, 0.5)
	await song.until(116.5)
	cs.face(bride, H(7.0, 5.4))
	cs.walk(bride, H(6.4, 5.4), 0.7)
	await song.until(116.86)
	# «Дважды.»
	cs._place(bride, bride.global_position)
	cs.face(bride, sig.global_position)
	CutsceneFx.flare(game.world, bride.global_position + UP * 1.4, ROSE, 2.6, 3.4, 1.0)
	cs.cam(bride.global_position + UP * 1.45, 3.3, 0.6)
	await song.until(MUSIC_BACK)


## 1:58 — полуприпев: музыка возвращается взрывом. «Хлеб, и кров, и дом!» — огонь бежит по жаровням.
## «Даже та, что в нём!» — Сольвейг идёт к нему и лиловеет. «Ты им веришь — я плачу́!» — золотой дождь.
## «Я — это ты, только лучше. Во вс—» — и музыка обрывается.
func _half_chorus() -> void:
	var bride: Puppet = shades["bride"]
	cs.flash(CRIMSON, 0.45, 0.5)
	_heat_to(1.0, 0.2)
	_spot_to(2.6, 0.2)
	cs.mood(&"feast", 0.2)
	for key in _wall_keys():
		_fade(mats[shades[key]], SHADE, 0.2)
	_columns()
	_frame(HALL, 0.0, 2.4, 9.6, 18.0, -4.0)
	cs.orbit(-12.0, 7.0)
	cs.cam(H(0.0, 2.2) + UP, 8.4, 6.0)
	await song.until(119.4)
	# «Всё твоё — моё!»
	sig.set_pose(&"triumph")
	await song.until(120.7)
	_hey()
	await song.until(121.05)
	# «Хлеб, и кров, и дом!» — огонь бежит от трона к нам, пара жаровен на каждое слово.
	sig.set_pose(&"talk")
	for word in [[121.05, 0], [121.45, 2], [121.86, 4]]:
		song.at(word[0], _column_pair.bind(word[1]))
	await song.until(122.3)
	_hey()
	await song.until(124.26)
	if cs.skipped:
		return
	# «Даже та, что в нём!» — она идёт к нему, он протягивает руку.
	sig.set_pose(&"offer")
	cs.face(sig, bride.global_position)
	cs.walk_then_face(bride, H(WALL_FRONT.x + 1.15, WALL_FRONT.y + 0.05), H(WALL_FRONT.x + 1.15, 8.0), 2.8)
	cs.cam(H(WALL_FRONT.x + 0.6, WALL_FRONT.y) + UP * 1.2, 4.2, 1.0)
	cs.orbit(-18.0, 2.0)
	await song.until(125.4)
	_tint(mats[bride], VIOLET.lerp(ROSE, 0.35) * SHADE_GLOW, 0.9)
	CutsceneFx.flare(game.world, bride.global_position + UP * 1.2, VIOLET, 2.2, 3.0, 0.9)
	await song.until(125.88)
	# «Ты им веришь — я плачу́!» — золото сыплется на стену купленных.
	sig.set_pose(&"talk")
	cs.face(sig, H(0.0, 8.0))
	_coin_rain(H(0.0, BLOCKS_Z), Vector2(3.6, 0.6), 22, 1.4)
	cs.flash(GOLD, 0.3, 0.15)
	cs.cam(H(0.0, 2.2) + UP * 1.4, 7.0, 0.8)
	cs.tilt(6.0, 0.8)
	await song.until(127.48)
	# «Я — это ты, только лучше.» — медленный наезд на него одного.
	cs.cam(sig.global_position + UP * 1.4, 3.8, 3.8)
	cs.tilt(-4.0, 3.8)
	cs.orbit(4.0, 4.0)
	await song.until(129.3)
	sig.set_pose(&"")
	await song.until(131.6)
	# «Во вс—»
	sig.set_pose(&"triumph")
	_columns()
	cs.flash(EMBER, 0.2, 0.3)
	await song.until(CUT)
	if cs.skipped:
		return
	# Обрыв: огонь гаснет разом, тени замирают, кадр — на его бедро.
	_heat_to(0.0, 0.0)
	_spot_to(2.6, 0.0, COLD)
	cs.mood(&"hush", 0.0)
	for key in _wall_keys() + ["bride"]:
		_fade(mats[shades[key]], 0.1, 0.05)
	cs.cam(_gum_focus(), 2.6, 0.0)
	cs.orbit(-10.0, 0.0)
	cs.tilt(0.0, 0.0)


## 2:12 — перерыв: «...Что это. Нет. Только не сейчас.» Скрипка тянет ноту, как резину. «Я хотел иметь
## только самое нужное...» — «...а у меня полные карманы жвачки». Рог — «КТО?!» — хирд на колени,
## а у шута за спиной надувается розовый пузырь. Руки вниз — чпок! — и пузырь тоже. «Скальд — дальше.»
func _gum_break() -> void:
	cs.cam(_gum_focus(), 1.9, 2.8)
	cs.orbit(-4.0, 2.8)
	await song.until(134.8)
	# «...Что это.»
	cs.face(sig, sig.global_position + _side() * 2.0 + stage.global_basis.z * 1.0)
	cs.orbit(6.0, 0.6)
	await song.until(136.52)
	# «Нет. Только не сейчас.»
	cs.face(sig, H(0.0, 8.0))
	cs.cam(sig.global_position + UP * 1.5, 3.4, 0.0)
	cs.orbit(0.0, 0.0)
	cs.shake(0.1)
	await song.until(139.66)
	# «Я хотел иметь только самое нужное...» — он один, лиловый свет.
	_spot_to(2.0, 1.6, VIOLET)
	cs.cam(H(0.0, 2.0) + UP * 1.2, 6.6, 4.0)
	cs.orbit(-8.0, 4.0)
	await song.until(142.2)
	# «(...самое нужное)» — шёпот хора: стена теней на миг проступает и гаснет.
	var keys := _wall_keys()
	for i in keys.size():
		var m: StandardMaterial3D = mats[shades[keys[i]]]
		var tw := stage.create_tween().set_ignore_time_scale(true)
		tw.tween_interval(i * 0.08)
		tw.tween_property(m, "albedo_color:a", 0.4, 0.4)
		tw.tween_property(m, "albedo_color:a", 0.1, 0.8)
	await song.until(144.0)
	# «...а у меня полные карманы жвачки.» — оба кармана в кадре.
	cs.cam(sig.global_position + UP * 1.2, 2.3, 0.0)
	cs.orbit(0.0, 0.0)
	cs.tilt(4.0, 0.0)
	cs.flash(GumStrand.PINK, 0.3, 0.15)
	await song.until(HORN)
	if cs.skipped:
		return
	# Вспыхивает, ревёт рог.
	cs.flash(CRIMSON, 0.7, 0.7)
	_heat_to(1.0, 0.0)
	_spot_to(2.6, 0.0, Color(1.0, 0.5, 0.4))
	_columns()
	cs.shake(0.5)
	cs.mood(&"blood", 0.2)
	_frame(HALL, 0.0, 1.6, 8.0, 0.0, -10.0)
	await song.until(147.48)
	# «КТО?!»
	cs.face(sig, H(-4.3, 2.2))
	cs.shake(0.3)
	await song.until(148.4)
	# «КТО ПОЛОЖИЛ МНЕ ЖВАЧКУ В КАРМАНЫ?!» — хирд на колени, тени съёживаются; камера обводит всех —
	# и останавливается на шуте.
	for i in hird.size():
		song.at(148.4 + i * 0.12, hird[i].set_pose.bind(&"kneel"))
	for key in _wall_keys() + ["bride"]:
		(shades[key] as Puppet).set_pose(&"huddle")
	cs.cam(H(-0.6, 1.3) + UP, 10.0, 0.6)
	cs.orbit(-10.0, 1.0)
	await song.until(149.6)
	skald_playing = false
	_bubble_grow(POP - 149.6)
	cs.cam(skald.global_position + UP * 0.75, 2.5, 0.8)
	cs.tilt(2.0, 0.8)
	await song.until(POP)
	if cs.skipped:
		return
	# Руки вниз — чпок! Жвачка лопается, и пузырь у шута тоже.
	_frame(HALL, (_lx(sig) + _lx(skald)) * 0.5, (_lz(sig) + _lz(skald)) * 0.5, 4.8, -22.0, -4.0)
	sig.set_pose(&"")
	_gum_pop()
	_bubble_pop()
	await song.until(153.2)
	# «...Всё. Я спокоен.»
	_heat_to(0.35, 1.0)
	_spot_to(2.0, 1.0)
	cs.mood(&"palace", 1.0)
	_hird_pose(&"")
	for key in _wall_keys() + ["bride"]:
		(shades[key] as Puppet).set_pose(&"")
		_fade(mats[shades[key]], 0.3, 1.0)
	cs.face(sig, H(0.0, 8.0))
	cs.cam(sig.global_position + UP * 1.4, 3.6, 1.2)
	await song.until(155.06)
	# «Скальд — дальше.»
	sig.set_pose(&"point")
	cs.face(sig, skald.global_position)
	await song.until(155.82)
	skald.set_pose(&"hold")
	skald_playing = true
	await song.until(156.2)
	cs.ui.black(1.0, 0.25)
	await song.until(BRIDGE)


## 2:36 — мост, тихо, на три четверти: покои ярла. «Слышишь, отец? Догорела свеча.» Перстень уходит
## младшему, старший — тёмная тень у плеча. Сигвард идёт к отцу — «Чтобы ты раз посмотрел на меня», —
## а тень отца отворачивается и тает. «Так смотри же теперь!»
func _bridge() -> void:
	var yh: Puppet = shades["young_hero"]
	var ys: Puppet = shades["young_brother"]
	var father: Puppet = shades["father"]
	_put(sig, C(-3.4, 2.2), C(0.0, -0.6))
	sig.set_pose(&"")
	_put(father, C(1.0, -0.9), C(-0.55, 0.05))
	father.set_pose(&"frail")
	_put(yh, C(-0.55, 0.05), father.global_position)
	yh.set_pose(&"")
	_put(ys, C(-1.25, 0.8), father.global_position)
	ys.set_pose(&"")
	_show(father, Color(0.85, 0.9, 1.0))
	_show(yh, GOLD)
	_tint(mats[yh], GOLD * SHADE_GLOW, 0.0)
	# Старший здесь — тусклая лиловая тень: проступит у плеча младшего, когда перстень уйдёт к тому.
	var dm: StandardMaterial3D = mats[ys]
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_color = Color(DARK_SHADE, 0.0)
	_heat_to(0.0, 0.0)
	_spot_to(1.2, 0.0, COLD)
	cs.mood(&"legend_cold", 0.0)
	_frame(CHAMBER, -0.6, 0.4, 6.8, -16.0, 2.0)
	cs.ui.black(0.0, 1.6)
	cs.cam(C(-0.2, -0.1) + UP * 1.1, 5.2, 7.0)
	cs.orbit(4.0, 9.0)
	await song.until(158.12)
	# «Слышишь, отец?»
	sig.set_pose(&"talk")
	await song.until(159.52)
	cs.cam(C(1.3, -1.1) + UP * 1.4, 3.6, 1.2)
	await song.until(160.08)
	# «…Догорела свеча.»
	candle_fire.emitting = false
	if candle_flame != null:
		candle_flame.visible = false
	CutsceneFx.light_to(candle, 0.0, 1.4)
	CutsceneFx.dust(game.world, candle_fire.global_position, 0.25, Color(0.4, 0.4, 0.45, 0.5), 8)
	await song.until(161.6)
	if cs.skipped:
		return
	# «Перстень — ему.»
	father.set_pose(&"frail_offer")
	cs.cam((father.global_position + yh.global_position) * 0.5 + UP * 1.1, 3.4, 0.6)
	ring.visible = true
	ring.scale = Vector3.ONE * 2.2
	var from := father.hand_position(&"r_hand")
	_fly_ring(from, yh)
	await song.until(162.54)
	# «А мне — тень у плеча.» — тусклая тень старшего проступает за плечом младшего.
	_fade(mats[ys], 0.75, 0.8)
	CutsceneFx.flare(game.world, ys.global_position + UP * 1.6, COLD, 1.6, 2.6, 1.2)
	cs.cam(ys.global_position + UP * 1.1, 3.0, 1.2)
	cs.orbit(-10.0, 2.0)
	await song.until(164.96)
	# «Ты говорил: «Он-то знает людей»...»
	father.set_pose(&"frail_offer")
	cs.face(father, yh.global_position)
	cs.cam((father.global_position + yh.global_position) * 0.5 + UP * 1.1, 3.8, 1.2)
	cs.orbit(-2.0, 2.0)
	await song.until(167.96)
	# «Я их узнал — до последних грошей.» — с его ладони сыплются монеты.
	father.set_pose(&"frail")
	sig.set_pose(&"offer")
	cs.cam(sig.global_position + UP * 1.3, 3.2, 0.8)
	await song.until(169.14)
	_coins(sig.hand_position(sig.offer_hand()), 7, 0.9, 0.2)
	await song.until(171.12)
	# «Я ведь хотел не меча, не коня —» — деревянный меч выпадает из руки тени.
	sig.set_pose(&"")
	cs.cam(ys.global_position + UP * 0.9, 3.0, 0.8)
	await song.until(172.46)
	var sword := ys.model.sockets[&"r_hand"].get_node_or_null("WoodenSword") as Node3D
	if sword != null:
		cs.drop(sword)
	await song.until(174.3)
	if cs.skipped:
		return
	# «Чтобы ты раз посмотрел на меня.» — он идёт к отцу, а тень отворачивается и тает.
	cs.walk(sig, C(-0.2, 0.9), 0.95)
	cs.cam(C(0.3, 0.0) + UP * 1.3, 3.8, 3.0)
	cs.orbit(-14.0, 6.0)
	await song.until(175.5)
	sig.set_pose(&"offer")
	cs.face(father, C(3.0, -2.5))
	await song.until(176.0)
	_fade(mats[father], 0.0, 2.2)
	_fade(mats[yh], 0.0, 2.6)
	await song.until(177.6)
	sig.set_pose(&"")
	cs.cam(sig.global_position + UP * 1.4, 2.8, 1.8)
	await song.until(ROAR)
	if cs.skipped:
		return
	# «Так смотри же теперь!» — рёв: тень старшего разлетается, кадр заливает багровым.
	sig.set_pose(&"triumph")
	_beam(sig.global_position, VIOLET, 7.0, 0.62, 1.4, 0.4)
	CutsceneFx.dust(game.world, ys.global_position, 1.2, Color(0.3, 0.1, 0.25, 0.7), 24)
	_fade(mats[ys], 0.0, 0.3)
	cs.flash(VIOLET, 0.6, 0.6)
	cs.shake(0.4)
	cs.mood(&"blood", 0.5)
	cs.tilt(-14.0, 1.0)
	cs.cam(sig.global_position + UP * 1.6, 5.0, 1.0)
	await song.until(BUILD)


## 3:01 — разгон к последнему припеву: зал в огне, весь хирд бьёт в пол на каждую долю, вещи
## поднимаются с пола и встают в круг. Камера взлетает от его сапог над залом.
func _build_up() -> void:
	_gum_out()
	cs.flash(CRIMSON, 0.4, 0.5)
	cs.mood(&"feast", 0.4)
	_heat_to(0.6, 0.0)
	_heat_to(1.0, FINAL - BUILD)
	_spot_to(2.4, 0.3)
	_put(sig, H(CENTER.x, CENTER.y), H(0.0, 8.0))
	sig.set_pose(&"")
	for p in hird:
		_put(p, H(signf(_lx(p)) * 4.3, _lz(p)), H(0.0, _lz(p)))
		p.set_pose(&"")
	for b in blocks:
		b.visible = false
	# Стена купленных — за его спиной; невеста — в стене, пока он не позовёт её на «и она!».
	var keys := _wall_keys()
	for i in keys.size():
		var p: Puppet = shades[keys[i]]
		var x := (i - (keys.size() - 1) * 0.5) * 0.95
		_put(p, H(x, -0.35), H(x, 8.0))
		p.model.position.y = 0.0
		p.set_pose(&"")
		_show(p, VIOLET)
	var bride: Puppet = shades["bride"]
	_put(bride, H(3.3, -0.1), H(0.0, 8.0))
	bride.set_pose(&"")
	_show(bride, VIOLET.lerp(ROSE, 0.35))
	_frame(HALL, 0.0, 1.6, 3.4, -30.0, -14.0, 0.5)
	cs.cam(H(0.0, 1.2) + UP * 1.3, 10.4, FINAL - BUILD)
	cs.orbit(28.0, FINAL - BUILD)
	cs.tilt(12.0, FINAL - BUILD)
	for bt in song.beats(BUILD + 0.2, FINAL - 0.1):
		song.at(bt, _stomp)
	for bt in song.beats(BUILD + 0.2, FINAL - 0.1, 2, 0):
		song.at(bt, _flare.bind(randi() % braziers.size(), 0.7))
	# Отданные вещи поднимаются с пола и встают в круг — по одной на долю.
	var beats := song.beats(184.2, FINAL - 0.3)
	var k := 0
	for id in Db.ITEM_IDS:
		if id == kept_id:
			continue
		if k < beats.size():
			song.at(beats[k], _claim.bind(id))
		k += 1
	await song.until(187.4)
	sig.set_pose(&"triumph")
	_hird_pose(&"arms_up")
	await song.until(FINAL)


## 3:08 — последний припев, на полтона выше, весь хирд и барабаны. «Перстень — и она!», «Выпито до дна!
## (Скол!)», «Ты им брат — а я им ярл!». «Ты уйдёшь — ни с чем» — последняя вещь брата слетает с чучела,
## и оно валится. «Я — это ты, только лучше! Во всё-ё-ём!» — камера над залом, огонь и свет всех семи вещей.
func _final_chorus() -> void:
	var bride: Puppet = shades["bride"]
	_burst(1.0)
	cs.flash(Color(1.0, 0.85, 0.55), 0.6, 0.6)
	_hird_pose(&"")
	_orbit_to(2.0, 1.8, 0.4)
	_frame(HALL, 0.0, 1.4, 8.8, 20.0, -6.0)
	cs.cam(H(0.0, 1.3) + UP, 7.2, 10.0)
	cs.orbit(-20.0, 11.0)
	await song.until(189.5)
	_hey()
	await song.until(189.98)
	# «Перстень —» — перстень отца на его руке (или только отблеск, если перчатки у брата).
	_ring_on_hand()
	cs.cam(sig.hand_position(&"r_hand"), 2.4, 0.3)
	await song.until(190.68)
	# «…и она!» — невеста шагает к нему из стены.
	cs.walk_then_face(bride, H(1.05, 1.25), H(0.0, 8.0), 2.6)
	CutsceneFx.flare(game.world, bride.global_position + UP * 1.3, ROSE, 2.0, 3.0, 0.8)
	cs.cam(H(0.5, 1.2) + UP * 1.3, 4.4, 0.4)
	await song.until(191.2)
	_hey()
	cs.cam(H(0.0, 1.3) + UP, 7.6, 0.8)
	await song.until(192.9)
	# «Выпито до дна!» — рог к небу, хирд поднимает клинки, как кубки.
	horn.visible = true
	sig.hold(horn, &"r_hand", 1.2)
	sig.set_pose(&"toast")
	_hird_pose(&"toast")
	cs.cam(sig.global_position + UP * 1.6, 4.6, 0.6)
	cs.tilt(-8.0, 0.6)
	await song.until(194.16)
	_skol()
	await song.until(194.7)
	if cs.skipped:
		return
	# «Ты им брат — а я им ярл!» — стена кланяется ему.
	sig.set_pose(&"talk")
	_hird_pose(&"")
	horn.visible = false
	var keys := _wall_keys()
	for i in keys.size():
		song.at(194.75 + i * 0.1, (shades[keys[i]] as Puppet).set_pose.bind(&"bow"))
	cs.cam(H(0.0, 0.6) + UP * 1.1, 6.4, 0.6)
	cs.tilt(-2.0, 0.6)
	await song.until(196.48)
	# «Ты им дал — а я забрал!» — вещи стягиваются к нему.
	sig.gesture(&"grab", 0.3)
	_orbit_to(1.15, 3.0, 0.5)
	Vfx.ring(sig, sig.global_position, 2.6, VIOLET, 0.5)
	await song.until(197.98)
	if cs.skipped:
		return
	# «Ты уйдёшь — ни с чем,» — последняя вещь брата слетает с чучела, и чучело валится.
	cs.cam(P(HALL, EFFIGY_AT.x, EFFIGY_AT.y) + UP * 0.9, 3.6, 0.3)
	cs.orbit(20.0, 0.3)
	cs.tilt(-4.0, 0.3)
	_strip_effigy()
	await song.until(199.4)
	# «Я останусь — со всем!»
	sig.set_pose(&"triumph")
	_orbit_to(2.3, 2.2, 0.6)
	orbit_h = 1.75
	cs.cam(H(0.0, 1.4) + UP, 9.4, 0.8)
	cs.orbit(4.0, 0.8)
	await song.until(200.3)
	_item_pillars()
	_columns()
	await song.until(201.06)
	# «Я — это ты, только лучше!» — камера взмывает над залом.
	cs.tilt(38.0, 5.0)
	cs.cam(H(0.0, 1.2), 13.5, 5.0)
	cs.orbit(-34.0, 9.0)
	for i in hird.size():
		song.at(202.8 + i * 0.15, hird[i].set_pose.bind(&"arms_up"))
		song.at(203.4 + i * 0.15, hird[i].set_pose.bind(&""))
	for bt in song.beats(203.6, 206.4, 2, 0):
		song.at(bt, _column_pair.bind(randi() % 3 * 2))
	await song.until(205.9)
	sig.set_pose(&"")
	await song.until(206.5)
	if cs.skipped:
		return
	# «Во всё-ё-ём!» — обе руки к небу; камера ныряет вниз. За руками снова тянется жвачка.
	sig.set_pose(&"triumph")
	cs.tilt(-6.0, 1.6)
	cs.cam(H(0.0, 1.4) + UP * 1.4, 7.4, 1.6)
	_orbit_to(2.4, 4.0, 1.0)
	for b in song.bars(206.6, LAST_HIT - 0.2):
		song.at(b, _item_pillars)
	for bt in song.beats(206.6, LAST_HIT - 0.2):
		song.at(bt, _flare.bind(randi() % braziers.size(), 1.0))
	await song.until(LAST_HIT)


## 3:30 — последний удар, тишина. Иллюзия осыпается: вещи падают на пол, тени гаснут. Тонкий скрип
## скрипки. «...Ладно. Во всём, кроме карманов.» — чпок.
func _outro() -> void:
	cs.flash(Color.WHITE, 0.5, 0.8)
	_heat_to(0.0, 0.15)
	_spot_to(2.6, 0.2, COLD)
	cs.mood(&"hush", 0.3)
	_drop_items()
	for key in _wall_keys() + ["bride"]:
		_vanish(shades[key], VIOLET, 0.8)
	_frame(HALL, 0.0, 1.2, 5.2, 8.0, 0.0, 1.3)
	cs.cam(sig.global_position + UP * 1.3, 4.2, 2.2)
	await song.until(210.3)
	# Тонкий скрип скрипки.
	cs.cam(skald.global_position + UP * 0.75, 2.2, 0.0)
	cs.orbit(-14.0, 0.0)
	skald_playing = true
	await song.until(211.0)
	skald_playing = false
	await song.until(211.7)
	# «...Ладно.»
	cs.cam(sig.global_position + UP * 1.45, 3.4, 0.0)
	cs.orbit(-6.0, 0.0)
	cs.face(sig, sig.global_position + _side() * 1.5 + stage.global_basis.z * 2.0)
	await song.until(212.4)
	# «Во всём, кроме карманов.»
	cs.cam(_gum_focus(), 2.4, 2.4)
	cs.orbit(4.0, 3.0)
	await song.until(POP_LAST)
	if cs.skipped:
		return
	# Чпок.
	sig.set_pose(&"")
	_gum_pop()
	cs.flash(GumStrand.PINK, 0.25, 0.2)
	cs.face(sig, H(0.0, 8.0))
	_heat_to(0.3, 1.0)
	skald_playing = true
	cs.cam(H(0.0, 1.8) + UP, 9.0, 3.0)
	cs.tilt(10.0, 3.0)
	cs.orbit(16.0, 3.4)
	await song.until(218.2)
	cs.ui.black(1.0, 1.4)
	await song.until(END)


# --- Огонь и свет --------------------------------------------------------------

## Жар зала: жаровни, багровый свет над троном и лиловый за спиной Сигварда.
func _heat_to(v: float, dur: float) -> void:
	if _heat_tw != null and _heat_tw.is_valid():
		_heat_tw.kill()
	if dur <= 0.0 or cs.skipped:
		heat = v
		return
	_heat_tw = stage.create_tween().set_ignore_time_scale(true)
	_heat_tw.tween_property(self, "heat", v, dur)


## Луч над Сигвардом: сила и цвет (тёплый — песня, холодный — тишина, лиловый — он один).
func _spot_to(energy: float, dur: float, color: Color = Color(1.0, 0.86, 0.7)) -> void:
	spot.light_color = color
	if _spot_tw != null and _spot_tw.is_valid():
		_spot_tw.kill()
	if dur <= 0.0 or cs.skipped:
		spot_base = energy
		return
	_spot_tw = stage.create_tween().set_ignore_time_scale(true)
	_spot_tw.tween_property(self, "spot_base", energy, dur)


## Жаровня вспыхивает: пламя, искры, столб огня (силу света ведёт жар зала).
func _ignite(i: int) -> void:
	(fires[i][0] as CPUParticles3D).emitting = true
	if cs.skipped:
		return
	var top := braziers[i].global_position + UP * 1.2
	CutsceneFx.sparks(game.world, top, EMBER, 22, 3.8)
	_beam(top, EMBER, 2.4, 0.26, 0.5)


## Жаровня выбрасывает огонь на долю. Без лампы: свет на долю и так вздрагивает (см. _on_tick).
func _flare(i: int, strength: float = 1.0) -> void:
	if cs.skipped:
		return
	var top := braziers[i].global_position + UP * 1.2
	CutsceneFx.sparks(game.world, top, EMBER, int(14 * strength), 3.6)
	_beam(top, EMBER, 1.8 * strength, 0.22, 0.35)


## Столб огня из жаровни.
func _column(i: int) -> void:
	var top := braziers[i].global_position + UP * 1.15
	_beam(top, EMBER, 3.4, 0.32, 0.6)
	CutsceneFx.sparks(game.world, top + UP * 0.3, EMBER, 14, 4.6)


## Столбы огня из всех жаровен — и одна общая вспышка на зал (вспышек-ламп не больше, чем нужно свету).
func _columns() -> void:
	if cs.skipped:
		return
	for i in braziers.size():
		_column(i)
	CutsceneFx.flare(game.world, H(0.0, 1.0) + UP * 3.0, EMBER, 3.2, 9.0, 0.6)


## Пара жаровен — от трона к нам: огонь бежит по залу.
func _column_pair(i: int) -> void:
	if cs.skipped:
		return
	for k in [i, i + 1]:
		if k < braziers.size():
			_column(k)


## Удар припева: вспышка, все жаровни, кольцо по полу.
func _burst(strength: float) -> void:
	if cs.skipped:
		return
	cs.flash(CRIMSON.lerp(EMBER, 0.4), 0.5, 0.5 * strength)
	_heat_to(1.0, 0.15)
	_columns()
	Vfx.ring(sig, sig.global_position, 6.0, EMBER, 0.6)
	cs.shake(0.35 * strength)


## Луч света от земли вверх: встаёт, держится и гаснет. Без лампы — одна сетка.
func _beam(at: Vector3, color: Color, height: float = 4.0, radius: float = 0.35, dur: float = 0.7, alpha: float = 0.6) -> void:
	if cs.skipped:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.45
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := Vfx.material(Color(color, alpha), 1.6, true)
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = height * 0.5
	var pivot := Node3D.new()
	pivot.add_child(mi)
	stage.add_child(pivot)
	pivot.global_position = at
	pivot.scale = Vector3(0.6, 0.05, 0.6)
	var tw := pivot.create_tween().set_ignore_time_scale(true)
	tw.tween_property(pivot, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "scale", Vector3(0.12, 1.15, 0.12), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(pivot.queue_free)


## Жаровня зала: угли тлеют тёмно-красным (яркий диск углей сверху читался бы плоским блином),
## над ними — ровное пламя и большое, которое поднимается, когда зал в огне. До музыки пламени нет.
func _stoke(b: Node3D) -> void:
	for ch in b.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).position.y > 1.1:
			(ch as MeshInstance3D).material_override = coal_mat
	var top := b.global_position + UP * 1.15
	var small := CutsceneFx.fire(b, top, 0.55)
	small.emitting = false
	var big := CutsceneFx.fire(b, top + UP * 0.08, 0.95)
	big.emitting = false
	fires.append([small, big])


# --- Хирд ----------------------------------------------------------------------

func _hird_pose(pose: StringName) -> void:
	for p in hird:
		if is_instance_valid(p):
			p.set_pose(pose)


## «Хей!» — хирд вскидывает клинки и бьёт в пол, все жаровни выбрасывают огонь.
func _hey() -> void:
	if cs.skipped:
		return
	_hird_pose(&"arms_up")
	for p in hird:
		CutsceneFx.dust(game.world, p.global_position, 0.6, Color(0.5, 0.36, 0.3, 0.6), 10)
	_columns()
	cs.shake(0.22)
	cs.flash(EMBER, 0.25, 0.16)
	cs.after(0.45, _hird_pose.bind(&""))


## Хирд бьёт в пол на долю.
func _stomp() -> void:
	if cs.skipped:
		return
	for p in hird:
		CutsceneFx.dust(game.world, p.global_position, 0.4, Color(0.45, 0.34, 0.3, 0.5), 6)
	cs.shake(0.05)


## «(Он!)» — хирд указывает на золотую тень младшего.
func _on_him(golden: Puppet) -> void:
	if cs.skipped:
		return
	_hird_pose(&"point")
	cs.after(0.55, _hird_pose.bind(&""))
	_beam(golden.global_position, GOLD, 4.0, 0.42, 0.6, 0.32)
	CutsceneFx.flare(game.world, golden.global_position + UP * 1.6, GOLD, 2.4, 4.0, 0.6)
	cs.flash(GOLD, 0.2, 0.15)


## Удар деревянных мечей в памяти: один бьёт, другой отбивает.
func _spar(attacker: Puppet, defender: Puppet, kind: StringName) -> void:
	if cs.skipped:
		return
	attacker.gesture(kind, 0.25)
	cs.after(0.14, func():
		defender.gesture(&"slash_back", 0.2)
		var at := (attacker.global_position + defender.global_position) * 0.5 + UP * 1.0
		CutsceneFx.sparks(game.world, at, GOLD.lerp(VIOLET, 0.5), 12, 3.0)
		cs.shake(0.08))


# --- Вещи и золото -------------------------------------------------------------

## Вещь брата встаёт в круг вокруг Сигварда: вспышка её цвета, шлейф. Ту, что Солдат оставил себе,
## он пока только хочет: на её месте — одна вспышка.
func _claim(id: StringName) -> void:
	if cs.skipped:
		return
	var i := Db.ITEM_IDS.find(id)
	if i < 0 or orbit_on[i]:
		return
	var color := Db.item(id).essence.color
	if id == kept_id:
		CutsceneFx.sparks(game.world, sig.global_position + UP * orbit_h, color, 10, 1.6)
		return
	orbit_on[i] = true
	var it := orbit_items[i]
	it.visible = true
	it.scale = Vector3.ONE * 0.05
	it.create_tween().set_ignore_time_scale(true).tween_property(it, "scale", Vector3.ONE * 0.85, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_trail(i)
	_orbit_tick(song.now(), 0.0)
	CutsceneFx.sparks(game.world, it.global_position, color, 12, 2.4)
	Vfx.burst(stage, it.global_position, color, 0.5, 0.35)
	CutsceneFx.light_to(orbit_light, 2.6, 0.3)


func _trail(i: int) -> void:
	if orbit_trails[i] == null or not is_instance_valid(orbit_trails[i]):
		orbit_trails[i] = CutsceneFx.trail(orbit_items[i], Db.item(Db.ITEM_IDS[i]).essence.color)
	orbit_trails[i].emitting = true


func _orbit_to(radius: float, spin: float, dur: float) -> void:
	if _orbit_tw != null and _orbit_tw.is_valid():
		_orbit_tw.kill()
	if dur <= 0.0 or cs.skipped:
		orbit_r = radius
		orbit_spin = spin
		return
	_orbit_tw = stage.create_tween().set_ignore_time_scale(true).set_parallel(true)
	_orbit_tw.tween_property(self, "orbit_r", radius, dur).set_trans(Tween.TRANS_SINE)
	_orbit_tw.tween_property(self, "orbit_spin", spin, dur)


## Вещи уходят из круга — до последнего припева.
func _orbit_hide() -> void:
	for i in orbit_items.size():
		if not orbit_on[i]:
			continue
		orbit_on[i] = false
		var it := orbit_items[i]
		var tw := it.create_tween().set_ignore_time_scale(true)
		tw.tween_property(it, "scale", Vector3.ONE * 0.01, 0.4).set_delay(i * 0.04)
		tw.tween_callback(func(): it.visible = false)
		if orbit_trails[i] != null and is_instance_valid(orbit_trails[i]):
			orbit_trails[i].emitting = false
	CutsceneFx.light_to(orbit_light, 0.0, 0.5)


func _orbit_slot(i: int, t: float) -> Vector3:
	var a := orbit_angle + TAU * i / orbit_items.size()
	var dir := stage.global_basis.x * cos(a) + stage.global_basis.z * sin(a)
	return sig.global_position + dir * orbit_r + UP * (orbit_h + sin(t * 2.0 + i) * 0.1)


func _orbit_tick(t: float, dt: float) -> void:
	orbit_angle += dt * orbit_spin
	for i in orbit_items.size():
		if not orbit_on[i] or not is_instance_valid(orbit_items[i]):
			continue
		var it := orbit_items[i]
		it.global_position = _orbit_slot(i, t)
		it.rotation.y += dt * 1.6
	if is_instance_valid(orbit_light):
		orbit_light.global_position = sig.global_position + UP * 1.6


## Столбы света в цвете каждой вещи круга.
func _item_pillars() -> void:
	if cs.skipped:
		return
	for i in orbit_items.size():
		if orbit_on[i]:
			var p := orbit_items[i].global_position
			_beam(Vector3(p.x, 0.0, p.z), Db.item(Db.ITEM_IDS[i]).essence.color, 5.2, 0.3, 0.8)
	CutsceneFx.flare(game.world, sig.global_position + UP * 2.0, GOLD, 3.0, 8.0, 0.6)


## Последний удар: вещи падают на пол — у ворот всё будет всерьёз.
func _drop_items() -> void:
	for i in orbit_items.size():
		if not orbit_on[i]:
			continue
		orbit_on[i] = false
		var it := orbit_items[i]
		var to := Vector3(it.global_position.x, 0.1, it.global_position.z)
		var tw := it.create_tween().set_ignore_time_scale(true).set_parallel(true)
		tw.tween_property(it, "global_position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(i * 0.05)
		tw.tween_property(it, "rotation", Vector3(PI * 0.5, it.rotation.y, 0.0), 0.45).set_delay(i * 0.05)
		tw.chain().tween_callback(func(): CutsceneFx.dust(game.world, to, 0.45, Color(0.5, 0.4, 0.38, 0.6), 8))
		if orbit_trails[i] != null and is_instance_valid(orbit_trails[i]):
			orbit_trails[i].emitting = false
	CutsceneFx.light_to(orbit_light, 0.0, 0.4)


## «Ты уйдёшь — ни с чем»: последняя вещь брата слетает с чучела в круг, плащ сползает, чучело валится.
func _strip_effigy() -> void:
	if cs.skipped:
		return
	if effigy_item != null and is_instance_valid(effigy_item) and kept_id != &"":
		var i := Db.ITEM_IDS.find(kept_id)
		var from := effigy_item.global_position
		effigy_item.visible = false
		var it := orbit_items[i]
		it.visible = true
		it.scale = Vector3.ONE * 0.85
		it.global_position = from
		_trail(i)
		var color := Db.item(kept_id).essence.color
		CutsceneFx.flare(game.world, from, color, 2.4, 3.0, 0.6)
		var tw := it.create_tween().set_ignore_time_scale(true)
		tw.tween_method(func(k: float):
			var s := k * k * (3.0 - 2.0 * k)
			it.global_position = from.lerp(_orbit_slot(i, song.now()), s) + UP * sin(k * PI) * 0.9, 0.0, 1.0, 0.7)
		tw.tween_callback(func():
			orbit_on[i] = true
			CutsceneFx.sparks(game.world, it.global_position, color, 16, 3.0))
	# Вспышка с нашей стороны: чучело стоит к нам спиной, его плащ в тени.
	CutsceneFx.flare(game.world, effigy.global_position + UP * 1.6 + stage.global_basis.z * 1.2, Color(1.0, 0.8, 0.6), 2.6, 4.0, 1.2)
	var cloak := effigy_cloak
	var drop := cloak.create_tween().set_ignore_time_scale(true).set_parallel(true)
	drop.tween_property(cloak, "position:y", 0.2, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(cloak, "rotation:x", 1.2, 0.45)
	var fall := effigy.create_tween().set_ignore_time_scale(true)
	fall.tween_interval(0.35)
	fall.tween_property(effigy, "rotation", Vector3(1.45, 0.0, 0.35), 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_callback(func():
		var base := effigy.global_position + stage.global_basis.z * 1.0
		CutsceneFx.dust(game.world, base, 1.1, STRAW, 22)
		CutsceneFx.sparks(game.world, base + UP * 0.2, STRAW, 14, 2.4)
		cs.shake(0.2))


## Перстень отца: на его руке — если перчатки отданы Бьёрну; иначе только отблеск, и тот гаснет.
func _ring_on_hand() -> void:
	if cs.skipped:
		return
	var hand := sig.hand_position(&"r_hand")
	if Story.was_given(RunState.snapshots, &"gloves"):
		var r := NpcLooks.father_ring(true)
		sig.hold(r, &"r_hand", 2.2)
		CutsceneFx.flare(game.world, hand, GOLD, 2.6, 3.0, 1.0)
		Vfx.burst(sig, hand, GOLD, 0.6, 0.4)
	else:
		CutsceneFx.sparks(game.world, hand, GOLD, 14, 1.5)
		CutsceneFx.flare(game.world, hand, GOLD, 1.4, 2.0, 0.6)


## Перстень в памяти уходит от отца к младшему.
func _fly_ring(from: Vector3, to: Puppet) -> void:
	_to_stage(ring)
	await cs.fly(ring, from, to.hand_position(&"r_hand"), 0.9, 0.4, GOLD)
	if cs.skipped or not is_instance_valid(ring):
		return
	to.hold(ring, &"r_hand", 2.2)
	to.set_pose(&"hold")
	_gild(ring, mats[to])
	_beam(to.global_position, GOLD, 4.0, 0.45, 1.0, 0.28)
	CutsceneFx.flare(game.world, to.hand_position(&"r_hand"), GOLD, 2.2, 3.0, 1.0)


## «(Скол!)» — золотые брызги из рога и из каждого поднятого клинка.
func _skol() -> void:
	if cs.skipped:
		return
	var tip := horn.global_position + UP * 0.2
	CutsceneFx.sparks(game.world, tip, GOLD, 30, 5.0)
	CutsceneFx.flare(game.world, tip, GOLD, 2.6, 4.0, 0.6)
	for p in hird:
		CutsceneFx.sparks(game.world, p.hand_position(&"r_hand"), GOLD, 10, 3.6)
	_columns()
	cs.flash(GOLD, 0.35, 0.3)
	cs.shake(0.25)


## Монеты разлетаются из точки и ложатся на пол — там и остаются.
func _coins(from: Vector3, count: int, spread: float, lift: float = 1.2) -> void:
	if cs.skipped:
		return
	for i in count:
		var c := _coin()
		c.global_position = from
		var a := randf() * TAU
		var r := randf_range(0.3, spread)
		var to := Vector3(from.x + cos(a) * r, 0.012, from.z + sin(a) * r)
		var up := randf_range(lift * 0.5, lift)
		var dur := randf_range(0.6, 0.95)
		var tw := c.create_tween().set_ignore_time_scale(true)
		tw.tween_method(func(k: float):
			c.global_position = from.lerp(to, k) + UP * sin(k * PI) * up
			c.rotation = Vector3(k * 9.0, k * 5.0, 0.0), 0.0, 1.0, dur)
		tw.tween_callback(func(): c.rotation = Vector3(0.0, randf() * TAU, 0.0))
	CutsceneFx.sparks(game.world, from, GOLD, 18, 3.0)
	CutsceneFx.flare(game.world, from, GOLD, 2.0, 4.0, 0.5)


## Золотой дождь над областью: монеты падают в случайные мгновения за dur.
func _coin_rain(center: Vector3, half: Vector2, count: int, dur: float) -> void:
	if cs.skipped:
		return
	for i in count:
		var c := _coin()
		var to := center + stage.global_basis.x * randf_range(-half.x, half.x) + stage.global_basis.z * randf_range(-half.y, half.y)
		to.y = 0.012
		var from := to + Vector3(randf_range(-0.3, 0.3), randf_range(4.0, 6.0), randf_range(-0.3, 0.3))
		c.global_position = from
		c.visible = false
		var tw := c.create_tween().set_ignore_time_scale(true)
		tw.tween_interval(randf() * dur)
		tw.tween_callback(func(): c.visible = true)
		tw.tween_property(c, "global_position", to, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "rotation", Vector3(7.0, 3.0, 0.0), 0.7)
		tw.tween_callback(func(): c.rotation = Vector3(0.0, randf() * TAU, 0.0))
	CutsceneFx.flare(game.world, center + UP * 3.0, GOLD, 2.4, 6.0, dur)


func _coin() -> MeshInstance3D:
	var c := SetPieces.steady(SetPieces.coin())
	stage.add_child(c)
	return c


# --- Торг ----------------------------------------------------------------------

## Кого продают на этой строке: тень встаёт на помост, ещё бледная — ничья.
func _on_block(i: int) -> void:
	if cs.skipped:
		return
	var p: Puppet = shades[AUCTION[i]]
	_put(p, H(BLOCKS_X[i], BLOCKS_Z), H(BLOCKS_X[i], BLOCKS_Z + 8.0))
	p.model.position.y = 0.26
	p.set_pose(&"")
	_show(p, PALE)
	block_lights[i].light_color = PALE
	CutsceneFx.light_to(block_lights[i], 3.2, 0.4)
	_beam(H(BLOCKS_X[i], BLOCKS_Z), PALE, 3.6, 0.42, 0.8, 0.28)


## «(Продано!)» — тень лиловеет и кланяется, на неё сыплется золото, хирд бьёт кулаком. Если его вещь
## Солдат оставил себе, он Сигварду не продан: тень отворачивается и гаснет.
func _sold(i: int) -> void:
	if cs.skipped:
		return
	var key := AUCTION[i]
	var p: Puppet = shades[key]
	var at := H(BLOCKS_X[i], BLOCKS_Z)
	if not _bought(key):
		cs.face(p, at - stage.global_basis.z * 3.0)
		_fade(mats[p], 0.0, 1.2)
		CutsceneFx.light_to(block_lights[i], 0.0, 1.0)
		CutsceneFx.dust(game.world, at + UP * 0.3, 0.6, Color(PALE, 0.5), 10)
		return
	_tint(mats[p], VIOLET * SHADE_GLOW, 0.3)
	p.set_pose(&"bow")
	block_lights[i].light_color = VIOLET
	_coin_rain(at, Vector2(0.4, 0.4), 6, 0.3)
	CutsceneFx.sparks(game.world, at + UP * 1.4, GOLD, 18, 3.4)
	CutsceneFx.flare(game.world, at + UP * 1.6, GOLD, 2.4, 4.0, 0.6)
	for h in hird:
		h.gesture(&"punch", 0.2)
	cs.flash(GOLD, 0.25, 0.18)
	cs.shake(0.15)


## Отдана ли этому человеку его вещь: только тогда он стоит за Сигвардом.
func _bought(key: String) -> bool:
	for s in RunState.snapshots:
		if String(Story.gift(s.def_id).get("who", &"")) == key:
			return true
	return false


## Стена купленных: те, кому вещь отдана, — по порядку куплета, кузнец и ученик знахаря по краям.
func _wall_keys() -> Array[String]:
	var out: Array[String] = []
	for key in ["smith", "friend", "refugee", "captain", "widow", "novice"]:
		if _bought(key):
			out.append(key)
	return out


var bride_light: OmniLight3D


func _bride_light(bride: Puppet) -> void:
	if bride_light == null or not is_instance_valid(bride_light):
		bride_light = CutsceneFx.light(bride, bride.global_position + UP * 2.2, ROSE, 2.2, 3.4)
		dim_lights.append(bride_light)


# --- Жвачка --------------------------------------------------------------------

## Карманы — там, где кисти висят в покое; жвачка тянется от них к кистям и видна, только когда рука поднята.
func _make_pockets() -> void:
	for hand in [&"l_hand", &"r_hand"]:
		var pocket := LowPoly.pivot("SongPocket_%s" % hand)
		sig.model.add_child(pocket)
		pocket.global_position = sig.hand_position(hand)
		pockets[hand] = pocket


func _gum_out() -> void:
	if cs.skipped:
		return
	_gum_away()
	for hand in pockets:
		var g := GumStrand.stretch(game.world, pockets[hand], sig.model.sockets[hand])
		g.min_length = GUM_REACH
		cs.prop(g)
		gum.append(g)


## Жвачка лопается — чпок.
func _gum_pop() -> void:
	for g in gum:
		if is_instance_valid(g):
			g.snap()
	gum.clear()


## Убрать тихо: руки опущены, жвачки и так не видно.
func _gum_away() -> void:
	for g in gum:
		if is_instance_valid(g):
			g.queue_free()
	gum.clear()


## Куда смотреть, чтобы видеть жвачку: середина нити от левого кармана к кисти.
func _gum_focus() -> Vector3:
	var pocket: Node3D = pockets.get(&"l_hand")
	if pocket == null:
		return sig.global_position + UP * 1.2
	return (pocket.global_position + sig.hand_position(&"l_hand")) * 0.5


## Влево по кадру — туда он косится на карман.
func _side() -> Vector3:
	return -stage.global_basis.x


func _bubble_grow(dur: float) -> void:
	if cs.skipped:
		return
	bubble.visible = true
	bubble.scale = Vector3.ONE * 0.05
	bubble.create_tween().set_ignore_time_scale(true).tween_property(bubble, "scale", Vector3.ONE, maxf(dur, 0.1)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _bubble_pop() -> void:
	if bubble.visible:
		CutsceneFx.sparks(game.world, bubble.global_position, GumStrand.PINK, 16, 2.2)
	bubble.visible = false


# --- Каждый кадр ---------------------------------------------------------------

## Жаровни вздрагивают на каждую долю, луч идёт за Сигвардом, вещи кружат, пёс виляет, скальд пилит.
func _on_tick(t: float) -> void:
	var dt := clampf(t - _last_t, 0.0, 0.1)
	_last_t = t
	if not is_instance_valid(sig):
		return
	var k := song.pulse(t)
	for l in flames:
		if is_instance_valid(l):
			(l as CutsceneFx.FlickerLight).base = (0.2 + 4.6 * heat) * (1.0 + 0.6 * heat * k)
	coal_mat.set_shader_parameter(&"emission_energy", 0.3 + 1.6 * heat + 0.6 * heat * k)
	for f in fires:
		(f[1] as CPUParticles3D).emitting = heat > 0.55
	for l in dim_lights:
		if is_instance_valid(l):
			l.visible = (l.get("base") if l is CutsceneFx.FlickerLight else l.light_energy) > 0.01
	if is_instance_valid(key_light):
		key_light.light_energy = 0.5 + 2.5 * heat
	if is_instance_valid(back_light):
		back_light.light_energy = 0.8 + 1.6 * heat
		var away := Combat.flat_dir(-game.rig.global_basis.z)
		back_light.global_position = sig.global_position + away * 1.4 + UP * 2.3
	if is_instance_valid(spot):
		var over := sig.global_position + UP * SPOT_H
		spot.global_position = over if spot.global_position.distance_to(over) > 12.0 else spot.global_position.lerp(over, minf(1.0, dt * 6.0))
		spot.light_energy = spot_base * SPOT_GAIN * (1.0 + 0.3 * k * heat)
	_orbit_tick(t, dt)
	if dog_wag and is_instance_valid(dog):
		(dog.get_node("Tail") as Node3D).rotation.y = sin(t * 13.0) * 0.7
	if is_instance_valid(bow):
		bow.rotation.z = sin(t * 9.0) * 0.45 if skald_playing else 0.0
	if is_instance_valid(bubble) and bubble.visible and is_instance_valid(skald):
		var head: Node3D = skald.model.sockets.get(&"head")
		if head != null:
			bubble.global_position = head.global_position + skald.facing * 0.14 + Vector3(0, -0.06, 0)


# --- Тени и расстановка --------------------------------------------------------

## Точка места действия: x — вправо по кадру, z — к зрителю.
func P(place: Vector3, x: float, z: float) -> Vector3:
	return stage.to_global(place + Vector3(x, 0.0, z))


func H(x: float, z: float) -> Vector3:
	return P(HALL, x, z)


func Y(x: float, z: float) -> Vector3:
	return P(YARD, x, z)


func C(x: float, z: float) -> Vector3:
	return P(CHAMBER, x, z)


## Где узел в тронном зале: x — вправо по кадру, z — к зрителю.
func _lx(n: Node3D) -> float:
	return stage.to_local(n.global_position).x - HALL.x


func _lz(n: Node3D) -> float:
	return stage.to_local(n.global_position).z - HALL.z


## Кадр сразу, без наезда: фокус, размер, облёт и наклон.
func _frame(place: Vector3, x: float, z: float, zoom: float, yaw: float, pitch: float = 0.0, h: float = 1.0) -> void:
	cs.cam(P(place, x, z) + UP * h, zoom, 0.0)
	cs.orbit(yaw, 0.0)
	cs.tilt(pitch, 0.0)


func _put(a: Puppet, pos: Vector3, look: Vector3) -> void:
	cs._place(a, Vector3(pos.x, 0.0, pos.z))
	a.look_toward(look)
	a.process_mode = Node.PROCESS_MODE_INHERIT
	a.visible = true


func _tag(node: Node3D, title: String, subtitle: String, color: Color, h: float, dur: float) -> void:
	if cs.skipped or node == null or not is_instance_valid(node):
		return
	cs.ui.tag(node, title, subtitle, color, h, dur)


## Тень: все сетки актёра — одним светящимся материалом.
func _gild(n: Node, mat: StandardMaterial3D) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gild(ch, mat)


## Тень появляется в цвете color. У сгенерированного Солдата много наложенных сеток: при той же
## прозрачности он выгорает в белое, поэтому его тень прозрачнее.
func _show(p: Puppet, color: Color, alpha: float = -1.0) -> void:
	p.visible = true
	p.process_mode = Node.PROCESS_MODE_INHERIT
	var m: StandardMaterial3D = mats[p]
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r * SHADE_GLOW, color.g * SHADE_GLOW, color.b * SHADE_GLOW, 0.0)
	var a := alpha if alpha >= 0.0 else (0.36 if p.kind == ActorModel.Kind.HERO else SHADE)
	_fade(m, a, 0.5)


## Тень рассыпается пылью и гаснет.
func _vanish(p: Puppet, color: Color, dur: float = 0.7) -> void:
	if not is_instance_valid(p) or not p.visible:
		return
	if not cs.skipped:
		CutsceneFx.dust(game.world, p.global_position, 0.8, Color(color, 0.6), 14)
	_fade(mats[p], 0.0, dur)
	if cs.skipped:
		_sleep(p)
		return
	stage.create_tween().set_ignore_time_scale(true).tween_callback(_sleep.bind(p)).set_delay(dur + 0.05)


## Невидимая тень не считает анимацию.
func _sleep(p: Puppet) -> void:
	if is_instance_valid(p):
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED


func _fade(mat: StandardMaterial3D, alpha: float, dur: float) -> void:
	if cs.skipped or dur <= 0.0:
		mat.albedo_color.a = alpha
		return
	stage.create_tween().set_ignore_time_scale(true).tween_property(mat, "albedo_color:a", alpha, dur)


func _tint(mat: StandardMaterial3D, color: Color, dur: float) -> void:
	if cs.skipped or dur <= 0.0:
		mat.albedo_color = Color(color, mat.albedo_color.a)
		return
	var from := mat.albedo_color
	stage.create_tween().set_ignore_time_scale(true).tween_method(func(k: float):
		mat.albedo_color = Color(from.lerp(color, k), mat.albedo_color.a), 0.0, 1.0, dur)


func _to_stage(node: Node3D) -> void:
	var xf := node.global_transform
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	stage.add_child(node)
	node.global_transform = xf


func _add(node: Node3D, place: Vector3, x: float, z: float, yaw: float = 0.0) -> Node3D:
	stage.add_child(node)
	node.position = place + Vector3(x, 0.0, z)
	node.rotation.y = yaw
	return node


# --- Постройка ---------------------------------------------------------------

func _build() -> void:
	stage = Node3D.new()
	stage.name = "SigvardSongStage"
	game.world.add_child(stage)
	cs.prop(stage)
	stage.global_position = ORIGIN
	stage.rotation.y = deg_to_rad(game.rig.yaw_degrees)
	_build_hall()
	_build_yard()
	_build_chamber()
	_cast()
	_build_items()


## Тронный зал: шесть жаровен, свой пол с частыми вершинами (на нём видны пятна света), луч над Сигвардом,
## помосты для торга (под полом до своего куплета), пёс у порога, щит пира.
func _build_hall() -> void:
	var hall := SetPieces.throne_hall()
	stage.add_child(hall)
	hall.position = HALL
	(hall.get_node("Floor") as Node3D).visible = false
	for n in ["Carpet", "CarpetTrimL", "CarpetTrimR"]:
		SetPieces.steady(hall.get_node(n) as MeshInstance3D)
	_add(SetPieces.stone_floor(Vector2(26, 20), Color(0.27, 0.24, 0.24)), HALL, 0.0, 2.0)
	braziers.assign(hall.get_meta(&"braziers"))
	for s in [[-3.2, 1.3], [3.2, 1.3], [-3.2, 3.1], [3.2, 3.1]]:
		braziers.append(_add(SetPieces.brazier(), HALL, s[0], s[1]))
	coal_mat = LowPoly.unique(LowPoly.mat(Color(0.85, 0.22, 0.06), 0.5, 0.0, 1.0))
	for b in braziers:
		_stoke(b)
	for s in [[-2.6, -0.6], [2.6, -0.6], [-3.2, 2.2], [3.2, 2.2]]:
		flames.append(cs.light(H(s[0], s[1]) + UP * 1.9, Color(1.0, 0.45, 0.22), 0.3, 4.8, 0.14))
	for x in [-4.6, 4.6]:
		_add(SetPieces.banner(), HALL, x, -2.4)
	key_light = cs.light(H(0.0, -3.4) + UP * 3.0, CRIMSON, 0.4, 10.0)
	# Лиловый контровой свет держится за спиной Сигварда (от камеры): контур на фоне огня.
	back_light = cs.light(H(0.0, -1.9) + UP * 2.4, VIOLET, 0.4, 3.6)
	gold_light = cs.light(H(0.0, 1.6) + UP * 3.0, GOLD, 0.0, 6.0)
	orbit_light = cs.light(H(CENTER.x, CENTER.y) + UP * 1.6, Color(1.0, 0.86, 0.62), 0.0, 3.8)
	dim_lights.append_array([gold_light, orbit_light])
	spot = SpotLight3D.new()
	spot.name = "SongSpot"
	spot.light_color = Color(1.0, 0.86, 0.7)
	spot.light_energy = 0.0
	spot.spot_range = SPOT_H + 4.0
	spot.spot_angle = 22.0
	spot.spot_attenuation = 0.2
	stage.add_child(spot)
	spot.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	spot.global_position = H(SIG_HOME.x, SIG_HOME.y) + UP * SPOT_H
	cs.motes(H(0.0, 1.2) + UP * 1.6, Vector3(6.0, 1.6, 4.5), EMBER, 60, 0.35)
	for i in BLOCKS_X.size():
		var b := _add(SetPieces.auction_block(), HALL, BLOCKS_X[i], BLOCKS_Z)
		b.position.y = -0.3
		b.visible = false
		blocks.append(b)
		block_lights.append(cs.light(H(BLOCKS_X[i], BLOCKS_Z + 0.7) + UP * 2.6, PALE, 0.0, 3.6))
	dim_lights.append_array(block_lights)
	# Пёс лежит сбоку от золотого брата, мордой к нему: в кадре — профилем.
	dog = _add(SetPieces.dog(), HALL, DOG_AT.x, DOG_AT.y)
	var to_golden := Vector3(GOLDEN_AT.x - DOG_AT.x, 0.0, GOLDEN_AT.y - DOG_AT.y)
	dog.rotation.y = atan2(to_golden.x, to_golden.z)
	dog.scale = Vector3.ONE * 1.3
	dog_mat = Vfx.material(Color(GOLD, 0.0), SHADE_GLOW, true)
	_gild(dog, dog_mat)
	dog.visible = false
	shield = SetPieces.round_shield()
	stage.add_child(shield)
	_gild(shield, Vfx.material(Color(GOLD, 0.5), SHADE_GLOW, true))
	shield.visible = false
	purse = SetPieces.purse()
	stage.add_child(purse)
	purse.visible = false
	horn = SetPieces.drinking_horn()
	stage.add_child(horn)
	horn.visible = false


## Двор крепости в его памяти: закат в воротах, стойка с деревянными мечами, чучело для учебных боёв.
## Пол тёмный: на светлом светящиеся тени выгорали бы в белое. Свет: закат из ворот — ключевой, лиловая
## заливка спереди и свой огонёк у Сигварда на краю кадра.
func _build_yard() -> void:
	_add(SetPieces.stone_floor(Vector2(24, 16), Color(0.3, 0.26, 0.24)), YARD, 0.0, 1.5)
	_add(SetPieces.yard_wall(18.0), YARD, 0.0, -3.2)
	_add(SetPieces.weapon_rack(), YARD, -2.7, -2.4)
	_add(SetPieces.training_post(), YARD, 2.9, -2.2, 0.3)
	for c in [[5.2, -2.4, 0.8], [6.0, -1.8, 0.6], [-5.4, -2.5, 0.7]]:
		var crate := LowPoly.box(Vector3.ONE * c[2], SetPieces.WOOD.darkened(0.25), Vector3(0, c[2] * 0.5, 0), 0.9, 0.0, 0.0, &"wood")
		_add(crate, YARD, c[0], c[1], c[0] * 0.3)
	cs.light(Y(0.0, -2.2) + UP * 2.2, DUSK, 5.0, 7.5)
	cs.light(Y(-0.8, 2.4) + UP * 2.8, VIOLET, 2.4, 7.5)
	cs.light(Y(-3.4, 2.7) + UP * 2.2, Color(1.0, 0.75, 0.6), 2.5, 3.6)
	cs.motes(Y(0.0, 0.0) + UP * 1.4, Vector3(5.0, 1.4, 4.0), Color(1.0, 0.85, 0.65, 0.8), 40, 0.08)


## Покои ярла: стена с окнами в зимнюю ночь, свеча у ложа — та, что погасла в прологе.
func _build_chamber() -> void:
	_add(SetPieces.stone_floor(Vector2(20, 14), Color(0.17, 0.16, 0.18)), CHAMBER, 0.0, 1.0)
	_add(LowPoly.box(Vector3(12.0, 5.0, 0.5), Color(0.3, 0.28, 0.3), Vector3(0, 2.5, 0), 0.95, 0.0, 0.0, &"brick"), CHAMBER, 0.0, -3.3)
	for x in [1.7, -2.4]:
		_add(SetPieces.night_window(), CHAMBER, x, -3.0)
	var stand := _add(SetPieces.candle_stand(), CHAMBER, 1.9, -1.55)
	for ch in stand.get_children():
		if (ch as Node3D).position.y >= SetPieces.flame_height() - 0.01:
			candle_flame = ch
	var flame := stand.global_position + UP * (SetPieces.flame_height() + 0.1)
	candle = cs.light(flame, Color(1.0, 0.7, 0.4), 3.5, 6.0, 0.18)
	candle_fire = CutsceneFx.fire(game.world, flame - UP * 0.05, 0.12)
	cs.prop(candle_fire)
	cs.light(C(1.7, -1.8) + UP * 2.4, COLD, 3.0, 9.0)
	cs.light(C(-3.0, 2.5) + UP * 3.0, COLD, 1.2, 8.0)
	cs.light(C(-1.6, 1.4) + UP * 2.6, COLD, 1.8, 4.5)
	cs.motes(C(0.0, 0.0) + UP * 1.5, Vector3(4.0, 1.4, 3.0), Color(0.75, 0.82, 1.0, 0.7), 30, 0.05)


func _cast() -> void:
	sig = cs.spawn(&"brother", H(SIG_HOME.x, SIG_HOME.y), H(0.0, 6.0), &"ssong_brother")
	puppets.append(sig)
	for i in 6:
		var side := -1.0 if i < 3 else 1.0
		var z := 0.4 + (i % 3) * 1.8
		hird.append(_extra(ActorModel.Kind.INFANTRY, H(side * 4.3, z), H(0.0, z)))
	_build_skald()
	_build_effigy()
	# Тени памяти: младший с деревянным мечом, старший с деревянным мечом, отец.
	var yh := _shade(&"hero", "young_hero", 0.86)
	yh.hold(NpcLooks.wooden_sword(), &"r_hand", 1.0)
	var ys := _shade(&"brother", "young_brother", 0.92, &"young")
	ys.hold(NpcLooks.wooden_sword(), &"r_hand", 1.0)
	_shade(&"father", "father")
	# Золотой брат пира — во всех семи вещах, каким его видели все.
	var golden := _shade(&"hero", "golden")
	var gear: Array[ItemState] = []
	for id in Db.ITEM_IDS:
		gear.append(Mastery.make_item(id))
	golden.set_items(gear)
	for who in ["friend", "refugee", "captain", "widow", "smith", "novice"]:
		_shade(StringName(who), who)
	_shade(&"beloved", "bride")
	for key in shades:
		var p: Puppet = shades[key]
		var m := Vfx.material(Color(GOLD, 0.0), SHADE_GLOW, true)
		mats[p] = m
		_gild(p, m)
		_sleep(p)


func _shade(who: StringName, key: String, size: float = 1.0, variant: StringName = &"") -> Puppet:
	var p := cs.spawn(who, H(0.0, -40.0), H(0.0, 0.0), StringName("ssong_" + key), variant)
	puppets.append(p)
	shades[key] = p
	if size != 1.0:
		p.model.scale *= size
	return p


## Актёр без реплик: стража, шут.
func _extra(kind: int, pos: Vector3, look: Vector3) -> Puppet:
	var p := Puppet.make(kind)
	p.name = "SongExtra_%d" % puppets.size()
	game.world.add_child(p)
	p.global_position = Vector3(pos.x, 0.0, pos.z)
	p.look_toward(look)
	puppets.append(p)
	return p


## Скальд — придворный шут-карлик: ножи убраны, в руках хардингфеле и смычок. Над ним — свой огонёк.
func _build_skald() -> void:
	skald = _extra(ActorModel.Kind.JESTER, H(SKALD_AT.x, SKALD_AT.y), H(0.6, 1.4))
	for hand in [&"l_hand", &"r_hand"]:
		var socket: Node3D = skald.model.sockets.get(hand)
		if socket != null:
			for ch in socket.get_children():
				(ch as Node3D).visible = false
	var fiddle := SetPieces.fiddle()
	skald.model.sockets[&"l_hand"].add_child(fiddle)
	fiddle.rotation = Vector3(0.0, 0.0, -0.5)
	bow = SetPieces.fiddle_bow()
	skald.model.sockets[&"r_hand"].add_child(bow)
	bubble = LowPoly.sphere(0.16, 8, 6, GumStrand.PINK, Vector3.ZERO, 0.4, 0.0, 0.6)
	stage.add_child(bubble)
	bubble.visible = false
	cs.light(H(SKALD_AT.x, SKALD_AT.y + 0.6) + UP * 1.6, Color(1.0, 0.7, 0.5), 1.6, 2.6)


## Чучело брата на ковре: столб с перекладиной, мешок соломы, его плащ — и та вещь, что Солдат оставил себе.
## Смотрит на трон (в -Z), плащ — к зрителю.
func _build_effigy() -> void:
	effigy = LowPoly.pivot("Effigy")
	stage.add_child(effigy)
	effigy.position = HALL + Vector3(EFFIGY_AT.x, 0.0, EFFIGY_AT.y)
	effigy.add_child(SetPieces.training_post())
	# Крестовина у основания: у чучела вместо ног — столб на подставке.
	for r in [0.4, 0.4 + PI * 0.5]:
		var plank := LowPoly.box(Vector3(0.75, 0.07, 0.12), SetPieces.WOOD.darkened(0.2), Vector3(0, 0.035, 0), 0.9, 0.0, 0.0, &"wood")
		plank.rotation.y = r
		effigy.add_child(plank)
	effigy_cloak = SetPieces.cloak(CLOAK)
	effigy_cloak.position = Vector3(0.0, 1.47, 0.0)
	effigy.add_child(effigy_cloak)
	if RunState.ring != null and not RunState.ring.items.is_empty():
		kept_id = RunState.ring.items[0].def_id
		effigy_item = ItemVisuals.build_display(Cutscene.item_state(kept_id))
		effigy.add_child(effigy_item)
		var slot: Array = _effigy_slot(kept_id)
		effigy_item.position = slot[0]
		effigy_item.rotation = slot[1]
		effigy_item.scale = Vector3.ONE * 0.85
	# Свой тёплый свет — чучело стоит у входа, далеко от жаровен.
	cs.light(effigy.global_position + UP * 1.9 - stage.global_basis.z * 0.9, Color(1.0, 0.82, 0.62), 1.8, 3.2)


## Где на чучеле вещь: [положение, поворот] — меч в «руке»-перекладине, шлем на голове и так далее.
static func _effigy_slot(id: StringName) -> Array:
	match id:
		&"sword":
			return [Vector3(0.48, 0.95, -0.12), Vector3(0.0, 0.0, 0.15)]
		&"shield":
			return [Vector3(-0.45, 1.05, -0.15), Vector3.ZERO]
		&"armor":
			return [Vector3(0.0, 0.95, -0.08), Vector3.ZERO]
		&"helmet":
			return [Vector3(0.0, 1.8, 0.0), Vector3.ZERO]
		&"gloves":
			return [Vector3(0.0, 1.38, -0.12), Vector3.ZERO]
		&"boots":
			return [Vector3(0.0, 0.18, -0.12), Vector3.ZERO]
	return [Vector3(0.0, 1.32, -0.24), Vector3.ZERO]


## Вещи брата для круга вокруг Сигварда — в облике этого забега (снимок жертвы или кольцо).
func _build_items() -> void:
	for id in Db.ITEM_IDS:
		var d := ItemVisuals.build_display(Cutscene.item_state(id))
		stage.add_child(d)
		d.visible = false
		d.scale = Vector3.ONE * 0.01
		orbit_items.append(d)
		orbit_on.append(false)
		orbit_trails.append(null)
	ring = NpcLooks.father_ring(true)
	stage.add_child(ring)
	ring.visible = false


func _finalize(moon: Node3D) -> void:
	if song != null and is_instance_valid(song):
		if song.tick.is_connected(_on_tick):
			song.tick.disconnect(_on_tick)
		cs.get_tree().create_timer(1.6, true, false, true).timeout.connect(song.queue_free)
	for tw in [_heat_tw, _spot_tw, _orbit_tw]:
		if tw != null and (tw as Tween).is_valid():
			(tw as Tween).kill()
	for p in puppets:
		if is_instance_valid(p):
			p.queue_free()
	for key in cs.cast.keys():
		if String(key).begins_with("ssong_"):
			cs.cast.erase(key)
	cs.ui.hide_line()
	cs.clear_props()
	game.arena.set_indoor(false)
	if moon != null:
		moon.visible = true
	cs.mood(&"none", 0.0)
	game.rig.cine_release(0.0)
