extends Node3D
## Галерея моделей для проверки визуала: герой в разной экипировке, враги, босс.


func _ready() -> void:
	var arena := Arena.new()
	add_child(arena)
	arena.build(15.0)
	var rs = get_node("/root/RunState")
	var row := [
		[ActorModel.Kind.HERO, Db.ITEM_IDS, Vector3(-4.5, 0, 0)],
		[ActorModel.Kind.HERO, [&"sword", &"boots"], Vector3(-3.0, 0, 0)],
		[ActorModel.Kind.HERO, [], Vector3(-1.5, 0, 0)],
	]
	for r in row:
		var a := Actor.new()
		add_child(a)
		a.global_position = r[2]
		var states: Array[ItemState] = []
		for id in r[1]:
			states.append(ItemState.create(id))
		a.set_items(states)
		a.set_process(false)
		a.set_physics_process(false)
		var m := ActorModel.new()
		a.add_child(m)
		m.setup(a, r[0])
		a.facing = Vector3(0.4, 0, 1).normalized()
	# Вещь с добавками всех сущностей.
	var decorated := ItemState.create(&"sword")
	for e in [&"gust", &"bulwark", &"mass"]:
		decorated.properties.append(Property.create(&"hit", e, &"dash", &"boots", 0.4))
	var hero2 := Actor.new()
	add_child(hero2)
	hero2.global_position = Vector3(0, 0, 0)
	var boots := ItemState.create(&"boots")
	boots.properties.append(Property.create(&"dash", &"gust", &"dash", &"boots", 0.4))
	boots.properties.append(Property.create(&"dash", &"energy", &"dash", &"boots", 0.4))
	var shield := ItemState.create(&"shield")
	for e in [&"blade", &"gaze", &"grip"]:
		shield.properties.append(Property.create(&"block", e, &"dash", &"boots", 0.4))
	hero2.set_items([decorated, boots, shield] as Array[ItemState])
	hero2.set_physics_process(false)
	var m2 := ActorModel.new()
	hero2.add_child(m2)
	m2.setup(hero2, ActorModel.Kind.HERO)
	hero2.facing = Vector3(0.4, 0, 1).normalized()
	var x := 1.8
	for id in Db.ENEMY_IDS:
		var def := Db.enemy(id)
		var e := EnemyFactory.create(def, 1)
		e.get_node("AI").set_physics_process(false)
		add_child(e)
		e.global_position = Vector3(x, 0, 0)
		e.facing = Vector3(-0.3, 0, 1).normalized()
		x += 1.3 * def.scale + 0.4
	var elite := EnemyFactory.create(Db.enemy(&"infantry"), 1, [ItemState.create(&"shield"), ItemState.create(&"helmet")] as Array[ItemState])
	elite.get_node("AI").set_physics_process(false)
	add_child(elite)
	elite.global_position = Vector3(x + 0.5, 0, 0)
	elite.facing = Vector3(-0.3, 0, 1).normalized()
	var boss := Actor.new()
	add_child(boss)
	boss.global_position = Vector3(x + 3.2, 0, 1.2)
	var boss_items: Array[ItemState] = []
	for id in [&"sword", &"shield", &"helmet", &"armor"]:
		boss_items.append(ItemState.create(id))
	boss.set_items(boss_items)
	boss.set_physics_process(false)
	var bm := ActorModel.new()
	boss.add_child(bm)
	bm.setup(boss, ActorModel.Kind.BOSS)
	bm.scale = Vector3.ONE * 1.7
	boss.facing = Vector3(-0.3, 0, 1).normalized()
	# Люди сюжетных сцен (второй ряд) — и Сигвард юный, из флешбэка.
	var npcs := [
		[ActorModel.Kind.FRIEND, &""], [ActorModel.Kind.BELOVED, &""], [ActorModel.Kind.FAITHFUL, &""],
		[ActorModel.Kind.REFUGEE, &""], [ActorModel.Kind.CAPTAIN, &""], [ActorModel.Kind.WIDOW, &""],
		[ActorModel.Kind.SMITH, &""], [ActorModel.Kind.NOVICE, &""], [ActorModel.Kind.TYRANT, &""],
		[ActorModel.Kind.TYRANT, &"young"], [ActorModel.Kind.FATHER, &""],
	]
	for i in npcs.size():
		var p := Puppet.make(npcs[i][0], npcs[i][1])
		add_child(p)
		p.global_position = Vector3(-2.0 + i * 1.2, 0, 3.4)
		p.look_toward(p.global_position + Vector3(0.4, 0, 1))
		p.set_physics_process(false)
	var rig := CameraRig.new()
	rig.size = 10.5
	var focus := Vector3(4.0, 0, 0.5)
	# cam=размер,x,z из аргументов командной строки.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cam="):
			var v := a.substr(4).split(",")
			rig.size = float(v[0])
			focus = Vector3(float(v[1]), 0, float(v[2]))
	add_child(rig)
	rig.global_position = focus
	set_process(false)
