extends Node

enum AmmoType {NINE_MM=0,PISTOL_AE=1}

const BLOOD = preload("uid://t3pfbgv7i028")
var maximum_blood_instances = 5
func blood_splatter(node:Node3D,direction:Vector3 = Vector3.UP) -> void:
	if get_tree().get_nodes_in_group("BLOOD").size() >= maximum_blood_instances:
		return
	var sangre = BLOOD.instantiate()
	sangre.particle_direction = direction
	node.add_child(sangre)
	sangre.position = Vector3.ZERO
	
	
