extends CharacterBody3D
class_name Zombie
@export var ragdoll_text : bool = false
@export var health_component : HealthComponent
@export var zombie_ap : AnimationPlayer
@onready var ragdoll: PhysicalBoneSimulator3D = %ragdoll

var hit_direction : Vector3
var bone_hit : Node3D
@onready var look_head: LookAtModifier3D = %LookHead

##Animation
@onready var at: AnimationTree = %AT
var playback : AnimationNodeStateMachinePlayback
func _ready() -> void:
	playback = at.get("parameters/zombie_sm/playback")
	


	if health_component:
		health_component = health_component.duplicate()
		health_component.connect("death",Callable(self,"die"))
		health_component.connect("hurted",Callable(self,"hurted"))

func _input(event: InputEvent) -> void:
	if ragdoll_text and event.is_action_pressed("M1"):
		ragdoll.physical_bones_start_simulation()

func hurted(who:Node3D) -> void:
	GameManager.blood_splatter(who)
	at["parameters/flinch/request"] = 1
	print_debug("OUCH MY: ",who)
	if who.name == "head":
		die()

func die() -> void:
	
	ragdoll.physical_bones_start_simulation()
