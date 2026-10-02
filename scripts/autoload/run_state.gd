extends Node
## Состояние забега: сид, кольцо, снимки жертв, текущий этап.

signal ring_changed
signal sacrificed(result: Dictionary)

enum Outcome { NONE, VICTORY, DEATH }

var seed_value: int = 0
var ring: Ring
## Снимки пожертвованных вещей по порядку жертв — из них собирается босс.
var snapshots: Array[ItemState] = []
## { "victim", "recipient", "property", "stage" } по порядку.
var sacrifice_log: Array[Dictionary] = []
var stage: int = 1
## Угрозы этапов 2–6 в случайном по сиду порядке.
var threat_order: Array[StringName] = []
var shrine_used: Dictionary = {}
var elapsed: float = 0.0
var running: bool = false
var outcome: int = Outcome.NONE
var seen_ring_tutorial: bool = false
var debug_immortal: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	new_run(0)
	running = false


func _process(delta: float) -> void:
	if running:
		elapsed += delta


func new_run(p_seed: int = -1) -> void:
	if p_seed < 0:
		randomize()
		p_seed = randi_range(100000, 999999)
	seed_value = p_seed
	ring = Ring.generate(seed_value, Db.ITEM_IDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	threat_order = Db.THREAT_IDS.duplicate()
	for i in range(threat_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := threat_order[i]
		threat_order[i] = threat_order[j]
		threat_order[j] = tmp
	snapshots.clear()
	sacrifice_log.clear()
	shrine_used.clear()
	stage = 1
	elapsed = 0.0
	outcome = Outcome.NONE
	running = true
	ring_changed.emit()


func is_boss_stage(s: int = -1) -> bool:
	return (stage if s < 0 else s) >= Db.balance.stage_count


func threat_for(s: int) -> ThreatDef:
	if s <= 1:
		return Db.threat(Db.TUTORIAL_THREAT)
	if s - 2 < threat_order.size():
		return Db.threat(threat_order[s - 2])
	return null


func current_threat() -> ThreatDef:
	return threat_for(stage)


func sacrifices_count() -> int:
	return snapshots.size()


func speed_multiplier() -> float:
	return 1.0 + Db.balance.sacrifice_speed_bonus * sacrifices_count()


func enemy_scale(s: int = -1) -> float:
	return pow(1.0 + Db.balance.enemy_scale_per_stage, (stage if s < 0 else s) - 1)


func sacrifice(index: int) -> Dictionary:
	var victim_id := ring.items[index].def_id
	var res := ring.sacrifice(index)
	snapshots.append(res["victim_snapshot"])
	sacrifice_log.append({
		"victim": victim_id,
		"recipient": (res["recipient"] as ItemState).def_id,
		"property": res["property"],
		"stage": stage,
	})
	ring_changed.emit()
	sacrificed.emit(res)
	return res


func swap(index: int) -> void:
	ring.swap_neighbors(index)
	shrine_used[stage] = true
	ring_changed.emit()


## Выдать свойство без жертвы (отладка): слушает событие вещи-хозяина.
func debug_give_property(host_index: int, essence_id: StringName) -> void:
	var host := ring.items[host_index]
	var source := Db.item_by_essence(essence_id)
	host.properties.append(Property.create(host.def().event_id, essence_id, source.event_id, source.id, Db.balance.property_cooldown))
	ring_changed.emit()


func last_property() -> Property:
	return sacrifice_log.back()["property"] if not sacrifice_log.is_empty() else null


## Имя артефакта: прилагательное последней поглощённой сущности + вещь.
func artifact_name() -> String:
	var holder := artifact_holder()
	if holder == null:
		return "—"
	var p := last_property()
	if p == null:
		return holder.def().display_name
	return "%s %s" % [Db.essence(p.essence_id).adjective_for(holder.def()), holder.def().display_name.to_lower()]


## Вещь, вокруг которой выросло дерево: последняя оставшаяся или последний получатель.
func artifact_holder() -> ItemState:
	if ring.size() == 1:
		return ring.items[0]
	if sacrifice_log.is_empty():
		return null
	return ring.get_item(sacrifice_log.back()["recipient"])


func time_text() -> String:
	var t := int(elapsed)
	return "%d:%02d" % [t / 60, t % 60]
