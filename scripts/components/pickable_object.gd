extends RigidBody3D
class_name PickableItem

@export var interact_resource: Interactable
## Tipo de objeto. Se usa para crear 'item' si no vino uno ya hecho.
@export var item_descriptor: ItemDescriptor

## El objeto REAL (con su contenido y estado). Al soltar algo del inventario se asigna antes
## de agregar este nodo a la escena, así una mochila conserva lo que lleva adentro.
var item: ItemInstance

@onready var collision: CollisionShape3D = %Collision


func _get_hint() -> String:
	return "Press USE to pickup"


func _ready() -> void:
	if item == null:
		if item_descriptor == null:
			queue_free()
			return
		item = ItemInstance.new(item_descriptor)
	item_descriptor = item.descriptor
	if item_descriptor.item_mesh == null:
		queue_free()
		return

	await item_descriptor.ensure_icon(self)

	var item_scene: Node3D = item_descriptor.item_mesh.instantiate()
	for child in item_scene.get_children():
		if child is MeshInstance3D:
			collision.shape = child.mesh.create_convex_shape()
			break
	add_child(item_scene)
