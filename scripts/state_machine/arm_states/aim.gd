extends State
@onready var crosshair: Marker3D = %Crosshair
var aim_node: Node3D 


var hand_to_aim_offset: Transform3D
var default_fov: float
var playback : AnimationNodeStateMachinePlayback
func enter(previous_state_path: String, data := {}) -> void:
	finished.emit("normal")
	return
	if player.viewmodel_at:
		playback = player.viewmodel_at["parameters/gun_sm/playback"]
		playback.travel("aim")
	else:
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
	return
	if playback:
		playback.travel("idle")
	else:
		player.viewmodel_ap.play_backwards("aim")
	default_fov = player.camera.fov
	var tween_fov = create_tween()
	tween_fov.tween_property(player.camera, "fov", 75, .15)
