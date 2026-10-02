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


static func enabled() -> bool:
	return Render.cutscenes and not RunState.skip_cutscenes


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
	game.hud.set_cinematic(true)
	if bars:
		ui.bars(true)


func end(release_camera: bool = true) -> void:
	ui.hide_line()
	ui.hide_center()
	ui.clear_tags()
	ui.bars(false)
	ui.skip_progress(0.0)
	game.hud.set_cinematic(false)
	if release_camera:
		game.rig.cine_release(0.9)
	var h := game.hero
	h.move_input = Vector3.ZERO
	h.immortal = RunState.debug_immortal
	h.invuln_time = 0.0
	h.speed_mult = _hero_mult
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


## Голос из дворца между этапами: тёмно-багровый экран и реплика Сигварда. Можно пропустить.
func interlude(text: String) -> void:
	var standalone := not active
	if standalone:
		active = true
		skipped = false
	var crimson := Color(0.07, 0.0, 0.015)
	ui.black(1.0, 0.4, crimson)
	await wait(0.4)
	ui.show_center(Story.interlude_header(), text, Color(0.86, 0.76, 0.95), Story.speaker(&"brother")["color"])
	await _read(text)
	ui.hide_center(0.4)
	await wait(0.4)
	ui.black(0.0, 0.4, crimson)
	if standalone:
		active = false
		skipped = false


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


# --- Камера и актёры --------------------------------------------------------

func cam(pos: Vector3, zoom: float, dur: float = 1.2) -> void:
	game.rig.cine_to(pos, zoom, 0.0 if skipped else dur)


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
func fly(node: Node3D, from: Vector3, to: Vector3, dur: float = 0.8, lift: float = 1.4) -> void:
	if not is_instance_valid(node):
		return
	node.global_position = from
	if skipped:
		node.global_position = to
		return
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
