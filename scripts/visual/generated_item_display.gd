class_name GeneratedItemDisplay
## Вещи выбранного сгенерированного героя для витрины меню: сетки item_<слот> из его
## модели, без скелета (поза покоя), по центру и в размер витрины. Без собранных моделей —
## пустой словарь, и витрина остаётся на процедурных вещах.

## Наибольший размер вещи на витрине, м. Настоящие размеры различаются в десятки раз
## (меч варвара 1.6 м, амулет 0.1 м): в настоящем размере амулет на кольце не виден,
## а меч не влезает в кадр.
const FIT := {&"sword": 1.6, &"shield": 1.2, &"armor": 1.5, &"helmet": 0.8, &"amulet": 0.75}
const FIT_DEFAULT := 0.9
## Зазор между левой и правой вещью пары, доля ширины одной: на теле перчатки
## в 1.4 м друг от друга, и пара в размер витрины выходила двумя точками.
const PAIR_GAP := 0.25
## Вещи, которые ставятся длинной стороной вверх: меч в руке смотрит клинком вперёд.
const UPRIGHT := [&"sword"]
static var _static_meshes: Dictionary = {}
static var _preview_sizes: Dictionary = {}


## Одна рамка для всех обликов: смена уровня не приближает камеру.
## Сфера вмещает рога и пламя при любом повороте вещи.
static func preview_size(slot: StringName) -> float:
	var key := "%s/%s" % [SkinnedActorModel.current()["id"], slot]
	if _preview_sizes.has(key):
		return _preview_sizes[key]
	var radius := 0.0
	for tier in [1, 2, 3]:
		var state := ItemState.create(slot)
		state.appearance = tier
		var display := build_single(state)
		for mesh: MeshInstance3D in display.find_children("*", "MeshInstance3D", true, false):
			var box := _local_transform(mesh, display) * mesh.mesh.get_aabb()
			for i in 8:
				radius = maxf(radius, box.get_endpoint(i).length())
		display.free()
	_preview_sizes[key] = maxf(float(FIT.get(slot, FIT_DEFAULT)) + 0.4, radius * 2.0 + 0.12)
	return _preview_sizes[key]


## Слот -> Node3D с вещью; начало координат — середина вещи (витрина её вращает).
static func build(states: Array[ItemState] = [], only_slot: StringName = &"") -> Dictionary:
	var out := {}
	if not SkinnedActorModel.available():
		return out
	var scene: Node3D = (load(SkinnedActorModel.current()["model"]) as PackedScene).instantiate()
	var parts := {}            # слот -> [MeshInstance3D]
	for mi: MeshInstance3D in scene.find_children("item_*", "MeshInstance3D", true, false):
		var slot := SkinnedActorModel._slot_of(mi.name.trim_prefix("item_"))
		if only_slot != &"" and slot != only_slot:
			continue
		var copy := MeshInstance3D.new()
		copy.name = mi.name
		copy.mesh = _static_mesh(mi.mesh)
		var src := mi.get_active_material(0) as BaseMaterial3D
		copy.material_override = LowPoly.mat_textured(src.albedo_texture if src else null)
		for state in states:
			if state.def_id == slot and state.appearance > 1:
				copy.add_child(ItemAppearance.build(mi, slot, state.appearance))
		parts.get_or_add(slot, []).append(copy)
	scene.free()
	for slot in parts:
		out[slot] = _display(slot, parts[slot])
		out[slot].set_meta(&"hero_variant", SkinnedActorModel.current()["id"])
	for state in states:
		if (state.appearance > 1 or not state.properties.is_empty()) and out.has(state.def_id):
			_decorate(out[state.def_id], parts[state.def_id], state)
	return out


## Скелетные атрибуты нельзя оставлять на копии без Skeleton3D: при рендере героя
## в другом viewport она может получить его деформацию и исчезнуть из кадра.
static func _static_mesh(source: Mesh) -> ArrayMesh:
	if _static_meshes.has(source):
		return _static_meshes[source]
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
	_static_meshes[source] = mesh
	return mesh


## Внешняя оболочка сохраняет нормализацию glb при задании масштаба в витрине или сцене.
static func build_single(state: ItemState) -> Node3D:
	var shown := build([state], state.def_id)
	if not shown.has(state.def_id):
		return null
	var root := Node3D.new()
	root.name = "Item_%s" % state.def_id
	root.set_meta(&"hero_variant", SkinnedActorModel.current()["id"])
	root.add_child(shown[state.def_id])
	return root


