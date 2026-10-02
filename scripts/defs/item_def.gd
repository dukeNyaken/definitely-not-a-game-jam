class_name ItemDef
extends Resource
## Одна из семи вещей героя.

@export var id: StringName
@export var display_name: String = ""
## Перчатки, Сапоги — множественное число (для согласования прилагательного).
@export var plural: bool = false
## Действие ввода: attack / block / dash / grab / volley. Пусто — пассив.
@export var input_action: StringName = &""
@export var input_label: String = ""
## Событие вещи и его слово в имени свойства: «удар», «блок», ...
@export var event_id: StringName
@export var event_word: String = ""
@export var essence: EssenceDef
@export_multiline var action_text: String = ""
## Скрипт компонента-действия, наследник ActionComponent.
@export var component_script: Script
@export var color: Color = Color.WHITE
## Все числа действия.
@export var stats: Dictionary = {}


func stat(key: String, fallback: Variant = 0.0) -> Variant:
	return stats.get(key, fallback)


func is_passive() -> bool:
	return input_action == &""


func event_label() -> String:
	return event_word.capitalize()
