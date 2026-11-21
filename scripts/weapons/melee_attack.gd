class_name MeleeAttack extends AttackOperation

func run() -> void:
	var melee: Melee = descriptor as Melee
	if melee == null or melee.swings.is_empty():
		return
	if not is_valid():
		return
	if controller.reloading:
		return
	if controller.fire_rate.time_left != 0.0:
		return
	if not is_instance_valid(controller.player.viewmodel_animator):
		return
	if controller.player.viewmodel_animator.is_swing_active():
		return

	if controller.swing_index >= melee.swings.size():
		controller.swing_index = 0
	var swing_data: SwingData = melee.swings[controller.swing_index]
	controller.swing_index += 1
	if is_instance_valid(controller.weapon_ap) and controller.weapon_ap.has_animation(swing_data.animation):
		controller.player.viewmodel_animator.play_base(swing_data.animation)
	controller.fire_rate.start(melee.fire_rate)

	await controller.get_tree().create_timer(swing_data.hit_time).timeout
	# Si este golpe fue cancelado (p. ej. por un swing posterior o un cambio de
	# arma), ya no debe actuar: el swing que tomó el control es el que sigue.
	# Si nadie lo reemplazó, limpiamos la vista para no quedarnos en `swing`.
	if not controller.is_active_operation(self):
		if controller._active_operation == null and cancelled:
			controller.player.viewmodel_animator.play_base(&"idle")
		return
	if controller.reloading or not is_valid():
		controller.player.viewmodel_animator.play_base(&"idle")
		return
	if not is_instance_valid(controller.player.viewmodel_animator):
		return
	if controller.view_punch:
		controller.view_punch.punch(Vector2(swing_data.recoil_kick.x, swing_data.recoil_kick.y))
	controller.player.viewmodel_animator.play_base(&"idle")
	var hit: MeleeProjectile = MeleeProjectile.new()
	controller.player.add_child(hit)
	hit.setup(melee, swing_data, controller.player)

	
	
