# data/inventory/wearable_item_descriptor.gd
class_name WearableItemDescriptor extends ItemDescriptor

@export var armor_value: float
@export var equip_slot: EquipSlot
@export var container_model: InventoryModel  # null = no es contenedor
@export var random_color : bool = true 

@export var cloth_color : Color = Color(255,10,23)

func _init() -> void:
	await Engine.get_main_loop().process_frame
	if random_color:
		var mesh : Node3D = item_mesh.instantiate()
		mesh.get_child(0).material_overlay.albedo_color = Color(randf(),randf(),randf())
		var packed : PackedScene = PackedScene.new()
		packed.pack(mesh)
		item_mesh = packed
	if container_model:
		container_model = container_model.duplicate()
		
enum EquipSlot { HEAD, TORSO, LEGS, FEET, BACK, SHOULDERS }
