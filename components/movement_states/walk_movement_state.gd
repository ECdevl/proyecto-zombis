class_name WalkMovementState
extends MovementState

var _speed : float

func _enter_state() -> void:
	_speed = machine.target.walk_speed
	if machine._can_debug:
		print_debug("Walk")

func _update_state_unhandled_input(event : InputEvent) -> void:
	if machine.has_jump() and event.is_action_pressed(machine.jump_action):
		machine.change_state(machine.jump_state)
	if machine.has_sprint() and event.is_action_pressed(machine.sprint_action):
		_speed = machine.target.sprint_speed
	if machine.has_sprint() and event.is_action_released(machine.sprint_action):
		_speed = machine.target.walk_speed


func _update_state_physics(_delta : float) -> void:
	if machine.target._direction:
		machine.target.velocity.x = machine.target._direction.x * _speed 
		machine.target.velocity.z = machine.target._direction.z * _speed 
	else:
		machine.change_state(machine.idle_state)
