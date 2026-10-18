extends ZombieState

var target : Variant

@export var forget_time : float = 3.0

func enter(previous_state_path: String, data := {}) -> void:
	zombie.playback.travel("walk")
	target = zombie.vision.target
	
func physics_update(_delta: float) -> void:
	zombie.handle_gravity(_delta)
	if zombie.playback.get_current_node() in ["awake_up","awake_down"] or zombie.ragdoll_component.is_ragdoll:
		zombie.velocity = Vector3.ZERO
		return
	else:
		zombie.playback.travel("walk")
	if target is Node3D:
		zombie.nav.target_position = target.global_position
	elif target is Vector3:
		zombie.nav.target_position = target
	else:
		finished.emit("idle")
		return
	zombie.nav.get_next_path_position()
	zombie.direction = zombie.global_position.direction_to(zombie.nav.get_next_path_position())
	var target_rot : float = atan2(-zombie.direction.x,-zombie.direction.z)
	zombie.rotation.y = rotate_toward(zombie.rotation.y, target_rot, deg_to_rad(720) * _delta)
	
	if zombie.direction != Vector3.ZERO:
		zombie.velocity.x = zombie.direction.x * zombie.speed
		zombie.velocity.z = zombie.direction.z * zombie.speed
	else:
		zombie.velocity.x = 0
		zombie.velocity.z = 0
	zombie.move_and_slide()

func exit(next_state_path:String) -> void:
	zombie.velocity = Vector3.ZERO
	var tween = create_tween()
	tween.tween_property(zombie.look_head,"influence",0.0,.5)

func _on_vision_target_lost(lost: Vector3) -> void:
	print_debug("target lost")
	await get_tree().create_timer(forget_time).timeout
	print_debug("finaly lost him")
	target = target.global_position
	

	
	



func _on_nav_target_reached() -> void:
	finished.emit("idle")
