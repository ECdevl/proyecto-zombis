extends Node



const BLOOD = preload("uid://t3pfbgv7i028")

func blood_splatter(hit_pos: Vector3, direction := Vector3.UP, follow: Node3D = null) -> void:
	var sangre = BLOOD.instantiate()
	sangre.particle_direction = direction
	get_tree().current_scene.add_child(sangre)
	sangre.global_position = hit_pos
	if follow:
		var local_offset := follow.global_transform.affine_inverse() * hit_pos
		_follow(sangre, follow, local_offset)


func _follow(fx: Node3D, target: Node3D, local_offset: Vector3) -> void:
	while is_instance_valid(fx) and is_instance_valid(target):
		fx.global_position = target.global_transform * local_offset
		await get_tree().process_frame
