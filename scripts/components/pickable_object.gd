extends RigidBody3D
class_name PickableItem

@export var item_resource : Item
@onready var mesh: MeshInstance3D = %Mesh
@onready var collision: CollisionShape3D = %Collision



func _ready() -> void:
	initialize()

func initialize() -> void:
	assert(item_resource.item_mesh != null,"El objeto no tiene mesh!")
	if item_resource.item_mesh == null:
		queue_free()
	mesh.mesh = item_resource.item_mesh
	collision.shape = mesh.mesh.create_convex_shape()
