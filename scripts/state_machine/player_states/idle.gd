extends PlayerState

func enter(previous_state_path: String, data := {}) -> void:
	player.yaw.position = Vector3(0,player.CAM_HEIGHT_STAND,0)
	player.collision_standing.disabled = false
	player.collision_crouched.disabled =true
	player.collision_prone.disabled = true

func update(_delta: float) -> void:
	player._camera_movement()
	player.body_at_playback.travel(&"idle")

func physics_update(_delta: float) -> void:
	if not player.is_on_floor():
		finished.emit("fall")
		return
	var horizontal : Vector2 = Vector2(player.velocity.x, player.velocity.z)
	if horizontal.length() > 0.0001:
		finished.emit("walk")
		return
	if Input.is_action_just_pressed(player.crouch):
		finished.emit("crouch")
	if Input.is_action_just_pressed(player.prone):
		finished.emit("prone")
	if Input.is_action_just_pressed(player.jump):
		finished.emit("jump")
