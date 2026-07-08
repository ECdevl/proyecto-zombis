extends Button
class_name ItemSlot
@onready var logo: TextureRect = %logo
@onready var name_label: Label = %name_label
@onready var quantity: Label = %quantity
@export var slot_resource : Item : 
	set(new):
		if new == null:
			slot_resource = new
			queue_free()
		else:
			slot_resource = new
func _initialize(resource: Item) -> void:
	slot_resource = resource
	name = resource.item_name
	if resource.icon:
		logo.texture = resource.icon
	name_label.text = resource.item_name
	quantity.text = str(resource.stack)
func _ready() -> void:
	if !slot_resource:
		queue_free()
	else:
		_initialize(slot_resource)
