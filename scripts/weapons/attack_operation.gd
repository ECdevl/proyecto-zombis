class_name AttackOperation extends RefCounted

var controller: WeaponController
var descriptor: EquippableDescriptor
var cancelled: bool = false

func start(p_controller: WeaponController, p_descriptor: EquippableDescriptor) -> void:
	controller = p_controller
	descriptor = p_descriptor

func cancel() -> void:
	cancelled = true

func is_valid() -> bool:
	if cancelled:
		return false
	if controller == null or not is_instance_valid(controller):
		return false
	if not is_instance_valid(controller.player):
		return false
	if not controller.player.can_act():
		return false
	if controller.current_weapon != descriptor:
		return false
	if not is_instance_valid(controller.weapon_node):
		return false
	return true

func run() -> void:
	pass
