extends GutTest
## При смене сцены Godot сразу отсоединяет старое меню от дерева.

class LeavingGallery extends "res://scripts/ui/cutscene_gallery.gd":
	var left := false
	var played := false

	func _ready() -> void:
		pass

	func _back() -> void:
		left = true
		get_parent().remove_child(self)

	func _play_one() -> void:
		played = true
		get_parent().remove_child(self)


func test_escape_does_not_access_gallery_viewport_after_leaving() -> void:
	var gallery := LeavingGallery.new()
	add_child_autofree(gallery)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	gallery._unhandled_input(event)
	assert_true(gallery.left)
	assert_false(gallery.is_inside_tree())


func test_enter_does_not_access_gallery_viewport_after_starting_scene() -> void:
	var gallery := LeavingGallery.new()
	add_child_autofree(gallery)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	gallery._unhandled_input(event)
	assert_true(gallery.played)
	assert_false(gallery.is_inside_tree())
