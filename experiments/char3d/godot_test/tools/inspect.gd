extends SceneTree
## Путь к скелету и список анимаций импортированной сцены — для настройки импорта.
##   godot --headless --path godot_test --script res://tools/inspect.gd -- res://characters/hero.glb

func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var res = load(path)
	if res is PackedScene:
		var root: Node = res.instantiate()
		for sk in root.find_children("*", "Skeleton3D", true, false):
			print("СКЕЛЕТ ", root.get_path_to(sk), " костей ", sk.get_bone_count(), " первая ", sk.get_bone_name(0))
		for ap in root.find_children("*", "AnimationPlayer", true, false):
			print("АНИМАЦИИ ", ap.get_animation_list())
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			print("СЕТКА ", root.get_path_to(mi))
		root.free()
	elif res is AnimationLibrary:
		print("БИБЛИОТЕКА ", res.get_animation_list().size(), " ", res.get_animation_list().slice(0, 6))
		var a: Animation = res.get_animation(res.get_animation_list()[0])
		print("ДОРОЖКИ ", [a.track_get_path(0), a.track_get_path(1)])
	quit()
