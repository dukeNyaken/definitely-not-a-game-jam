class_name RuneSpinner
extends Node3D
## Медленно вращающиеся руны Энергии.

var speed: float = 1.6


func _process(delta: float) -> void:
	rotation.y += speed * delta
