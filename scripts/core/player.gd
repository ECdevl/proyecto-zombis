extends CharacterBody3D
class_name Player


signal item_consumed(proceed:bool)
signal attacked_close

@export var player_needs : PlayerNeeds
@export var player_stats : PlayerStats
@export var health_component : HealthComponent
@export var inventory: PlayerCarriedInventories
@export var can_swing : bool = true
@export var can_debug : bool = false
@export_category("To Assign")
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
@export var walk_speed    : float = 5.0
@export var sprint_speed  : float = 8.0
@export var crouch_speed : float = 1.5
@export var jump_velocity : float = 4.5

@export var hang_velocity : float = 2.0
@export_category("Camera Settings")
@export_range(0.0, 10.0, 0.1) var camera_sensitivity : float = 5.0
@export_category("Nodes References")
@export var ARMS_PISTOL : Node3D

var weapon_scene : Node3D
var weapon_AP : AnimationPlayer
@onready var weapon_pivot: Node3D = %WeaponPivot
@onready var ads_controller: ADSController = %ADSController

@onready var yaw         : Node3D        = %Yaw
@onready var camera_rig  : NeckCameraRig = %CameraRig
@onready var pitch       : Node3D        = %Pitch
@onready var camera      : Camera3D      = %Camera3D



@onready var collision_crouched   : CollisionShape3D = %CrouchedCollisionShape
@onready var collision_standing   : CollisionShape3D = %StandingCollisionShape
@onready var collision_prone : CollisionShape3D = %ProneCollisionShape
@onready var armsy: Node3D = %armsy
@onready var view_punch: ViewPunch = %ViewPunch

@onready var weapon_controller: WeaponController = %WeaponController
@onready var flashlight_controller: FlashlightController = %FlashlightController

var current_viewmodel: Node3D
var viewmodel_ap: AnimationPlayer
var viewmodel_animation_tree: AnimationTree
var viewmodel_animator: ViewmodelAnimator = null
var viewmodel_playback: AnimationNodeStateMachinePlayback


var arms_ap: AnimationPlayer
@onready var body_at: AnimationTree = %BodyAT
var body_at_playback : AnimationNodeStateMachinePlayback

@onready var animation_tree: AnimationTree = %AnimationTree

var arms_mesh: MeshInstance3D
var can_move : bool = true
var playback : AnimationNodeStateMachinePlayback
var arms_animator: ArmsAnimator = ArmsAnimator.new()
var looking_at_obj : Node3D = null
var is_dead : bool = false
var _input_locks : Dictionary = {}

var _input_direction: Vector2 = Vector2.ZERO
var direction : Vector3
var _mouse_delta: Vector2 = Vector2.ZERO

var speed : float = 3.0
@onready var ui: UI = %UI

func _ready() -> void:
	health_component = health_component.duplicate()
	health_component.hurted.connect(hurted)
	health_component.death.connect(die)
	if player_needs:
		player_needs.health_component = health_component
	inventory.hands.main_weapon_changed.connect(equip_weapon)
	grabbed_object.connect(_on_grabbed_object)
	arms_ap = armsy.get_node("AnimationPlayer")
	arms_mesh = armsy.find_child("PiernaIzquierda",true,false)
	arms_animator.setup(animation_tree, arms_ap)
	playback = arms_animator.playback
	assert(camera.get_parent() == pitch, "Camera needs to be a child of pitch")
	assert(pitch.get_parent() == camera_rig, "Pitch needs to be a child of CameraRig")
	assert(camera_rig.get_parent() == yaw, "CameraRig needs to be a child of yaw")
	assert(yaw.get_parent() == self, "Yaw needs to be a child of this CharacterBody3D")
	camera_sensitivity = camera_sensitivity / 1000
	speed = walk_speed
	body_at_playback = body_at["parameters/body/playback"]


	
@onready var look_at_component: RayCast3D = %LookAtComponent

