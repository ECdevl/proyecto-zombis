extends PlayerState
@onready var stand_shape: ShapeCast3D = %StandShape



func enter(previous_state_path: String, data := {}) -> void:
	player.speed = player.crouch_speed
	player.body_at_playback.travel("crouch")
	player.tween_cam_height(player.CAM_HEIGHT_CROUCH)
	player.collision_crouched.disabled = false
	player.collision_standing.disabled = true
	player.collision_prone.disabled = true
	
func update(_delta: float) -> void:
	player._camera_movement()
func physics_update(_delta: float) -> void:
	if Input.is_action_just_released(player.crouch) or Input.is_action_just_pressed(player.jump):
		if !stand_shape.is_colliding():
			finished.emit("idle")
	if Input.is_action_just_pressed(player.prone):
		finished.emit("prone")
	if player.velocity == Vector3.ZERO:
		player.body_at_playback.travel("crouch")
	else:
		player.body_at_playback.travel("crouch_walk")

func exit(next_state_path:String) -> void:
	if next_state_path == "idle":
		player.tween_cam_height(player.CAM_HEIGHT_STAND)
	if next_state_path != "prone" and next_state_path != "crouch":
		player.collision_standing.disabled = false
		player.collision_crouched.disabled = true
		player.collision_prone.disabled = true
