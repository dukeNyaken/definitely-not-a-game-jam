@tool
extends EditorExportPlugin
## Идентификатор создаётся один раз при экспорте, без изменения исходников проекта.


func _get_name() -> String:
	return "BuildProfile"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	add_file("res://build_profile.id", id.to_utf8_buffer(), false)
