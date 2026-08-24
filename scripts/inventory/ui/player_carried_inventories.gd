# PlayerCarriedInventories.gd
extends Node
class_name PlayerCarriedInventories
var _containers: Array[InventoryModel] = []
@onready var clothes: Panel = %Clothes

signal add_container(model:InventoryModel, display:String)
signal remove_container(model:InventoryModel)

signal item_received(descriptor: ItemDescriptor, container: InventoryModel)
signal item_lost(descriptor:ItemDescriptor)

func register_container(model: InventoryModel, priority: int = 0, display:String = "") -> void:
	if _containers.has(model):
		return
	_containers.append(model)
	add_container.emit(model,display)
	model.item_placed.connect(_on_item_placed.bind(model))
	model.item_removed.connect(_on_item_removed)

func _on_item_placed(descriptor: ItemDescriptor, row: int, col: int, rotated: bool, model: InventoryModel) -> void:
	item_received.emit(descriptor, model)

func _on_item_removed(descriptor: ItemDescriptor) -> void:
	item_lost.emit(descriptor)



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
