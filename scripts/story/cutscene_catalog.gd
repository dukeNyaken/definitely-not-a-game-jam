class_name CutsceneCatalog
extends RefCounted
## Каталог сюжетных сцен для меню «Катсцены»: все сцены по порядку забега — когда идут, что в них
## происходит, от чего зависят и кто в них участвует. Отсюда же Theater узнаёт, какой забег подготовить,
## чтобы показать сцену отдельно. Здесь — описания; реплики сцен — в Story.
##
## Сцена каталога: { key, scene, n, group, title, subtitle, when, about, logic, cast, quote, seconds,
## options, playable }. options — варианты сцены: [{ key, label, choices: [[значение, подпись]], default }];
## seconds — сколько идёт сцена, если не торопить реплики (замеряет tools/theater.gd).

## Показательный забег: в каком порядке отданы вещи, пока зритель не выбрал иначе. Последняя остаётся у Солдата.
const DEMO_ORDER: Array[StringName] = [&"sword", &"amulet", &"boots", &"shield", &"gloves", &"armor", &"helmet"]

const GROUP_START := "Перед этапом 1"
const GROUP_AFTER := "После этапа %d"
const GROUP_PALACE := "Этап 7 · дворец"

const GIFT_ABOUT := "Тот, кому вещь нужнее, выходит к Солдату и просит. Вещь перелетает из рук в руки, и получатель клянётся в низком поклоне не предать. Столб света: сила вещи не ослабла — она уходит соседней вещи Солдата новым свойством. Крупный план вещи в чужих руках: Солдат вспоминает её слабое место. Ильва делится своим."
const GIFT_LOGIC: Array[String] = [
	"Вещь выбирает игрок, поэтому получатель зависит от вещи, а не от номера дара.",
	"Реплика Ильвы идёт по номеру дара, какая бы вещь ни была отдана.",
	"Мысль о слабом месте вещи — закладка: в бою и в финале Солдат узнаёт её на Тиране.",
]
## Что добавляется к логике дара с этим номером.
const GIFT_EXTRA := {
	1: "После первого дара Ильва отдаёт Солдату свою флягу.",
	2: "Сразу после этого дара — сцена у очага.",
	3: "После третьего дара Ильва отдаёт Солдату хлеб, а Сигвард зовёт Сольвейг во дворец.",
	6: "Последний алтарь: дальше — ворота дворца.",
}

const PALACE_LOGIC: Array[String] = [
	"Короткая сцена между этапами: зал строится далеко от арены, пока экран тёмный.",
	"Реплика идёт по номеру дара, а не по вещи.",
]
## Что добавляется к логике сцен, где Сигвард замечает жвачку (Story.BROTHER_GUM).
const PALACE_GUM := "Шутка поверх изъяна модели: за поднятой рукой Сигварда от бедра тянется нить. Здесь она стала розовой жвачкой — Тиран собрал всё на свете, и жвачку тоже."
## Сколько идёт голос из дворца и на сколько дольше — сцена со жвачкой.
const PALACE_SECONDS := 11
const PALACE_GUM_SECONDS := 9
## Голос из дворца по номеру дара: [подзаголовок, что делает Сигвард, что добавляется к логике].
const PALACE := {
	1: ["У окна", "Сигвард смотрит в окно на зарево над городом и на середине реплики оборачивается.", "Первая реплика — о том, что люди продаются: так и выйдет у ворот."],
	2: ["По ковру", "Сигвард идёт по ковру от трона прямо на зрителя, руки за спиной.", "Перед этой сценой — дом Сольвейг: сначала её страх, потом его уверенность."],
	3: ["Деревянный меч", "Сигвард стоит у жаровни с детским деревянным мечом — и бросает его в огонь. Пламя взвивается. Потом он замечает, что из кармана за рукой тянется жвачка, говорит о ней — и она лопается.", "Тот самый меч из пролога. Сцена идёт сразу после его разговора с Сольвейг."],
	4: ["Письмо Сольвейг", "Сигвард читает письмо с багровой печатью. Дочитав — роняет его.", "Письмо — от Сольвейг: в тронном зале она сказала «нет», а теперь пишет ему сама."],
	5: ["Пустая рука", "Сигвард смотрит на свою пустую руку: на ней нет отцовского перстня.", "Если перчатки с перстнем уже отданы Бьёрну, реплика другая: «Бьёрн уже мой»."],
	6: ["Перед троном", "Сигвард встаёт перед троном, раскидывает руки — и обе жаровни вспыхивают. За руками из обоих карманов тянется жвачка: «лучше во всём» приходится поправить.", "Последняя реплика перед воротами дворца."],
}

