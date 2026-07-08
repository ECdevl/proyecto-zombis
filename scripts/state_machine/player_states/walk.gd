extends State

func enter(previous_state_path: String, data := {}) -> void:
	player.speed = player.walk_speed

func update(_delta: float) -> void:
	player._camera_movement()

func physics_update(_delta: float) -> void:
	if player.velocity.x == 0 and player.velocity.z == 0:
		finished.emit("idle")
		return
	if Input.is_action_just_pressed(player.sprint):
		if player.player_needs.current_stamina > 0:
			finished.emit("run")
			return
	if Input.is_action_just_pressed(player.crouch):
		finished.emit("crouch")
		return
	if Input.is_action_just_pressed(player.crouch):
		finished.emit("crouch")
		return
	if Input.is_action_just_released(player.prone):
		finished.emit("prone")
		return
	if Input.is_action_just_pressed(player.jump):
		finished.emit("jump")
		return
