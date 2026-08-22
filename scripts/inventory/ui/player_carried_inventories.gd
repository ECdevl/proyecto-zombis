# PlayerCarriedInventories.gd
extends Node
class_name PlayerCarriedInventories
var _containers: Array[InventoryModel] = []
@onready var clothes: Panel = %Clothes

signal add_container(model:InventoryModel)
signal remove_container(model:InventoryModel)



func register_container(model: InventoryModel, priority: int = 0) -> void:
	if _containers.has(model):
		return
	_containers.append(model)
	add_container.emit(model)
	# opcional: ordenar por prioridad (bolsillos primero, mochila después)

func unregister_container(model: InventoryModel) -> void:
	_containers.erase(model)
	remove_container.emit(model)

func try_add_anywhere(item: ItemDescriptor) -> bool:
	
	for model in _containers:
		if model.add_item_by_descriptor(item): # el método que ya tengan en InventoryModel
			if item is WearableItemDescriptor:
				if item.container_model:
					register_container(item.container_model)
			return true
	return false


func _on_remove_container(model: InventoryModel) -> void:
	pass # Replace with function body.
