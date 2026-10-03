class_name FlipbookFx
extends MeshInstance3D
## Покадровый пиксельный эффект из листа спрайтов (assets/vfx). Листы белые/серые —
## цвет задаётся оттенком. Билборд к камере или плашмя на земле; разовый или зацикленный.

const SHEETS := {
	&"impact": {"tex": preload("res://assets/vfx/impact.png"), "grid": Vector2i(3, 2), "ms": [40, 40, 50, 60, 60, 70]},
	&"gaze_eye": {"tex": preload("res://assets/vfx/gaze_eye.png"), "grid": Vector2i(3, 3), "ms": [70, 60, 60, 120, 140, 120, 60, 80]},
	&"elite_aura": {"tex": preload("res://assets/vfx/elite_aura.png"), "grid": Vector2i(3, 3), "ms": [90, 90, 90, 90, 90, 90, 90, 90]},
	## Развёртка взмаха: x — вдоль дуги от хвоста к голове, y — от кромки лезвия внутрь (натягивается на сектор).
	&"slash_arc": {"tex": preload("res://assets/vfx/slash_arc.png"), "grid": Vector2i(3, 2), "ms": [30, 30, 40, 50, 60, 70]},
	## Кольцо волны сверху; radius_px — радиус фронта в каждом кадре (лист 128 px).
	&"shock_ring": {"tex": preload("res://assets/vfx/shock_ring.png"), "grid": Vector2i(3, 3), "ms": [40, 40, 50, 50, 60, 60, 70, 80],
		"radius_px": [10, 24, 36, 45, 52, 57, 60, 62], "size_px": 128},
}

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, skip_vertex_transform, %s;

uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;
uniform vec2 grid = vec2(1.0);
uniform float frame = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 1.0;
uniform float fade = 1.0;
// Сдвиг к камере в метрах: вспышка не прячется в теле того, по кому попали.
uniform float depth_pull = 0.0;

void vertex() {
	if (%s) {
		vec2 sc = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
		VERTEX = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz + vec3(VERTEX.xy * sc, 0.0);
	} else {
		VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	VERTEX.z += depth_pull;
}

void fragment() {
	vec2 cell_px = vec2(textureSize(sheet, 0)) / grid;
	vec2 local = clamp(UV, 0.5 / cell_px, 1.0 - 0.5 / cell_px);
	vec2 cell = vec2(mod(frame, grid.x), floor(frame / grid.x));
	vec4 t = texture(sheet, (local + cell) / grid);
	ALBEDO = t.rgb * tint.rgb * energy;
	ALPHA = t.a * tint.a * fade;
}
"""

static var _shaders: Dictionary = {}
static var _quad: QuadMesh
static var _plane: PlaneMesh

var loop: bool = false
var speed: float = 1.0
## Кадры выставляет владелец (set_frame), сам эффект не листает и не удаляется.
var manual: bool = false
var _ms: Array = []
var _frame: int = 0
var _t: float = 0.0
var _mat: ShaderMaterial
var _fading: bool = false


static func _shader(additive: bool, billboard: bool) -> Shader:
	var key := int(additive) + 2 * int(billboard)
	if not _shaders.has(key):
		var s := Shader.new()
		s.code = SHADER % ["blend_add" if additive else "blend_mix", "true" if billboard else "false"]
		_shaders[key] = s
	return _shaders[key]


## Длительность листа целиком, мс.
static func total_ms(id: StringName) -> float:
	var sum := 0.0
	for ms in SHEETS[id]["ms"]:
		sum += float(ms)
	return sum


## opts: additive (true), billboard (true), loop (false), speed (1.0) или duration (с),
## energy (1.6), pull (0.0), mesh (своя сетка с UV — тогда без билборда), manual (false).
static func make(id: StringName, tint: Color, size: float, opts: Dictionary = {}) -> FlipbookFx:
	var spec: Dictionary = SHEETS[id]
	var billboard: bool = opts.get("billboard", true) and not opts.has("mesh")
	var fx := FlipbookFx.new()
	fx.name = "Fx_%s" % id
	if opts.has("mesh"):
		fx.mesh = opts["mesh"]
	elif billboard:
		if _quad == null:
			_quad = QuadMesh.new()
		fx.mesh = _quad
	else:
		if _plane == null:
			_plane = PlaneMesh.new()
			_plane.size = Vector2.ONE
		fx.mesh = _plane
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.scale = Vector3.ONE * size
	fx.loop = opts.get("loop", false)
	fx.speed = opts.get("speed", 1.0)
	if opts.has("duration"):
		fx.speed = total_ms(id) / (1000.0 * maxf(float(opts["duration"]), 0.01))
	fx.manual = opts.get("manual", false)
	fx._ms = spec["ms"]
	var m := ShaderMaterial.new()
	m.shader = _shader(opts.get("additive", true), billboard)
	m.set_shader_parameter(&"sheet", spec["tex"])
	m.set_shader_parameter(&"grid", Vector2(spec["grid"]))
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"energy", opts.get("energy", 1.6))
	m.set_shader_parameter(&"depth_pull", opts.get("pull", 0.0))
	fx._mat = m
	fx.material_override = m
	return fx


## Разовый эффект в мировой точке, рядом с owner.
static func spawn(owner: Node, id: StringName, pos: Vector3, tint: Color, size: float, opts: Dictionary = {}) -> FlipbookFx:
	var parent := Vfx.root_for(owner)
	if parent == null:
		return null
	var fx := make(id, tint, size, opts)
	parent.add_child(fx)
	fx.global_position = pos
	return fx


## Эффект, прикреплённый к узлу (следует за ним).
static func attach(parent: Node3D, id: StringName, local_pos: Vector3, tint: Color, size: float, opts: Dictionary = {}) -> FlipbookFx:
	var fx := make(id, tint, size, opts)
	parent.add_child(fx)
	fx.position = local_pos
	return fx


## Вспышка попадания между целью и источником удара.
static func impact(target: Node3D, source: Vector3, height: float, tint: Color, size: float = 1.1) -> void:
	if target == null or not target.is_inside_tree():
		return
	var to_src := Combat.flat_dir(source - target.global_position, Vector3.ZERO)
	var pos := target.global_position + to_src * 0.35 + Vector3(0, height, 0)
	FlipbookFx.spawn(target, &"impact", pos, tint, size, {"energy": 2.2, "pull": 1.2})


func set_frame(i: int) -> void:
	_frame = clampi(i, 0, _ms.size() - 1)
	_mat.set_shader_parameter(&"frame", float(_frame))


func set_fade(v: float) -> void:
	_mat.set_shader_parameter(&"fade", v)


func fade_out(duration: float) -> void:
	if _fading:
		return
	_fading = true
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"fade", v), 1.0, 0.0, duration)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if manual:
		return
	_t += delta * 1000.0 * speed
	while _t >= float(_ms[_frame]):
		_t -= float(_ms[_frame])
		_frame += 1
		if _frame >= _ms.size():
			if not loop:
				queue_free()
				return
			_frame = 0
	_mat.set_shader_parameter(&"frame", float(_frame))
