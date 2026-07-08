extends Node

var _movement_state_machine : MovementStateMachine

func initialize(player : Player):
	if player.can_debug:
		print_debug("Initializing movement controller...")
	_movement_state_machine = MovementStateMachine.new()
	_movement_state_machine.set_crouch_action(player.crouch)
	_movement_state_machine.set_jump_action(player.jump)
	_movement_state_machine.set_sprint_action(player.sprint)
	add_child(_movement_state_machine)
	_movement_state_machine.initialize_state_machine(
		player, 
		_movement_state_machine.idle_state, 
		player.can_debug
	)
	if player.can_debug:
		print_debug("Movement controller initialized!")
