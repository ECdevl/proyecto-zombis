extends Resource
class_name HealthComponent

signal death
signal hurted(values:Variant)
@export var max_health : float = 100.0
@export var current_health : float = 100.0

func hurt(damage:float,where:Node3D = null) -> void:
	current_health -= damage
	emit_signal("hurted",where)
	if current_health <= 0:
		emit_signal("death")
