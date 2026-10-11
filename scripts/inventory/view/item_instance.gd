class_name ItemInstance extends RefCounted
## Un objeto REAL del juego (esta manzana, esta mochila). Guarda su propio estado.
## 'descriptor' = datos fijos compartidos. Todo lo que cambie durante el juego va acá.

var descriptor: ItemDescriptor
## Contenido propio si el objeto es un contenedor (mochila). null si no lo es.
var container: InventoryModel
## Cuánto queda por consumir (1.0 = intacto). Lo usa el estado "consuming".
var remaining_ratio := 1.0


func _init(data: ItemDescriptor) -> void:
	descriptor = data
	if data.container_capability:
		container = data.container_capability.duplicate() as InventoryModel
		container.title = data.item_name
		container.setup()
