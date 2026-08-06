extends State

@export var stamina_cost : float = 1.5
func enter(previous_state_path: String, data := {}) -> void:
	if player.viewmodel:
		if player.viewmodel_ap:
			if player.viewmodel_ap.current_animation not in ["reload","aim","shoot","aim_shoot"]:
				player.viewmodel_ap.play("run",.25)
	player.speed = player.sprint_speed
	player.playback.travel("run")

func update(_delta: float) -> void:
	player._camera_movement()
	player.player_needs.current_stamina -= 5.0 * _delta
	if player.player_needs.current_stamina <= 0:
		finished.emit("walk")
		return

func physics_update(_delta: float) -> void:
	if player.velocity.x == 0 and player.velocity.z == 0:
		finished.emit("idle")
	if Input.is_action_just_released(player.sprint):
		finished.emit("walk")
	if Input.is_action_just_pressed(player.jump):
		finished.emit("jump")

func exit(next_state_path:String) -> void:
	if player.viewmodel:
		if player.viewmodel_ap:
			if player.viewmodel_ap.current_animation not in ["reload","aim","shoot","aim_shoot"]:
				player.viewmodel_ap.play("idle",.25)
	player.playback.travel("Idle")
