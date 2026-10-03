extends SceneTree
## Траектория стоп одного клипа в пространстве скелета (без игровых поправок) — для разбора фаз шага.
##   godot --headless --path godot_test --script res://tools/dump_clip.gd -- <персонаж> <клип> <выход.csv>
## Столбцы: t, щиколотка y, z, носок y, z (левая нога).

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var root: Node3D = (load("res://characters/%s.glb" % args[0]) as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	ap.add_animation_library("ual", load("res://anims/ual.glb"))
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ank := sk.find_bone("LeftFoot")
	var toe := sk.find_bone("LeftToes")
	var a := ap.get_animation(args[1])
	ap.play(args[1])
	var f := FileAccess.open(args[2], FileAccess.WRITE)
	var t := 0.0
	while t <= a.length:
		ap.seek(t, true)
		sk.force_update_all_bone_transforms()
		var p := sk.get_bone_global_pose(ank).origin
		var q := sk.get_bone_global_pose(toe).origin
		f.store_line("%.3f,%.4f,%.4f,%.4f,%.4f" % [t, p.y, p.z, q.y, q.z])
		t += 1.0 / 60.0
	f.close()
	quit()
