class_name EclipseSky
extends Node3D
## Затмение в небе: чёрное солнце в багровой короне. Висит в углу кадра за ареной.

var _corona: MeshInstance3D
var _t: float = 0.0


static func sky_material(color: Color, additive: bool) -> StandardMaterial3D:
	var m := Vfx.material(color, 1.0, additive)
	m.set("disable_fog", true)
	return m


func _ready() -> void:
	var glow := MeshInstance3D.new()
	glow.mesh = Vfx.sector_mesh(7.5, 360.0, 0.0, 32)
	glow.material_override = sky_material(Color(0.55, 0.06, 0.04, 0.35), true)
	glow.rotation.x = PI / 2
	glow.position.z = -0.6
	add_child(glow)
	_corona = MeshInstance3D.new()
	_corona.mesh = Vfx.ring_mesh(4.1, 1.0, 40)
	_corona.material_override = sky_material(Color(1.6, 0.25, 0.1, 0.95), true)
	_corona.rotation.x = PI / 2
	_corona.position.z = -0.3
	add_child(_corona)
	var rim := MeshInstance3D.new()
	rim.mesh = Vfx.ring_mesh(3.4, 0.25, 40)
	rim.material_override = sky_material(Color(2.2, 0.7, 0.35, 1.0), true)
	rim.rotation.x = PI / 2
	rim.position.z = -0.2
	add_child(rim)
	var disc := MeshInstance3D.new()
	disc.mesh = Vfx.sector_mesh(3.3, 360.0, 0.0, 40)
	disc.material_override = sky_material(Color(0.0, 0.0, 0.0, 1.0), false)
	disc.rotation.x = PI / 2
	add_child(disc)
	# Рваные облака поперёк.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for k in 5:
		var cloud := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(5.0, 11.0), rng.randf_range(0.25, 0.6), 0.1)
		cloud.mesh = b
		cloud.material_override = sky_material(Color(0.04, 0.015, 0.02, 0.9), false)
		cloud.position = Vector3(rng.randf_range(-5, 5), rng.randf_range(-3.5, 3.5), 0.4)
		cloud.rotation.z = rng.randf_range(-0.12, 0.12)
		add_child(cloud)
	for n in get_children():
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
	var k := 1.0 + sin(_t * 1.3) * 0.03
	_corona.scale = Vector3(k, k, k)
