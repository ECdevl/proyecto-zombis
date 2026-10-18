extends ZombieState

func enter(previous_state_path: String, data := {}) -> void:

	var random_idle : int = randi_range(0,1)
	if random_idle == 1:
		zombie.playback.travel("idle1")
	else:
		zombie.playback.travel("idle2")

func physics_update(_delta: float) -> void:
	zombie.velocity.x = 0
	zombie.velocity.z = 0
	zombie.handle_gravity(_delta)
	zombie.move_and_slide()

func _on_vision_target_spotted(target: Node3D) -> void:
	print_debug("IVE SPOTTED: ",target)
	

	var tween = create_tween()
	tween.tween_property(zombie.look_head,"influence",1.0,.5)
	zombie.look_head.target_node = target.yaw.get_path()
	finished.emit("chase")
	
