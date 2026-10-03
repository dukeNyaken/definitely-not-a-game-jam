extends Node3D
## Тестовая сцена эффектов: удары, крит, Взор, аура элиты — для сравнения «было/стало».

var hero: Actor
var dummies: Array[Actor] = []
var elite: Actor
var _t: float = 0.0
var _done: Dictionary = {}


func _ready() -> void:
	var arena := Arena.new()
	add_child(arena)
	arena.build(15.0)
	hero = Actor.new()
	add_child(hero)
	hero.global_position = Vector3(1.2, 0, 1.2)
	hero.set_items([ItemState.create(&"sword"), ItemState.create(&"helmet")] as Array[ItemState])
	var hm := ActorModel.new()
	hero.add_child(hm)
	hm.setup(hero, ActorModel.Kind.HERO)
	hero.add_child(HeroMarker.new())
	Combat.hero = hero
	for p in [Vector3(-1.2, 0, -0.4), Vector3(-0.2, 0, -1.4), Vector3(-1.9, 0, -1.9)]:
		var d := EnemyFactory.create(Db.enemy(&"infantry"), 1)
		(d.get_node("AI") as AIController).active = false
		add_child(d)
		d.global_position = p
		d.max_hp = 9999.0
		d.hp = 9999.0
		d.facing = Combat.flat_dir(hero.global_position - p)
		dummies.append(d)
	elite = EnemyFactory.create(Db.enemy(&"infantry"), 1, [ItemState.create(&"shield"), ItemState.create(&"helmet")] as Array[ItemState])
	(elite.get_node("AI") as AIController).active = false
	add_child(elite)
	elite.global_position = Vector3(1.6, 0, -2.2)
	elite.facing = Combat.flat_dir(hero.global_position - elite.global_position)
	hero.aim_point = dummies[0].global_position
	var rig := CameraRig.new()
	rig.size = 7.5
	add_child(rig)
	rig.global_position = Vector3(-0.3, 0, -0.5)
	rig.cinematic = true


func _once(key: String, at: float) -> bool:
	if _t >= at and not _done.has(key):
		_done[key] = true
		return true
	return false


func _process(delta: float) -> void:
	_t += delta
	var ctx := ActionContext.make(hero, null)
	if _once("gaze", 1.1):
		var e := Db.essence(&"gaze")
		var g := ActionContext.make(hero, ItemState.create(&"helmet"))
		g.from_property = true
		Db.effect(&"gaze").apply(e, g)
	if _once("hit1", 1.3):
		dummies[1].open_time = 0.0
		Combat.deal(ctx, dummies[1], 10.0)
	if _once("block", 1.33):
		elite.block_arc_degrees = 140.0
		Combat.deal(ctx, elite, 10.0)
	if _once("crit", 1.36):
		dummies[0].open_for_crit(1.0)
		Combat.deal(ctx, dummies[0], 10.0)
	if _once("kill", 2.0):
		elite.block_arc_degrees = 0.0
		Combat.deal(ctx, elite, 99999.0)
