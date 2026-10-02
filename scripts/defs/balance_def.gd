class_name BalanceDef
extends Resource
## Общие числа забега.

@export_group("Hero")
@export var hero_hp: float = 100.0
@export var hero_speed: float = 6.0
@export var fist_damage: float = 5.0
@export var fist_range: float = 1.7
@export var fist_arc_degrees: float = 100.0
@export var fist_cooldown: float = 0.35

@export_group("Ring")
@export var item_count: int = 7
@export var sacrifice_speed_bonus: float = 0.06
@export var property_damage_bonus: float = 0.10
@export var property_cooldown: float = 0.4
@export var max_chain_depth: int = 12
## Крит по открытой цели, если шлема уже нет (Взор всё ещё открывает врагов).
@export var crit_multiplier: float = 2.0

@export_group("Stages")
@export var stage_count: int = 7
@export var waves_per_stage: int = 3
@export var wave_pause: float = 2.0
@export var wave_timeout: float = 45.0
@export var enemy_scale_per_stage: float = 0.12
@export var wave_count_growth: float = 0.12
@export var elite_hp_multiplier: float = 2.5
@export var elite_item_count_max: int = 2
@export var shrine_stages: PackedInt32Array = PackedInt32Array([3, 5])
@export var shrine_wait: float = 15.0
@export var arena_radius: float = 15.0
@export var max_alive_enemies: int = 26

@export_group("Boss")
@export var boss_hp: float = 1500.0
@export var boss_phase_thresholds: PackedFloat32Array = PackedFloat32Array([0.6, 0.25])
@export var boss_phase_speeds: PackedFloat32Array = PackedFloat32Array([2.6, 4.0, 5.6])
@export var boss_phase_item_counts: PackedInt32Array = PackedInt32Array([6, 3, 1])
@export var boss_armor_restore_on_phase: bool = true
@export var ai_reaction: float = 0.5
@export var ai_shield_chance: float = 0.5
@export var ai_shield_hold: float = 0.9
## После опускания щита ИИ какое-то время не поднимает его снова.
@export var ai_shield_cooldown: float = 2.2
## Урон вещей героя в руках элит и босса (вещи рассчитаны на врагов с 30 HP).
@export var enemy_item_damage_mult: float = 0.5
## Пауза ИИ между действиями вещей: элиты и фазы босса 1–3.
@export var elite_action_gap: float = 1.1
@export var boss_action_gaps: PackedFloat32Array = PackedFloat32Array([0.9, 0.6, 0.35])
## Пауза после завершающего удара комбо меча.
@export var ai_sword_combo_pause: float = 1.3
