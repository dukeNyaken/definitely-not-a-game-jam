class_name SkinnedActorModel
extends ActorModel
## Герой и босс из сгенерированных glb на скелете (prototype/, конвейер experiments/char3d)
## вместо процедурных фигур. Всё остальное от ActorModel: вспышка, контурный свет,
## тень, добавки свойств на сокетах, потоки жертвы.
## Варианты героя (тело + 7 вещей) — prototype/heroes.json, выбор — меню «Герой»
## (хранится в user://hero.cfg). Босс носит вещи того же варианта, посаженные по его росту.
## Вещь — сетки item_<слот>[__<часть>]; часть тела под ней — hide_<слот>, прячется, пока вещь надета.
##
## Анимации — библиотека Quaternius UAL после ретаргета, через AnimationTree:
##   берётся клип ходьбы/бега/спринта, ближайший по скорости, с темпом под неё, чтобы стопы
##   не скользили (скорость стоп каждого клипа замерена на этом теле — prototype/measure/);
##   удары и реакции — только на верхнюю половину тела, ноги продолжают шаг;
##   рывок — кувырок на весь рост, смерть — отдельное состояние.
## Что играет и какое окно клипа берётся — prototype/animation.json.

const CONFIG := "res://prototype/animation.json"
const HEROES := "res://prototype/heroes.json"
const CHOICE := "user://hero.cfg"

var _cfg: Dictionary
var _tree: AnimationTree
var _speeds: PackedFloat32Array = []      # родные скорости клипов ходьбы, по порядку locomotion
var _idle_node: AnimationNodeAnimation
var _gen_items: Dictionary = {}           # слот -> [MeshInstance3D] из glb
var _hidden_body: Dictionary = {}         # слот -> [MeshInstance3D] части тела под вещью
var _was_dashing := false
var _hit_index := 0
var _mod: LocomotionModifier
var _twist := 0.0
var _blend_pos := 0.0
var _measure_path := ""



## Модель героя: сгенерированная, если прототип собран, иначе процедурная.
## Одна точка выбора для игры и витрины меню.
static func for_hero() -> ActorModel:
	return SkinnedActorModel.new() if available() else ActorModel.new()


## Модель босса: та же логика; вещи на нём — из выбранного варианта героя.
static func for_boss() -> ActorModel:
	return SkinnedActorModel.new() if available() and ResourceLoader.exists(current()["boss"]) else ActorModel.new()


## Есть ли собранный прототип: без него игра остаётся на процедурной модели.
static func available() -> bool:
	return FileAccess.file_exists(CONFIG) and not variants().is_empty() and ResourceLoader.exists(current()["model"])


static func variants() -> Array:
	if not FileAccess.file_exists(HEROES):
		return []
	return JSON.parse_string(FileAccess.get_file_as_string(HEROES))["heroes"]


## Выбранный вариант (меню «Герой»); первый, если выбора нет или он устарел.
static func current() -> Dictionary:
	var list := variants()
	var cfg := ConfigFile.new()
	var id := ""
	if cfg.load(CHOICE) == OK:
		id = cfg.get_value("hero", "variant", "")
	for v in list:
		if v["id"] == id:
			return v
	return list[0] if list else {}


static func select(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("hero", "variant", id)
	cfg.save(CHOICE)


static func _read_config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONFIG))


