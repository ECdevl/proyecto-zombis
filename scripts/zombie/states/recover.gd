extends ZombieState


func enter(previous_state_path: String, data := {}) -> void:
	can_transition = false
	zombie.at["parameters/grabbing/blend_amount"] = 0
	if previous_state_path == "stun":
		zombie.playback.start("stun_recover")
	else:
		zombie.playback.start(data.get("animation"))
	await zombie.at.animation_finished
	can_transition = true
	finished.emit("chase")