static var _entries: Array[Dictionary] = []


## Все сцены по порядку забега.
static func entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_build()
	return _entries


static func find(key: String) -> Dictionary:
	for e in entries():
		if e["key"] == key:
			return e
	return {}


static func playable() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries():
		if e["playable"]:
			out.append(e)
	return out


static func _build() -> void:
	var gifts := Db.balance.stage_count - 1
	_entries.append(_prologue())
	_entries.append(_rule())
	for n in range(1, gifts + 1):
		_entries.append(_gift(n))
		if n == Story.SONG_AFTER_GIFT:
			_entries.append(_song())
		if n == Story.HEARTH_AFTER_GIFT:
			_entries.append(_hearth())
		if n == Story.TEMPTATION_AFTER_GIFT:
			_entries.append(_temptation())
		_entries.append(_palace(n))
	_entries.append(_gates())
	_entries.append(_barks())
	_entries.append(_finale())


static func _entry(key: String, scene: StringName, group: String, title: String, subtitle: String) -> Dictionary:
	return {
		"key": key, "scene": scene, "n": 0, "group": group, "title": title, "subtitle": subtitle,
		"when": "", "about": "", "logic": [] as Array[String], "cast": [] as Array[StringName],
		"quote": [], "seconds": 0, "options": [] as Array[Dictionary], "playable": true,
	}


static func _prologue() -> Dictionary:
	var ch := Story.chapter("prologue")
	var e := _entry("prologue", &"prologue", GROUP_START, ch[0], ch[1])
	e["when"] = "В начале каждого забега, перед первым этапом."
	e["about"] = "Флешбэк на «старой плёнке»: двор крепости, ярл смотрит, как сыновья бьются на деревянных мечах. Младший побеждает и подаёт брату руку — старший её отбивает. Годы спустя умирающий ярл при свече отдаёт родовой перстень младшему; свеча гаснет. Затем — семь вещей Солдата, прощание Сольвейг и хлеб от Ильвы."
	e["logic"] = [
		"Идёт один раз — пока не отдана ни одна вещь.",
		"Задаёт то, что сыграет в финале: зависть Сигварда и перстень отца. Правило мира звучит позже — у первого алтаря.",
		"Сольвейг провожает Солдата как любящая невеста. Ильва остаётся рядом и ничего не просит.",
	] as Array[String]
	e["cast"] = [&"father", &"hero", &"brother", &"beloved", &"faithful"] as Array[StringName]
	e["quote"] = [&"father", Story.PROLOGUE["father_spar"]]
	e["seconds"] = 115
	return e


## Правило мира у первого алтаря — перед первым выбором жертвы.
static func _rule() -> Dictionary:
	var ch := Story.chapter("rule")
	var e := _entry("rule", &"rule", GROUP_AFTER % 1, ch[0], ch[1])
	e["n"] = 1
	e["when"] = "После первого этапа: посреди арены поднимается первый алтарь, и до выбора жертвы звучит предание."
	e["about"] = "Солдат подходит к алтарю. Свет алтаря поднимается столбом, арена темнеет, идёт снег. В стуже встают две тени прошлого: замёрзший стоит в снегу, сжавшись и дрожа, бледный от холода; воин в багровом плаще идёт мимо — и останавливается. Он снимает плащ и укрывает им чужого человека; тот согревается и распрямляется. Тепло плаща светом возвращается к отдавшему: снег стихает, кадр теплеет, и от ног воина загорается дорога из света. Они уходят по ней вдвоём. Перстень отца на руке Солдата отзывается светом."
	e["logic"] = [
		"Идёт один раз за забег — у первого алтаря, пока не отдана ни одна вещь.",
		"Раньше правило звучало в прологе текстом на чёрном фоне. Теперь оно стоит там, где нужно игроку: сразу после сцены открывается выбор жертвы.",
		"Отдают плащ, а не меч: меч — первый дар самого Солдата, и сцена дара показала бы то же самое дважды. Отдать плащ в стужу — значит рискнуть собой, поэтому «не ослабляет» видно без слов.",
		"Холод и тепло играют правило цветом: замёрзший бледно-синий, согретый — золотой; кадр из холодного становится тёплым.",
		"Тени не похожи ни на кого из героев: это предание. Солдат слышал его от отца — как и Сигвард.",
		"То же самое покажет каждая сцена дара: вещь уходит, а её сила переходит соседней вещи Солдата.",
	] as Array[String]
	e["cast"] = [&"hero"] as Array[StringName]
	e["quote"] = [&"chronicle", Story.RULE["law"]]
	e["seconds"] = 30
	return e


