class_name SacrificeFx
extends Node3D
## Жертва: вещь растворяется в поток своего цвета, и он по дуге влетает в получателя.

var model: ActorModel
var start: Vector3
var recipient_id: StringName
var color: Color
var _orbs: Array[Dictionary] = []
var _done: bool = false


static func play(parent: Node, p_model: ActorModel, p_start: Vector3, p_recipient: StringName, p_color: Color) -> SacrificeFx:
	var fx := SacrificeFx.new()
	fx.model = p_model
	fx.start = p_start
	fx.recipient_id = p_recipient
	fx.color = p_color
	parent.add_child(fx)
	return fx


func _ready() -> void:
	Vfx.burst(self, start, color, 1.4, 0.4)
	var mat := Vfx.material(Color(color, 1.0), 2.4, true)
	for i in 18:
		var s := SphereMesh.new()
		s.radius = 0.09 + randf() * 0.06
		s.height = s.radius * 2.0
		s.radial_segments = 6
		s.rings = 3
		var mi := MeshInstance3D.new()
		mi.mesh = s
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		mi.global_position = start
		_orbs.append({
			"node": mi,
			"t": -i * 0.045,
			"side": randf_range(-1.2, 1.2),
			"lift": randf_range(1.0, 2.2),
		})


func _target() -> Vector3:
	if model != null and is_instance_valid(model):
		return model.socket_position(recipient_id)
	return start


func _process(delta: float) -> void:
	if _done:
		return
	var target := _target()
	var alive := 0
	for orb in _orbs:
		if orb.get("done", false):
			continue
		var mi: MeshInstance3D = orb["node"]
		orb["t"] = float(orb["t"]) + delta * 1.25
		var t: float = orb["t"]
		if t < 0.0:
			alive += 1
			continue
		mi.visible = true
		if t >= 1.0:
			orb["done"] = true
			mi.queue_free()
			continue
		alive += 1
		var side_dir := Combat.flat_dir(target - start, Vector3.RIGHT).cross(Vector3.UP)
		var mid := (start + target) * 0.5 + Vector3.UP * float(orb["lift"]) + side_dir * float(orb["side"])
		var a := start.lerp(mid, t)
		var b := mid.lerp(target, t)
		mi.global_position = a.lerp(b, t)
		mi.scale = Vector3.ONE * (1.0 - t * 0.4)
	if alive == 0:
		_done = true
		Vfx.burst(self, target, color, 1.0, 0.35)
		Vfx.ring(self, Vector3(target.x, 0.0, target.z), 2.2, color, 0.5, 0.25)
		Audio.play(&"absorb")
		queue_free()
