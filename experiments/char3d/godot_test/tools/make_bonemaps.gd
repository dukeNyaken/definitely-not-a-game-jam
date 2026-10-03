extends SceneTree
## BoneMap-ресурсы для ретаргета из data/bonemaps.json (одно место для таблиц).
##   godot --headless --path godot_test --script res://tools/make_bonemaps.gd

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../data/bonemaps.json")))
	for rig in ["mixamo", "ual"]:
		var bm := BoneMap.new()
		bm.profile = SkeletonProfileHumanoid.new()
		var n := 0
		for profile_name in data[rig]:
			bm.set_skeleton_bone_name(profile_name, data[rig][profile_name])
			n += 1
		var path := "res://retarget/bonemap_%s.tres" % rig
		ResourceSaver.save(bm, path)
		print("%s: %d костей -> %s" % [rig, n, path])
	quit()
