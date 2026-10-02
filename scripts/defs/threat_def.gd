class_name ThreatDef
extends Resource
## Угроза этапа: состав волн.

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
## Три обычные волны: { "enemy_id": count }.
@export var waves: Array[Dictionary] = []
## Сопровождение элитной волны: { "enemy_id": count }.
@export var elite_escort: Dictionary = {}
## Из каких типов делать элит.
@export var elite_bases: Array[StringName] = []
@export var elite_count: int = 1
@export var floor_tint: Color = Color(0.32, 0.3, 0.28)
