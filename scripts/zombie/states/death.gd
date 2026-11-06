extends ZombieState

func enter(previous_state_path: String, data := {}) -> void:
	zombie.set_collision_layer_value(2,false)
	zombie.nav.set_avoidance_layer_value(1,false)
	var zombie_body : Node3D = zombie.get_node("ZombiConRig")
	zombie_body.reparent(get_tree().current_scene,true)
	zombie_body.owner = get_tree().current_scene
	owner.queue_free()
	
