extends State

func enter(previous_state_path: String, data := {}) -> void:
	player.yaw.position = Vector3(0,player.CAM_HEIGHT_STAND,0)
	player.collision_standing.disabled = false
	player.collision_crouched.disabled =true
	player.collision_prone.disabled = true

func update(_delta: float) -> void:
	player._camera_movement()



func physics_update(_delta: float) -> void:
	if player.velocity != Vector3.ZERO:
		finished.emit("walk")
	if Input.is_action_just_pressed(player.crouch):
		finished.emit("crouch")
	if Input.is_action_just_released(player.prone):
		finished.emit("prone")
	if Input.is_action_just_pressed(player.jump):
		finished.emit("jump")
