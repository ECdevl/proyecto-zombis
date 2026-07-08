class_name IdleMovementState
extends MovementState

func _enter_state() -> void:
	if machine._can_debug:
		print_debug("Idle")

func _update_state_physics(_delta : float) -> void:
	#print_debug("Player input direction is: " + str(machine.target._input_direction))
	if machine.target._input_direction != Vector2(0,0):
		machine.change_state(machine.walk_state)
	else:
		machine.target.velocity.x = move_toward(machine.target.velocity.x, 0, machine.target.walk_speed)
		machine.target.velocity.z = move_toward(machine.target.velocity.z, 0, machine.target.walk_speed)
