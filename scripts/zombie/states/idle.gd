extends ZombieState


func physics_update(_delta: float) -> void:
	zombie.velocity.x = 0
	zombie.velocity.z = 0
	zombie.handle_gravity(_delta)
	zombie.move_and_slide()

func enter(previous_state_path: String, data := {}) -> void:
	zombie.velocity = Vector3.ZERO
	await zombie.at.animation_finished
	finished.emit("chase")
	zombie.state_machine.can_change_state = true
	zombie.vision.can_see = true


func _on_vision_target_spotted(_target: Node3D) -> void:
	print_debug("SPOTTED: ", _target)

	# El zombi NO gira la cabeza para clavar la mirada en el jugador: la
	# detección y el "mirar de frente" los decide el cuerpo (ver D-018).
	# Aquí solo arranca la persecución; `chase` gira andando.
	finished.emit("chase")
