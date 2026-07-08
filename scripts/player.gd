extends CharacterBody3D
class_name Player

const CAM_HEIGHT_STAND  : float = 1.5
const CAM_HEIGHT_CROUCH : float = 0.75
const CAM_HEIGHT_PRONE : float = 0.2
@export var player_needs : PlayerNeeds
@export var player_stats : PlayerStats
@export var can_swing : bool = true
@export var can_debug : bool = false
@export_category("To Assign")
## Set action to change Input.mouse_mode to Input.MOUSE_MODE_VISIBLE. 
## Default is "ui_cancel", set to the Escape key.
@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin") var input_mouse_mode  : StringName = "ui_cancel"
@export_group("Movement Actions")
@export_subgroup("Movement Keys")
@export_custom(PROPERTY_HINT_INPUT_NAME, "") var forward  : StringName 
@export_custom(PROPERTY_HINT_INPUT_NAME, "") var backward : StringName
@export_custom(PROPERTY_HINT_INPUT_NAME, "") var left     : StringName
@export_custom(PROPERTY_HINT_INPUT_NAME, "") var right    : StringName
@export_subgroup("")
@export_custom(PROPERTY_HINT_INPUT_NAME, "") var sprint   : StringName
@export_custom(PROPERTY_HINT_INPUT_NAME, "") var crouch   : StringName
@export_custom(PROPERTY_HINT_INPUT_NAME, "") var jump     : StringName
@export_custom(PROPERTY_HINT_INPUT_NAME, "") var prone     : StringName
@export_group("")
@export_category("Character Settings")
## Character's walk speed.
## This controls how fast the character
## walks.
@export var walk_speed    : float = 5.0
## Character's sprint speed.
## This controls how fast the character
## sprints.
@export var sprint_speed  : float = 8.0
## Character's crouch speed.
## This controls how fast the character
## moves while crouched.
@export var crouch_speed : float = 1.5
## Character's jump velocity.
## This controls how high the character
## jumps.
@export var jump_velocity : float = 4.5
## Character's sprint jump velocity.
## This controls how high the character
## jumps during sprint.
@export var sprint_jump_velocity : float = 9.0
@export var hang_velocity : float = 2.0
@export_category("Camera Settings")
## Affects camera sensitivity. Ranges from 0.0 to 10.0.
@export_range(0.0, 10.0, 0.1) var camera_sensitivity : float = 5.0

@onready var yaw    : Node3D   = %Yaw
@onready var pitch  : Node3D   = %Pitch
@onready var camera : Camera3D = %Camera3D


@onready var collision_crouched   : CollisionShape3D = %CrouchedCollisionShape
@onready var collision_standing   : CollisionShape3D = %StandingCollisionShape
@onready var collision_prone : CollisionShape3D = %ProneCollisionShape
@onready var armsy: Node3D = %armsy
@onready var arms_ap: AnimationPlayer 
@onready var ui: UI = %UI
var arms_mesh: MeshInstance3D 

var can_move : bool = true

@onready var animation_tree: AnimationTree = %AnimationTree
var playback : AnimationNodeStateMachinePlayback 



var _input_direction := Vector2.ZERO
var direction : Vector3
var _mouse_delta := Vector2.ZERO

var speed : float = 3.0


# Engine virtuals


func _ready() -> void:
	ui.connect("equip_weapon",Callable(self,"equip_weapon"))
	arms_ap = armsy.get_node("AnimationPlayer")
	arms_mesh = armsy.get_child(0).get_child(0).get_node("ArmsMesh")
	playback = animation_tree.get("parameters/playback")
	# Redundancy checks to avoid mistakes
	assert(self is CharacterBody3D, "This script only works within a CharacterBody3D")
	#assert(camera.get_parent() == pitch, "Camera needs to be a child of pitch")
	assert(pitch.get_parent() == yaw, "Pitch needs to be a child of yaw")
	assert(yaw.get_parent() == self, "Yaw needs to be a child of this CharacterBody3D")
	camera_sensitivity = camera_sensitivity / 1000
	yaw.position.y = CAM_HEIGHT_STAND
	speed = walk_speed
	arms_ap.play("Idle")
	
@onready var look_at_component: RayCast3D = %LookAtComponent
@onready var weapon_grip: Node3D = %weapon_grip

signal weapon_changed(gun:Weapon)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use"):
		if look_at_component.is_colliding():
			if look_at_component.get_collider() is PickableItem:
				var objeto : PickableItem = look_at_component.get_collider()
				ui.add_item(objeto.item_resource)
				if objeto.item_resource is Weapon and !get_current_weapon():
					equip_weapon(objeto.item_resource)
				objeto.queue_free()

	if event is InputEventMouseButton:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed(input_mouse_mode) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	__camera_input(event)


func _physics_process(delta: float) -> void:
	__player_movement(delta)
	_gravity(delta)

func _process(_delta: float) -> void:

	if look_at_component.is_colliding():
		var obj : Node3D = look_at_component.get_collider()
		if obj is PickableItem:
			pass
	if can_debug:
		print_debug(velocity.y)
		print_debug("CURRENT STATE: ", %StateMachine.state.name)
	pass

func __camera_input(event : InputEvent) -> void:
	if event is not InputEventMouseMotion:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative

func _camera_movement(limit_yaw:bool = false, from:float = 0.0) -> void:
	yaw.rotate_y(-_mouse_delta.x * camera_sensitivity)
	pitch.rotate_x(-_mouse_delta.y * camera_sensitivity)
	pitch.rotation.x = clampf(pitch.rotation.x, -PI/3, PI/3)
	if limit_yaw:
		yaw.rotation.y = clampf(yaw.rotation.y,from - deg_to_rad(45),from + deg_to_rad(45))
	_mouse_delta = Vector2.ZERO

func _gravity(delta: float) -> void:
	if !is_on_floor():
		velocity.y += get_gravity().y * delta

func __player_movement(delta:float) -> void:
	_input_direction = Input.get_vector(left, right, forward, backward)
	if !%StateMachine.state.name == "hang":
		direction = (yaw.transform.basis * Vector3(_input_direction.x  , 0, _input_direction.y  )).normalized()
	else:
		direction = (yaw.transform.basis * Vector3(_input_direction.x  , 0, 0  )).normalized()
	if can_move:
		velocity.x = direction.x * speed / player_stats.base_speed
		velocity.z = direction.z * speed / player_stats.base_speed

	
	move_and_slide()









func equip_weapon(resource:Weapon):
	emit_signal("weapon_changed",resource)

func drop_item(item:Item):
	if !item:
		return
	const PICKABLE_OBJECT = preload("uid://dnwmecb1siwnm")
	var object : PickableItem = PICKABLE_OBJECT.instantiate()
	object.item_resource = item
	get_tree().current_scene.add_child(object)
	if look_at_component.is_colliding():
		object.global_position = look_at_component.get_collision_point()
	else:
		object.global_position = look_at_component.target_position
		weapon_grip.get_child(0).mesh = null
	emit_signal("weapon_changed",null)

func get_current_weapon() -> Weapon:
	return %idle.current_weapon
	
