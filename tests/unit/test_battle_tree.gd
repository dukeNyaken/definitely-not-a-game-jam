extends GutTest
## Связи из настоящих жертв, точные боевые параметры и выбор поглощённой вещи.

var _ring: Ring
var _xp: Dictionary
var _choices: Dictionary
var _memory: bool


func before_each() -> void:
	_ring = RunState.ring
	_xp = Mastery.xp.duplicate()
	_choices = Mastery.choices.duplicate()
	_memory = Mastery.memory_only
	Mastery.memory_only = true
	Mastery.xp = {&"sword": 1000, &"boots": 1000, &"amulet": 1000}
	Mastery.choices.clear()


func after_each() -> void:
	RunState.ring = _ring
	Mastery.xp = _xp
	Mastery.choices = _choices
	Mastery.memory_only = _memory


func values(metrics: Array[Dictionary]) -> Dictionary:
	var result := {}
	for entry in metrics:
		result[entry["label"]] = entry["value"]
	return result


func test_chain_follows_emitted_events_instead_of_property_storage_order() -> void:
	var ring := Ring.from_ids([&"shield", &"boots", &"sword"])
	ring.sacrifice(0)
	ring.sacrifice(0)
	var sword := ring.get_item(&"sword")
	sword.properties.reverse()
	var nodes := PropertyDiagram.tree_nodes(sword)
	assert_eq(nodes.size(), 3)
	assert_eq((nodes[1]["property"] as Property).source_item_id, &"boots")
	assert_eq(nodes[1]["parent"], 0, "Удар запускает рывок")
	assert_eq((nodes[2]["property"] as Property).source_item_id, &"shield")
	assert_eq(nodes[2]["parent"], 1, "Рывок запускает оплот")
	assert_true(nodes[2]["linked"])


func test_branches_do_not_turn_into_one_long_chain() -> void:
	var ring := Ring.from_ids([&"shield", &"boots", &"sword", &"armor", &"helmet", &"gloves", &"amulet"])
	for id in [&"shield", &"boots", &"helmet", &"armor", &"sword", &"amulet"]:
		ring.sacrifice(ring.index_of(id))
	var nodes := PropertyDiagram.tree_nodes(ring.items[0])
	assert_eq(nodes.size(), 7)
	var parents := {}
	for i in range(1, nodes.size()):
		var prop: Property = nodes[i]["property"]
		var parent := int(nodes[i]["parent"])
		parents[prop.source_item_id] = &"gloves" if parent == 0 else (nodes[parent]["property"] as Property).source_item_id
	assert_eq(parents, {&"helmet": &"gloves", &"armor": &"gloves", &"sword": &"gloves", &"amulet": &"gloves", &"boots": &"sword", &"shield": &"boots"})


func test_detached_debug_property_has_no_false_link_to_native_skill() -> void:
	var sword := ItemState.create(&"sword")
	sword.properties.append(Property.create(&"grab", &"gust", &"dash", &"boots", 0.4))
	sword.properties.append(Property.create(&"dash", &"bulwark", &"block", &"shield", 0.4))
	var nodes := PropertyDiagram.tree_nodes(sword)
	assert_eq(nodes[1]["parent"], -1)
	assert_eq(nodes[2]["parent"], 1)
	assert_false(nodes[1]["linked"])
	assert_false(nodes[2]["linked"])


func test_selecting_sacrificed_chip_opens_its_effect_on_surviving_host() -> void:
	RunState.ring = Ring.from_ids([&"shield", &"boots", &"sword"])
	RunState.ring.sacrifice(0)
	RunState.ring.sacrifice(0)
	var panel := TreeUi.new()
	add_child_autofree(panel)
	panel._chips[&"shield"].pressed.emit()
	assert_eq(panel._host.def_id, &"sword")
	var diagram := panel._diagram
	assert_eq((diagram.nodes[diagram.selected_node]["property"] as Property).source_item_id, &"shield")
	assert_eq(diagram.selected_path(), [2, 1, 0] as Array[int])
	assert_true(panel._chips[&"shield"].tooltip_text.contains("больше не получает XP"))
	panel._chips[&"sword"].pressed.emit()
	assert_eq(diagram.selected_node, 0)


func test_metrics_use_worn_appearance_and_property_damage_bonus() -> void:
	var sword := ItemState.create(&"sword")
	sword.appearance = 3
	sword.properties.append(Property.create(&"hit", &"gust", &"dash", &"boots", 0.4))
	var info := values(BattleSkillInfo.native(sword))
	assert_eq(info["Комбо · урон"], "11/11/22")
	assert_eq(info["Финальный удар"], "360°")
	assert_eq(info["Дальность финала"], "3,2 м")
	sword.appearance = 1
	info = values(BattleSkillInfo.native(sword))
	assert_eq(info["Финальный удар"], "120°", "уровень профиля не подменяет надетый облик")
	var amulet := ItemState.create(&"amulet")
	amulet.appearance = 3
	info = values(BattleSkillInfo.native(amulet))
	assert_eq(info["Отброс"], "3 м")
	assert_eq(info["Оглушение"], "0,6 с")


func test_sacrificed_appearance_does_not_upgrade_inherited_essence() -> void:
	var ring := Ring.from_ids([&"amulet", &"boots"])
	ring.items[0].appearance = 3
	ring.sacrifice(0)
	var boots := ring.items[0]
	var info := values(BattleSkillInfo.effect(boots.properties[0], boots))
	assert_eq(info["Урон"], "16,5", "исходные 15 урона энергии × бонус носителя")
	assert_eq(info["Дальность"], "12 м")
	assert_false(info.has("Оглушение"), "особый эффект облика жертвы не передаётся")
	boots.appearance = 3
	assert_eq(values(BattleSkillInfo.native(boots))["Рывок"], "5 м")
	var gust := Property.create(&"hit", &"gust", &"dash", &"boots", 0.4)
	assert_eq(values(BattleSkillInfo.effect(gust, boots))["Рывок к курсору"], "4 м")
