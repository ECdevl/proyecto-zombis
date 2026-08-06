extends State
@onready var check_climb: RayCast3D = %CheckClimb



func update(_delta: float) -> void:
	pass

func enter(previous_state_path: String, data := {}) -> void:
	player.armsy.hide()
	player.pitch.rotation = Vector3.ZERO



	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(player,"global_transform:origin",check_climb.get_collision_point(),.5)
	var tween2 = create_tween()
	tween2.tween_property(player.camera,"rotation_degrees",Vector3(0,0,-15),.25)
	tween2.tween_interval(.05)
	tween2.tween_property(player.camera,"rotation_degrees",Vector3(0,0,0),.25)
	
	await tween.finished
	player.weapon_grip.show()
	

	finished.emit("normal")

func exit(next_state_path:String) -> void:
	player.armsy.show()
	player.arms_mesh.top_level = false
	player.arms_mesh.position = Vector3.ZERO 
	player.arms_mesh.rotation_degrees = Vector3.ZERO
