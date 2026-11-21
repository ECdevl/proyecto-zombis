@abstract
class_name HoldableDescriptor extends ItemDescriptor
## Base de todo objeto que se puede sostener con una mano.
## Separa dos conceptos que antes eran el mismo: "se puede tener en la mano"
## (esto) y "es el arma principal del viewmodel" (EquippableDescriptor).
## HandsModel decide el viewmodel con `is EquippableDescriptor`, así que una
## linterna no puede convertirse en arma principal por el mero hecho de heredar.

func get_hands_required() -> int:
	return 1


func get_actions() -> Array[String]:
	var actions: Array[String] = super.get_actions()
	actions.append("equipar")
	return actions
