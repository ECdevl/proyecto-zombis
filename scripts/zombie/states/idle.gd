extends ZombieState


func physics_update(_delta: float) -> void:
	zombie.velocity.x = 0
	zombie.velocity.z = 0
	zombie.handle_gravity(_delta)


func enter(previous_state_path: String, data := {}) -> void:
	zombie.velocity = Vector3.ZERO
	await zombie.at.animation_finished
	finished.emit("chase")
	zombie.state_machine.can_change_state = true
	zombie.vision.can_see = true


func _on_vision_target_spotted(target: Node3D) -> void:
	print_debug("SPOTTED: ", target)


	var tween = create_tween()
	tween.tween_property(zombie.look_head, "influence", 1.0, 0.5)
	zombie.look_head.target_node = target.yaw.get_path()
	finished.emit("chase")