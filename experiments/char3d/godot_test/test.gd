extends Node
## Стенд персонажа: одетый герой + библиотека анимаций UAL, материалы как из импорта.
## PS1-вид (дрожь вершин, аффинные текстуры, низкое разрешение) делает сама игра
## своим шейдером и пост-обработкой — конвейер выдаёт только модель, стенд
## проверяет её форму, вещи и анимации. Вид в игре — tools/anim_check.gd игры.
##
## Tab / Shift+Tab — следующая / предыдущая анимация; 1-7 — снять/надеть вещь
## (по порядку слотов); стрелки — вращать.
## Персонаж: -- --char=<имя> (characters/<имя>.glb), без него — первый в characters/.
## Запуск с -- --check: кадры анимаций с вещами и без в shots/, сводка, выход.
##
## Персонаж и библиотека импортированы с ретаргетом (godot_import.py): скелет
## у обоих — %GeneralSkeleton со стандартными именами костей Godot, поэтому
## анимация библиотеки играет на любом персонаже как своя.

const LIBRARY := "res://anims/ual.glb"
const LIB_NAME := "ual"
# Порядок слотов — как кольцо вещей в игре; вещь — сетки item_<слот>[__<часть>][_L|_R|_under].
const SLOTS := ["sword", "shield", "armor", "helmet", "gloves", "boots", "amulet"]

var model: Node3D
var player: AnimationPlayer
var items := {}            # слот -> [MeshInstance3D]
var anims: PackedStringArray
var current := 0
var label: Label


func _ready() -> void:
	label = Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.09, 0.08, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 2.7)
	cam.fov = 45
	add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))

	model = (load(_character_path()) as PackedScene).instantiate()
	add_child(model)
	var stats := _stats(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("item_"):
			var slot: String = mi.name.trim_prefix("item_").get_slice("__", 0).trim_suffix("_under").trim_suffix("_L").trim_suffix("_R")
			items.get_or_add(slot, []).append(mi)
	player = model.find_children("*", "AnimationPlayer", true, false)[0]
	player.add_animation_library(LIB_NAME, load(LIBRARY))
	anims = player.get_animation_list()
	current = max(0, anims.find(LIB_NAME + "/Idle"))
	_play()
	print("СТЕНД: мешей %d, треугольников %d, текстуры %s" % [stats.meshes, stats.tris, stats.textures])
	print("вещи: %s; анимаций %d" % [items.keys(), anims.size()])
	if "--check" in OS.get_cmdline_user_args():
		_check.call_deferred()


## Сводка для проверки: сетки, треугольники, размеры текстур.
func _stats(root: Node) -> Dictionary:
	var stats := {"meshes": 0, "tris": 0, "textures": []}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		stats.meshes += 1
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			stats.tris += idx.size() / 3 if idx.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size() / 3
			var mat: Material = mi.get_active_material(s)
			var tex: Texture2D = mat.albedo_texture if mat is BaseMaterial3D else null
			if tex:
				stats.textures.append("%s %dx%d" % [mi.name, tex.get_width(), tex.get_height()])
	return stats


func _character_path() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--char="):
			return "res://characters/%s.glb" % a.trim_prefix("--char=")
	var files := Array(DirAccess.get_files_at("res://characters")).filter(func(f): return f.ends_with(".glb"))
	files.sort()
	return "res://characters/" + files[0]


func _play() -> void:
	player.play(anims[current])
	var worn := SLOTS.filter(func(s): return items.has(s) and items[s][0].visible)
	label.text = "%s  (%d/%d)\nнадето: %s" % [anims[current], current + 1, anims.size(), ", ".join(worn)]


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	if e.keycode == KEY_TAB:
		current = (current + (-1 if e.shift_pressed else 1) + anims.size()) % anims.size()
		_play()
	elif e.keycode >= KEY_1 and e.keycode <= KEY_7:
		equip(SLOTS[e.keycode - KEY_1], not _worn(SLOTS[e.keycode - KEY_1]))
		_play()


## Надеть/снять: вещь — сетка на общем скелете, достаточно показать или спрятать.
func equip(slot: String, on: bool) -> void:
	for mi in items.get(slot, []):
		mi.visible = on


func _worn(slot: String) -> bool:
	return items.has(slot) and items[slot][0].visible


func _process(delta: float) -> void:
	model.rotate_y(Input.get_axis("ui_left", "ui_right") * delta * 2.0)


func _check() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	# [анимация, доля длины, поворот модели]
	var shots := [["ual/Idle", 0.3, 0.0], ["ual/Walk", 0.25, -0.7], ["ual/Sword_Idle", 0.3, 0.5],
		["ual/Sword_Attack", 0.45, 0.6], ["ual/Punch_Cross", 0.4, 0.6], ["ual/Death01", 0.98, 0.3], ["Walk", 0.25, -0.7]]
	for dressed in [true, false]:
		for slot in items:
			equip(slot, dressed)
		for s in shots:
			current = anims.find(s[0])
			if current < 0:
				print("нет анимации ", s[0])
				continue
			_play()
			player.seek(player.current_animation_length * s[1], true)
			player.pause()
			model.rotation.y = s[2]
			for _f in 3:
				await RenderingServer.frame_post_draw
			var file := "res://shots/%s%s.png" % [s[0].replace("/", "_"), "" if dressed else "_naked"]
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
	print("снимки: ", DirAccess.get_files_at(ProjectSettings.globalize_path("res://shots")).size())
	get_tree().quit()
