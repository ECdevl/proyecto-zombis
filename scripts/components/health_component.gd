extends Resource
class_name HealthComponent

signal death(damage: float, info:Dictionary)
signal hurted(damage: float, info:Dictionary)
@export var max_health : float = 100.0
@export var current_health : float = 100.0
var _death_emitted : bool = false

func hurt(damage: float,info:Dictionary = {}) -> void:

	if _death_emitted:
		return
	current_health -= damage
	hurted.emit(damage,info)
	if current_health <= 0:
		_death_emitted = true
		death.emit(damage,info)

func heal(amount: float) -> void:
	if _death_emitted:
		return
	current_health += amount
	if current_health > max_health:
		current_health = max_health
	if current_health > 0:
		_death_emitted = false
