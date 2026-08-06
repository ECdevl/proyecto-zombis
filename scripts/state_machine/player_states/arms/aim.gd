extends State
@onready var crosshair: Marker3D = %Crosshair
var aim_node: Node3D 
@onready var hand_bone: BoneAttachment3D = %hand

var hand_to_aim_offset: Transform3D
var default_fov: float

func enter(previous_state_path: String, data := {}) -> void:

	player.viewmodel_ap.play("aim")
	print_debug(player.viewmodel_ap.current_animation)
	default_fov = player.camera.fov
	var tween_fov = create_tween()
	tween_fov.tween_property(player.camera, "fov", 25, .15)

func handle_input(_event: InputEvent) -> void:
	if _event.is_action_pressed("M1"):
		
		player.weapon_controller.call_deferred("shoot")
	if _event.is_action_released("M2"):
		finished.emit("normal")

func exit(next_state_path:String) -> void:
	player.viewmodel_ap.play_backwards("aim")
	default_fov = player.camera.fov
	var tween_fov = create_tween()
	tween_fov.tween_property(player.camera, "fov", 75, .15)
