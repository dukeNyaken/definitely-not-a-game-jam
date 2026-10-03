class_name ItemAppearance
extends RefCounted
## Геометрия обликов в координатах исходной вещи. В бою крепится к костям,
## в витрине — к копии той же сетки. Добавки поглощённых сущностей живут отдельно.

const RED := Color(1.0, 0.035, 0.025)
const IRON := Color(0.38, 0.4, 0.43)
const FLAME := preload("res://shaders/relic_flame.gdshader")
static var _flame_material: ShaderMaterial


static func bind_pose(mesh: MeshInstance3D, bone: StringName) -> Transform3D:
	if mesh.skin != null:
		for i in mesh.skin.get_bind_count():
			if mesh.skin.get_bind_name(i) == bone:
				return mesh.skin.get_bind_pose(i).affine_inverse()
	return Transform3D.IDENTITY


## Оси предмета, а не общей рамки тела: щит вдоль предплечья, пальцы вдоль кисти.
static func frame_for(mesh: MeshInstance3D, slot: StringName) -> Transform3D:
	if slot == &"sword":
		return Transform3D(Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT), Vector3.ZERO)
	if slot == &"gloves" or slot == &"shield":
		var bone := StringName(("Left" if mesh.name.ends_with("_L") or slot == &"shield" else "Right") + ("Hand" if slot == &"gloves" else "LowerArm"))
		var bind := bind_pose(mesh, bone)
		var up := -bind.basis.y.normalized()
		var front := Vector3.BACK if slot == &"gloves" else Vector3.RIGHT
		front = (front - up * front.dot(up)).normalized()
		var right := up.cross(front).normalized()
		return Transform3D(Basis(right, up, right.cross(up)), bind.origin)
	return Transform3D.IDENTITY


static func build(mesh: MeshInstance3D, slot: StringName, tier: int) -> Node3D:
	var root := Node3D.new()
	root.name = "RelicAppearance"
	root.set_meta(&"mastery_trim", true)
	root.set_meta(&"appearance_tier", tier)
	if tier < 2 or "__legs" in String(mesh.name) or mesh.name.ends_with("_under"):
		return root
	var frame := frame_for(mesh, slot)
	var faces := PackedVector3Array()
	var inverse := frame.affine_inverse()
	for v in mesh.mesh.get_faces():
		faces.append(inverse * v)
	_make(root, slot, tier, faces, frame)
	return root


static func _bounds(faces: PackedVector3Array) -> AABB:
	var box := AABB(faces[0], Vector3.ZERO)
	for v in faces:
		box = box.expand(v)
	return box


