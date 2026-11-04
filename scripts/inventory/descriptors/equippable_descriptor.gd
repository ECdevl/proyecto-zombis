@abstract
class_name EquippableDescriptor extends ItemDescriptor
## Base de todo lo que se sostiene en las manos (armas de fuego y cuerpo a cuerpo).
## Solo datos comunes. Lo propio de cada tipo vive en Weapon / Melee.

enum Handle { ONE, TWO }

@export var weapon_handle: Handle = Handle.ONE
@export var viewmodel_model: PackedScene
@export var damage: float
@export var fire_rate: float
@export var weapon_range: float
## Fuerza del empuje al golpear: la usa `MeleeProjectile` → `Zombie.die()` →
## `ragdoll_component.start(..., force)` como magnitud del impulso del ragdoll.
## Los .tres que no lo guardan usan este valor (antes estaba hardcodeado como
## 20.0 en el `hurt()` del melee; bate.tres lo sube a500).
@export var knockback: float = 20.0


func get_hands_required() -> int:
	return 2 if weapon_handle == Handle.TWO else 1


func get_actions() -> Array[String]:
	var actions := super.get_actions()
	actions.append("equipar")
	return actions
