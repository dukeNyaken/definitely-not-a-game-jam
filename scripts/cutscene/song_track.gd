class_name SongTrack
extends Node
## Песня с разметкой по словам: часы музыкальной сцены и строка текста, которая закрашивается под пение.
## Разметка — файл *.sync.json (LyricSync): alignment.lines[].words[] с start_seconds / end_seconds.
## Слова без времени (их разметка не нашла) получают его по соседям.
##
## Часы идут по звуку, пока он играет с обычной скоростью. При ускорении (бот, просмотр со speed=N)
## и без звука (--headless) часы идут по времени сцены — сцена доигрывается всегда и одинаково.
##
## Доли такта — равная сетка (beat_period / beat_phase) или, если рядом с записью лежит *.beats.json
## (tools/song_beats.py), доли, снятые с ударных: у живой записи темп «плавает», и равная сетка
## к концу куплета уходила бы с удара.

## Каждый кадр, пока песня идёт: время песни в секундах.
signal tick(t: float)

## Цвета слов: спето, поётся сейчас, впереди.
const SUNG := "f0c868"
const NOW := "fff4d6"
const AHEAD := "8f8576"
## Строка появляется чуть раньше первого слова и держится после последнего.
const LEAD := 0.35
const TAIL := 0.8
## Песня — в центре внимания: громче фоновой музыки, но слушается настройки громкости.
const GAIN_DB := 6.0

var lines: Array[Dictionary] = []
var duration: float = 0.0
## Доли такта: период и время первой доли (замерены по записи).
var beat_period: float = 0.5
var beat_phase: float = 0.0
## Доли и сильные доли тактов, снятые с записи (*.beats.json). Если они есть, beats() берёт их, а не сетку.
var beat_times: PackedFloat32Array = []
var bar_times: PackedFloat32Array = []
## Строки, которые начинаются позже, под музыку не показываются: их произносят в сцене.
var lyrics_until: float = INF
var _cs: Cutscene
var _stream: AudioStream
var _player: AudioStreamPlayer
var _t: float = 0.0
var _running: bool = false
var _shown: int = -1
var _cues: Array[Array] = []


static func load_track(sync_path: String, audio_path: String, beats_path: String = "") -> SongTrack:
	var s := SongTrack.new()
	s.name = "SongTrack"
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(sync_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(sync_path))
		if data is Dictionary:
			s.lines = parse(data)
			s.duration = float((data as Dictionary).get("audio", {}).get("duration_seconds", 0.0))
	if beats_path != "" and FileAccess.file_exists(beats_path):
		var rhythm: Variant = JSON.parse_string(FileAccess.get_file_as_string(beats_path))
		if rhythm is Dictionary:
			s.beat_times = PackedFloat32Array((rhythm as Dictionary).get("beats", []))
			s.bar_times = PackedFloat32Array((rhythm as Dictionary).get("bars", []))
	if ResourceLoader.exists(audio_path):
		s._stream = load(audio_path)
	if s.duration <= 0.0 and s._stream != null:
		s.duration = s._stream.get_length()
	return s


