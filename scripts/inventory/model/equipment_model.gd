class_name EquipmentModel extends Resource
## Lo que el jugador lleva puesto, por ranura. Avisa cambios con `changed`.

var _slots: Dictionary[WearableItemDescriptor.EquipSlot, ItemInstance] = {}


## false si no es ropa o la ranura ya está ocupada.
func equip(item: ItemInstance) -> bool:
	var wearable := item.descriptor as WearableItemDescriptor
	if wearable == null or _slots.has(wearable.equip_slot):
		return false
	_slots[wearable.equip_slot] = item
	emit_changed()
	return true


func remove(item: ItemInstance) -> bool:
	for slot in _slots:
		if _slots[slot] == item:
			_slots.erase(slot)
			emit_changed()
			return true
	return false


func get_equipped(slot: WearableItemDescriptor.EquipSlot) -> ItemInstance:
	return _slots.get(slot)


func items() -> Array:
	return _slots.values()
