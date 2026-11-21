@abstract
class_name EquippableDescriptor extends HoldableDescriptor

enum Handle { ONE, TWO }

@export var weapon_handle: Handle = Handle.ONE
@export var viewmodel_model: PackedScene
@export var damage: float
@export var fire_rate: float
@export var weapon_range: float
@export var push_time: float = .3
@export var knockback: float = 20.0
@export var behaviour: AttackBehaviour

func get_hands_required() -> int:
	return 2 if weapon_handle == Handle.TWO else 1

func can_reload() -> bool:
	return behaviour != null and behaviour.can_reload()

func get_reload_time(ap: AnimationPlayer) -> float:
	if behaviour == null:
		return 0.0
	return behaviour.get_reload_time(self, ap)

func create_projectile(host: Node3D) -> Projectile:
	if behaviour == null:
		return null
	return behaviour.create_projectile(host, self)
