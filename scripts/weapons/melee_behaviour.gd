class_name MeleeBehaviour extends AttackBehaviour

func create_operation(controller: WeaponController, descriptor: EquippableDescriptor) -> AttackOperation:
	var operation: MeleeAttack = MeleeAttack.new()
	operation.start(controller, descriptor)
	return operation
