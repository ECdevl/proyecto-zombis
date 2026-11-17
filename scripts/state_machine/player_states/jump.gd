extends PlayerState

func enter(previous_state_path: String, data := {}) -> void:
	player.velocity.y = player.sprint_jump_velocity if previous_state_path == "run" else player.jump_velocity
	player.body_at_playback.travel("jump")
func update(_delta: float) -> void:
	player._camera_movement()
func physics_update(_delta: float) -> void:
	if player.is_on_floor():
		player.velocity.y = 0.0
		var horizontal : Vector2 = Vector2(player.velocity.x, player.velocity.z)
		if horizontal.length() <= 0.0001:
			finished.emit("idle")
		return
	if player.velocity.y <= 0.0:
		finished.emit("fall")

