class_name SprintMovementState
extends MovementState

func _enter_state() -> void:
	if machine._can_debug:
		print_debug("Sprint")

func _update_state_unhandled_input(event : InputEvent) -> void:
	if machine.has_sprint() and event.is_action_released(machine.sprint_action):
		machine.change_state(machine.walk_state)
