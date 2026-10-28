extends PlayerState
@onready var check_climb: RayCast3D = %CheckClimb



func update(_delta: float) -> void:
	pass

func enter(previous_state_path: String, data := {}) -> void:
	if is_instance_valid(player.armsy):
		player.armsy.hide()
	if is_instance_valid(player.current_viewmodel):
		player.current_viewmodel.hide()
	player.pitch.rotation = Vector3.ZERO



	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(player,"global_transform:origin",check_climb.get_collision_point(),.5)
	var tween2 = create_tween()
	tween2.tween_property(player.camera,"rotation_degrees",Vector3(0,0,-15),.25)
	tween2.tween_interval(.05)
	tween2.tween_property(player.camera,"rotation_degrees",Vector3(0,0,0),.25)
	
	await tween.finished
	if is_instance_valid(player.weapon_grip):
		player.weapon_grip.show()
	

	finished.emit("normal")

func exit(next_state_path:String) -> void:
	if is_instance_valid(player.armsy):
		player.armsy.show()
	if is_instance_valid(player.current_viewmodel):
		player.current_viewmodel.show()
	if is_instance_valid(player.arms_mesh):
		player.arms_mesh.top_level = false
		player.arms_mesh.position = Vector3.ZERO 
		player.arms_mesh.rotation_degrees = Vector3.ZERO
