extends ZombieState

@export var min_stun_time : float = 3.0
@export var max_stun_time : float = 7.0

func enter(previous_state_path: String, data := {}) -> void:

	zombie.look_head.influence = 0.0
	if data:
		if data.get("ragdoll"):
			return
	can_transition = false
	
	var stun_dir : int = data.get("direction")
	if stun_dir:
		zombie.zombie_mesh.scale.x = 1
	else:
		zombie.zombie_mesh.scale.x = -1
	zombie.playback.start("stun")
	await get_tree().create_timer(randf_range(min_stun_time,max_stun_time)).timeout
	
	
	zombie.playback.travel("stun_recover")
	await zombie.at.animation_finished
	can_transition = true
	
	finished.emit("chase")
	

func exit(next_state_path:String) -> void:
	zombie.zombie_mesh.scale.x = 1
	
