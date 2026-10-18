extends Resource
class_name HealthComponent

signal death(who: Node3D, damage: float, attacker: Node3D, hit_pos: Vector3)
signal hurted(who: Node3D, damage: float, attacker: Node3D, hit_pos: Vector3)
@export var max_health : float = 100.0
@export var current_health : float = 100.0

func hurt(damage: float, who: Node3D = null, attacker: Node3D = null, hit_pos := Vector3.INF) -> void:

	current_health -= damage

	hurted.emit(who, damage, attacker, hit_pos)
	if current_health <= 0:
		death.emit(who, damage, attacker, hit_pos)
