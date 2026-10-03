extends SceneTree
## Референсы для prologue_npcs.py: процедурный наряд сюжетного персонажа спереди и сзади,
## без света, в A-позе, без реквизита в руках, на сером фоне 768x1024.
##   godot --path <игра> --script <этот файл> -- <выходная папка> <id=Kind> ...
## Пример: ... -- references/prologue friend=FRIEND smith=SMITH

## Реквизит, который остаётся отдельным предметом на сокете, а не частью тела.
const PROPS := ["Staff", "Lantern", "Bundle", "CaptainShield", "Baby", "Katana", "Crossbow", "Cleaver", "Knife"]


var _started := false


## Классы игры зависят от автозагрузок: они грузятся только после старта, как в tools/shot.gd.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		run()
	return false


func run() -> void:
	var puppet: GDScript = load("res://scripts/cutscene/puppet.gd")
	var kinds: Dictionary = (load("res://scripts/visual/actor_model.gd") as GDScript).get_script_constant_map()["Kind"]
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var vp := SubViewport.new()
	vp.size = Vector2i(768, 1024)
	vp.own_world_3d = true
	vp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(184, 184, 184)
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.6
	vp.add_child(cam)
	for pair in args.slice(1):
		var id: String = pair.split("=")[0]
		var p: Node3D = puppet.make(kinds[pair.split("=")[1]])
		vp.add_child(p)
		await process_frame
		var m: Node3D = p.model
		m.set_process(false)
		for prop in PROPS:
			for n in m.find_children(prop, "", true, false):
				n.visible = false
		# Чистый цвет наряда: текстуры поверхностей ретро-шейдера темнят референс
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var sm := (mi as MeshInstance3D).get_active_material(0) as ShaderMaterial
			if sm != null and sm.get_shader_parameter(&"albedo_color") != null:
				var flat := StandardMaterial3D.new()
				flat.albedo_color = sm.get_shader_parameter(&"albedo_color")
				(mi as MeshInstance3D).material_override = flat
		for arm in [m.arm_l, m.arm_r]:
			arm.basis = Basis(Vector3.BACK, signf(arm.position.x) * deg_to_rad(40.0))
		# Высота центра кадра — середина роста с поправкой масштаба наряда.
		var mid := 1.0 * m.scale.y
		for side in [["front", -1.0], ["back", 1.0]]:
			cam.position = Vector3(0, mid, side[1] * 6.0)
			cam.look_at(Vector3(0, mid, 0))
			await process_frame
			await process_frame
			var path: String = out.path_join("%s_%s.png" % [id, side[0]])
			vp.get_texture().get_image().save_png(path)
			print("REF ", path)
		p.free()
	print("NPC_REFS_DONE")
	quit()
