extends CanvasLayer
## Ретро-рендер: PS1 (низкое разрешение, дрожание вершин, дизеринг, вершинный свет)
## или PS2 (мягче, свечение, зерно). Переключается F2, в меню и в паузе; запоминается.

signal mode_changed(mode: int)

enum Mode { PS1, PS2 }
const MODE_NAMES: Array[String] = ["PS1", "PS2"]
const SETTINGS_PATH := "user://settings.cfg"
## Целевое число строк по вертикали.
const TARGET_LINES := {Mode.PS1: 270.0, Mode.PS2: 450.0}

var mode: int = Mode.PS1
var shader_ps1: Shader = preload("res://shaders/retro_ps1.gdshader")
var shader_ps2: Shader = preload("res://shaders/retro_ps2.gdshader")
var _post: ColorRect
var _post_mat: ShaderMaterial
var _materials: Array[WeakRef] = []
var _pixel: float = 3.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_post = ColorRect.new()
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = preload("res://shaders/retro_post.gdshader")
	_post.material = _post_mat
	add_child(_post)
	_load()
	get_tree().root.size_changed.connect(_update_resolution)
	apply()


func _process(_delta: float) -> void:
	if mode == Mode.PS2:
		_post_mat.set_shader_parameter(&"seed", float(Engine.get_process_frames() % 977))


func shader() -> Shader:
	return shader_ps1 if mode == Mode.PS1 else shader_ps2


## Все ретро-материалы регистрируются здесь, чтобы при переключении получить новый шейдер.
func register(mat: ShaderMaterial) -> void:
	mat.shader = shader()
	_materials.append(weakref(mat))


func mode_name() -> String:
	return MODE_NAMES[mode]


func toggle() -> void:
	set_mode((mode + 1) % MODE_NAMES.size())


func set_mode(m: int) -> void:
	mode = m
	apply()
	_save()
	mode_changed.emit(mode)


func is_ps1() -> bool:
	return mode == Mode.PS1


func apply() -> void:
	var alive: Array[WeakRef] = []
	var sh := shader()
	for w in _materials:
		var m := w.get_ref() as ShaderMaterial
		if m != null:
			m.shader = sh
			alive.append(w)
	_materials = alive
	var p := _post_mat
	if mode == Mode.PS1:
		p.set_shader_parameter(&"levels", 24.0)
		p.set_shader_parameter(&"dither_amount", 1.0)
		p.set_shader_parameter(&"smooth_amount", 0.0)
		p.set_shader_parameter(&"bloom", 0.0)
		p.set_shader_parameter(&"grain", 0.0)
		p.set_shader_parameter(&"scanlines", 0.0)
		p.set_shader_parameter(&"saturation", 0.62)
		p.set_shader_parameter(&"contrast", 1.12)
		p.set_shader_parameter(&"vignette", 0.45)
	else:
		p.set_shader_parameter(&"levels", 96.0)
		p.set_shader_parameter(&"dither_amount", 0.35)
		p.set_shader_parameter(&"smooth_amount", 0.55)
		p.set_shader_parameter(&"bloom", 0.6)
		p.set_shader_parameter(&"grain", 0.05)
		p.set_shader_parameter(&"scanlines", 0.06)
		p.set_shader_parameter(&"saturation", 0.62)
		p.set_shader_parameter(&"contrast", 1.18)
		p.set_shader_parameter(&"vignette", 0.5)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if mode == Mode.PS1 else Viewport.MSAA_2X
	_update_resolution()


func _update_resolution() -> void:
	var h := float(get_window().size.y)
	var w := float(get_window().size.x)
	if h <= 0.0:
		return
	_pixel = maxf(1.0, roundf(h / TARGET_LINES[mode]))
	_post_mat.set_shader_parameter(&"pixel", _pixel)
	RenderingServer.global_shader_parameter_set(&"retro_pixel", _pixel)
	RenderingServer.global_shader_parameter_set(&"retro_aspect", w / h)
	RenderingServer.global_shader_parameter_set(&"retro_snap_res", h / _pixel if mode == Mode.PS1 else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"render"):
		toggle()
		get_viewport().set_input_as_handled()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mode = clampi(int(cfg.get_value("render", "mode", Mode.PS1)), 0, MODE_NAMES.size() - 1)
		Audio.sfx_volume_db = float(cfg.get_value("audio", "sfx", Audio.sfx_volume_db))
		Audio.music_volume_db = float(cfg.get_value("audio", "music", Audio.music_volume_db))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("render", "mode", mode)
	cfg.set_value("audio", "sfx", Audio.sfx_volume_db)
	cfg.set_value("audio", "music", Audio.music_volume_db)
	cfg.save(SETTINGS_PATH)


func save_settings() -> void:
	_save()
