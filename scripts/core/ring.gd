class_name Ring
extends RefCounted
## Кольцо вещей. Жертва ring[i] уходит в ring[(i + 1) % n], после чего кольцо смыкается.

var items: Array[ItemState] = []


static func generate(seed_value: int, ids: Array[StringName]) -> Ring:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var order: Array[StringName] = ids.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	return Ring.from_ids(order)


static func from_ids(ids: Array[StringName]) -> Ring:
	var ring := Ring.new()
	for id in ids:
		ring.items.append(ItemState.create(id))
	return ring


func size() -> int:
	return items.size()


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in items:
		out.append(s.def_id)
	return out


func index_of(id: StringName) -> int:
	for i in items.size():
		if items[i].def_id == id:
			return i
	return -1


func get_item(id: StringName) -> ItemState:
	var i := index_of(id)
	return items[i] if i >= 0 else null


func has_item(id: StringName) -> bool:
	return index_of(id) >= 0


func recipient_index(i: int) -> int:
	return (i + 1) % items.size()


## Свойство, которое получит сосед: его событие → сущность жертвы → событие жертвы.
func property_for(i: int) -> Property:
	var victim := items[i].def()
	var recipient := items[recipient_index(i)].def()
	return Property.create(recipient.event_id, victim.essence.id, victim.event_id, victim.id, Db.balance.property_cooldown)


## Что произойдёт при жертве, без изменения кольца.
func preview(i: int) -> Dictionary:
	var victim := items[i]
	var recipient := items[recipient_index(i)]
	var after := recipient.snapshot()
	var prop := property_for(i)
	after.properties.append(prop)
	for p in victim.properties:
		after.properties.append(p.duplicate())
	return {
		"victim": victim,
		"recipient": recipient,
		"property": prop,
		"recipient_after": after,
	}


## Жертва: возвращает { victim_snapshot, recipient, property }.
func sacrifice(i: int) -> Dictionary:
	assert(items.size() > 1, "Нельзя пожертвовать последнюю вещь")
	var victim := items[i]
	var recipient := items[recipient_index(i)]
	var snap := victim.snapshot()
	var prop := property_for(i)
	recipient.properties.append(prop)
	for p in victim.properties:
		recipient.properties.append(p)
	victim.properties.clear()
	items.remove_at(i)
	return {
		"victim_snapshot": snap,
		"recipient": recipient,
		"property": prop,
	}


## Святилище: меняет местами ring[i] и его соседа по часовой.
func swap_neighbors(i: int) -> void:
	var j := recipient_index(i)
	var tmp := items[i]
	items[i] = items[j]
	items[j] = tmp
