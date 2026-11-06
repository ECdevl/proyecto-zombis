extends PlayerState


func enter(previous_state_path: String, data := {}) -> void:
	player.velocity.y = player.jump_velocity
	player.body_at_playback.travel("jump")
func update(_delta: float) -> void:
	player._camera_movement()
func physics_update(_delta: float) -> void:
	if player.is_on_floor():
		# Anular solo la vertical: conservar la horizontal para que el salto
		# en carrera aterrice con inercia y derrape (el suelo la frena igual).
		player.velocity.y = 0.0
		finished.emit("idle")
	
