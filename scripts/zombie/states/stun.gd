extends ZombieState

@export var min_stun_time : float = 3.0
@export var max_stun_time : float = 7.0
func enter(previous_state_path: String, data := {}) -> void:
	var is_ragdoll : bool = false

	zombie.look_head.influence = 0.0
	if data:
		if data.get("ragdoll"):
			is_ragdoll = data.get("ragdoll")

	
	if not is_ragdoll:
		can_transition = false
		var stun_dir : int = data.get("direction")
		if stun_dir:
			zombie.zombie_mesh.scale.x = 1
		else:
			zombie.zombie_mesh.scale.x = -1
		zombie.playback.start("stun")
		await get_tree().create_timer(randf_range(min_stun_time,max_stun_time)).timeout
		can_transition = true
		
		finished.emit("recover",{"animation":"stun_recover"})
	else:
		zombie.at["parameters/TimeScale/scale"] = 0.0
		can_transition = true

func physics_update(_delta: float) -> void:
	zombie.velocity.x = 0
	zombie.velocity.z = 0
	zombie.handle_gravity(_delta)
	zombie.move_and_slide()

func exit(next_state_path:String) -> void:
	zombie.at["parameters/TimeScale/scale"] = 1.0
	zombie.zombie_mesh.scale.x = 1


func _on_ragdoll_component_recovered(face_up: bool) -> void:
	finished.emit("recover",{"animation": "awake_up" if face_up else "awake_down"})
	


func _on_ragdoll_component_animation_face(face_up: bool) -> void:
	zombie.playback.start("awake_up" if face_up else "awake_down")
