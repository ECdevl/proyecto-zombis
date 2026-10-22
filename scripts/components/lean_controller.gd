extends PlayerComponent

var player : Player

@export var lean_amount : float = 2.0
@export var lean_degrees: float = 25.0

func _ready() -> void:
	player = owner

func _input(event: InputEvent) -> void:
	if enabled == false:
		return
	if event.is_action_released("lean_left") or event.is_action_released("lean_right"):
		var tween = create_tween().set_parallel(true)
		tween.tween_property(player.pitch,"rotation_degrees:z",0.0,.15)
		tween.tween_property(player.pitch,"position:x",0,.15)
	elif event.is_action_pressed("lean_left"):
		var tween = create_tween().set_parallel(true)
		tween.tween_property(player.pitch,"rotation_degrees:z",lean_degrees,.15)
		tween.tween_property(player.pitch,"position:x",-lean_amount,.15)
	elif event.is_action_pressed("lean_right"):
		var tween = create_tween().set_parallel(true)
		tween.tween_property(player.pitch,"rotation_degrees:z",-lean_degrees,.15)
		tween.tween_property(player.pitch,"position:x",lean_amount,.15)
