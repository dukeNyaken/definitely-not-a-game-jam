extends SceneTree
## Bake model-specific, grounded stances and occupied-hand gestures for story people
## (npcs.json) and enemies (enemies.json). Run in the game project after importing the GLBs.

var sk: Skeleton3D
var ap: AnimationPlayer

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await process_frame
	# Люди сюжетных сцен и враги: один формат реестра, враги держат оружие на обычных сокетах
	for path in ["res://assets/characters/npcs.json", "res://assets/characters/enemies.json"]:
		if not FileAccess.file_exists(path):
			continue
		var people: bool = path.ends_with("npcs.json")
		var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for id in registry:
			var model: Node3D = load(registry[id]["model"]).instantiate()
			root.add_child(model)
			await process_frame
			sk = model.find_children("*", "Skeleton3D", true, false)[0]
			ap = model.find_children("*", "AnimationPlayer", true, false)[0]
			ap.add_animation_library("ual", load("res://assets/characters/anims/ual.glb"))
			neutral()
			save_pose(id, "idle")
			# Реквизит процедурного наряда собран под модель, смотрящую в -Z, и висит в сокете
			# без поворота; тело glb развёрнуто на 180°. В стойке покоя сокет повторяет эту рамку.
			var sockets := {}
			for socket_name in (registry[id].get("props", {}) if people else {}):
				var bone: String = {"l_hand": "LeftHand", "r_hand": "RightHand", "chest": "UpperChest"}[socket_name]
				var basis := sk.get_bone_global_pose(sk.find_bone(bone)).basis.orthonormalized()
				var frame := Basis(Vector3.UP, PI)
				if id == "captain":
					# щит висит на предплечье сбоку, лицом наружу (влево), как у героя, а не перед грудью
					frame = frame * Basis(Vector3.UP, PI / 2)
				var rot := (basis.inverse() * frame).get_euler() * 180.0 / PI
				sockets[socket_name] = {"rot": [rot.x, rot.y, rot.z]}
				if socket_name == "chest":
					# младенец у груди: чуть ниже кости и вперёд
					var off := basis.inverse() * (frame * Vector3(0, -0.2, -0.3))
					sockets[socket_name]["offset"] = [off.x, off.y, off.z]
			if not sockets.is_empty():
				registry[id]["sockets"] = sockets
			if people:
				# общие позы сцен: руки сцеплены у пояса (тревога), то же с опущенной головой
				# (сомнение), сжался от холода — руки крест-накрест на груди
				for pose_name in ["wring", "downcast", "huddle"]:
					neutral()
					var l := point("LeftUpperArm")
					var r := point("RightUpperArm")
					var waist := point("Hips").y + 0.14
					if pose_name == "huddle":
						turn_world("Spine", Vector3.RIGHT, 10.0)
						turn_world("Chest", Vector3.RIGHT, 8.0)
						turn_world("Head", Vector3.RIGHT, 10.0)
						l = point("LeftUpperArm")
						r = point("RightUpperArm")
						reach("Left", Vector3(r.x * 0.55, r.y - 0.12, r.z + 0.2), Vector3(l.x + 0.1, l.y - 0.35, l.z + 0.25))
						reach("Right", Vector3(l.x * 0.55, l.y - 0.18, l.z + 0.24), Vector3(r.x - 0.1, r.y - 0.35, r.z + 0.25))
					else:
						if pose_name == "downcast":
							turn_world("Spine", Vector3.RIGHT, 4.0)
							turn_world("Head", Vector3.RIGHT, 12.0)
						reach("Left", Vector3(0.04, waist, 0.2), Vector3(l.x + 0.15, l.y - 0.35, -0.05))
						reach("Right", Vector3(-0.04, waist, 0.2), Vector3(r.x - 0.15, r.y - 0.35, -0.05))
					save_pose(id, pose_name)
					registry[id]["animations"][pose_name] = "res://assets/characters/anims/npc_%s_%s.tres" % [id, pose_name]
					registry[id].get_or_add("poses", {})[pose_name] = {"anim": "npc/" + pose_name}
				neutral()
			if id == "friend":
				# рука на перевязи: левое предплечье поперёк живота
				var ls := point("LeftUpperArm")
				reach("Left", Vector3(ls.x - 0.3, ls.y - 0.4, 0.24), Vector3(ls.x + 0.15, ls.y - 0.45, 0.0))
				save_pose(id, "sling")
			if id == "infantry":
				# катана двумя руками перед поясом, клинок вперёд-вверх
				var rs := point("RightUpperArm")
				var blade := Vector3(0, 0.55, 0.83).normalized()
				var grip := Vector3(rs.x * 0.25, rs.y - 0.5, 0.32)
				reach("Right", grip, Vector3(rs.x - 0.2, rs.y - 0.4, 0.0))
				var kb := Basis(Vector3.RIGHT, deg_to_rad(-100))
				# клинок вперёд-вверх, лезвие (выпуклая сторона, -Z катаны) вперёд-вниз
				align("RightHand", item_dir(kb * Vector3.UP), blade, item_dir(kb * Vector3.FORWARD), Vector3(0, -blade.z, blade.y))
				var ls := point("LeftUpperArm")
				reach("Left", grip - blade * 0.22, Vector3(ls.x + 0.2, ls.y - 0.45, 0.0))
				save_pose(id, "guard")
			if id == "archer":
				# арбалет на уровне груди, ложе вперёд; правая рука у спуска
				var ls := point("LeftUpperArm")
				var rs := point("RightUpperArm")
				reach("Left", Vector3(ls.x * 0.4, ls.y - 0.12, 0.55), Vector3(ls.x + 0.25, ls.y - 0.3, 0.2))
				var cb := Basis(Vector3.RIGHT, deg_to_rad(-80))
				# ложе вперёд (+Z скелета), дуга лежит горизонтально: верх арбалета вверх
				align("LeftHand", item_dir(cb * Vector3.FORWARD), Vector3.BACK, item_dir(cb * Vector3.UP), Vector3.UP)
				reach("Right", Vector3(rs.x * 0.3, rs.y - 0.16, 0.3), Vector3(rs.x - 0.25, rs.y - 0.3, 0.0))
				save_pose(id, "aim")
			if id == "widow":
				# баюкает младенца: оба предплечья перед грудью, локти в стороны
				var wl := point("LeftUpperArm")
				var wr := point("RightUpperArm")
				reach("Left", Vector3(wl.x - 0.14, wl.y - 0.32, 0.26), Vector3(wl.x + 0.15, wl.y - 0.35, 0.0))
				reach("Right", Vector3(wr.x + 0.14, wr.y - 0.3, 0.26), Vector3(wr.x - 0.15, wr.y - 0.35, 0.0))
				save_pose(id, "hold")
			if id in ["father", "faithful"]:
				if id == "father":
					turn_world("Spine", Vector3.RIGHT, 9.0)
					turn_world("Chest", Vector3.RIGHT, 7.0)
					turn_world("Head", Vector3.RIGHT, 8.0)
				var left_shoulder := point("LeftUpperArm")
				var hand := Vector3(left_shoulder.x + 0.12, left_shoulder.y - 0.52, 0.32)
				reach("Left", hand, Vector3(left_shoulder.x + 0.28, left_shoulder.y - 0.42, 0.05))
				var pose_name := "frail" if id == "father" else "lantern"
				save_pose(id, pose_name)
				# Both original props have a small local pitch; cancel it at the socket.
				var prop_pitch := -0.55 if id == "father" else -0.45
				var basis := sk.get_bone_global_pose(sk.find_bone("LeftHand")).basis.orthonormalized()
				var rot := (basis.inverse() * Basis(Vector3.RIGHT, -prop_pitch)).get_euler() * 180.0 / PI
				registry[id]["sockets"] = {"l_hand": {"rot": [rot.x, rot.y, rot.z]}}
				var shoulder := point("RightUpperArm")
				reach("Right", Vector3(shoulder.x - 0.06, shoulder.y - 0.3, 0.57), Vector3(shoulder.x - 0.18, shoulder.y - 0.35, 0.25))
				save_pose(id, "frail_offer" if id == "father" else "offer")
			model.free()
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(registry, "  ", false) + "\n")
	print("NPC_POSES_DONE")
	quit()