func _build_body() -> void:
	_add_shadow()
	_cfg = _read_config()
	var holder := Node3D.new()
	holder.name = "Generated"
	holder.rotation_degrees.y = _cfg["facing_yaw_deg"]
	add_child(holder)
	var variant := current()
	var boss := kind == Kind.BOSS
	_measure_path = variant["boss_measure" if boss else "measure"]
	var scene: Node3D = (load(variant["boss" if boss else "model"]) as PackedScene).instantiate()
	holder.add_child(scene)
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var src := mi.get_active_material(0) as BaseMaterial3D
		mi.material_override = LowPoly.mat_textured(src.albedo_texture if src else null)
		# item_<слот>[__<часть>][_L|_R|_under], hide_<слот>[__<часть>]: часть вещи (поножи
		# доспеха, подложка под кирасой) надевается и снимается вместе со своим слотом
		if mi.name.begins_with("item_"):
			_gen_items.get_or_add(_slot_of(mi.name.trim_prefix("item_")), []).append(mi)
		elif mi.name.begins_with("hide_"):
			_hidden_body.get_or_add(_slot_of(mi.name.trim_prefix("hide_")), []).append(mi)
	for socket_name in _cfg["sockets"]:
		var s: Dictionary = _cfg["sockets"][socket_name]
		var att := BoneAttachment3D.new()
		skeleton.add_child(att)
		att.bone_name = s["bone"]
		var off: Array = s.get("offset", [0, 0, 0])
		var socket := LowPoly.pivot("Socket_%s" % socket_name, Vector3(off[0], off[1], off[2]))
		socket.rotation_degrees = Vector3(s["rot"][0], s["rot"][1], s["rot"][2])
		att.add_child(socket)
		sockets[StringName(socket_name)] = socket
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	player.add_animation_library(&"ual", load(_cfg["library"]))
	_build_tree(scene, player)
	_mod = LocomotionModifier.new()
	_mod.name = "Locomotion"
	skeleton.add_child(_mod)
	_collect_meshes()


static func _slot_of(mesh_name: String) -> StringName:
	return StringName(mesh_name.get_slice("__", 0).trim_suffix("_under").trim_suffix("_L").trim_suffix("_R"))


# --- Дерево анимаций ----------------------------------------------------------

func _anim(name: String, from: float = -1.0, to: float = -1.0, loop := Animation.LOOP_NONE) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = name
	if from >= 0.0:
		a.use_custom_timeline = true
		a.start_offset = from
		a.timeline_length = to - from
		a.stretch_time_scale = false
		a.loop_mode = loop
	return a


func _upper_filter(node: AnimationNode) -> void:
	node.filter_enabled = true
	for bone in _cfg["upper_bones"]:
		node.set_filter_path(NodePath("%%GeneralSkeleton:%s" % bone), true)


## Одиночное действие поверх входа: OneShot <- TimeScale <- клип с окном.
func _shot(bt: AnimationNodeBlendTree, prev: StringName, name: String, clip: AnimationNodeAnimation, fade: float, upper: bool, x: float) -> StringName:
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade
	shot.fadeout_time = fade * 2.0
	if upper:
		_upper_filter(shot)
	bt.add_node(name, shot, Vector2(x, 0))
	bt.add_node(name + "_clip", clip, Vector2(x - 200, 160))
	bt.add_node(name + "_ts", AnimationNodeTimeScale.new(), Vector2(x - 100, 160))
	bt.connect_node(name + "_ts", 0, name + "_clip")
	bt.connect_node(name, 0, prev)
	bt.connect_node(name, 1, name + "_ts")
	return StringName(name)


