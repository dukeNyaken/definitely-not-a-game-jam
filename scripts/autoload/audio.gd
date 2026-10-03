extends Node
## Звуки и музыка. Файлы лежат в res://assets/audio/<имя>.mp3|.ogg|.wav; отсутствующие тихо пропускаются.
## Музыка «на плёнке»: у алтаря трек битвы зажёвывает (tape_switch), после алтаря лента снова
## раскручивается с того же места (tape_resume).

const SFX_DIR := "res://assets/audio/"
const EXTENSIONS := ["mp3", "ogg", "wav"]
const POOL_SIZE := 24
## Сколько лента замедляется до остановки и сколько раскручивается обратно, с.
const TAPE_STOP := 0.85
const TAPE_START := 0.6

var sfx_volume_db: float = -4.0
var music_volume_db: float = -10.0
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: StringName = &""
var _music_active: AudioStreamPlayer
## Поколение музыки: отложенный запуск трека не срабатывает, если музыку уже сменили.
var _music_gen: int = 0
## Где плёнка остановила каждый трек, с.
var _music_pos: Dictionary = {}
## Трек, который зажевало у алтаря и который вернётся по tape_resume.
var _tape_held: StringName = &""
## Твины каждого музыкального плеера: перед повторным запуском плеера старые гасятся.
var _music_tweens: Dictionary = {}
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)


func _stream(sfx_name: StringName) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var s: AudioStream = null
	for ext: String in EXTENSIONS:
		var path := SFX_DIR + String(sfx_name) + "." + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_streams[sfx_name] = s
	return s


## Короткий звук. pitch_jitter даёт разнообразие повторов.
func play(sfx_name: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	# Не даём одному звуку звучать чаще раза в 35 мс.
	if now - int(_last_played.get(sfx_name, -1000)) < 35:
		return
	_last_played[sfx_name] = now
	var s := _stream(sfx_name)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = sfx_volume_db + volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_music(track: StringName, fade: float = 1.2) -> void:
	if track == _music_current:
		return
	_music_current = track
	_tape_held = &""
	_music_pos.clear()
	_fade_out(_music_active, fade)
	_music_active = _start_music(track, 0.0, fade)


func stop_music(fade: float = 1.0) -> void:
	_music_current = &""
	_tape_held = &""
	_music_gen += 1
	for p in [_music_a, _music_b]:
		_fade_out(p, fade)


## Плёнку зажёвывает: текущий трек дёргается и замедляется до остановки (место запоминается),
## затем играет track — с того места, где плёнка остановила его в прошлый раз.
func tape_switch(track: StringName) -> void:
	if track == _music_current:
		return
	var old := _music_active
	if _music_current != &"":
		_tape_held = _music_current
	if old != null and old.playing:
		_music_pos[_music_current] = old.get_playback_position()
		_tape_down(old)
		play(&"tape_stop", -2.0, 0.0)
	_music_current = track
	_music_active = _start_music(track, float(_music_pos.get(track, 0.0)), 0.6, TAPE_STOP * 0.75)


## Плёнку снова запускают: текущая музыка гаснет, track (по умолчанию тот, что зажевало)
## раскручивается с места, где его остановили.
func tape_resume(track: StringName = &"") -> void:
	if track == &"":
		track = _tape_held
	_tape_held = &""
	if track == &"" or track == _music_current:
		return
	var old := _music_active
	if old != null and old.playing:
		_music_pos[_music_current] = old.get_playback_position()
		_fade_out(old, 0.3)
	_music_current = track
	play(&"tape_start", -2.0, 0.0)
	_music_active = _start_music(track, float(_music_pos.get(track, 0.0)), 0.2, 0.08, true)


## Есть зажёванный трек, который ждёт возвращения.
func tape_held() -> bool:
	return _tape_held != &""


## Запуск track на свободном плеере с from (с), нарастание громкости за fade; spin_up — раскрутка ленты.
func _start_music(track: StringName, from: float, fade: float, delay: float = 0.0, spin_up: bool = false) -> AudioStreamPlayer:
	_music_gen += 1
	var s := _stream(track)
	if s == null:
		return null
	_ensure_loop(s)
	var p := _music_b if _music_active == _music_a else _music_a
	_kill_tweens(p)
	p.stop()
	p.stream = s
	p.pitch_scale = 1.0
	p.volume_db = -60.0
	var gen := _music_gen
	var tw := _tween(p)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if gen == _music_gen:
			p.play(from))
	tw.tween_property(p, "volume_db", music_volume_db, fade)
	if spin_up:
		p.pitch_scale = 0.05
		# Мотор набирает ход: скорость (и высота) растут, в начале лента ещё подрагивает.
		var tw2 := _tween(p)
		tw2.tween_interval(delay)
		tw2.tween_method(func(t: float) -> void:
			var k := 1.0 - (1.0 - t) * (1.0 - t)
			p.pitch_scale = maxf(lerpf(0.05, 1.0, k) * (1.0 + 0.05 * (1.0 - t) * sin(t * 40.0)), 0.02), 0.0, 1.0, TAPE_START)
	return p


## Лента тянется всё медленнее и дёргается всё сильнее, к концу глохнет.
func _tape_down(p: AudioStreamPlayer) -> void:
	_kill_tweens(p)
	var tw := _tween(p)
	tw.tween_method(func(t: float) -> void:
		var wobble := 1.0 + t * (0.09 * sin(t * 47.0) + 0.05 * sin(t * 83.0))
		p.pitch_scale = maxf(lerpf(1.0, 0.04, t * t) * wobble, 0.02)
		p.volume_db = music_volume_db - 40.0 * clampf((t - 0.65) / 0.35, 0.0, 1.0), 0.0, 1.0, TAPE_STOP)
	tw.tween_callback(func() -> void:
		p.stop()
		p.pitch_scale = 1.0)


func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	if p == null or not p.playing:
		return
	_kill_tweens(p)
	var tw := _tween(p)
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.stop)


func _tween(p: AudioStreamPlayer) -> Tween:
	var tw := create_tween()
	if not _music_tweens.has(p):
		_music_tweens[p] = []
	_music_tweens[p].append(tw)
	return tw


func _kill_tweens(p: AudioStreamPlayer) -> void:
	for tw in _music_tweens.get(p, []):
		if (tw as Tween).is_valid():
			(tw as Tween).kill()
	_music_tweens[p] = []


## Петли размечены при импорте; на всякий случай включаем и здесь.
func _ensure_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true


func set_music_volume(db: float) -> void:
	music_volume_db = db
	for p in [_music_a, _music_b]:
		var pl: AudioStreamPlayer = p
		if pl.playing:
			pl.volume_db = db


func _exit_tree() -> void:
	for p in [_music_a, _music_b]:
		(p as AudioStreamPlayer).stop()
		(p as AudioStreamPlayer).stream = null
	for p in _pool:
		p.stop()
		p.stream = null
	_streams.clear()
