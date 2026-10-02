class_name RingMoon
extends Node3D
## Небо мира: бледная треснувшая луна в кольце из семи осколков — семь вещей кольца.
## Плоская фигура в локальной плоскости XY, лицом к +Z.

var _orbit: Node3D
var _t: float = 0.0


static func sky_material(color: Color, additive: bool) -> StandardMaterial3D:
	var m := Vfx.material(color, 1.0, additive)
	m.set("disable_fog", true)
	return m


func _ready() -> void:
	var pale := Color(0.78, 0.82, 0.9)
	var halo := MeshInstance3D.new()
	halo.mesh = Vfx.sector_mesh(6.5, 360.0, 0.0, 40)
	halo.material_override = sky_material(Color(0.35, 0.42, 0.6, 0.22), true)
	halo.rotation.x = PI / 2
	halo.position.z = -0.6
	add_child(halo)
	var moon := MeshInstance3D.new()
	moon.mesh = Vfx.sector_mesh(2.6, 360.0, 0.0, 14)
	moon.material_override = sky_material(Color(pale, 1.0), false)
	moon.rotation.x = PI / 2
	add_child(moon)
	# Тёмные пятна и трещина через луну.
	for spot in [Vector3(-0.8, 0.6, 0.05), Vector3(0.9, -0.4, 0.05), Vector3(0.2, 1.3, 0.05)]:
		var s := MeshInstance3D.new()
		s.mesh = Vfx.sector_mesh(0.45 + absf(spot.x) * 0.2, 360.0, 0.0, 7)
		s.material_override = sky_material(Color(0.5, 0.52, 0.6, 1.0), false)
		s.rotation.x = PI / 2
		s.position = spot
		add_child(s)
	var crack := [Vector3(-1.6, 1.8, 0.1), Vector3(-0.5, 0.6, 0.1), Vector3(0.1, 0.8, 0.1), Vector3(0.6, -0.4, 0.1), Vector3(1.5, -1.9, 0.1)]
	for i in crack.size() - 1:
		var a: Vector3 = crack[i]
		var b: Vector3 = crack[i + 1]
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(a.distance_to(b), 0.14, 0.02)
		seg.mesh = box
		seg.material_override = sky_material(Color(0.12, 0.08, 0.1, 1.0), false)
		seg.position = (a + b) * 0.5
		seg.rotation.z = atan2(b.y - a.y, b.x - a.x)
		add_child(seg)
	var ring := MeshInstance3D.new()
	ring.mesh = Vfx.ring_mesh(4.3, 0.08, 48)
	ring.material_override = sky_material(Color(0.6, 0.68, 0.85, 0.5), true)
	ring.rotation.x = PI / 2
	ring.position.z = -0.2
	add_child(ring)
	# Семь осколков по кольцу.
	_orbit = Node3D.new()
	add_child(_orbit)
	for k in 7:
		var a := TAU * k / 7.0
		var shard := MeshInstance3D.new()
		shard.mesh = LowPoly.gem_mesh(0.32, 0.75, 0.4, 4)
		shard.material_override = sky_material(Color(0.82, 0.88, 1.0, 0.95), false)
		shard.position = Vector3(cos(a), sin(a), 0) * 4.3
		shard.rotation.z = a - PI / 2
		_orbit.add_child(shard)
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
	_orbit.rotation.z = _t * 0.08
