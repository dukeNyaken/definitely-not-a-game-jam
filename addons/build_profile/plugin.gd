@tool
extends EditorPlugin

var _exporter: EditorExportPlugin


func _enter_tree() -> void:
	_exporter = preload("res://addons/build_profile/export_plugin.gd").new()
	add_export_plugin(_exporter)


func _exit_tree() -> void:
	remove_export_plugin(_exporter)
	_exporter = null
