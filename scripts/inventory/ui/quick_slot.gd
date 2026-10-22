extends PanelContainer
class_name QuickSlot
@export var item_linked : ItemDescriptor
var instance_item : ItemInstance
@export var number_input : Key : 
	set(new):
		number_input = new
		label.text = OS.get_keycode_string(new)
@onready var texture_rect: TextureRect = %TextureRect
@onready var label: Label = %Label

signal quick_slot_call(item:ItemInstance)


func _ready() -> void:
	add_to_group("drop_targets")

func change_linked_item(new_item:ItemInstance) -> void:
	if new_item:
		item_linked = new_item.descriptor
		texture_rect.texture = new_item.descriptor.icon
		instance_item = new_item
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_pressed():
			if event.key_label in [Key.KEY_1,Key.KEY_2,Key.KEY_3,Key.KEY_4,Key.KEY_5,Key.KEY_6,Key.KEY_7,Key.KEY_8,Key.KEY_9]:
				if event.key_label == number_input:
					quick_slot_call.emit(instance_item)
