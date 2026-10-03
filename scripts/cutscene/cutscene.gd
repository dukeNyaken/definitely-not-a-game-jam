class_name Cutscene
extends Node
## Режиссёр сюжетных сцен. Один на Game: сцены, голос из дворца между этапами и реплики в бою.
## Шаги — корутины. После пропуска любой шаг возвращается сразу (ходьба — телепортом),
## а сцена сама доводит мир до конечного состояния — поэтому пропуск в любой момент безопасен.
## Время сцен идёт по реальным часам (не замедляется хит-стопом), но ускоряется вместе с ботом.

## Игрок пропустил сцену: для шагов, которые ждут не Cutscene (сборка босса).
signal skip_requested

const HOLD_TO_SKIP := 0.7
const CHARS_PER_SEC := 38.0
const WALK_SPEED := 2.4
## «Плёнка» кадра: [тонировка, сила тонировки, виньетка, зерно, мерцание].
const MOODS := {
	&"none": [Color.WHITE, 0.0, 0.0, 0.0, 0.0],
	&"scene": [Color.WHITE, 0.0, 0.6, 0.12, 0.0],
	&"flashback": [CutsceneUi.SEPIA, 0.85, 0.7, 0.5, 0.6],
	&"palace": [Color(1.0, 0.5, 0.45), 0.32, 1.1, 0.2, 0.0],
	&"hearth": [Color(1.0, 0.74, 0.48), 0.3, 0.95, 0.16, 0.0],
	&"hurt": [Color(0.72, 0.78, 0.95), 0.5, 0.9, 0.18, 0.0],
	&"blood": [Color(1.0, 0.32, 0.3), 0.45, 1.05, 0.2, 0.0],
	&"dawn": [Color(1.0, 0.84, 0.58), 0.4, 0.45, 0.1, 0.0],
}

var game: Game
var ui: CutsceneUi
## Идёт сцена: ввод в игру заблокирован, пауза не открывается.
var active: bool = false
var skipped: bool = false
## Актёры, живущие дольше одной сцены (у ворот и в финале): ключ -> Puppet.
var cast: Dictionary = {}
## Реквизит сцены в мире (упавший меч, перстень в полёте) — убирается clear_props().
var props: Array[Node3D] = []
var _advance: bool = false
var _hold: float = 0.0
var _last_us: int = 0
## Реальное время кадра с учётом ускорения бота.
var _dt: float = 0.0
var _was_running: bool = false
var _hero_mult: float = 1.0
var _barks: Array[Array] = []
var _barking: bool = false


## В просмотре из меню «Катсцены» сцены идут всегда — что бы ни стояло в настройке.
static func enabled() -> bool:
	return Theater.requested() or (Render.cutscenes and not RunState.skip_cutscenes)


func setup(p_game: Game) -> void:
	game = p_game
	name = "Cutscene"
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = CutsceneUi.new()
	ui.name = "CutsceneUi"
	add_child(ui)


# --- Начало и конец ---------------------------------------------------------

func begin(bars: bool = true) -> void:
	active = true
	skipped = false
	_advance = false
	_hold = 0.0
	_was_running = RunState.running
	RunState.running = false
	game.lock_input(true)
	game.controller.set_physics_process(false)
	var h := game.hero
	h.move_input = Vector3.ZERO
	h.release(&"block")
	h.immortal = true
	h.invuln_time = 1e6
	_hero_mult = h.speed_mult
	_set_marker(false)
	game.hero_model.rest_pose = &"ease"
	game.hud.set_cinematic(true)
	if bars:
		ui.bars(true)
	mood(&"scene", 0.8)


func end(release_camera: bool = true) -> void:
	ui.hide_line()
	ui.hide_center()
	ui.hide_chapter()
	ui.clear_tags()
	ui.bars(false)
	ui.skip_progress(0.0)
	ui.grade(Color.WHITE, 0.0, 0.0, 0.0, 0.0, 0.6)
	if Engine.time_scale < 1.0 and game.state != Game.State.OVER:
		Engine.time_scale = 1.0
	game.hud.set_cinematic(false)
	if release_camera:
		game.rig.cine_release(0.9)
	var h := game.hero
	h.move_input = Vector3.ZERO
	h.immortal = RunState.debug_immortal
	h.invuln_time = 0.0
	h.speed_mult = _hero_mult
	game.hero_model.rest_pose = &""
	_set_marker(true)
	game.controller.set_physics_process(true)
	game.lock_input(false)
	if game.state != Game.State.OVER:
		RunState.running = _was_running
	active = false