static func _gift(n: int) -> Dictionary:
	var e := _entry("gift_%d" % n, &"gift", GROUP_AFTER % n, "", "")
	e["n"] = n
	e["when"] = "После этапа %d: Солдат встаёт на алтарь и выбирает, какую вещь отдать." % n
	e["about"] = GIFT_ABOUT
	var logic := GIFT_LOGIC.duplicate()
	if GIFT_EXTRA.has(n):
		logic.append(GIFT_EXTRA[n])
	e["logic"] = logic
	var choices := []
	for id in DEMO_ORDER:
		choices.append([id, _cap(Story.ITEM_NAMES[id])])
	e["options"] = [{"key": "item", "label": "Вещь", "choices": choices, "default": DEMO_ORDER[n - 1]}] as Array[Dictionary]
	e["seconds"] = 40
	return e


## Песня Ильвы — музыкальная сцена после второго дара.
static func _song() -> Dictionary:
	var ch := Story.chapter("song")
	var n := Story.SONG_AFTER_GIFT
	var e := _entry("song", &"song", GROUP_AFTER % n, ch[0], ch[1])
	e["n"] = n
	e["when"] = "После дара №%d, сразу за сценой дара: Ильва говорит «Я клясться не умею — я просто иду рядом», и начинается песня." % n
	e["about"] = "Музыкальная сцена. Ночь, привал у костра: Солдат спит, Ильва поёт о том, чего не скажет ему вслух. Воспоминания встают светящимися тенями: дети бегут по льду фьорда мимо вмёрзших ладей; юноша отдаёт плащ мальчишке у горящего дома; Солдат отдаёт оберег Сольвейг, а Ильва стоит в стороне. В припевах они идут рядом по зимней дороге, и тропа загорается под ногами на каждую долю такта. В мосте песни — её предчувствие: тёмные тени уходят к высокой фигуре, а она выходит из тьмы с фонарём. Под утро: «Пойдём?» — «Пойдём»."
	e["logic"] = [
		"Сцена идёт по часам песни: кадры сменяются на строках, свет и тропа — на долях такта. Слова закрашиваются под пение.",
		"Песня начинается со слов, которые Ильва только что сказала в сцене дара, и собирает её реплики: фляга, хлеб, «не спорь».",
		"Она стоит перед домом Сольвейг нарочно: та же ночь, две женщины. Сольвейг боится его щедрости — Ильва любит его за неё.",
		"Мост песни — предчувствие, а не показ финала: тени без лиц, ворот дворца в кадре нет. «Пусть мир тебя предал весь» здесь значит «даже если».",
		"Ильва укрывает спящего пледом — как он когда-то отдал свой плащ: теперь хоть кто-то защитит его самого.",
		"«Пойдём?» — «Пойдём» вернутся в финале теми же словами.",
	] as Array[String]
	e["cast"] = [&"faithful", &"hero"] as Array[StringName]
	e["quote"] = [&"faithful", Story.SONG["quote"]]
	e["seconds"] = 160
	return e


