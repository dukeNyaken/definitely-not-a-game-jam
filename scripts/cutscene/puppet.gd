class_name Puppet
extends Actor
## Актёр сюжетных сцен: та же модель и походка, что у персонажей, но вне боя —
## не в группе actors (его не видят Combat, ИИ, полоски здоровья и бот), без столкновений,
## неуязвим и может стоять за краем арены (в проёме ворот).

var kind: int = ActorModel.Kind.HERO
var variant: StringName = &""
## Процедурная модель даже там, где есть сгенерированная (тесты механики поз ActorModel).
var procedural := false
var model: ActorModel
var _fade_tween: Tween


static func make(p_kind: int, p_variant: StringName = &"") -> Puppet:
	var p := Puppet.new()
	p.kind = p_kind
	p.variant = p_variant
	p.faction = Actor.Faction.HERO
	p.base_speed = 2.4
	p.immortal = true
	p.collision_layer = 0
	p.collision_mask = 0
	return p


func _ready() -> void:
	super()
	remove_from_group(&"actors")
	model = ActorModel.new() if procedural else SkinnedActorModel.for_puppet(kind, variant)
	model.name = "Model"
	model.variant = variant
	add_child(model)
	model.setup(self, kind)
	model.scale = Vector3.ONE * NpcLooks.scale_for(kind, variant)


## Не прижимается к краю арены: актёры выходят из ворот и уходят в темноту.
func _clamp_to_arena() -> void:
	global_position.y = 0.0


func look_toward(point: Vector3) -> void:
	aim_point = point
	var d := Combat.flat(point - global_position)
	if d.length_squared() > 0.0001:
		facing = d.normalized()


func set_pose(p: StringName) -> void:
	model.pose = p


func gesture(kind_name: StringName, duration: float = 0.4) -> void:
	model.play_swing(kind_name, duration)


## Вещь или реквизит в руке.
func hold(node: Node3D, hand: StringName = &"r_hand", scale_k: float = 0.75) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	model.sockets[hand].add_child(node)
	node.position = Vector3.ZERO
	node.scale = Vector3.ONE * scale_k


## Рука, которой актёр протягивает вещь в позе offer: у сгенерированных моделей это левая.
func offer_hand() -> StringName:
	return model.pose_hand(&"offer")


func hand_position(hand: StringName = &"r_hand") -> Vector3:
	var s: Node3D = model.sockets.get(hand)
	return s.global_position if s != null else global_position + Vector3(0, 1, 0)


## Проявление и растворение дизерингом ретро-шейдера (параметр fade).
func fade(to: float, duration: float) -> void:
	var mats: Array[ShaderMaterial] = []
	_unique_materials(model, mats)
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if duration <= 0.0:
		for m in mats:
			m.set_shader_parameter(&"fade", to)
		visible = to > 0.01
		return
	visible = true
	_fade_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	for m in mats:
		# У непрозрачного материала параметр не задан (Nil) — твину нужно число на старте.
		var from: Variant = m.get_shader_parameter(&"fade")
		m.set_shader_parameter(&"fade", 1.0 if from == null else float(from))
		_fade_tween.tween_property(m, "shader_parameter/fade", to, duration)
	if to <= 0.01:
		_fade_tween.chain().tween_callback(func(): visible = false)


func _unique_materials(n: Node, out: Array[ShaderMaterial]) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			if mi.material_override is ShaderMaterial:
				if not mi.has_meta(&"puppet_unique"):
					var m := LowPoly.unique(mi.material_override as ShaderMaterial)
					# Контурный свет уже наложен; помечаем, чтобы ActorModel не заменил копию.
					m.set_meta(&"rim_variant", true)
					mi.material_override = m
					mi.set_meta(&"puppet_unique", true)
				out.append(mi.material_override as ShaderMaterial)
		_unique_materials(ch, out)
