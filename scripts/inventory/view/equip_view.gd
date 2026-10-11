extends Control
class_name EquipSlotView
## Una ranura de ropa. Muestra el icono y acepta objetos arrastrados (el controller decide).

@export var equip_slot: WearableItemDescriptor.EquipSlot
@export var equipment_model: EquipmentModel
@export var icon_rect: TextureRect

@onready var controller: InventoryUIController = %InventoryUIController


func _ready() -> void:
	add_to_group("drop_targets")
	mouse_filter = Control.MOUSE_FILTER_STOP
	if icon_rect == null:
		icon_rect = get_child(0) as TextureRect
	equipment_model.changed.connect(_refresh)
	_refresh()


## ¿Este objeto es ropa de esta ranura?
func accepts(item: ItemInstance) -> bool:
	var wearable := item.descriptor as WearableItemDescriptor
	return wearable != null and wearable.equip_slot == equip_slot


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		controller.unequip(equip_slot)


func _refresh() -> void:
	var item := equipment_model.get_equipped(equip_slot)
	icon_rect.texture = item.descriptor.icon if item else null