signal weapon_changed(gun:Resource)

signal grabbed_object(world_obj:Node3D)
signal loot_opened(model:InventoryModel,display:String)
signal player_death
@onready var hurt_claw: AudioStreamPlayer = %HurtClaw

func hurted(damage:float,info:Dictionary) -> void:
	if is_dead:
		return
	if info:
		if info.get("attacker"):
			if info.get("attacker") is Zombie:
				hurt_claw.play()
	view_punch.punch(Vector2(damage,0))
	ui.flash_hurt()

func set_input_lock(reason: StringName, locked: bool) -> void:
	if locked:
		_input_locks[reason] = true
	else:
		_input_locks.erase(reason)

func is_input_locked() -> bool:
	return not _input_locks.is_empty()

func can_perform(action: StringName) -> bool:
	if not can_act():
		return false
	var current_state : PlayerState = %StateMachine.state
	return current_state == null or current_state.is_action_allowed(action)

func can_act() -> bool:
	if is_dead or is_input_locked():
		return false
	if %ArmsFSM and %ArmsFSM.state and %ArmsFSM.state.name == "grabbed":
		return false
	return true

func can_be_grabbed() -> bool:
	return not is_dead and grabber == null

func die(damage:float,info:Dictionary) -> void:
	if is_dead:
		return
	is_dead = true
	can_move = false
	velocity = Vector3.ZERO
	set_input_lock(&"death", true)
	if is_instance_valid(ui):
		ui.close_inventory()
	if grabber:
		end_grab()
	ads_controller.aiming = false
	player_death.emit()

func _try_interact(hit_object: Node) -> void:
	if is_dead or is_input_locked():
		return
	if hit_object is ContainerInteractable:
		emit_signal("loot_opened",hit_object.inventory_model,hit_object.display_name)
	elif hit_object.has_method("interact"):
		hit_object.interact(self)
	elif hit_object is Area3D:
		if hit_object.owner is PickableItem:
			grabbed_object.emit(hit_object.owner)
	elif hit_object is DoorComponent:
		var door : DoorComponent = look_at_component.get_collider()
		door.check_door(self)
func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked():
		return
	__camera_input(event)
	if event.is_action_pressed("toggle_flashlight"):
		if flashlight_controller:
			flashlight_controller.toggle_flashlight()
	if event.is_action_pressed("use"):
		var object
		if look_at_component.is_colliding():
			_try_interact(look_at_component.get_collider())




	




	

func _physics_process(delta: float) -> void:
	__player_movement(delta)
	_gravity(delta)

func _process(_delta: float) -> void:

	if look_at_component.is_colliding():

		var obj : Node3D = look_at_component.get_collider()
		if obj is Area3D:
			obj = obj.owner
		looking_at_obj = obj
	else:
		looking_at_obj = null


func __camera_input(event : InputEvent) -> void:
	if event is not InputEventMouseMotion:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative
		

func _camera_movement(limit_yaw:bool = false, from:float = 0.0) -> void:
	yaw.rotate_y(-_mouse_delta.x * camera_sensitivity)
	pitch.rotate_x(-_mouse_delta.y * camera_sensitivity)
	pitch.rotation.x = clampf(pitch.rotation.x, -PI/2, PI/2)
	if limit_yaw:
		yaw.rotation.y = clampf(yaw.rotation.y,from - deg_to_rad(45),from + deg_to_rad(45))
	_mouse_delta = Vector2.ZERO

func _gravity(delta: float) -> void:
	if !is_on_floor():
		velocity.y += get_gravity().y * delta