func neutral() -> void:
	ap.play("ual/Idle")
	ap.seek(0.5, true)
	sk.force_update_all_bone_transforms()
	var arms := {}
	for i in sk.get_bone_count():
		var name := sk.get_bone_name(i)
		if "Arm" in name or "Shoulder" in name or "Hand" in name:
			arms[i] = sk.get_bone_pose_rotation(i)
	ap.stop()
	sk.reset_bone_poses()
	# Поза покоя после fix_silhouette загибает ступни носком вверх; ровно сетка стоит в позе
	# привязки скина (как в SkinnedActorModel.bind_rotation) — от неё всё, кроме рук.
	var skin: Skin = null
	for mi in sk.find_children("*", "MeshInstance3D", false, false):
		if (mi as MeshInstance3D).skin != null:
			skin = (mi as MeshInstance3D).skin
	for i in sk.get_bone_count():
		if not arms.has(i) and skin != null:
			var parent := sk.get_bone_parent(i)
			var pb := bind_global(skin, parent) if parent >= 0 else Basis.IDENTITY
			sk.set_bone_pose_rotation(i, (pb.inverse() * bind_global(skin, i)).get_rotation_quaternion())
	for i in arms:
		sk.set_bone_pose_rotation(i, arms[i])
	sk.force_update_all_bone_transforms()

