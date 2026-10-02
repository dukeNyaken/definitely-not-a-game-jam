class_name TestHelpers
extends RefCounted
## Общие заготовки для тестов: герой, манекены врагов.


static func hero(test: GutTest, states: Array[ItemState]) -> Actor:
	var a := Actor.new()
	a.faction = Actor.Faction.HERO
	a.max_hp = 100.0
	a.hp = 100.0
	test.add_child_autofree(a)
	a.global_position = Vector3.ZERO
	a.facing = Vector3.FORWARD
	a.aim_point = Vector3(0, 0, -5)
	a.set_items(states)
	return a


static func dummy(test: GutTest, pos: Vector3, hp: float = 1000.0) -> Actor:
	var d := Actor.new()
	d.faction = Actor.Faction.ENEMY
	d.max_hp = hp
	d.hp = hp
	test.add_child_autofree(d)
	d.global_position = pos
	return d


static func clear_projectiles(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(&"projectiles"):
		n.free()
