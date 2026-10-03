class_name GeneratedItemDisplay
## Вещи выбранного сгенерированного героя для витрины меню: сетки item_<слот> из его
## модели, без скелета (поза покоя), по центру и в размер витрины. Без прототипа —
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


## Слот -> Node3D с вещью; начало координат — середина вещи (витрина её вращает).
static func build() -> Dictionary:
	var out := {}
	if not SkinnedActorModel.available():
		return out
	var scene: Node3D = (load(SkinnedActorModel.current()["model"]) as PackedScene).instantiate()
	var parts := {}            # слот -> [MeshInstance3D]
	for mi: MeshInstance3D in scene.find_children("item_*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.name = mi.name
		copy.mesh = mi.mesh    # без скина сетка рисуется в позе покоя
		var src := mi.get_active_material(0) as BaseMaterial3D
		copy.material_override = LowPoly.mat_textured(src.albedo_texture if src else null)
		parts.get_or_add(SkinnedActorModel._slot_of(mi.name.trim_prefix("item_")), []).append(copy)
	scene.free()
	for slot in parts:
		out[slot] = _display(slot, parts[slot])
	return out


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
