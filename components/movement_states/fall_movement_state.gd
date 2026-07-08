class_name FallMovementState
extends MovementState

func _enter_state() -> void:
	if machine._can_debug:
		print_debug("Fall")

func _update_state_physics(delta : float) -> void:
	if not machine.target.is_on_floor():
		machine.target.velocity += machine.target.get_gravity() * delta
	else:
		machine.change_state(machine.walk_state)
