class_name EnemyDef
extends Resource
## Тип рядового врага.

enum Behavior { MELEE, RANGED, SWARM, BRUTE, CASTER, SLIME, JESTER }

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

@export_group("Slime")
## Ядовитый след: урон за тик, радиус лужи, время жизни, шаг между лужами.
@export var trail_damage: float = 0.0
@export var trail_tick: float = 0.5
@export var trail_radius: float = 0.6
@export var trail_lifetime: float = 5.0
@export var trail_spacing: float = 0.7
## При смерти распадается на split_count врагов split_into.
@export var split_into: StringName = &""
@export var split_count: int = 0
## Кости внутри куба (у большого слизня — кости и ядро; 0 — только череп).
@export var slime_bones: int = 3

@export_group("Jester")
## Выпад и серия ударов ножами, затем сальто назад.
@export var lunge_distance: float = 0.0
@export var combo_hits: int = 1
@export var combo_gap: float = 0.16
@export var retreat_distance: float = 0.0
## Уворот от замаха героя.
@export var dodge_chance: float = 0.0
@export var dodge_distance: float = 2.5
@export var dodge_cooldown: float = 2.0
@export var orbit_distance: float = 0.0