## Луч от внешней стороны гарантирует, что крепление сидит на поверхности модели.
static func surface(seed: Vector3, direction: Vector3, faces: PackedVector3Array) -> Vector3:
	var distance := maxf(_bounds(faces).get_longest_axis_size(), 0.01) * 2.0
	var start := seed + direction * distance
	var best := seed
	var nearest := INF
	for i in range(0, faces.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(start, -direction, faces[i], faces[i + 1], faces[i + 2])
		if hit != null and start.distance_squared_to(hit) < nearest:
			nearest = start.distance_squared_to(hit)
			best = hit
	if nearest < INF:
		return best
	for i in range(0, faces.size(), 3):
		for edge in 3:
			var p := Geometry3D.get_closest_point_to_segment(seed, faces[i + edge], faces[i + (edge + 1) % 3])
			if seed.distance_squared_to(p) < nearest:
				nearest = seed.distance_squared_to(p)
				best = p
	return best


static func _make(root: Node3D, slot: StringName, tier: int, faces: PackedVector3Array, frame: Transform3D) -> void:
	if faces.is_empty():
		return
	var box := _bounds(faces)
	var c := box.get_center()
	var w := box.size.x
	var h := box.size.y
	var d := box.size.z
	match slot:
		&"helmet":
			if tier == 2:
				var p := surface(Vector3(c.x, box.end.y, c.z + d * 0.12), Vector3.UP, faces)
				_horn(root, frame, p, [Vector3.ZERO, Vector3(0, w * 0.5, 0), Vector3(0, w, -w * 0.16)], w * 0.17, tier, &"head_horn")
			else:
				for side in [-1.0, 1.0]:
					var p := surface(Vector3(c.x + side * w * 0.46, c.y + h * 0.2, c.z), Vector3(side, 0.25, 0).normalized(), faces)
					_horn(root, frame, p, [Vector3.ZERO, Vector3(side * w * 0.4, w * 0.15, 0), Vector3(side * w * 0.62, w * 0.65, 0), Vector3(side * w * 0.5, w * 1.05, 0)], w * 0.18, tier, &"head_horn")
			var p := surface(Vector3(c.x, c.y + h * 0.12, box.end.z), Vector3.BACK, faces)
			_bar(root, frame, p - Vector3(w * 0.3, 0, 0), p + Vector3(w * 0.3, 0, 0), h * 0.035, tier, &"visor")
		&"shield":
			for side in ([0.0] if tier == 2 else [-1.0, 1.0]):
				var p := surface(Vector3(c.x + side * w * 0.32, box.end.y - h * 0.06, c.z), Vector3.UP, faces)
				_horn(root, frame, p, [Vector3.ZERO, Vector3(side * w * 0.12, h * 0.15, 0), Vector3(side * w * 0.08, h * 0.29, 0)], w * 0.11, tier, &"shield_horn")
			var outline := [Vector3(c.x - w * 0.42, c.y + h * 0.36, c.z), Vector3(c.x + w * 0.42, c.y + h * 0.36, c.z), Vector3(c.x + w * 0.35, c.y - h * 0.12, c.z), Vector3(c.x, c.y - h * 0.43, c.z), Vector3(c.x - w * 0.35, c.y - h * 0.12, c.z)]
			for i in outline.size():
				_bar(root, frame, surface(outline[i], Vector3.BACK, faces) + Vector3(0, 0, 0.003), surface(outline[(i + 1) % outline.size()], Vector3.BACK, faces) + Vector3(0, 0, 0.003), w * 0.02, tier, &"rim")
		&"armor":
			for side in ([1.0] if tier == 2 else [-1.0, 1.0]):
				for k in (1 if tier == 2 else 2):
					var p := surface(Vector3(c.x + side * w * (0.36 + k * 0.075), c.y + h * 0.35, c.z), Vector3.UP, faces)
					_horn(root, frame, p, [Vector3.ZERO, Vector3(side * w * 0.055, w * 0.12, 0), Vector3(side * w * 0.1, w * (0.27 - k * 0.035), -w * 0.04)], w * 0.065, tier, &"shoulder_horn")
		&"gloves":
			for x in [-0.24, 0.0, 0.24]:
				var p := surface(Vector3(c.x + w * x, box.position.y + h * 0.25, c.z), Vector3.BACK, faces)
				_horn(root, frame, p, [Vector3.ZERO, Vector3(0, -w * 0.12, w * 0.2), Vector3(0, -w * 0.25, w * 0.36)], w * 0.07, tier, &"phalanx_horn")
			if tier == 3:
				for side in [-1.0, 1.0]:
					var p := surface(Vector3(c.x + side * w * 0.32, box.end.y - h * 0.16, c.z), Vector3.BACK, faces)
					_horn(root, frame, p, [Vector3.ZERO, Vector3(side * w * 0.15, w * 0.15, w * 0.25), Vector3(side * w * 0.23, w * 0.44, w * 0.34)], w * 0.12, tier, &"wrist_horn")
		&"boots":
			for side in ([0.0] if tier == 2 else [-1.0, 1.0]):
				var p := surface(Vector3(c.x + side * w * 0.2, box.position.y + h * 0.15, box.end.z - d * 0.08), Vector3.UP, faces)
				_horn(root, frame, p, [Vector3.ZERO, Vector3(side * w * 0.06, w * 0.06, d * 0.17), Vector3(side * w * 0.08, w * 0.32, d * 0.23)], w * 0.12, tier, &"toe_horn")
		&"sword":
			var start := box.position.y + h * (0.45 if tier == 2 else 0.23)
			# Обе стороны клинка: руна видна и при повороте витрины, и на замахе.
			for front in [-1.0, 1.0]:
				for side in ([0.0] if tier == 2 else [-1.0, 1.0]):
					var points: Array[Vector3] = []
					for i in 5:
						var y := lerpf(start, box.end.y - h * 0.035, i / 4.0)
						var normal := Vector3(0, 0, front)
						points.append(surface(Vector3(c.x + side * w * 0.1, y, c.z), normal, faces) + normal * 0.003)
					for i in 4:
						_bar(root, frame, points[i], points[i + 1], h * 0.012, tier, &"blade_edge")
			if tier == 3:
				for side in [-1.0, 1.0]:
					var p := surface(Vector3(c.x + side * w * 0.3, box.position.y + h * 0.18, c.z), Vector3.BACK, faces)
					_horn(root, frame, p, [Vector3.ZERO, Vector3(side * h * 0.085, -h * 0.02, 0), Vector3(side * h * 0.1, h * 0.07, 0)], h * 0.035, tier, &"guard_horn")
		&"amulet":
			var radius := w * 0.48
			var p := Vector3(c.x, c.y, box.end.z)
			var core := _feature(root, frame, p, &"seal")
			var gem := LowPoly.gem(radius * 0.55, radius * 0.18, radius * 0.05, 7, RED, Vector3.ZERO, &"", 0.0, 2.0 if tier == 2 else 4.0)
			gem.rotation.x = PI / 2
			core.add_child(gem)
			for i in (3 if tier == 2 else 7):
				var a := TAU * i / float(3 if tier == 2 else 7)
				var direction := Vector3(cos(a), sin(a), 0)
				_horn(root, frame, p + direction * radius * 0.65, [Vector3.ZERO, direction * radius * 0.65, direction * radius], radius * 0.18, tier, &"sun_prong")


static func _feature(parent: Node3D, frame: Transform3D, p: Vector3, type: StringName) -> Node3D:
	var node := Node3D.new()
	node.name = String(type).to_pascal_case()
	node.transform = frame * Transform3D(Basis.IDENTITY, p)
	node.set_meta(&"appearance_feature", type)
	node.set_meta(&"attachment_point", frame * p)
	parent.add_child(node)
	return node


## Три-четыре кольца, по четыре стороны: изогнутый рог остаётся гранёным.
static func _horn(parent: Node3D, frame: Transform3D, p: Vector3, path: Array, radius: float, tier: int, type: StringName) -> void:
	var root := _feature(parent, frame, p, type)
	var rings: Array = []
	for i in path.size():
		var tangent: Vector3 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var x := tangent.cross(Vector3.FORWARD if absf(tangent.z) < 0.9 else Vector3.UP).normalized()
		var z := tangent.cross(x).normalized()
		var r := radius * (1.0 - i / float(path.size() - 1)) + radius * 0.025
		var ring: Array[Vector3] = []
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4
			ring.append(path[i] + (x * cos(a) + z * sin(a)) * r)
		rings.append(ring)
	for i in range(path.size() - 1):
		var faces: Array = [rings[i], rings[i + 1]]
		for k in 4:
			faces.append([rings[i][k], rings[i][(k + 1) % 4], rings[i + 1][(k + 1) % 4], rings[i + 1][k]])
		var mi := MeshInstance3D.new()
		mi.mesh = LowPoly.convex(faces)
		var hot := i == path.size() - 2
		mi.material_override = LowPoly.mat(RED if hot else IRON, 0.85, 0.25, (1.8 if tier == 2 else 3.0) if hot else 0.0, &"" if hot else &"iron")
		root.add_child(mi)
		# Раскалённая кромка читается и там, где самый кончик рога занимает один пиксель.
		var edge_start: Vector3 = (rings[i][0] + rings[i][1]) * 0.5
		var edge_end: Vector3 = (rings[i + 1][0] + rings[i + 1][1]) * 0.5
		var edge := LowPoly.cyl(radius * 0.08, radius * 0.08, edge_start.distance_to(edge_end), 4, RED, (edge_start + edge_end) * 0.5, 0.9, 0.0, 1.4 if tier == 2 else 2.8)
		edge.basis = ItemVisuals._anchor(Vector3.ZERO, (edge_end - edge_start).normalized()).basis
		root.add_child(edge)
	var collar := LowPoly.cyl(radius * 1.15, radius * 1.25, radius * 0.45, 6, IRON, Vector3.ZERO, 0.9, 0.25, 0.0, &"iron")
	collar.basis = ItemVisuals._anchor(Vector3.ZERO, (path[1] as Vector3).normalized()).basis
	root.add_child(collar)
	if tier == 3 and type != &"phalanx_horn" and type != &"sun_prong":
		_flame(root, path[-1], radius * 4.5)


static func _bar(parent: Node3D, frame: Transform3D, a: Vector3, b: Vector3, width: float, tier: int, type: StringName) -> void:
	if a.distance_to(b) < 0.0001:
		return
	var root := _feature(parent, frame, (a + b) * 0.5, type)
	var strip := LowPoly.cyl(width * 0.6, width * 0.6, a.distance_to(b), 4, RED, Vector3.ZERO, 0.9, 0.0, 1.3 if tier == 2 else 3.0)
	strip.basis = ItemVisuals._anchor(Vector3.ZERO, (b - a).normalized()).basis
	root.add_child(strip)


static func _flame(parent: Node3D, tip: Vector3, size: float) -> void:
	if _flame_material == null:
		_flame_material = ShaderMaterial.new()
		_flame_material.shader = FLAME
	var fx := MeshInstance3D.new()
	fx.name = "RelicFlame"
	fx.set_meta(&"appearance_fx", true)
	var plane := QuadMesh.new()
	plane.size = Vector2(size * 0.7, size)
	fx.mesh = plane
	fx.position = tip + Vector3(0, size * 0.35, 0)
	fx.material_override = _flame_material
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fx)


## Совместимость с процедурными персонажами: те же модели в их локальных осях.
static func decorate_procedural(part: Dictionary, state: ItemState) -> void:
	var root: Node3D = part["node"]
	var faces := PackedVector3Array()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var transform := GeneratedItemDisplay._local_transform(mi, root)
		for v in mi.mesh.get_faces():
			faces.append(transform * v)
	var frame := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	if state.def_id == &"sword":
		frame = Transform3D.IDENTITY
	var local := PackedVector3Array()
	for v in faces:
		local.append(frame.affine_inverse() * v)
	var trim := Node3D.new()
	trim.name = "RelicAppearance"
	trim.set_meta(&"mastery_trim", true)
	trim.set_meta(&"appearance_tier", state.appearance)
	root.add_child(trim)
	_make(trim, state.def_id, state.appearance, local, frame)
