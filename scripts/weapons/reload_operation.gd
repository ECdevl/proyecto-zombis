class_name ReloadOperation extends AttackOperation

var gun: Weapon

func start(p_controller: WeaponController, p_descriptor: EquippableDescriptor) -> void:
	super.start(p_controller, p_descriptor)
	gun = p_descriptor as Weapon

func is_valid() -> bool:
	if not super.is_valid():
		return false
	if not is_instance_valid(controller.ammo_source):
		return false
	if not controller.weapon_node.is_visible_in_tree():
		return false
	return true

func can_start() -> bool:
	if gun == null:
		return false
	if not descriptor.can_reload():
		return false
	if not is_valid():
		return false
	if cancelled:
		return false
	if controller.reloading:
		return false
	if not controller.player.can_perform(&"reload"):
		return false
	var missing: int = gun.mag_size - gun.curr_bullets
	if missing <= 0 or controller.get_reserve_ammo() <= 0:
		controller.play_reload_idle(self)
		return false
	return true

func run() -> void:
	if not can_start():
		return
	
	controller.reloading = true
	controller.play_reload_animation(self)
	while true:
		var t: float = descriptor.get_reload_time(controller.weapon_ap)
		if t <= 0.0:
			t = 1.0
		await controller.get_tree().create_timer(t).timeout
		if not is_valid() or not controller.is_active_operation(self):
			break
		var missing: int = gun.mag_size - gun.curr_bullets
		if missing <= 0 or controller.get_reserve_ammo() <= 0:
			break
		if gun.bullet_per_reload == 0:
			gun.curr_bullets += controller.ammo_source.take_ammo(gun.ammo_type, missing)
			break
		var ammo_taken: int = controller.ammo_source.take_ammo(gun.ammo_type, gun.bullet_per_reload)
		if ammo_taken <= 0:
			break
		gun.curr_bullets += ammo_taken
		if gun.curr_bullets >= gun.mag_size:
			break
		controller.play_reload_animation(self)

	if not controller.is_active_operation(self):
		return
	controller.reloading = false
	controller.play_reload_idle(self)
