extends Control
class_name EquipSlotView

@export var equip_slot: WearableItemDescriptor.EquipSlot
@export var equipment_model: EquipmentModel
@export var icon_rect: TextureRect

# equip_slot_view.gd
func _ready() -> void:
	add_to_group("drop_targets")
	mouse_filter = Control.MOUSE_FILTER_STOP
	equipment_model.item_equipped.connect(_on_equipped)
	equipment_model.item_unequipped.connect(_on_unequipped)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		equipment_model.unequip(equip_slot)

func try_place(item: ItemVisual, _world_pos: Vector2) -> bool:
	if item.descriptor is not WearableItemDescriptor:
		return false
	var wearable := item.descriptor as WearableItemDescriptor
	if wearable.equip_slot != equip_slot:
		return false
	equipment_model.equip(equip_slot, wearable)  # ya tipado bien
	return true

func _on_equipped(slot: WearableItemDescriptor.EquipSlot, descriptor: ItemDescriptor) -> void:
	if slot == equip_slot and icon_rect:
		icon_rect.texture = descriptor.icon

func _on_unequipped(slot: WearableItemDescriptor.EquipSlot, _descriptor: ItemDescriptor) -> void:
	if slot == equip_slot and icon_rect:
		icon_rect.texture = null