func _build_tree(scene: Node3D, player: AnimationPlayer) -> void:
	var measure: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_measure_path))
	var bt := AnimationNodeBlendTree.new()
	# Ходьба: точки смеси стоят на родных скоростях клипов — смесь сама подбирает шаг.
	var loco := AnimationNodeBlendSpace1D.new()
	loco.sync = true
	var top := 0.0
	for name in _cfg["locomotion"]:
		var v: float = measure[name]["foot_speed"]
		# скорости ходьбы растут по списку; клип медленнее предыдущего — сбой замера
		# (у босса Sprint вышел 0.95 м/с): без этой проверки он включался бы на медленном шаге
		if not _speeds.is_empty() and v <= _speeds[_speeds.size() - 1]:
			push_warning("SkinnedActorModel: %s %.2f м/с не быстрее предыдущего клипа — пропущен (%s)" % [name, v, _measure_path])
			continue
		_speeds.append(v)
		var a := _anim(name)
		if _idle_node == null:
			_idle_node = a
		loco.add_blend_point(a, v, -1, StringName(name.get_file()))
		top = maxf(top, v)
	loco.max_space = top * 1.5
	bt.add_node(&"loco", loco, Vector2(0, 0))
	bt.add_node(&"loco_ts", AnimationNodeTimeScale.new(), Vector2(150, 0))
	bt.connect_node(&"loco_ts", 0, &"loco")
	# Блок щитом: держится кусок стойки, туда-обратно, только верх.
	var b: Dictionary = _cfg["block"]
	var block := AnimationNodeBlend2.new()
	_upper_filter(block)
	bt.add_node(&"block", block, Vector2(300, 0))
	bt.add_node(&"block_clip", _anim(b["anim"], b["from"], b["to"], Animation.LOOP_PINGPONG), Vector2(150, 160))
	bt.connect_node(&"block", 0, &"loco_ts")
	bt.connect_node(&"block", 1, &"block_clip")
	# Замах врага (босса): пока копится удар, верх держит начало клипа удара —
	# позиция в окне = доля накопления (TimeSeek каждый кадр, сам клип стоит).
	var w: Dictionary = _cfg["windup"]
	var windup := AnimationNodeBlend2.new()
	_upper_filter(windup)
	bt.add_node(&"windup", windup, Vector2(400, 0))
	bt.add_node(&"windup_clip", _anim(w["anim"], w["from"], w["to"]), Vector2(250, 160))
	bt.add_node(&"windup_seek", AnimationNodeTimeSeek.new(), Vector2(325, 160))
	bt.connect_node(&"windup_seek", 0, &"windup_clip")
	bt.connect_node(&"windup", 0, &"block")
	bt.connect_node(&"windup", 1, &"windup_seek")
	var prev := &"windup"
	var x := 500.0
	for kind_name in _cfg["actions"]:
		var act: Dictionary = _cfg["actions"][kind_name]
		prev = _shot(bt, prev, "act_" + kind_name, _anim(act["anim"], act["from"], act["to"]), act["fade"], true, x)
		x += 300.0
	var hit: Dictionary = _cfg["hit"]
	for i in hit["anims"].size():
		prev = _shot(bt, prev, "hit_%d" % i, _anim(hit["anims"][i]), hit["fade"], true, x)
		x += 300.0
	var dash: Dictionary = _cfg["dash"]
	prev = _shot(bt, prev, "dash", _anim(dash["anim"], dash["from"], dash["to"]), dash["fade"], false, x)
	# Жив / мёртв: смерть — своё состояние, последний кадр держится.
	var state := AnimationNodeTransition.new()
	state.input_count = 2
	state.set_input_name(0, "alive")
	state.set_input_name(1, "dead")
	state.xfade_time = _cfg["death"]["fade"]
	bt.add_node(&"state", state, Vector2(x + 300, 0))
	bt.add_node(&"death_clip", _anim(_cfg["death"]["anim"]), Vector2(x + 150, 160))
	bt.connect_node(&"state", 0, prev)
	bt.connect_node(&"state", 1, &"death_clip")
	bt.connect_node(&"output", 0, &"state")

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	scene.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.tree_root = bt
	_tree.active = true


func _fire(name: String, scale: float) -> void:
	_tree["parameters/%s_ts/scale" % name] = scale
	_tree["parameters/%s/request" % name] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


# --- Вещи ---------------------------------------------------------------------

## Поверх ActorModel.refresh_items: у вещей, для которых есть сгенерированная сетка,
## процедурная геометрия прячется, а добавки свойств остаются на своих сокетах.
func refresh_items() -> void:
	super.refresh_items()
	for slot in _gen_items:
		for mi in _gen_items[slot]:
			mi.visible = actor.has_item(slot)
	for slot in _hidden_body:
		for mi in _hidden_body[slot]:
			mi.visible = not actor.has_item(slot)
	for id in _item_nodes:
		if not _gen_items.has(id):
			continue
		for part in _item_nodes[id]:
			for ch in (part as Node).get_children():
				if not ch.has_meta(&"prop_index"):
					(ch as Node3D).visible = false
	if _idle_node != null and _cfg.has("armed_idle"):
		_idle_node.animation = _cfg["armed_idle"] if actor.has_item(&"sword") else _cfg["locomotion"][0]


