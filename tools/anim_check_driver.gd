extends Node
## Драйвер tools/anim_check.gd: герой с полным кольцом вещей, состояния по очереди, кадр на каждое.
## variant=<id> — вариант героя из assets/characters/heroes.json; boss=1 — босс со всеми вещами варианта
## (размер как в игре: модель x1.7), кадры стойки, замаха, удара и смерти.

var _out := "user://anim_check"
var _size := 5.0
var _boss := false
var hero: Actor
var model: ActorModel
var _pivot: Node3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"out": _out = kv[1]
			"render": Render.set_mode(Render.Mode.PS2 if kv[1] == "ps2" else Render.Mode.PS1, false)
			"size": _size = float(kv[1])
			"variant": SkinnedActorModel.select(kv[1])
			"boss": _boss = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(_out)
	RunState.new_run(424242)
	var world := Node3D.new()
	add_child(world)
	var floor_disc := LowPoly.cyl(3.0, 3.0, 0.1, 16, Color(0.32, 0.26, 0.26), Vector3(0, -0.05, 0))
	world.add_child(floor_disc)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.09, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.45, 0.45)
	world.add_child(env)
	# Камера как CameraRig: орто, наклон 35°, поворот 45°, только ближе.
	var pivot := Node3D.new()
	pivot.rotation_degrees = Vector3(-35, 45, 0)
	pivot.position = Vector3(0, 1.0, 0)
	world.add_child(pivot)
	_pivot = pivot
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = _size
	cam.position = Vector3(0, 0, 20)
	pivot.add_child(cam)
	cam.current = true
	# Движение — как в игре: move_input и физика Actor; взгляд зафиксирован (без курсора).
	hero = Actor.new()
	hero.turn_with_aim = false
	world.add_child(hero)
	hero.set_items(RunState.ring.items.duplicate())
	hero.facing = Vector3(1, 0, 1).normalized()   # к камере (она стоит на +X+Z)
	if _boss:
		hero.faction = Actor.Faction.ENEMY
		model = SkinnedActorModel.for_boss()
		hero.add_child(model)
		model.setup(hero, ActorModel.Kind.BOSS, Color(0.16, 0.11, 0.2), Color(0.1, 0.07, 0.12))
		model.scale = Vector3.ONE * (load("res://data/enemies/boss.tres") as EnemyDef).scale
		cam.size = _size * 1.9
		pivot.position.y = 2.0
	else:
		model = SkinnedActorModel.for_hero()
		hero.add_child(model)
		model.setup(hero, ActorModel.Kind.HERO)
	print("модель: ", model.get_class(), " ", model.get_script().resource_path)
	var sk0: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	print("щиколотка в покое: %.3f м" % (sk0.global_transform * sk0.get_bone_global_rest(sk0.find_bone("LeftFoot"))).origin.y)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if hero != null and _pivot != null:
		_pivot.position = hero.global_position + Vector3(0, 1.0, 0)   # камера ведёт героя


func _boss_run() -> void:
	await _shot("b1_idle")
	for k in [0.5, 1.0]:
		model.set_windup(k)
		await _wait(0.15)
		await _shot("b2_windup_%d" % int(k * 100))
	model.set_windup(0.0)
	model.play_swing(&"chop", 0.22)
	await _wait(0.12)
	await _shot("b3_chop")
	await _wait(0.5)
	hero.died.emit(hero)
	await _wait(2.2)
	await _shot("b4_death")


## «Лыжи»: мировая скорость стопы, пока она на полу (ниже min+3 см). Должна быть ~0;
## если стопа едет по ходу движения — клип отстаёт от перемещения.
func _skate(label: String, seconds := 1.5) -> void:
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var foot := sk.find_bone("LeftFoot")
	var pts: Array[Vector3] = []
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		# сокет стопы (BoneAttachment3D) видит итоговую позу — после LocomotionModifier;
		# get_bone_global_pose из скрипта отдаёт позу до модификаторов
		pts.append((model.sockets[&"l_foot"] as Node3D).get_parent().global_position)
	var csv := FileAccess.open("%s/skate_%s.csv" % [_out, label.replace(" ", "_")], FileAccess.WRITE)
	var hp := hero.global_position
	for q in pts:
		csv.store_line("%f,%f,%f" % [q.x, q.y, q.z])
	csv.close()
	var low := INF
	for q in pts:
		low = minf(low, q.y)
	var v: Array[float] = []
	var along: Array[float] = []
	var dir := Combat.flat(hero.velocity).normalized()
	for i in range(1, pts.size()):
		if pts[i].y < low + 0.03 and pts[i - 1].y < low + 0.03:
			var d := Combat.flat(pts[i] - pts[i - 1]) / get_physics_process_delta_time()
			v.append(d.length())
			along.append(d.dot(dir))
	v.sort()
	along.sort()
	var t_tree: AnimationTree = model.find_children("*", "AnimationTree", true, false)[0]
	print("%s: скорость героя %.2f м/с, стопа на полу (ниже %.2f м) скользит %.2f м/с (по ходу %.2f), темп клипа %.2f" % [
		label, Combat.flat(hero.velocity).length(), low + 0.03, v[v.size() / 2], along[along.size() / 2],
		t_tree.get("parameters/loco_ts/scale")])


