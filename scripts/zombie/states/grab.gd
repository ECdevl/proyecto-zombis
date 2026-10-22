extends ZombieState

@export var grab_anchor: Marker3D
var player: Player

func enter(_previous_state_path: String, _data := {}) -> void:
	_land_grab()


# Llamar en el frame en que la animación toca al jugador:
func _land_grab() -> void:

	player = zombie.vision.target
	player.playback.start("grabbed_start",true)
	zombie.playback.start("grab_start",true)
	player.grab_escaped.connect(_on_escaped, CONNECT_ONE_SHOT)
	player.get_grabbed(zombie, grab_anchor)

	
@export var loop_length := 1.8333  # la duración del paso 1
var _t := 0.0

func physics_update(delta: float) -> void:
	_t += delta
	if _t >= loop_length:
		_t -= loop_length
		zombie.playback.start("grab")
		player.playback.start("grabbed")
func _on_escaped() -> void:
	zombie.push(zombie.global_position - player.global_position)  # dispara su stagger

func exit(_next_state_path: String) -> void:
	if player:
		if player.grab_escaped.is_connected(_on_escaped):
			player.grab_escaped.disconnect(_on_escaped)
		player.end_grab()  # quien agarra, suelta
