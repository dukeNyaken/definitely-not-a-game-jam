extends SceneTree
## Замеры анимаций библиотеки на ретаргетнутом персонаже — чтобы настраивать по цифрам.
##   godot --headless --path godot_test --script res://tools/measure_anims.gd -- <персонаж> <выход.json>
##
## Для каждой анимации:
##   length       — длительность, с;
##   foot_speed   — скорость опорной стопы относительно тела, м/с: медиана |dz/dt|
##                  обеих стоп у земли (ниже min+5 см) в опорной фазе (см. ниже).
##                  Окно 5 см: при 2 см в замер попадали только касание и отрыв, а середина
##                  опоры (у Jog ~5.9 м/с) выпадала — бег выходил медленнее перемещения. Это родная скорость шага клипа — под неё
##                  подгоняется темп, чтобы ноги не скользили. Без условия «назад» в замер
##                  попадала фаза переноса (стопа низко, но летит вперёд вдвое быстрее тела),
##                  и бег выходил «на лыжах»: Jog 6.67 м/с вместо настоящих ~3;
##   hand_peak    — момент, с, наибольшей скорости правой кисти — пик удара;
##   hand_speed   — эта скорость, м/с.

const STEP := 1.0 / 60.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame          # до первого кадра узлы не готовы и скелет не принимает позу
	var args := OS.get_cmdline_user_args()
	var root: Node3D = (load("res://characters/%s.glb" % args[0]) as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	ap.add_animation_library("ual", load("res://anims/ual.glb"))
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var foot := sk.find_bone("LeftFoot")
	var foot_r := sk.find_bone("RightFoot")
	var hand := sk.find_bone("RightHand")
	var out := {}
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		ap.play(name)
		var t := 0.0
		var feet: Array[Vector3] = []
		var feet_r: Array[Vector3] = []
		var hands: Array[Vector3] = []
		while t <= a.length:
			ap.seek(t, true)
			sk.force_update_all_bone_transforms()
			feet.append(sk.get_bone_global_pose(foot).origin)
			feet_r.append(sk.get_bone_global_pose(foot_r).origin)
			hands.append(sk.get_bone_global_pose(hand).origin)
			t += STEP
		# Опорная фаза — знак скорости, который у земли (ниже min+5 см) встречается чаще:
		# опора длится дольше переноса. Так замерен Jog 5.89 м/с — в игре стопа на полу
		# скользит 0.3-0.5 м/с при 6 м/с. На отдельных клипах (Sprint у босса) знак
		# выбирается неверно — такие клипы отбрасывает SkinnedActorModel (скорости
		# ходьбы обязаны расти по списку locomotion).
		var pos_v: Array[float] = []
		var neg_v: Array[float] = []
		for track in [feet, feet_r]:
			var low := INF
			for q in track:
				low = minf(low, q.y)
			for i in range(1, track.size()):
				var dz: float = (track[i].z - track[i - 1].z) / STEP
				if track[i].y < low + 0.05 and absf(dz) > 0.05:
					(pos_v if dz > 0.0 else neg_v).append(absf(dz))
		var speeds: Array[float] = pos_v if pos_v.size() >= neg_v.size() else neg_v
		speeds.sort()
		var peak := 0.0
		var peak_t := 0.0
		for i in range(1, hands.size()):
			var v := hands[i].distance_to(hands[i - 1]) / STEP
			if v > peak:
				peak = v
				peak_t = i * STEP
		out[name] = {"length": snappedf(a.length, 0.01), "loop": a.loop_mode != Animation.LOOP_NONE,
			"foot_speed": snappedf(speeds[speeds.size() / 2] if speeds else 0.0, 0.01),
			"hand_peak": snappedf(peak_t, 0.01), "hand_speed": snappedf(peak, 0.1)}
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", false))
	print("замерено анимаций: ", out.size())
	quit()
