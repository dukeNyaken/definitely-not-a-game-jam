class_name EssenceDef
extends Resource
## Сущность вещи: то, что перетекает в соседа при жертве.

@export var id: StringName
@export var display_name: String = ""
## Прилагательное для имени свойства и артефакта (м. р.): «Режущий».
@export var adjective: String = ""
## Форма для вещей во множественном числе: «Режущие перчатки».
@export var adjective_plural: String = ""
## Визуальная добавка на вещи-получателе: шипы, кромка, ...
@export var addon_name: String = ""
@export var color: Color = Color.WHITE
@export_multiline var effect_text: String = ""
## Скрипт эффекта, наследник EssenceEffect.
@export var effect_script: Script
## Все числа эффекта.
@export var stats: Dictionary = {}


func stat(key: String, fallback: Variant = 0.0) -> Variant:
	return stats.get(key, fallback)


func adjective_for(item: ItemDef) -> String:
	return adjective_plural if item.plural else adjective