func _set_marker(on: bool) -> void:
	for ch in game.hero.get_children():
		if ch is HeroMarker:
			(ch as HeroMarker).set_cinematic(not on)


func skip() -> void:
	if skipped or not active:
		return
	skipped = true
	_advance = true
	ui.hide_line(0.1)
	ui.hide_center(0.1)
	ui.hide_chapter(0.1)
	Audio.play(&"ui_click", -6.0)
	skip_requested.emit()


# --- Ввод и время -----------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not active:
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if event.is_action(&"debug") or event.is_action(&"render"):
		return
	if event.is_pressed() and not event.is_echo():
		var key := event is InputEventKey and ((event as InputEventKey).physical_keycode in [KEY_ENTER, KEY_KP_ENTER])
		if key or event.is_action(&"attack") or event.is_action(&"dash") or event.is_action(&"interact"):
			_advance = true
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := 0.0 if _last_us == 0 else minf((now - _last_us) / 1e6, 0.1)
	_last_us = now
	_dt = real * maxf(Engine.time_scale, 1.0)
	if not active:
		return
	var holding := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ESCAPE)
	_hold = _hold + real if holding and not skipped else 0.0
	ui.skip_progress(_hold / HOLD_TO_SKIP)
	if _hold >= HOLD_TO_SKIP:
		skip()


func wait(sec: float) -> void:
	var t := 0.0
	while not skipped and t < sec:
		await get_tree().process_frame
		t += _dt


## Ждёт, пока текст напечатается и его прочтут (или игрок нажмёт «дальше»).
func _read(text: String, extra: float = 1.0) -> void:
	_advance = false
	var type_time := maxf(text.length() / CHARS_PER_SEC, 0.2)
	var t := 0.0
	while not skipped and t < type_time and not _advance:
		ui.set_typed(t / type_time)
		await get_tree().process_frame
		t += _dt
	ui.set_typed(1.0)
	_advance = false
	var hold := clampf(1.2 + text.length() * 0.035, 2.0, 5.5) * extra
	t = 0.0
	while not skipped and t < hold and not _advance:
		await get_tree().process_frame
		t += _dt
	_advance = false


# --- Текст ------------------------------------------------------------------

func say(who: StringName, text: String) -> void:
	if skipped or text == "":
		return
	var sp := Story.speaker(who)
	ui.show_line(sp["name"], sp["color"], text)
	await _read(text)
	ui.hide_line()


## Мысль Солдата: без имени, золотым наклонным.
func thought(text: String) -> void:
	if skipped or text == "":
		return
	ui.show_line("", UiKit.GOLD, text, true)
	await _read(text)
	ui.hide_line()


## Летопись по центру кадра.
func narrate(text: String) -> void:
	if skipped:
		return
	ui.show_center("", text)
	await _read(text, 1.2)
	ui.hide_center()
	await wait(0.5)


## Заставка главы. Крупная ждёт, пока её прочтут; компактная (small) идёт поверх сцены и не ждёт.
func chapter(title: String, subtitle: String, small: bool = false, hold: float = 2.2) -> void:
	if skipped or title == "":
		return
	ui.chapter(title, subtitle, small, hold)
	if not small:
		await wait(hold + 1.4)


## Реплика в бою: не останавливает игру, реплики идут по очереди.
func bark(who: StringName, text: String, duration: float = 3.0) -> void:
	_barks.append([who, text, duration])
	if not _barking:
		_bark_loop()


func clear_barks() -> void:
	_barks.clear()
	ui.hide_bark()


func _bark_loop() -> void:
	_barking = true
	while not _barks.is_empty():
		var b: Array = _barks.pop_front()
		var who: StringName = b[0]
		var sp := Story.speaker(who)
		ui.show_bark("" if who == &"thought" else sp["name"], sp["color"], b[1], who == &"thought")
		var t := 0.0
		while t < float(b[2]):
			await get_tree().process_frame
			t += _dt
		ui.hide_bark()
		await get_tree().create_timer(0.35, true, false, true).timeout
	_barking = false


