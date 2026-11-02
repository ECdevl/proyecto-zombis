# data/inventory/wearable_item_descriptor.gd
class_name WearableItemDescriptor extends ItemDescriptor

@export var armor_value: float
@export var equip_slot: EquipSlot

@export var random_color : bool = true 
@export var quick_slots : int = 0
@export var cloth_color : Color = Color(255,10,23)

## Tinte propio de la prenda: si random_color, cada instancia recibe un color
## distinto (ícono y objeto soltado al mundo). Corre también en el editor
## (pickable_object.gd es @tool), así que el color se ve al decorar la escena.
func decorar_malla(malla: MeshInstance3D) -> void:
	if not random_color:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(randf(), randf(), randf())
	malla.material_overlay = material

		
enum EquipSlot { HEAD, TORSO, LEGS, FEET, BACK, SHOULDERS }
