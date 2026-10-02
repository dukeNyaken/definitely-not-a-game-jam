class_name HeroMarker
extends Node3D
## Кольцо под героем и шеврон направления к курсору — героя легко найти в толпе.

var _ring: MeshInstance3D
var _chevron: MeshInstance3D


func _ready() -> void:
	# Тёплый свет вокруг героя: в тёмной арене его и ближайших врагов видно сразу.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.55)
	light.light_energy = 2.2
	light.omni_range = 8.0
	light.omni_attenuation = 1.4
	light.position = Vector3(0, 3.2, 0.6)
	add_child(light)
	_ring = MeshInstance3D.new()
	_ring.mesh = Vfx.ring_mesh(0.62, 0.06, 32)
	_ring.material_override = Vfx.material(Color(1.0, 0.8, 0.45, 0.8), 1.8, true)
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_chevron = MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(Vector3(0, 0, -0.28))
	st.add_vertex(Vector3(0.2, 0, 0.05))
	st.add_vertex(Vector3(-0.2, 0, 0.05))
	_chevron.mesh = st.commit()
	_chevron.material_override = Vfx.material(Color(1.0, 0.85, 0.45, 0.7), 1.5, true)
	_chevron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chevron)


func _process(_delta: float) -> void:
	var actor := get_parent() as Actor
	if actor == null:
		return
	visible = not actor.dead
	var f := actor.facing
	_chevron.position = Vector3(f.x, 0.035, f.z) * 0.95
	_chevron.rotation.y = atan2(-f.x, -f.z)
