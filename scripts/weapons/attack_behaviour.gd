@abstract
class_name AttackBehaviour extends Resource

func create_operation(controller: WeaponController, descriptor: EquippableDescriptor) -> AttackOperation:
	return null

func can_reload() -> bool:
	return false

func get_reload_time(descriptor: EquippableDescriptor, ap: AnimationPlayer) -> float:
	return 0.0

func create_projectile(host: Node3D, descriptor: EquippableDescriptor) -> Projectile:
	return null
