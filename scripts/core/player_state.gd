class_name PlayerState extends State

@export var blocked_action : Array[StringName] = []

func is_action_allowed(action: StringName) -> bool:
	if action in blocked_action:
		return false
	else:
		return true
		
	


var player : Player

func _ready() -> void:
	player = owner
