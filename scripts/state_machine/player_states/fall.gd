extends PlayerState
@onready var footstep_player: FootstepPlayer = %FootstepPlayer

func enter(previous_state_path: String, data := {}) -> void:
	player.body_at_playback.travel("jump")

func update(_delta: float) -> void:
	player._camera_movement()

func physics_update(_delta: float) -> void:
	if player.is_on_floor():
		player.velocity.y = 0.0

		finished.emit("idle")
		return

func exit(next_state_path:String) -> void:
	footstep_player.play_step()
