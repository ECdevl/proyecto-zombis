extends StaticBody3D
class_name ContainerInteractable

@export var inventory_model: InventoryModel
@export var display_name: String = "Contenedor"

func _get_hint() -> String:
	return "Presiona USAR para abrir"