## Строки разметки: [{ text, start, end, words: [{ text, start, end }] }]. Строки без времени пропущены.
static func parse(data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in data.get("alignment", {}).get("lines", []):
		if l.get("start_seconds") == null or l.get("end_seconds") == null:
			continue
		var start := float(l["start_seconds"])
		var end := float(l["end_seconds"])
		var words: Array[Dictionary] = []
		for w in l.get("words", []):
			words.append({"text": str(w.get("text", "")), "start": w.get("start_seconds"), "end": w.get("end_seconds")})
		_fill_gaps(words, start, end)
		out.append({"text": str(l.get("display_text", "")), "start": start, "end": end, "words": words})
	return out


## Слова без времени делят поровну промежуток между соседями, у которых оно есть.
static func _fill_gaps(words: Array[Dictionary], line_start: float, line_end: float) -> void:
	var i := 0
	while i < words.size():
		if words[i]["start"] != null and words[i]["end"] != null:
			i += 1
			continue
		var j := i
		while j < words.size() and (words[j]["start"] == null or words[j]["end"] == null):
			j += 1
		var from := line_start if i == 0 else float(words[i - 1]["end"])
		var to := line_end if j >= words.size() else float(words[j]["start"])
		var step := maxf(to - from, 0.0) / (j - i)
		for k in range(i, j):
			words[k]["start"] = from + step * (k - i)
			words[k]["end"] = from + step * (k - i + 1)
		i = j


## from — с какой секунды песни начать (например, без вступления, которое в этом забеге было бы неправдой).
func start(cs: Cutscene, from: float = 0.0) -> void:
	_cs = cs
	_t = maxf(from, 0.0)
	_shown = -1
	_running = true
	if _stream != null and DisplayServer.get_name() != "headless":
		_player = AudioStreamPlayer.new()
		_player.stream = _stream
		_player.volume_db = volume_db()
		add_child(_player)
		_player.play(_t)


## Громкость песни: настройка музыки игры плюс GAIN_DB; выключенная музыка остаётся выключенной.
static func volume_db() -> float:
	var base := Audio.music_volume_db
	return base if base <= -40.0 else minf(base + GAIN_DB, 0.0)


func now() -> float:
	return _t


func playing() -> bool:
	return _running


## Ждёт, пока песня дойдёт до секунды t. Возвращается сразу, если сцену пропустили или песня кончилась.
func until(t: float) -> void:
	while _running and not _cs.skipped and _t < t:
		await get_tree().process_frame


## Вызвать f, когда песня дойдёт до секунды t (если сцену не пропустят раньше). Не ждать.
func at(t: float, f: Callable) -> void:
	_cues.append([t, f])


## Времена долей между a и b: каждая every-я, начиная со сдвига offset (0..every-1).
## У долей, снятых с записи, счёт идёт от сильной доли такта: every = 4, offset = 0 — сильные доли,
## every = 2, offset = 1 — вторая и четвёртая.
func beats(a: float, b: float, every: int = 1, offset: int = 0) -> Array[float]:
	var out: Array[float] = []
	if not beat_times.is_empty():
		for i in range(beat_times.bsearch(a), beat_times.size()):
			var x := beat_times[i]
			if x > b:
				break
			if posmod(_beat_in_bar(i) - offset, every) == 0:
				out.append(x)
		return out
	var k := int(ceil((a - beat_phase) / beat_period))
	while beat_phase + k * beat_period <= b:
		if posmod(k - offset, every) == 0:
			out.append(beat_phase + k * beat_period)
		k += 1
	return out


## Сильные доли тактов между a и b (без снятых с записи тактов — каждая четвёртая доля сетки).
func bars(a: float, b: float) -> Array[float]:
	if bar_times.is_empty():
		return beats(a, b, 4, 0)
	var out: Array[float] = []
	for i in range(bar_times.bsearch(a), bar_times.size()):
		if bar_times[i] > b:
			break
		out.append(bar_times[i])
	return out


## Номер доли i в её такте: 0 — сильная доля.
func _beat_in_bar(i: int) -> int:
	var x := beat_times[i]
	var bar := bar_times.bsearch(x + 0.001) - 1
	if bar < 0:
		return i
	return i - beat_times.bsearch(bar_times[bar] - 0.001)


## Удар доли в момент t: 1 — на самой доле, к следующей спадает до 0. Там, где ритма нет
## (вступление на словах, «стоп»), — 0: свет на долю там не вздрагивает.
func pulse(t: float) -> float:
	var last: float
	var next: float
	if beat_times.is_empty():
		last = beat_phase + floorf((t - beat_phase) / beat_period) * beat_period
		next = last + beat_period
	else:
		var i := beat_times.bsearch(t + 0.0001) - 1
		if i < 0 or i + 1 >= beat_times.size():
			return 0.0
		last = beat_times[i]
		next = beat_times[i + 1]
		if next - last > 1.0:
			return 0.0
	var k := 1.0 - clampf((t - last) / maxf(next - last, 0.01), 0.0, 1.0)
	return k * k


func stop(fade: float = 0.5) -> void:
	_running = false
	_cues.clear()
	if _cs != null:
		_cs.ui.hide_lyric(0.2)
	if _player != null and is_instance_valid(_player):
		var p := _player
		_player = null
		if fade <= 0.0:
			p.stop()
			p.queue_free()
		else:
			var tw := create_tween().set_ignore_time_scale(true)
			tw.tween_property(p, "volume_db", -60.0, fade)
			tw.tween_callback(p.queue_free)


func _process(delta: float) -> void:
	if not _running:
		return
	_t += _cs._dt if _cs != null else delta
	_follow_audio()
	if _cs != null and _cs.skipped:
		return
	_fire_cues()
	var idx := line_index(_t)
	if idx >= 0:
		_cs.ui.show_lyric(bbcode(lines[idx], _t))
	elif _shown >= 0:
		_cs.ui.hide_lyric()
	_shown = idx
	tick.emit(_t)
	if _t >= duration + 0.5:
		_running = false


## Пока звук играет с обычной скоростью, часы идут за ним: мелкое расхождение выбирается плавно,
## крупное (заминка кадра) — сразу. При ускорении звук подгоняется под часы высотой тона.
func _follow_audio() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.playing:
		return
	if not is_equal_approx(Engine.time_scale, 1.0):
		if Engine.time_scale > 4.0:
			_player.stop()
		else:
			_player.pitch_scale = maxf(Engine.time_scale, 0.25)
		return
	_player.pitch_scale = 1.0
	var pos := _player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	if pos <= 0.0:
		return
	if absf(pos - _t) > 0.12:
		_t = pos
	else:
		_t = move_toward(_t, pos, 0.01)


func _fire_cues() -> void:
	if _cues.is_empty():
		return
	var due: Array[Callable] = []
	var rest: Array[Array] = []
	for c in _cues:
		if float(c[0]) <= _t:
			due.append(c[1])
		else:
			rest.append(c)
	_cues = rest
	for f in due:
		if f.is_valid():
			f.call()


## Какая строка сейчас на экране; -1 — никакой.
func line_index(t: float) -> int:
	for i in lines.size():
		var l := lines[i]
		if float(l["start"]) > lyrics_until:
			break
		var until_t := float(l["end"]) + TAIL
		if i + 1 < lines.size() and float(lines[i + 1]["start"]) <= lyrics_until:
			until_t = minf(until_t, float(lines[i + 1]["start"]) - LEAD)
		if t >= float(l["start"]) - LEAD and t < until_t:
			return i
	return -1


## Строка для RichTextLabel: спетые слова — золотые, слово под голосом — светлое, остальные — приглушены.
static func bbcode(line: Dictionary, t: float) -> String:
	var parts := PackedStringArray()
	for w in line["words"]:
		var col := AHEAD
		if t >= float(w["end"]):
			col = SUNG
		elif t >= float(w["start"]):
			col = NOW
		parts.append("[color=#%s]%s[/color]" % [col, w["text"]])
	return " ".join(parts)
