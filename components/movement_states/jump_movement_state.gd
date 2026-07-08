class_name JumpMovementState
extends MovementState

func _enter_state() -> void:
	machine.target.velocity.y = machine.target.jump_velocity
	if machine._can_debug:
		print_debug("Jump")

func _update_state_physics(_delta : float) -> void:
	if not machine.target.is_on_floor():
		machine.change_state(machine.fall_state)
	else:
		machine.change_state(machine.walk_state)