func _shot(name: String) -> void:
	for _f in 2:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _run() -> void:
	await _wait(0.8)
	if _boss:
		await _boss_run()
		get_tree().quit()
		return
	if "trace=1" in OS.get_cmdline_user_args():
		var m := model as SkinnedActorModel
		m._mod.active = false
		var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		hero.move_input = hero.facing
		await _wait(0.5)
		for k in 70:
			await get_tree().physics_frame
			var a := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftFoot"))).origin
			var h := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin
			var tt: AnimationTree = model.find_children("*", "AnimationTree", true, false)[0]
			print("след %02d ank_y=%.3f hips_y=%.3f hero_y=%.3f blend=%.2f" % [k, a.y, h.y, hero.global_position.y, tt.get("parameters/loco/blend_position")])
		get_tree().quit()
		return
	await _shot("01_idle")
	hero.move_input = hero.facing
	await _wait(0.6)
	var t: AnimationTree = model.find_children("*", "AnimationTree", true, false)[0]
	print("бег: скорость %.2f м/с, смесь %.2f, темп %.2f" % [Combat.flat(hero.velocity).length(), t.get("parameters/loco/blend_position"), t.get("parameters/loco_ts/scale")])
	await _shot("02_run_a")
	await _skate("бег вперёд")
	for k in 12:                         # плёнка бега: кадр каждые ~0.05 с
		await _shot("run_strip_%02d" % k)
		await _wait(0.04)
	await _wait(0.17)
	await _shot("03_run_b")
	var side := hero.facing.cross(Vector3.UP)
	for sd in [["вправо", side], ["влево", -side], ["наискосок", (hero.facing + side).normalized()]]:
		hero.move_input = sd[1]
		await _wait(0.5)
		var mm := model as SkinnedActorModel
		print("бег %s: поворот таза %.0f°" % [sd[0], rad_to_deg(mm._twist)])
		await _skate("бег " + sd[0])
		await _shot("04_strafe_%s" % sd[0])
		if sd[0] == "наискосок" and "strip=1" in OS.get_cmdline_user_args():
			for k in 10:
				await _shot("diag_strip_%02d" % k)
				await _wait(0.05)
	hero.move_input = -hero.facing * 0.6
	await _wait(0.5)
	print("спиной: темп %.2f" % t.get("parameters/loco_ts/scale"))
	await _shot("04_backpedal")
	hero.move_input = Vector3.ZERO
	await _wait(0.4)
	var swings := [[&"slash", 0.2], [&"slash_back", 0.2], [&"chop", 0.3], [&"punch", 0.18], [&"grab", 0.3], [&"cast", 0.32]]
	var i := 5
	for s in swings:
		model.play_swing(s[0], s[1])
		await _wait(s[1] * 0.55)
		await _shot("%02d_%s" % [i, s[0]])
		await _wait(0.5)
		i += 1
	hero.move_input = hero.facing
	await _wait(0.3)
	model.play_swing(&"slash", 0.2)
	await _wait(0.11)
	await _shot("%02d_slash_running" % i)
	i += 1
	hero.move_input = Vector3.ZERO
	hero.block_arc_degrees = 120.0
	await _wait(0.5)
	await _shot("%02d_block" % i)
	i += 1
	hero.block_arc_degrees = 0.0
	await _wait(0.4)
	hero.start_dash(Vector3(1, 0, -1).normalized(), 3.0, 0.3)
	await _wait(0.13)
	await _shot("%02d_dash" % i)
	i += 1
	await _wait(0.5)
	hero.hit_received.emit(5.0, false, null)
	await _wait(0.12)
	await _shot("%02d_hit" % i)
	i += 1
	await _wait(0.5)
	hero.died.emit(hero)
	await _wait(2.2)
	await _shot("%02d_death" % i)
	print("кадры: ", _out)
	get_tree().quit()
