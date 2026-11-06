extends ZombieState


func enter(previous_state_path: String, data := {}) -> void:
	can_transition = false
	zombie.playback.start(data.get("animation"))
	await zombie.at.animation_finished
	can_transition = true
	finished.emit("chase")


func physics_update(_delta: float) -> void:
	zombie.velocity.x = 0
	zombie.velocity.z = 0
	zombie.handle_gravity(_delta)
	zombie.move_and_slide()
