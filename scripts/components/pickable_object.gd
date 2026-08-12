extends RigidBody3D
class_name PickableItem

@export var item_resource : Item
@onready var collision: CollisionShape3D = %Collision
@export var interact_resource : Interactable



func _get_hint() -> String:
	return "Press USE to pickup"

func _ready() -> void:
	initialize()




func initialize() -> void:
	assert(item_resource.item_mesh != null,"El objeto no tiene mesh!")
	if item_resource.item_mesh == null:
		queue_free()
	var item_scene : Node3D = item_resource.item_mesh.instantiate()
	var mesh : MeshInstance3D
	for i in item_scene.get_children():
		if i.name.contains("mesh") and i is MeshInstance3D:
			mesh = i
			break
	collision.shape = mesh.mesh.create_convex_shape()
	add_child(item_scene)
