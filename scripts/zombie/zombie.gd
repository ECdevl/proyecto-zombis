extends CharacterBody3D
class_name Zombie
@export var ragdoll_text : bool = false
@export var health_component : HealthComponent
@export var zombie_ap : AnimationPlayer
@onready var ragdoll: PhysicalBoneSimulator3D = %ragdoll
var hit_direction : Vector3
var bone_hit : Node3D
func _ready() -> void:
	if ragdoll_text:
		await get_tree().create_timer(1).timeout
		zombie_ap.stop()
		ragdoll.physical_bones_start_simulation()
	if health_component:
		health_component = health_component.duplicate()
		health_component.connect("death",Callable(self,"die"))
		health_component.connect("hurted",Callable(self,"hurted"))


func hurted(who:Node3D) -> void:
	GameManager.blood_splatter(who)
	print_debug("OUCH MY: ",who)

func die() -> void:
	ragdoll.physical_bones_start_simulation()
