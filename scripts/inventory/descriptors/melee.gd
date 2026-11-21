class_name Melee extends EquippableDescriptor

const MAX_SWINGS: int = 2

@export var swings: Array[SwingData]
@export var hitbox_radius: float = 0.15


@export var melee_swing : AudioStreamRandomizer = preload("uid://duac6iayflpfe")
@export var melee_hit : AudioStreamRandomizer

func _init() -> void:
	damage = 25.0
	weapon_range = 1.0
	fire_rate = 0.4
	behaviour = MeleeBehaviour.new()
