class_name Telegraph
extends Node3D
## Предупреждение на полу: сектор, круг или линия, заполняется за время замаха.

enum Shape { SECTOR, CIRCLE, LINE }

var shape: int = Shape.CIRCLE
var radius: float = 2.0
var arc_degrees: float = 90.0
var width: float = 0.3
var color: Color = Color(1.0, 0.25, 0.15)
var _fill: MeshInstance3D
var _edge: MeshInstance3D
var _fill_mat: StandardMaterial3D


static func create(parent: Node, p_shape: int, p_radius: float, p_color: Color = Color(1.0, 0.25, 0.15), p_arc: float = 90.0) -> Telegraph:
	var t := Telegraph.new()
	t.shape = p_shape
	t.radius = p_radius
	t.arc_degrees = p_arc
	t.color = p_color
	if parent != null:
		parent.add_child(t)
	return t


func _ready() -> void:
	var fill_mesh: Mesh
	var edge_mesh: Mesh
	match shape:
		Shape.SECTOR:
			fill_mesh = Vfx.sector_mesh(radius, arc_degrees)
			edge_mesh = Vfx.sector_mesh(radius, arc_degrees, radius - 0.08)
		Shape.CIRCLE:
			fill_mesh = Vfx.sector_mesh(radius, 360.0, 0.0, 32)
			edge_mesh = Vfx.ring_mesh(radius, 0.1, 32)
		Shape.LINE:
			var b := BoxMesh.new()
			b.size = Vector3(width, 0.01, radius)
			fill_mesh = b
			var e := BoxMesh.new()
			e.size = Vector3(width * 0.35, 0.01, radius)
			edge_mesh = e
	_fill_mat = Vfx.material(Color(color, 0.32), 1.2, false)
	_fill = MeshInstance3D.new()
	_fill.mesh = fill_mesh
	_fill.material_override = _fill_mat
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edge = MeshInstance3D.new()
	_edge.mesh = edge_mesh
	_edge.material_override = Vfx.material(Color(color, 0.75), 1.4, false)
	_edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_edge)
	add_child(_fill)
	if shape == Shape.LINE:
		_fill.position.z = -radius * 0.5
		_edge.position.z = -radius * 0.5
	position.y = 0.04
	set_progress(0.0)


func set_progress(p: float) -> void:
	if _fill == null:
		return
	var k := clampf(p, 0.0, 1.0)
	if shape == Shape.LINE:
		_fill.scale = Vector3(1, 1, maxf(k, 0.01))
		_fill.position.z = -radius * 0.5 * k
	else:
		_fill.scale = Vector3.ONE * maxf(k, 0.01)
	_fill_mat.albedo_color.a = 0.2 + 0.35 * k


func place(pos: Vector3, dir: Vector3) -> void:
	global_position = Vector3(pos.x, 0.04, pos.z)
	var d := Combat.flat_dir(dir)
	look_at(global_position + d, Vector3.UP)
