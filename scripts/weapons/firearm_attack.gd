class_name FirearmAttack extends AttackOperation

func run() -> void:
	var gun: Weapon = descriptor as Weapon
	if gun == null:
		return
	if not is_valid():
		return
	if controller.reloading:
		return
	if controller.fire_rate.time_left != 0.0:
		return
	if gun.curr_bullets <= 0:
		return

	await controller.get_tree().process_frame
	if not is_valid() or controller.reloading:
		return

	gun.curr_bullets -= 1
	controller.fire_rate.start(gun.fire_rate)
	if is_instance_valid(controller.player.viewmodel_animator):
		controller.player.viewmodel_animator.fire_shot(&"shoot")
	controller.gun_fired.emit(gun.ammo_type)
	controller.apply_recoil(gun)
	controller.load_projectile(gun)
	var muzzle: Node = controller.get_tree().get_first_node_in_group("muzzle")
	if muzzle and muzzle.has_method("start_effect"):
		muzzle.start_effect()
