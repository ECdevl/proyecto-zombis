# data/inventory/equipment_model.gd
class_name EquipmentModel extends Resource

signal item_equipped(slot: WearableItemDescriptor.EquipSlot, descriptor: WearableItemDescriptor)
signal item_unequipped(slot: WearableItemDescriptor.EquipSlot, descriptor: WearableItemDescriptor)

var slots: Dictionary = {}  # EquipSlot -> WearableItemDescriptor

func equip(slot: WearableItemDescriptor.EquipSlot, descriptor: WearableItemDescriptor) -> bool:
	if slots.has(slot):
		return false
		
	slots[slot] = descriptor
	item_equipped.emit(slot, descriptor)
	return true

func unequip(slot: WearableItemDescriptor.EquipSlot) -> bool:
	if not slots.has(slot):
		return false
	var descriptor: WearableItemDescriptor = slots[slot]
	slots.erase(slot)
	emit_signal("item_unequipped",slot,descriptor)
	
	return true

func get_equipped(slot: WearableItemDescriptor.EquipSlot) -> WearableItemDescriptor:
	return slots.get(slot)
