extends StaticBody3D
class_name ContainerInteractable

## Plantilla del contenido. Cada cofre trabaja con su propia copia.
@export var inventory_model: InventoryModel
@export var display_name: String = "Contenedor"


func _ready() -> void:
	if inventory_model == null:
		push_error("%s: falta inventory_model" % name)
		return
	inventory_model = inventory_model.duplicate() as InventoryModel
	inventory_model.title = display_name
	inventory_model.setup()


func _get_hint() -> String:
	return "Presiona USAR para abrir"
