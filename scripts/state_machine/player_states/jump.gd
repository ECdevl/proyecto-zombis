extends State


func enter(previous_state_path: String, data := {}) -> void:
	player.velocity.y = player.jump_velocity
func update(_delta: float) -> void:
	player._camera_movement()
func physics_update(_delta: float) -> void:
	if player.is_on_floor():
		finished.emit("idle")
	
