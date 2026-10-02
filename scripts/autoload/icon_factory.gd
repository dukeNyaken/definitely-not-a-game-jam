extends Node
## Иконки вещей — снимки их же 3D-моделей. Рендерятся один раз при старте.

signal icons_ready

const SIZE := 80
const FRAMING := {
	&"sword": [2.5, Vector3(0, 0, -0.75)],
	&"shield": [1.35, Vector3(0.1, PI + 0.35, 0)],
	&"armor": [1.55, Vector3(0.2, PI - 0.5, 0)],
	&"helmet": [0.95, Vector3(0.15, PI - 0.7, 0)],
	&"gloves": [0.95, Vector3(0.35, PI, 0)],
	&"boots": [1.05, Vector3(0.2, PI - 0.6, 0)],
	&"amulet": [0.62, Vector3(0.4, PI, 0)],
}

var icons: Dictionary = {}
var ready_done: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		ready_done = true
		return
	_render_all.call_deferred()


func icon(id: StringName) -> Texture2D:
	return icons.get(id)


func _render_all() -> void:
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
		var frame: Array = FRAMING[id]
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = frame[0]
		vp.add_child(cam)
		cam.position = Vector3(0, 0, 4)
		cam.current = true
		var item := ItemVisuals.build_display(ItemState.create(id))
		var rot: Vector3 = frame[1]
		item.rotation = rot
		var pivot := Node3D.new()
		pivot.rotation = Vector3(deg_to_rad(15), deg_to_rad(-25), 0)
		pivot.add_child(item)
		vp.add_child(pivot)
		icons[id] = vp.get_texture()
		viewports[id] = vp
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for id in viewports:
		var vp: SubViewport = viewports[id]
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			icons[id] = ImageTexture.create_from_image(img)
		vp.queue_free()
	ready_done = true
	icons_ready.emit()
