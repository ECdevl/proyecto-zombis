extends ZombieState

@export var hurt_time : float = 3
@onready var hurt_timer: Timer = %HurtTimer

func enter(previous_state_path: String, data := {}) -> void:
	hurt_timer.start(hurt_time)
	var blend : Vector3 = data.get("blend")
	zombie.at["parameters/zombie_sm/hurt_blend/blend_position"] = blend
	zombie.playback.start("hurt_blend")
	await hurt_timer.timeout
	if get_parent().state == self:
		finished.emit("chase")


func physics_update(_delta: float) -> void:
	zombie.velocity.x = 0
	zombie.velocity.z = 0
	zombie.handle_gravity(_delta)
	zombie.move_and_slide()