# --- Камера, кадр и свет ---------------------------------------------------

func cam(pos: Vector3, zoom: float, dur: float = 1.2) -> void:
	game.rig.cine_to(pos, zoom, 0.0 if skipped else dur)


## Облёт: камера поворачивается вокруг фокуса на degrees от обычного угла.
func orbit(degrees: float, dur: float = 4.0) -> void:
	game.rig.cine_yaw(degrees, 0.0 if skipped else dur)


func shake(amount: float) -> void:
	if not skipped:
		game.rig.shake(amount)


## Вспышка во весь кадр.
func flash(color: Color = Color.WHITE, dur: float = 0.5, strength: float = 0.85) -> void:
	if not skipped:
		ui.flash(color, dur, strength)


## Настроение кадра (см. MOODS): тонировка, виньетка, зерно, мерцание.
func mood(key: StringName, dur: float = 1.0) -> void:
	var m: Array = MOODS.get(key, MOODS[&"scene"])
	ui.grade(m[0], m[1], m[2], m[3], m[4], 0.0 if skipped else dur)


## Замедление времени на dur секунд реального времени: удар, превращение, распад.
func slowmo(scale: float, dur: float) -> void:
	if skipped:
		return
	Engine.time_scale = scale
	await wait(dur)
	if Engine.time_scale == scale:
		Engine.time_scale = 1.0


## Свет сцены: остаётся до clear_props(). flicker > 0 — живой огонь.
func light(pos: Vector3, color: Color, energy: float = 1.5, range_m: float = 5.0, flicker: float = 0.0) -> OmniLight3D:
	var l := CutsceneFx.light(game.world, pos, color, energy, range_m, flicker)
	props.append(l)
	return l


## Пылинки, угли или искры в воздухе — до clear_props().
func motes(center: Vector3, extents: Vector3, color: Color, amount: int = 40, rise: float = 0.15) -> CPUParticles3D:
	var p := CutsceneFx.motes(game.world, center, extents, color, amount, rise)
	props.append(p)
	return p


func spawn(who: StringName, pos: Vector3, look: Vector3, key: StringName = &"", variant: StringName = &"") -> Puppet:
	var p := Puppet.make(Story.kind_of(who), variant)
	p.name = "Puppet_%s" % (key if key != &"" else who)
	game.world.add_child(p)
	p.global_position = Vector3(pos.x, 0.0, pos.z)
	p.look_toward(look)
	cast[key if key != &"" else who] = p
	return p


## Табличка над головой: имя и роль говорящего (или свои title/subtitle). Видна duration секунд.
func tag(a: Node3D, who: StringName, duration: float = 4.5, title: String = "", subtitle: String = "") -> void:
	if skipped or a == null or not is_instance_valid(a):
		return
	var sp := Story.speaker(who)
	var h := 2.35
	if a is Puppet:
		h *= (a as Puppet).model.scale.y
	ui.tag(a, title if title != "" else sp["name"], subtitle if subtitle != "" else str(sp.get("role", "")), sp["color"], h, duration)


## Актёр из прошлой сцены, если он ещё жив.
func actor(key: StringName) -> Puppet:
	var p: Puppet = cast.get(key)
	return p if p != null and is_instance_valid(p) else null


## Идёт к точке своим шагом и смотрит по ходу. Если сцену пропустили — сразу оказывается там.
func walk(a: Actor, to: Vector3, speed: float = WALK_SPEED) -> void:
	if a == null or not is_instance_valid(a):
		return
	to.y = 0.0
	if skipped:
		_place(a, to)
		return
	if not a.has_meta(&"cs_speed"):
		a.set_meta(&"cs_speed", [a.base_speed, a.speed_mult])
	a.base_speed = speed
	a.speed_mult = 1.0
	var id := int(a.get_meta(&"cs_walk", 0)) + 1
	a.set_meta(&"cs_walk", id)
	# Страховка: если путь чем-то перекрыт, через удвоенное время шага актёр просто оказывается на месте.
	var limit := Combat.flat(to - a.global_position).length() / maxf(speed, 0.1) * 2.0 + 2.0
	var t := 0.0
	while is_instance_valid(a) and not skipped and int(a.get_meta(&"cs_walk", 0)) == id:
		var d := Combat.flat(to - a.global_position)
		if d.length() < 0.06:
			break
		if t > limit:
			a.global_position = to
			break
		a.move_input = d.normalized() * clampf(d.length() / 0.5, 0.3, 1.0)
		a.aim_point = to + d.normalized()
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	if not is_instance_valid(a) or int(a.get_meta(&"cs_walk", 0)) != id:
		return
	a.move_input = Vector3.ZERO
	if skipped:
		a.global_position = to
	var saved: Array = a.get_meta(&"cs_speed")
	a.base_speed = saved[0]
	a.speed_mult = saved[1]
	a.remove_meta(&"cs_speed")


