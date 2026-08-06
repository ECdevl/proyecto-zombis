extends VBoxContainer
class_name ContainerItems
@export var container_resource : ContainerResource 
const ITEM_INVENTORY = preload("uid://emtrk8exj7f")
var container_weight : float

func _enter_tree() -> void: 
	
	container_resource = container_resource.duplicate()
	container_resource.connect("added",Callable(self,"item_added"))
	container_resource.connect("removed",Callable(self,"item_removed"))
	

func _ready() -> void:
	if owner == null:
		await tree_entered


func has_cloth_item(item:Item) -> bool:
	for i in get_children():
		if i is ItemSlot:
			if i.slot_resource == item:
				return true
			else:
				continue
	return false

func item_added(item:Item) -> void:
	
	var item_slot : ItemSlot = ITEM_INVENTORY.instantiate()
	item_slot.slot_resource = item
	add_child(item_slot)
	if owner == null:
		await tree_entered
	item_slot.connect("toggled",Callable(owner,"item_pressed"),16)
	
	container_weight += item.weight

func item_removed(item:Item) -> void:
	for i in get_children():
		if i is ItemSlot:
			if i.slot_resource == item:
				i.queue_free()
func container_changed() -> void:
	container_weight = 0
