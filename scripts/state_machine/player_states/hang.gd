extends State
@onready var check_ledge_l: RayCast3D = %CheckLedgeL
@onready var check_ledge_r: RayCast3D = %CheckLedgeR

@onready var check_climb: RayCast3D = $"../../Yaw/CheckClimb"
@onready var check_ledge_2: RayCast3D = %CheckLedge2

var yaw_rot : float

var climbing : bool = false

func enter(previous_state_path: String, data := {}) -> void:
	player.arms_mesh.top_level = true
	player.arms_mesh.global_position = player.global_position
	player.arms_mesh.rotation_degrees = Vector3(0,-180.0,0)
	player.speed = player.hang_velocity
	yaw_rot = player.yaw.rotation.y
	player.playback.travel("Ledge")
	
	player.weapon_grip.hide()
	
func update(_delta: float) -> void:
	player._camera_movement(true,yaw_rot)

func physics_update(_delta: float) -> void:
	player.velocity = Vector3.ZERO


	
	if !check_ledge_l.is_colliding() and !check_ledge_r.is_colliding() or check_ledge_2.is_colliding():
		finished.emit("idle")
		
	if Input.is_action_just_pressed(player.jump):
		if check_climb.is_colliding():
			finished.emit("climb")
			return
		else:
			print_debug("no puedo subir!!!")
	if Input.is_action_just_pressed(player.crouch):
		finished.emit("idle")

func exit(next_state_path:String) -> void:
	if next_state_path != "Climb":
		player.weapon_grip.show()
		player.playback.travel("Idle")
		player.arms_mesh.top_level = false
