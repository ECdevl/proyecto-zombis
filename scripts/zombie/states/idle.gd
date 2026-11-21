extends ZombieState

@onready var idle_sounds: Timer = %IdleSounds


func physics_update(_delta: float) -> void:
	zombie.velocity.x = 0
	zombie.velocity.z = 0
	zombie.handle_gravity(_delta)
	zombie.move_and_slide()
	

func enter(previous_state_path: String, data := {}) -> void:
	idle_sounds.start(randf_range(1.0,5.0))
	zombie.velocity = Vector3.ZERO
	await zombie.at.animation_finished
	# La espera puede terminar cuando el zombi ya está en grab, hurt, etc.
	# Sin este guard, un `idle` pendiente pisa ese estado y suelta al jugador.
	if zombie.state_machine.state != self:
		return
	zombie.state_machine.can_change_state = true
	zombie.vision.can_see = true
	finished.emit("chase")


func _on_vision_target_spotted(_target: Node3D) -> void:
	print_debug("SPOTTED: ", _target)

	# La señal de visión está cableada permanentemente en la escena. Solo
	# debe iniciar persecución si idle sigue siendo el estado activo.
	if zombie.state_machine.state != self:
		return
	# El zombi NO gira la cabeza para clavar la mirada en el jugador: la
	# detección y el "mirar de frente" los decide el cuerpo (ver D-018).
	# Aquí solo arranca la persecución; `chase` gira andando.
	finished.emit("chase")


func _on_idle_sounds_timeout() -> void:
	if zombie.state_machine.state == self:
		idle_sounds.start(randf_range(1.0,5.0))
		zombie.zombie_sounds.play()
