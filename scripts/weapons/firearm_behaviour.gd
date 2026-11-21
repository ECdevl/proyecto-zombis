class_name FirearmBehaviour extends AttackBehaviour

const PROJECTILE = preload("uid://bct0h10f6qq3m")

func create_operation(controller: WeaponController, descriptor: EquippableDescriptor) -> AttackOperation:
	var operation: FirearmAttack = FirearmAttack.new()
	operation.start(controller, descriptor)
	return operation

func can_reload() -> bool:
	return true

func get_reload_time(descriptor: EquippableDescriptor, ap: AnimationPlayer) -> float:
	var gun: Weapon = descriptor as Weapon
	if gun == null:
		return 0.0
	if gun.reload_time > 0.0:
		return gun.reload_time
	if is_instance_valid(ap) and ap.has_animation(&"reload"):
		return ap.get_animation(&"reload").length
	return 0.0

func create_projectile(host: Node3D, descriptor: EquippableDescriptor) -> Projectile:
	var gun: Weapon = descriptor as Weapon
	if gun == null:
		return null
	var projectile: Projectile = PROJECTILE.instantiate()
	_attach(host, projectile)
	projectile.set_projectile(gun.damage, gun.weapon_range)
	return projectile

func _attach(host: Node3D, projectile: Projectile) -> void:
	if not is_instance_valid(host):
		return
	var muzzle: Node = host.find_child("Muzzle", true, false)
	if muzzle and muzzle is Node3D:
		(muzzle as Node3D).add_child(projectile)
		projectile.global_position = (muzzle as Node3D).global_position
	else:
		host.add_child(projectile)
