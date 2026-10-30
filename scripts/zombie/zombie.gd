extends CharacterBody3D
class_name Zombie
@export var ragdoll_text : bool = false
@export var health_component : HealthComponent
@export var zombie_ap : AnimationPlayer
@export var can_debug : bool = false
@onready var nav: NavigationAgent3D = %Nav

@export var speed : float = 2.5

var hit_direction : Vector3
var bone_hit : Node3D
@onready var look_head: LookAtModifier3D = %LookHead
##Animation
@onready var at: AnimationTree = %AT
var playback : AnimationNodeStateMachinePlayback
@onready var vision: ZombieVision = %Vision
@onready var skeleton_3d: Skeleton3D = $ZombiConRig/rig/Skeleton3D

@export var zombie_mesh : MeshInstance3D
@export var claw_damage : float = 10.0
var direction : Vector3
@onready var state_machine: StateMachine = %StateMachine

signal pushed(direction: Vector3)

func push(direction: Vector3) -> void:
	pushed.emit(direction)

@onready var ragdoll_component: ZombieRagdoll = %RagdollComponent
const BLOOD_SPLATTER = preload("res://scenes/components/blood_splatter.tscn")


	
func _ready() -> void:
	playback = at.get("parameters/zombie_sm/playback")



	if health_component:
		health_component = health_component.duplicate()
		health_component.connect("death",Callable(self,"die"))
		health_component.connect("hurted",Callable(self,"hurted"))


func _input(event: InputEvent) -> void:
	if ragdoll_text and event.is_action_pressed("M1"):
		ragdoll_component.start(true)


func hurted(who: Node3D, damage: float, attacker: Node3D, hit_pos := Vector3.INF) -> void:
	var random_x = randf_range(-1.0,1.0)
	var random_y = randf_range(-1.0,1.0)
	at["parameters/flinch_var/blend_position"] = Vector2(random_x,random_y)
	at["parameters/flinch/request"] = 1

	if not hit_pos.is_finite():
		hit_pos = who.global_position  # respaldo si no llega el punto
	
	var to_attacker := hit_pos.direction_to(attacker.global_position)
	GameManager.blood_splatter(hit_pos, to_attacker, who)
	_spawn_decals(hit_pos, to_attacker)
	if who.is_in_group("zombie_legs_left"):
		print_debug("OH MY LEG")
		state_machine.state.finished.emit("stun",{"direction":1})
	elif who.is_in_group("zombie_legs_right"):
		print_debug("OH MY LEG")
		state_machine.state.finished.emit("stun",{"direction":0})
		

func _spawn_decals(pos: Vector3, to_attacker: Vector3) -> void:
	var fx: BloodSplatter = BLOOD_SPLATTER.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.splash(pos, to_attacker, -to_attacker)  # (punto, normal, dirección de la bala)

func stagger(attacker:Node3D) -> void:
	if not attacker:
		return

	var forward = global_basis.z
	state_machine.state.finished.emit("stagger",{"dot":forward.dot(attacker.global_position.direction_to(global_position)),"attacker":attacker})



func handle_gravity(delta:float)-> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	


func die(who: Node3D, damage: float, attacker: Node3D,impulse:Vector3 = Vector3.ZERO,force: float = 10) -> void:
	state_machine.state.finished.emit("death")
	var imp := impulse
	if imp.length_squared() < 0.0001 and has_meta("melee_hit_dir"):
		imp = get_meta("melee_hit_dir") as Vector3
		force = force if force > 0.0 else 800.0
	ragdoll_component.start(true,imp,force)  # permanente, reemplaza physical_bones_start_simulation()
	if has_meta("melee_hit_dir"):
		remove_meta("melee_hit_dir")


func _on_ragdoll_component_recovered(face_up: bool) -> void:
	state_machine.state.finished.emit("recover",{"animation": "awake_up" if face_up else "awake_down"})
	

func _on_ragdoll_component_ragdoll_started() -> void:
	vision.can_see = false
	state_machine.state.finished.emit("stun",{"ragdoll":true})
	
	