static func _hearth() -> Dictionary:
	var ch := Story.chapter("hearth")
	var n := Story.HEARTH_AFTER_GIFT
	var e := _entry("hearth", &"hearth", GROUP_AFTER % n, ch[0], ch[1])
	e["n"] = n
	e["when"] = "После дара №%d, перед голосом из дворца." % n
	e["about"] = "Дом Сольвейг, ночь. Мать прядёт у огня, дочь стоит у окна. Сольвейг любит Солдата — и боится его щедрости: он пустит по ветру всё, и они останутся в нищете, всеми брошенные. Пока она говорит о страхе, тёплый кадр холодеет и огонь в очаге садится; под конец она возвращается к окну, и свеча на столе гаснет."
	e["logic"] = [
		"Здесь рождается сомнение: Сольвейг ещё верна, но уже считает, сколько он отдал.",
		"Она перечисляет вещи, которые Солдат уже отдал чужим, — те, что выбрал игрок.",
		"Если оберег уже у неё, она держит его в руках и говорит о нём отдельно.",
		"«Те, кому он помог, отвернутся первыми» — сбудется у ворот дворца, и о ней самой.",
	] as Array[String]
	e["cast"] = [&"mother", &"beloved"] as Array[StringName]
	e["quote"] = [&"beloved", Story.HEARTH["alone"]]
	e["options"] = [{"key": "amulet", "label": "Оберег", "default": "given",
		"choices": [["given", "уже у Сольвейг"], ["kept", "ещё у Солдата"]]}] as Array[Dictionary]
	e["seconds"] = 70
	return e


static func _temptation() -> Dictionary:
	var ch := Story.chapter("temptation")
	var n := Story.TEMPTATION_AFTER_GIFT
	var e := _entry("temptation", &"temptation", GROUP_AFTER % n, ch[0], ch[1])
	e["n"] = n
	e["when"] = "После дара №%d, перед голосом из дворца." % n
	e["about"] = "Сигвард зовёт Сольвейг во дворец и склоняет её оставить Солдата: тот раздаст всё, а здесь — стены, хлеб и огонь. Он говорит вслух то, чего она боится, и бросает к её ногам кошель с золотом. Сольвейг отказывает: она дала слово. Но, уходя, замедляет шаг у золота — и у края ковра оборачивается на трон."
	e["logic"] = [
		"Идёт после сцены у очага: Сигвард бьёт в тот самый страх, о котором она говорила матери.",
		"Она говорит «нет». Колебание — не в словах, а в действии: молчание на его вопрос, взгляд на кошель, взгляд назад.",
		"Следующий шаг — после четвёртого дара: Сигвард уже читает её письмо.",
		"У ворот дворца она встанет рядом с ним.",
	] as Array[String]
	e["cast"] = [&"brother", &"beloved"] as Array[StringName]
	e["quote"] = [&"brother", Story.TEMPTATION["looked_back"]]
	e["seconds"] = 65
	return e


static func _palace(n: int) -> Dictionary:
	var act: Array = PALACE[n]
	var e := _entry("palace_%d" % n, &"palace", GROUP_AFTER % n, "Голос из дворца", act[0])
	e["n"] = n
	e["when"] = "После дара №%d, перед этапом %d." % [n, n + 1]
	e["about"] = "Тронный зал Сигварда в багровом свете жаровен и зарева за окнами. " + act[1]
	var logic := PALACE_LOGIC.duplicate()
	logic.append(act[2])
	var gum := Story.brother_gum(n) != ""
	if gum:
		logic.append(PALACE_GUM)
	e["logic"] = logic
	e["cast"] = [&"brother"] as Array[StringName]
	if n == Story.RING_LINE_INDEX:
		e["options"] = [{"key": "ring", "label": "Перстень отца", "default": "given",
			"choices": [["given", "уже у Бьёрна"], ["kept", "ещё у Солдата"]]}] as Array[Dictionary]
	e["seconds"] = PALACE_SECONDS + (PALACE_GUM_SECONDS if gum else 0)
	return e


