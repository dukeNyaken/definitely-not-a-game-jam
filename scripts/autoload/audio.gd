extends Node
## Звуки и музыка. Файлы лежат в res://assets/audio/<имя>.wav; отсутствующие тихо пропускаются.

const SFX_DIR := "res://assets/audio/"
const POOL_SIZE := 24

var sfx_volume_db: float = -4.0
var music_volume_db: float = -10.0
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: StringName = &""
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
	var path := SFX_DIR + String(sfx_name) + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
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
	var s := _stream(track)
	var old := _music_a if _music_a.playing else _music_b
	var new := _music_b if old == _music_a else _music_a
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if s == null:
		return
	# Петли размечены при импорте (edit/loop_mode=2); на всякий случай включаем и здесь.
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)
	new.stream = s
	new.volume_db = -40.0
	new.play()
	var tw2 := create_tween()
	tw2.tween_property(new, "volume_db", music_volume_db, fade)


func stop_music(fade: float = 1.0) -> void:
	_music_current = &""
	for p in [_music_a, _music_b]:
		var pl: AudioStreamPlayer = p
		if pl.playing:
			var tw := create_tween()
			tw.tween_property(pl, "volume_db", -60.0, fade)
			tw.tween_callback(pl.stop)


func set_music_volume(db: float) -> void:
	music_volume_db = db
	for p in [_music_a, _music_b]:
		var pl: AudioStreamPlayer = p
		if pl.playing:
			pl.volume_db = db
