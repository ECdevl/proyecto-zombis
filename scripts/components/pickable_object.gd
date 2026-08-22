extends RigidBody3D
class_name PickableItem



const ICON_CREATOR = preload("uid://w8pon5lrn51x")

func _generate_icon(mesh: PackedScene) -> ImageTexture:
	var creator: SubViewport = ICON_CREATOR.instantiate()
	add_child(creator)  # necesita estar en el árbol para renderizar
	var texture: ImageTexture = await creator.create_texture(mesh)
	return texture

@export var interact_resource : Interactable
@onready var collision: CollisionShape3D = %Collision


func _get_hint() -> String:
	return "Press USE to pickup"

@export var item_descriptor : ItemDescriptor 
func _ready() -> void:
	if item_descriptor.item_mesh == null:
		queue_free()
	item_descriptor.icon =  await _generate_icon(item_descriptor.item_mesh)
	var item_scene : Node3D = item_descriptor.item_mesh.instantiate()
	var mesh : MeshInstance3D
	for i in item_scene.get_children():
		if i.name.contains("mesh") and i is MeshInstance3D:
			mesh = i
			break
	collision.shape = mesh.mesh.create_convex_shape()
	add_child(item_scene)
