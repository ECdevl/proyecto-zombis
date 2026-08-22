class_name State extends Node

@export var can_transition : bool = true



signal finished(next_state_path: String, data: Dictionary)## Emitted when the state finishes and wants to transition to another state.
var player : Player

func _ready() -> void:
	player = owner

func handle_input(_event: InputEvent) -> void:## Called by the state machine when receiving unhandled input events.
	pass


func update(_delta: float) -> void:## Called by the state machine on the engine's main loop tick.
	pass


func physics_update(_delta: float) -> void:## Called by the state machine on the engine's physics update tick.
	pass



func enter(previous_state_path: String, data := {}) -> void:## Called by the state machine upon changing the active state. The `data` parameter is a dictionary with arbitrary data the state can use to initialize itself.
	pass


 
func exit(next_state_path:String) -> void:## Called by the state machine before changing the active state. Use this function to clean up the state.
	pass
