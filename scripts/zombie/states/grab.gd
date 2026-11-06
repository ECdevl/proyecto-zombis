extends ZombieState

@export var grab_anchor: Marker3D
var player: Player

func enter(previous_state_path: String, _data := {}) -> void:
	_land_grab()


# Call on the frame when the animation touches the player:
func _land_grab() -> void:
	player = zombie.vision.target
	player.playback.start("grabbed_start", true)
	zombie.playback.start("grab_start", true)
	player.grab_escaped.connect(_on_escaped, CONNECT_ONE_SHOT)
	player.get_grabbed(zombie, grab_anchor)


func _on_escaped() -> void:
	zombie.push(zombie.global_position - player.global_position)  # triggers stagger


func exit(_next_state_path: String) -> void:
	if player:
		if player.grab_escaped.is_connected(_on_escaped):
			player.grab_escaped.disconnect(_on_escaped)
		player.end_grab()  # the grabber releases