func __player_movement(delta:float) -> void:
	if not can_move:
		return
	if is_input_locked():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	_input_direction = Input.get_vector(left, right, forward, backward)
	if %StateMachine.state.name != "hang":
		direction = (yaw.transform.basis * Vector3(_input_direction.x  , 0, _input_direction.y  )).normalized()
	else:
		direction = (yaw.transform.basis * Vector3(_input_direction.x  , 0, 0  )).normalized()
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

	if direction == Vector3.ZERO:
		if is_on_floor():
			horizontal = horizontal.move_toward(Vector3.ZERO, player_stats.deceleration * delta)
			velocity.x = horizontal.x
			velocity.z = horizontal.z
	else:
		var target: Vector3 = direction * speed / player_stats.base_speed
		var rate: float = player_stats.deceleration
		if horizontal == Vector3.ZERO or horizontal.normalized().dot(direction) >= 0.0:
			rate = player_stats.acceleration
		if not is_on_floor():
			rate *= player_stats.air_control
		horizontal = horizontal.move_toward(target, rate * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

	move_and_slide()





const THROW_SPEED: float = 6.0
const DROP_DISTANCE: float = 0.6


const PICKABLE_SCENE: PackedScene = preload("res://scenes/components/pickable_object.tscn")


func drop_item(item: ItemInstance) -> void:
	if item == null or is_dead:
		return
	if not %normal.can_transition:
		inventory.add_anywhere(item)
		return
	if item.descriptor.item_mesh == null and item.descriptor.has_method("ensure_item_mesh"):
		item.descriptor.ensure_item_mesh()
	if item.descriptor.item_mesh == null:
		push_warning("drop_item: '%s' no tiene item_mesh." % item.descriptor.item_name)
		inventory.add_anywhere(item)
		return
	var pickable: PickableItem = PICKABLE_SCENE.instantiate()
	pickable.item_descriptor = item.descriptor
	pickable.item = item
	get_tree().current_scene.add_child(pickable)
	var forward: Vector3 = -camera.global_transform.basis.z
	pickable.global_position = camera.global_position + forward * DROP_DISTANCE
	pickable.launch(forward * THROW_SPEED)
	weapon_controller.update_inventory_ammo(item)



func equip_weapon(resource:EquippableDescriptor) -> void:
	if resource == get_current_weapon():
		return
	weapon_changed.emit(resource)



func get_current_weapon() -> EquippableDescriptor:
	return weapon_controller.current_weapon
	


func use_item(item: ItemInstance) -> void:
	if is_dead or grabber != null:
		return
	await get_tree().process_frame
	if is_dead or grabber != null:
		return
	%ArmsFSM.state.can_transition = true
	%ArmsFSM.state.finished.emit("consuming", {"item": item})


func _on_grabbed_object(world_obj: Node3D) -> void:
	if not inventory.pick_up(world_obj.item):
		print_debug("No entra en ningún lado")
		return

	weapon_controller.play_grab_animation()
	_animate_grab(world_obj)
	weapon_controller.update_inventory_ammo(world_obj)
	

@onready var grab: AudioStreamPlayer3D = %grab

func _animate_grab(what: PickableItem) -> void:
	grab.play()
	var tween = create_tween()
	tween.tween_property(what,"global_position",global_position,0.15)
	await tween.finished
	if is_instance_valid(what):
		what.queue_free()

signal grab_escaped

var grabber: CharacterBody3D
var grab_anchor: Node3D

func get_grabbed(by: CharacterBody3D, anchor: Node3D) -> bool:
	if not can_be_grabbed():
		return false
	grabber = by
	grab_anchor = anchor
	if is_instance_valid(ui):
		ui.close_inventory()
	set_input_lock(&"grabbed", true)
	var data: Dictionary = {"grabber": by, "anchor": anchor}
	%StateMachine.state.finished.emit("grabbed", data)
	%ArmsFSM.state.can_transition = true
	%ArmsFSM.state.finished.emit("grabbed", data)
	return true

func end_grab() -> void:
	if not grabber:
		return
	grabber = null
	grab_anchor = null
	set_input_lock(&"grabbed", false)
	%StateMachine.state.finished.emit("idle")
	%ArmsFSM.state.finished.emit("normal")
