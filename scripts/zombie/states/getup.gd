extends ZombieState


func enter(previous_state_path: String, data := {}) -> void:
	zombie.velocity = Vector3.ZERO
	await zombie.at.animation_finished
	finished.emit("chase")
	zombie.state_machine.can_change_state = true
	zombie.vision.can_see = true
