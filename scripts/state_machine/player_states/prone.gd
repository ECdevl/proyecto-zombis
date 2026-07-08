extends State
@onready var crouch_shape: ShapeCast3D = %CrouchShape
@onready var stand_shape: ShapeCast3D = %StandShape

func enter(previous_state_path: String, data := {}) -> void:
	player.speed = player.crouch_speed 
	player.yaw.position = Vector3(0,player.CAM_HEIGHT_PRONE,0)
	player.collision_prone.disabled = false
	player.collision_standing.disabled = true
	player.collision_crouched.disabled = true
func update(_delta: float) -> void:
	player._camera_movement()	
func physics_update(_delta: float) -> void:
	if Input.is_action_just_pressed(player.jump) or Input.is_action_just_released(player.crouch):
		if !crouch_shape.is_colliding():
			finished.emit("crouch")
	if Input.is_action_just_released(player.prone):
		if !stand_shape.is_colliding():
			finished.emit("idle")

func exit(next_state_path:String) -> void:
	if next_state_path != "prone" or next_state_path != "crouch":
		player.yaw.position = Vector3(0.0,1.0,0.0)
		player.collision_standing.disabled = false
		player.collision_crouched.disabled =true
		player.collision_prone.disabled = true
