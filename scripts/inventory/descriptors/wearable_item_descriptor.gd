# data/inventory/wearable_item_descriptor.gd
class_name WearableItemDescriptor extends ItemDescriptor

@export var armor_value: float
@export var equip_slot: EquipSlot
@export var container_model: InventoryModel  # null = no es contenedor

enum EquipSlot { HEAD, TORSO, LEGS, FEET, BACK, SHOULDERS }
