class_name ItemState
extends Resource
## Вещь в текущем забеге: определение плюс накопленное дерево свойств.

@export var def_id: StringName
@export var properties: Array[Property] = []


static func create(id: StringName) -> ItemState:
	var s := ItemState.new()
	s.def_id = id
	return s


func def() -> ItemDef:
	return Db.item(def_id)


## Снимок для босса: глубокая копия с собственными свойствами.
func snapshot() -> ItemState:
	var s := ItemState.create(def_id)
	for p in properties:
		s.properties.append(p.duplicate())
	return s


func property_names() -> PackedStringArray:
	var names := PackedStringArray()
	for p in properties:
		names.append(p.display_name())
	return names
