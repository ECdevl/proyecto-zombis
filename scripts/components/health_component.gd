extends Resource
class_name HealthComponent

signal death
signal hurted
@export var max_health : float = 100.0
@export var current_health : float = 100.0

func hurt(damage:float) -> void:
	current_health -= damage
	emit_signal("hurted")
	if current_health <= 0:
		emit_signal("death")
