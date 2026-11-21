extends PlayerState

var original_sens: float

func enter(previous_state_path: String, data: Dictionary = {}) -> void:
	player.ads_controller.aiming = true
	original_sens = player.camera_sensitivity
	player.camera_sensitivity = player.camera_sensitivity / 2

func handle_input(_event: InputEvent) -> void:
	if not player.can_act():
		return
	if _event.is_action_pressed("M1"):
		player.weapon_controller.call_deferred("attack")
	if _event.is_action_released("M2"):
		finished.emit("normal")

func exit(next_state_path: String) -> void:
	player.ads_controller.aiming = false
	player.camera_sensitivity = original_sens