## Добавки поглощённых сущностей. Собственный облик уже на каждой исходной части.
static func _decorate(root: Node3D, meshes: Array, state: ItemState) -> void:
	var box := _bounds(meshes, root)
	box = AABB(box.position * root.scale.x, box.size * root.scale.x)
	var trim := Node3D.new()
	trim.name = "AppearanceTrim"
	trim.scale = Vector3.ONE / root.scale.x
	root.add_child(trim)
	var anchors: Array = []
	var faces := PackedVector3Array()
	for mesh: MeshInstance3D in meshes:
		var transform := _local_transform(mesh, root)
		for vertex in mesh.mesh.get_faces():
			faces.append((transform * vertex) * root.scale.x)
	for y in [0.25, -0.25]:
		for x in [-0.25, 0.25]:
			var point := box.get_center() + Vector3(box.size.x * x, box.size.y * y, box.size.z * 0.5)
			point = _surface_point(point, faces, box.size.z)
			anchors.append(ItemVisuals._anchor(point, Vector3.BACK))
	ItemVisuals.decorate([{"node": trim, "anchors": anchors}], state, false)


## Передняя поверхность; если точка попала за контур клинка или щита — ближайший край.
static func _surface_point(target: Vector3, faces: PackedVector3Array, depth: float) -> Vector3:
	var origin := target + Vector3(0, 0, depth + 0.01)
	var nearest := target
	var distance := INF
	for i in range(0, faces.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(origin, Vector3.FORWARD, faces[i], faces[i + 1], faces[i + 2])
		if hit != null:
			var d: float = origin.distance_squared_to(hit)
			if d < distance:
				distance = d
				nearest = hit
	if distance < INF:
		return nearest
	for i in range(0, faces.size(), 3):
		for edge in 3:
			var point := Geometry3D.get_closest_point_to_segment(target, faces[i + edge], faces[i + (edge + 1) % 3])
			var d := target.distance_squared_to(point)
			if d < distance:
				distance = d
				nearest = point
	return nearest


static func _display(slot: StringName, meshes: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Item_%s" % slot
	var body := Node3D.new()
	root.add_child(body)
	var pair := meshes.size() == 2 and meshes.all(func(m): return m.name.ends_with("_L") or m.name.ends_with("_R"))
	if pair:
		# пара — вплотную бок о бок, каждая по своей середине
		for m: MeshInstance3D in meshes:
			var box := m.mesh.get_aabb()
			var side := 1.0 if m.name.ends_with("_L") else -1.0
			m.position = -box.get_center() + Vector3(side * box.size.x * (0.5 + PAIR_GAP / 2.0), 0, 0)
			body.add_child(m)
	else:
		# составная вещь (доспех: кираса и поножи) сохраняет взаимное положение частей
		var box := _bounds(meshes)
		for m: MeshInstance3D in meshes:
			m.position = -box.get_center()
			body.add_child(m)
	if slot == &"amulet":
		# Посадка на тело может сжать медальон в полоску (комплект рыцаря).
		# В витрине восстанавливаем круглые пропорции, не меняя сетку на персонаже.
		var box := _bounds(meshes, body)
		if box.size.y < box.size.x * 0.35:
			var restore := box.size.x / maxf(box.size.y, 0.0001)
			body.scale = Vector3(1.0, restore, restore)
			# Новая геометрия уже объёмная: исправление плоской исходной сетки
			# рыцаря не должно растянуть её рога в десятки раз.
			for m: MeshInstance3D in meshes:
				var center := m.mesh.get_aabb().get_center()
				var correction := Transform3D(Basis.IDENTITY, center) * Transform3D(Basis.from_scale(Vector3(1, 1 / restore, 1 / restore)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -center)
				for child in m.get_children():
					if child.has_meta(&"mastery_trim"):
						child.transform = correction * child.transform
	if slot in UPRIGHT:
		var box := _bounds(meshes, body)
		if box.size.z >= box.size.x and box.size.z >= box.size.y:
			body.rotation.x = -PI / 2
		elif box.size.x >= box.size.y:
			body.rotation.z = PI / 2
	var size := _bounds(meshes, root).get_longest_axis_size()
	root.scale = Vector3.ONE * float(FIT.get(slot, FIT_DEFAULT)) / maxf(size, 0.001)
	return root


## Общая рамка сеток (в системе relative_to, если задана, иначе по их собственным сеткам).
static func _bounds(meshes: Array, relative_to: Node3D = null) -> AABB:
	var box := AABB()
	for i in meshes.size():
		var m: MeshInstance3D = meshes[i]
		var b := m.mesh.get_aabb()
		if relative_to != null:
			b = _local_transform(m, relative_to) * b
		box = b if i == 0 else box.merge(b)
	return box


static func _local_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t := Transform3D()
	var n: Node = node
	while n != ancestor and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