func bind_global(skin: Skin, bone: int) -> Basis:
	for b in skin.get_bind_count():
		if skin.get_bind_bone(b) == bone or skin.get_bind_name(b) == StringName(sk.get_bone_name(bone)):
			return skin.get_bind_pose(b).affine_inverse().basis.orthonormalized()
	return sk.get_bone_global_rest(bone).basis.orthonormalized()

func point(name: String) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone(name)).origin

func set_world(name: String, basis: Basis) -> void:
	var i := sk.find_bone(name)
	var parent := sk.get_bone_parent(i)
	var parent_basis := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(i, (parent_basis.inverse() * basis).get_rotation_quaternion())
	sk.force_update_all_bone_transforms()

func turn_world(name: String, axis: Vector3, degrees: float) -> void:
	set_world(name, Basis(axis, deg_to_rad(degrees)) * sk.get_bone_global_pose(sk.find_bone(name)).basis.orthonormalized())

func aim(name: String, child: String, target: Vector3) -> void:
	var from := (point(child) - point(name)).normalized()
	var to := (target - point(name)).normalized()
	set_world(name, Basis(Quaternion(from, to)) * sk.get_bone_global_pose(sk.find_bone(name)).basis.orthonormalized())

func reach(side: String, target: Vector3, pole: Vector3) -> void:
	var upper := side + "UpperArm"
	var lower := side + "LowerArm"
	var wrist := side + "Hand"
	var start := point(upper)
	var a := start.distance_to(point(lower))
	var b := point(lower).distance_to(point(wrist))
	var direction := (target - start).normalized()
	var distance := clampf(start.distance_to(target), absf(a - b) + 0.001, a + b - 0.001)
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var out := (pole - start) - direction * (pole - start).dot(direction)
	var elbow := start + direction * along + out.normalized() * sqrt(maxf(0.0, a * a - along * along))
	aim(upper, lower, elbow)
	aim(lower, wrist, start + direction * distance)

## Направление предмета в кости кисти: сокет кисти из animation.json (как у меча героя)
## и собственный поворот предмета; в нём предмет задан осью local_dir.
func item_dir(local_dir: Vector3) -> Vector3:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/animation.json"))
	var r: Array = cfg["sockets"]["r_hand"]["rot"]
	return Basis.from_euler(Vector3(deg_to_rad(r[0]), deg_to_rad(r[1]), deg_to_rad(r[2]))) * local_dir

## Поворачивает кость так, чтобы ось bone_dir (в её пространстве) смотрела в want (в пространстве
## скелета), а вторая ось bone_up — как можно ближе к want_up: иначе предмет крутится вокруг первой.
func align(name: String, bone_dir: Vector3, want: Vector3, bone_up: Vector3, want_up: Vector3) -> void:
	set_world(name, frame(want, want_up) * frame(bone_dir, bone_up).inverse())

func frame(fwd: Vector3, up: Vector3) -> Basis:
	var f := fwd.normalized()
	var u := (up - f * up.dot(f)).normalized()
	return Basis(f, u, f.cross(u))

func save_pose(id: String, name: String) -> void:
	var anim := Animation.new()
	anim.resource_name = id + " " + name
	anim.length = 2.4
	anim.loop_mode = Animation.LOOP_LINEAR
	for i in sk.get_bone_count():
		var path := NodePath("%GeneralSkeleton:" + sk.get_bone_name(i))
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, path)
		var rot := sk.get_bone_pose_rotation(i)
		anim.rotation_track_insert_key(track, 0.0, rot)
		if sk.get_bone_name(i) == "Head":
			anim.rotation_track_insert_key(track, 1.2, rot * Quaternion(Vector3.RIGHT, 0.012))
			anim.rotation_track_insert_key(track, 2.4, rot)
		track = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(track, path)
		anim.position_track_insert_key(track, 0.0, sk.get_bone_pose_position(i))
	var path := "res://assets/characters/anims/npc_%s_%s.tres" % [id, name]
	assert(ResourceSaver.save(anim, path) == OK)
	print("POSE ", path)