func _place(a: Actor, to: Vector3) -> void:
	a.set_meta(&"cs_walk", int(a.get_meta(&"cs_walk", 0)) + 1)
	a.move_input = Vector3.ZERO
	a.global_position = to
	if a.has_meta(&"cs_speed"):
		var saved: Array = a.get_meta(&"cs_speed")
		a.base_speed = saved[0]
		a.speed_mult = saved[1]
		a.remove_meta(&"cs_speed")


## Дойти и повернуться к точке — для тех, кто расходится по местам параллельно со сценой.
func walk_then_face(a: Actor, to: Vector3, look: Vector3, speed: float = WALK_SPEED) -> void:
	await walk(a, to, speed)
	face(a, look)


func face(a: Actor, point: Vector3) -> void:
	if a == null or not is_instance_valid(a):
		return
	a.aim_point = point
	var d := Combat.flat(point - a.global_position)
	if d.length_squared() > 0.0001:
		a.facing = d.normalized()


## Реквизит в мире: будет убран clear_props().
func prop(node: Node3D) -> Node3D:
	if node.get_parent() == null:
		game.world.add_child(node)
	props.append(node)
	return node


func clear_props() -> void:
	for n in props:
		if is_instance_valid(n):
			n.queue_free()
	props.clear()


## Предмет выпадает из рук на землю и остаётся лежать.
func drop(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var xf := node.global_transform
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	game.world.add_child(node)
	node.global_transform = xf
	props.append(node)
	var target := Vector3(xf.origin.x, 0.06, xf.origin.z)
	var tw := node.create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(node, "global_position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "rotation", Vector3(PI / 2, node.rotation.y, 0.0), 0.35)


## Предмет летит по дуге из точки в точку (вещь из рук в руки).
func fly(node: Node3D, from: Vector3, to: Vector3, dur: float = 0.8, lift: float = 1.4, trail: Color = Color.TRANSPARENT) -> void:
	if not is_instance_valid(node):
		return
	node.global_position = from
	if skipped:
		node.global_position = to
		return
	var tr: CPUParticles3D = null
	if trail.a > 0.0:
		tr = CutsceneFx.trail(node, trail)
	var mid := (from + to) * 0.5 + Vector3(0, lift, 0)
	var t := 0.0
	while t < dur and is_instance_valid(node):
		var k := t / dur
		k = k * k * (3.0 - 2.0 * k)
		node.global_position = from.lerp(mid, k).lerp(mid.lerp(to, k), k)
		node.rotation.y += _dt * 4.0
		await get_tree().process_frame
		t += _dt
		if skipped:
			break
	if is_instance_valid(node):
		node.global_position = to
	if tr != null and is_instance_valid(tr):
		tr.emitting = false
		CutsceneFx._free_after(tr, 0.7)


## Предмет летит в руку (сокет модели) и остаётся в ней. Реквизит — уберётся clear_props().
func fly_to_hand(node: Node3D, from: Vector3, socket: Node3D, dur: float = 0.7, lift: float = 0.4, trail: Color = Color.TRANSPARENT) -> void:
	if not props.has(node):
		prop(node)
	await fly(node, from, socket.global_position, dur, lift, trail)
	if not is_instance_valid(node) or not is_instance_valid(socket):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	socket.add_child(node)
	node.position = Vector3.ZERO


## Через sec секунд вызвать f, если сцену не пропустили, — действие посреди реплики. Не ждать.
func after(sec: float, f: Callable) -> void:
	await wait(sec)
	if not skipped and active and f.is_valid():
		f.call()
