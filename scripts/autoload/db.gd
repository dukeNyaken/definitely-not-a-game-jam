extends Node
## Все определения игры из .tres.

const ITEM_IDS: Array[StringName] = [&"sword", &"shield", &"armor", &"helmet", &"gloves", &"boots", &"amulet"]
const ENEMY_IDS: Array[StringName] = [&"infantry", &"archer", &"swarm", &"brute", &"caster"]
const THREAT_IDS: Array[StringName] = [&"arrows", &"swarm", &"armor", &"magic", &"onslaught"]
const TUTORIAL_THREAT: StringName = &"tutorial"

var balance: BalanceDef
var items: Dictionary = {}
var essences: Dictionary = {}
var enemies: Dictionary = {}
var threats: Dictionary = {}
var _by_event: Dictionary = {}
var _by_essence: Dictionary = {}
var _effects: Dictionary = {}


func _init() -> void:
	balance = load("res://data/balance.tres")
	for id in ITEM_IDS:
		var def: ItemDef = load("res://data/items/%s.tres" % id)
		items[id] = def
		essences[def.essence.id] = def.essence
		_by_event[def.event_id] = def
		_by_essence[def.essence.id] = def
		var effect: EssenceEffect = def.essence.effect_script.new()
		_effects[def.essence.id] = effect
	for id in ENEMY_IDS:
		enemies[id] = load("res://data/enemies/%s.tres" % id)
	for id in THREAT_IDS:
		threats[id] = load("res://data/threats/%s.tres" % id)
	threats[TUTORIAL_THREAT] = load("res://data/threats/%s.tres" % TUTORIAL_THREAT)


func item(id: StringName) -> ItemDef:
	return items[id]


func essence(id: StringName) -> EssenceDef:
	return essences[id]


func item_by_event(event_id: StringName) -> ItemDef:
	return _by_event[event_id]


func item_by_essence(essence_id: StringName) -> ItemDef:
	return _by_essence[essence_id]


func effect(essence_id: StringName) -> EssenceEffect:
	return _effects[essence_id]


func enemy(id: StringName) -> EnemyDef:
	return enemies[id]


func threat(id: StringName) -> ThreatDef:
	return threats[id]


func event_word(event_id: StringName) -> String:
	return item_by_event(event_id).event_word