# --- Каждый кадр ----------------------------------------------------------------

func _animate(delta: float) -> void:
	var target_yaw := atan2(-actor.facing.x, -actor.facing.z)
	_yaw = lerp_angle(_yaw, target_yaw, minf(1.0, delta * 18.0))
	rotation.y = _yaw
	if _tree == null:
		return
	var vel := Combat.flat(actor.velocity)
	var speed := vel.length()
	# Один клип, ближайший по скорости, с темпом «скорость / родная скорость клипа»:
	# смесь двух клипов разного ритма укорачивает шаг (Walk+Jog на 6 м/с давали
	# скольжение 1.4 м/с). Смесь остаётся только на переходе, пока точка доезжает.
	var target_pos := 0.0
	var scale := 1.0
	if speed > _cfg["loco_min_speed"]:
		var best := 1
		for i in range(1, _speeds.size()):
			if absf(log(speed / _speeds[i])) < absf(log(speed / _speeds[best])):
				best = i
		target_pos = _speeds[best]
		scale = speed / _speeds[best] * _cfg.get("tempo_gain", 1.0)
	_blend_pos = move_toward(_blend_pos, target_pos, delta * _cfg["loco_blend_rate"])
	_tree["parameters/loco/blend_position"] = _blend_pos
	# Куда бежит относительно взгляда: до back_deg — вперёд с поворотом таза,
	# дальше — спиной вперёд (клип назад) с поворотом таза на остаток угла.
	var target_twist := 0.0
	if speed > 0.5:
		var phi := actor.facing.signed_angle_to(vel.normalized(), Vector3.UP)
		var limit := deg_to_rad(_cfg["twist"]["max_deg"])
		if absf(phi) > deg_to_rad(_cfg["twist"]["back_deg"]):
			scale = -scale
			phi = wrapf(phi + PI, -PI, PI)
		target_twist = clampf(phi, -limit, limit)
	_twist = lerp_angle(_twist, target_twist, minf(1.0, delta * _cfg["twist"]["speed"]))
	_tree["parameters/loco_ts/scale"] = scale
	if _mod != null:
		_mod.twist = 0.0 if actor.is_dashing() or actor.dead else _twist
	var blocking := actor.block_arc_degrees > 0.0
	var amount: float = _tree["parameters/block/blend_amount"]
	_tree["parameters/block/blend_amount"] = move_toward(amount, 1.0 if blocking else 0.0, delta / _cfg["block"]["fade"])
	var w: Dictionary = _cfg["windup"]
	_tree["parameters/windup/blend_amount"] = 1.0 if _windup > 0.0 else move_toward(_tree["parameters/windup/blend_amount"], 0.0, delta * 8.0)
	if _windup > 0.0:
		_tree["parameters/windup_seek/seek_request"] = w["from"] + (w["to"] - w["from"]) * _windup
	if actor.is_dashing() and not _was_dashing:
		var d: Dictionary = _cfg["dash"]
		_fire("dash", (d["to"] - d["from"]) / maxf(actor.dash_time, 0.05))
	_was_dashing = actor.is_dashing()


func play_swing(kind_name: StringName, duration: float = 0.2) -> void:
	var actions: Dictionary = _cfg["actions"]
	var key := String(kind_name) if actions.has(String(kind_name)) else "slash"
	var a: Dictionary = actions[key]
	_fire("act_" + key, (a["to"] - a["from"]) / (duration * a["stretch"]))


func _on_hit(amount: float, crit: bool, ctx: ActionContext) -> void:
	super._on_hit(amount, crit, ctx)
	if _tree != null and not actor.dead:
		_fire("hit_%d" % _hit_index, 1.0)
		_hit_index = (_hit_index + 1) % _cfg["hit"]["anims"].size()


func _on_died(_a: Actor) -> void:
	_dying = true
	if _tree != null:
		_tree["parameters/state/transition_request"] = "dead"
	var tw := create_tween()
	tw.tween_property(self, "position:y", -0.6, 0.8).set_delay(_cfg["death"]["sink_after"])