static func _gates() -> Dictionary:
	var ch := Story.chapter("gates")
	var e := _entry("gates", &"gates", GROUP_PALACE, ch[0], ch[1])
	e["when"] = "В начале седьмого этапа, перед боем с Тираном."
	e["about"] = "Все, кому Солдат отдал вещи, стоят у постаментов спиной к нему. Ворота открываются, выходит Сигвард и говорит о зависти. Сольвейг отдаёт ему вещи брата и признаётся: она любила — но выбрала дворец, а не нищету. Вещи слетаются в Сигварда, и он становится рыцарем-боссом. К Солдату выходит только Ильва."
	e["logic"] = [
		"У ворот стоят получатели только тех вещей, что отданы. Говорят не больше трёх — первые по порядку жертв.",
		"Если у ворот говорил Торстейн, Сигвард отвечает: «У него один брат».",
		"Признание Сольвейг зависит от оберега: отдан ей — «я сама отнесла его ему»; оставлен — «единственное, что ты оставил себе».",
		"Если отданы перчатки, Сигвард получает перстень отца. После сцены сразу начинается бой.",
	] as Array[String]
	e["cast"] = [&"hero", &"brother", &"beloved", &"faithful"] as Array[StringName]
	e["options"] = [_kept_option()] as Array[Dictionary]
	e["seconds"] = 125
	return e


static func _barks() -> Dictionary:
	var e := _entry("barks", &"barks", GROUP_PALACE, "Реплики в бою", "Тиран сбрасывает вещи")
	e["when"] = "Во время боя с Тираном, при смене фазы. Игра не останавливается."
	e["about"] = "Субтитры поверх боя. На 60% здоровья Тиран срывается на крик и сбрасывает вещи; на 25% — снова, и Ильва кричит ему наперекор. Каждый раз Солдат узнаёт сброшенную вещь: он знает её слабое место."
	e["logic"] = [
		"Это не отдельная сцена, а реплики поверх боя: увидеть их можно только в забеге.",
		"Мысль Солдата — о первой из сброшенных вещей. Какие вещи сбрасываются, зависит от порядка жертв.",
	] as Array[String]
	e["cast"] = [&"brother", &"faithful", &"hero"] as Array[StringName]
	e["quote"] = [&"brother", Story.BROTHER_BARKS[1]]
	e["playable"] = false
	return e


static func _finale() -> Dictionary:
	var ch := Story.chapter("epilogue")
	var e := _entry("finale", &"finale", GROUP_PALACE, "Финал", "Последний дар")
	e["when"] = "После победы над Тираном."
	e["about"] = "Рыцарь рассыпается — на коленях остаётся Сигвард, просто человек. Солдат узнаёт каждую отданную вещь: она вспыхивает, пока он вспоминает, где она подвела. Последний дар: он сам отдаёт брату отцовский перстень. Те, кого он спас, просят прощения. Сольвейг просит подождать — он молча проходит мимо и уходит с Ильвой; кадр теплеет, как на рассвете. Все расходятся, и последний кадр — Сигвард один среди вещей. В конце — «%s»." % ch[0]
	e["logic"] = [
		"Монтаж показывает до четырёх вещей — первые по порядку жертв.",
		"Если отданы перчатки, перстень лежит на камнях за спиной Сигварда. Солдат идёт за ним — и Бьёрн, капитан гвардии, решает, что добивать: выбегает из толпы у ворот и закрывает нового ярла щитом. Солдат выбивает щит и говорит, зачем пришёл; Бьёрн отходит в сторону.",
		"Если перчатки остались у Солдата, Бьёрна в сцене нет: перстень он снимает со своей руки.",
		"«Прости» говорит Эйвинд; если его у ворот нет — первый из стоящих там. Он делает шаг вперёд из толпы.",
		"Каждый, кто входит в кадр, сначала показан там, откуда идёт: Бьёрн и Сольвейг — у ворот, Ильва — у края арены.",
		"После сцены — карточка артефакта.",
	] as Array[String]
	e["quote"] = [&"hero", Story.FINALE["never_helped"]]
	e["options"] = [_kept_option()] as Array[Dictionary]
	e["seconds"] = 140
	return e


## Вариант для ворот и финала: какую вещь Солдат оставил себе (остальные шесть отданы).
static func _kept_option() -> Dictionary:
	var choices := []
	for id in DEMO_ORDER:
		choices.append([id, _cap(Story.ITEM_NAMES[id])])
	return {"key": "kept", "label": "Солдат оставил себе", "choices": choices, "default": DEMO_ORDER.back()}


