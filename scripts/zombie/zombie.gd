extends CharacterBody3D
class_name Zombie
@export var ragdoll_text : bool = false
@export var health_component : HealthComponent
@onready var ragdoll: PhysicalBoneSimulator3D = %ragdoll
var hit_direction : Vector3
var bone_hit : PhysicalBone3D
func _ready() -> void:
	if ragdoll_text:
		await get_tree().create_timer(1).timeout
		ragdoll.physical_bones_start_simulation()
	if health_component:
		health_component.connect("death",Callable(self,"die"))
		health_component.connect("hurted",Callable(self,"hurted"))


func hurted() -> void:
	if bone_hit:
		GameManager.blood_splatter(bone_hit,hit_direction)

func die() -> void:
	ragdoll.physical_bones_start_simulation()
