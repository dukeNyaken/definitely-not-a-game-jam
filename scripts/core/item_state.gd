class_name ItemState
extends Resource
## Вещь в текущем забеге: определение плюс накопленное дерево свойств.

@export var def_id: StringName
@export var appearance: int = 1
var _variant: ItemDef
var _variant_level: int = 0
@export var properties: Array[Property] = []


static func create(id: StringName) -> ItemState:
	var s := ItemState.new()
	s.def_id = id
	return s


func def() -> ItemDef:
	if appearance <= 1:
		return Db.item(def_id)
	if _variant == null or _variant_level != appearance:
		_variant = Db.item(def_id).duplicate()
		_variant.stats = _variant.stats.duplicate()
		var form := Mastery.form(def_id, appearance)
		_variant.stats.merge(form["stats"], true)
		_variant.action_text += " · " + str(form["effect"])
		_variant_level = appearance
	return _variant


## Снимок для босса: глубокая копия с собственными свойствами.
func snapshot() -> ItemState:
	var s := ItemState.create(def_id)
	s.appearance = appearance
	for p in properties:
		s.properties.append(p.duplicate())
	return s


func property_names() -> PackedStringArray:
	var names := PackedStringArray()
	for p in properties:
		names.append(p.display_name())
	return names