static func _cap(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


# --- Варианты сцены ---------------------------------------------------------

## Варианты по умолчанию: ключ варианта -> значение.
static func defaults(e: Dictionary) -> Dictionary:
	var out := {}
	for o in e["options"]:
		out[o["key"]] = o["default"]
	return out


## Варианты сцены: выбранные зрителем поверх значений по умолчанию.
static func resolve(e: Dictionary, chosen: Dictionary = {}) -> Dictionary:
	var out := defaults(e)
	for key in chosen:
		if out.has(key):
			out[key] = chosen[key]
	return out


## Заголовок и подзаголовок сцены. У дара они зависят от вещи: «Дар третий» / «Сапоги · Эйвинд».
static func title_of(e: Dictionary, opts: Dictionary) -> Array:
	if e["scene"] == &"gift":
		return Story.gift_chapter(e["n"], opts["item"])
	return [e["title"], e["subtitle"]]


## Кто в кадре. У дара — получатель выбранной вещи; в финале Бьёрн выходит, только если перчатки отданы.
static func cast_of(e: Dictionary, opts: Dictionary) -> Array[StringName]:
	match e["scene"]:
		&"gift":
			return [&"hero", Story.gift(opts["item"])["who"], &"faithful"] as Array[StringName]
		&"finale":
			var out: Array[StringName] = [&"hero", &"brother"]
			if opts["kept"] != &"gloves":
				out.append(&"captain")
			out.append_array([&"beloved", &"faithful"])
			return out
	return e["cast"]


## Ключевая реплика сцены: [кто, текст]. Кто — ключ Story.speaker (у предания — &"chronicle").
static func quote_of(e: Dictionary, opts: Dictionary) -> Array:
	match e["scene"]:
		&"gift":
			var g := Story.gift(opts["item"])
			return [g["who"], g["oath"]]
		&"palace":
			return [&"brother", Story.brother_line(e["n"], _snapshots(given_before(e, opts)))]
		&"gates":
			return [&"beloved", Story.GATES["confess_kept" if opts["kept"] == &"amulet" else "confess_given"]]
	return e["quote"]


# --- Забег под сцену --------------------------------------------------------

## Этап, на котором идёт сцена.
static func stage_of(e: Dictionary) -> int:
	match e["scene"]:
		&"prologue":
			return 1
		&"gates", &"barks", &"finale":
			return Db.balance.stage_count
	return e["n"]


## Какие вещи уже отданы к началу сцены — по порядку жертв.
static func given_before(e: Dictionary, opts: Dictionary) -> Array[StringName]:
	match e["scene"]:
		&"gift":
			return _given(e["n"] - 1, &"", opts["item"])
		&"hearth":
			var kept: bool = opts["amulet"] == "kept"
			return _given(e["n"], &"" if kept else &"amulet", &"amulet" if kept else &"")
		&"temptation", &"song":
			return _given(e["n"])
		&"palace":
			if e["n"] != Story.RING_LINE_INDEX:
				return _given(e["n"])
			var kept: bool = opts["ring"] == "kept"
			return _given(e["n"], &"" if kept else &"gloves", &"gloves" if kept else &"")
		&"gates", &"barks", &"finale":
			return _given(DEMO_ORDER.size() - 1, &"", opts.get("kept", DEMO_ORDER.back()))
	return []


## Первые count вещей показательного забега: без exclude и обязательно с include.
static func _given(count: int, include: StringName = &"", exclude: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for id in DEMO_ORDER:
		if out.size() < count and id != exclude:
			out.append(id)
	if include != &"" and not out.is_empty() and not out.has(include):
		out[out.size() - 1] = include
	return out


static func _snapshots(ids: Array[StringName]) -> Array[ItemState]:
	var out: Array[ItemState] = []
	for id in ids:
		out.append(ItemState.create(id))
	return out


## «около 1 мин 20 с» — сколько идёт сцена, если не торопить реплики.
static func duration_text(seconds: int) -> String:
	if seconds <= 0:
		return ""
	var minutes := int(seconds / 60.0)
	if minutes == 0:
		return "около %d с" % seconds
	if seconds % 60 == 0:
		return "около %d мин" % minutes
	return "около %d мин %d с" % [minutes, seconds % 60]
