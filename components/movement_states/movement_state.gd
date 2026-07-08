class_name MovementState
extends Node

var machine : MovementStateMachine

func _init(state_machine : MovementStateMachine) -> void:
	machine = state_machine

@warning_ignore("unused_parameter")
func _enter_state() -> void:
	pass

@warning_ignore("unused_parameter")
func _update_state_input(event : InputEvent) -> void:
	pass

@warning_ignore("unused_parameter")
func _update_state_unhandled_input(event : InputEvent) -> void:
	pass

@warning_ignore("unused_parameter")
func _update_state_process(delta : float) -> void:
	pass

@warning_ignore("unused_parameter")
func _update_state_physics(delta : float) -> void:
	pass

func _exit_state() -> void:
	pass
