extends Resource
class_name HealthComponent

signal death(damage: float, info:Dictionary)
signal hurted(damage: float, info:Dictionary)
@export var max_health : float = 100.0
@export var current_health : float = 100.0

func hurt(damage: float,info:Dictionary = {}) -> void:

	current_health -= damage

	hurted.emit(damage,info)
	if current_health <= 0:
		death.emit(damage,info)
