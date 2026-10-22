extends PlayerState
## Agarrado: quieto, pegado al ancla, mirando al zombi y sin cámara libre.

var _anchor: Node3D
var _grabber: CharacterBody3D
@export var turn_smoothing := 8.0  # más alto = gira más rápido

func enter(_previous_state_path: String, data := {}) -> void:
	_grabber = data.get("grabber")
	_anchor = data.get("anchor")
	player.can_move = false
	player.velocity = Vector3.ZERO
	player.add_collision_exception_with(_grabber)
	_grabber.add_collision_exception_with(player)


func update(delta: float) -> void:
	player._mouse_delta = Vector2.ZERO  # sigue sin cámara libre
	if not is_instance_valid(_grabber):
		return
	# Hacia dónde debe mirar: el zombi.
	var to := _grabber.global_position - player.global_position
	var target_yaw := atan2(-to.x, -to.z)
	# Cada frame recorre una fracción t de lo que falta.
	var t := 1.0 - exp(-turn_smoothing * delta)
	player.yaw.rotation.y = lerp_angle(player.yaw.rotation.y, target_yaw, t)
	player.pitch.rotation.x = lerpf(player.pitch.rotation.x, 0.0, t)
	if _grabber.state_machine.state.name == "death":
		finished.emit("idle")
func physics_update(_delta: float) -> void:
	if not is_instance_valid(_anchor) or not is_instance_valid(_grabber):
		finished.emit("idle")
		return
	player.velocity = Vector3.ZERO
	player.global_position = _anchor.global_position

func exit(_next_state_path: String) -> void:
	player.can_move = true
	if is_instance_valid(_grabber):
		player.remove_collision_exception_with(_grabber)
		_grabber.remove_collision_exception_with(player)
