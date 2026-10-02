class_name EnemyDef
extends Resource
## Тип рядового врага.

enum Behavior { MELEE, RANGED, SWARM, BRUTE, CASTER }

@export var id: StringName
@export var display_name: String = ""
@export var behavior: Behavior = Behavior.MELEE
@export var hp: float = 30.0
@export var damage: float = 10.0
@export var speed: float = 3.5
@export var body_radius: float = 0.45
@export var attack_range: float = 1.6
@export var attack_arc_degrees: float = 90.0
@export var windup: float = 0.6
@export var recovery: float = 0.5
@export var attack_cooldown: float = 1.2
## Дистанция, которую держит враг (лучник, заклинатель).
@export var preferred_distance: float = 0.0
@export var knockback_immune: bool = false
@export var aoe_radius: float = 0.0
@export var projectile_speed: float = 0.0
@export var zone_delay: float = 1.0
@export var color: Color = Color(0.6, 0.6, 0.6)
@export var scale: float = 1.0
