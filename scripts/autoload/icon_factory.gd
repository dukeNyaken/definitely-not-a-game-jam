extends Node
## Иконки — модели выбранного героя с надетыми обликами; кэш обновляется при смене выбора.

signal icons_ready

const SIZE := 80
const FRAMING := {
	&"sword": [1.9, Vector3(0, 0, -0.75)],
	&"shield": [1.35, Vector3(0.1, PI + 0.35, 0)],
	&"armor": [1.55, Vector3(0.2, PI - 0.5, 0)],
	&"helmet": [0.95, Vector3(0.15, PI - 0.7, 0)],
	&"gloves": [0.95, Vector3(0.35, PI, 0)],
	&"boots": [1.05, Vector3(0.2, PI - 0.6, 0)],
	&"amulet": [0.62, Vector3(0.4, PI, 0)],
}

var icons: Dictionary = {}
var ready_done: bool = false
var _requested_key := ""
var _rendering := false


func _ready() -> void:
	Mastery.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if DisplayServer.get_name() == "headless":
		ready_done = true
		return
	var key := str(SkinnedActorModel.current().get("id", "procedural"))
	for id in Db.ITEM_IDS:
		key += ":%d" % Mastery.selected(id)
	if key == _requested_key:
		return
	_requested_key = key
	if not _rendering:
		_rendering = true
		_render_all.call_deferred()


func icon(id: StringName) -> Texture2D:
	return icons.get(id)


func _render_all() -> void:
	var rendered_key := _requested_key
	var rendered_icons := {}
	var viewports := {}
	for id in Db.ITEM_IDS:
		var vp := SubViewport.new()
		vp.size = Vector2i(SIZE, SIZE)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.6, 0.6, 0.7)
		e.ambient_light_energy = 0.8
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.environment = e
		vp.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, 35, 0)
		light.light_energy = 1.4
		vp.add_child(light)
		var item := ItemVisuals.build_display(Mastery.make_item(id))
		var generated := item.has_meta(&"hero_variant")
		var frame: Array = FRAMING[id]
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = GeneratedItemDisplay.preview_size(id) if generated else frame[0]
		vp.add_child(cam)
		cam.position = Vector3(0, 0, 4)
		cam.current = true
		item.rotation = Vector3.ZERO if generated else frame[1]
		if generated and id == &"shield":
			# На руке щит стоит боком; иконка должна показывать лицевую сторону.
			item.rotation.y = PI / 2
		var pivot := Node3D.new()
		pivot.rotation = Vector3(deg_to_rad(15), deg_to_rad(-25), 0)
		pivot.add_child(item)
		vp.add_child(pivot)
		viewports[id] = vp
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for id in viewports:
		var vp: SubViewport = viewports[id]
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			rendered_icons[id] = ImageTexture.create_from_image(img)
		vp.queue_free()
	if rendered_key != _requested_key:
		_render_all.call_deferred()
		return
	icons = rendered_icons
	_rendering = false
	ready_done = true
	icons_ready.emit()
