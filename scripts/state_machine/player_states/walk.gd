extends State

func enter(previous_state_path: String, data := {}) -> void:
	player.speed = player.walk_speed
	player.body_at_playback.travel("walk_dir")
func update(_delta: float) -> void:
	player._camera_movement()
var blend_pos : Vector2 = Vector2.ZERO
func physics_update(_delta: float) -> void:
	var input_dir : Vector2
	input_dir = Input.get_vector("left","right","forward","back")
	
	blend_pos = blend_pos.lerp(input_dir,10.0*_delta)
	player.body_at["parameters/body/walk_dir/blend_position"] = blend_pos
	print_debug(blend_pos)
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
