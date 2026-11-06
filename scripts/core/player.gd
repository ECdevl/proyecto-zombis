extends CharacterBody3D
class_name Player


signal item_consumed(proceed:bool)

const CAM_HEIGHT_STAND  : float = 1.5
const CAM_HEIGHT_CROUCH : float = 0.75
const CAM_HEIGHT_PRONE  : float = 0.2
const CAM_LERP_TIME     : float = 0.2

func tween_cam_height(target: float, duration: float = CAM_LERP_TIME) -> void:
	if not is_instance_valid(yaw):
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(yaw, "position:y", target, duration)

@export var player_needs : PlayerNeeds
@export var player_stats : PlayerStats
@export var health_component : HealthComponent
## Lo que el jugador carga. Lo tiene el Player (es estado de juego), no la UI.
@export var inventory: PlayerCarriedInventories
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
@export_category("Nodes References")
@export var ARMS_PISTOL : Node3D

var weapon_scene : Node3D
var weapon_AP : AnimationPlayer
@onready var weapon_pivot: Node3D = %WeaponPivot
@onready var ads_controller: ADSController = %ADSController

@onready var yaw    : Node3D   = %Yaw
@onready var pitch  : Node3D   = %Pitch
@onready var camera : Camera3D = %Camera3D



@onready var collision_crouched   : CollisionShape3D = %CrouchedCollisionShape
@onready var collision_standing   : CollisionShape3D = %StandingCollisionShape
@onready var collision_prone : CollisionShape3D = %ProneCollisionShape
@onready var armsy: Node3D = %armsy
@onready var view_punch: ViewPunch = %ViewPunch

@onready var weapon_controller: WeaponController = %WeaponController

## Viewmodel unificado (arma + brazos juntos)
var current_viewmodel: Node3D
var viewmodel_ap: AnimationPlayer
var viewmodel_animation_tree: AnimationTree
var viewmodel_playback: AnimationNodeStateMachinePlayback


var arms_ap: AnimationPlayer 
@onready var body_at: AnimationTree = %BodyAT
var body_at_playback : AnimationNodeStateMachinePlayback

@onready var animation_tree: AnimationTree = %AnimationTree

var arms_mesh: MeshInstance3D 
var can_move : bool = true
var playback : AnimationNodeStateMachinePlayback 
var looking_at_obj : Node3D = Node3D.new()

var _input_direction := Vector2.ZERO
var direction : Vector3
var _mouse_delta := Vector2.ZERO

var speed : float = 3.0
@onready var ui: UI = %UI

func _ready() -> void:
	health_component = health_component.duplicate()
	health_component.hurted.connect(hurted)

	#ui.inventory_manager.connect("equip_weapon",Callable(self,"equip_weapon"))
	inventory.hands.main_weapon_changed.connect(equip_weapon)
	grabbed_object.connect(_on_grabbed_object)
	arms_ap = armsy.get_node("AnimationPlayer")
	arms_mesh = armsy.find_child("PiernaIzquierda",true,false)
	playback = animation_tree.get("parameters/player_sm/playback")
	# Redundancy checks to avoid mistakes
	#assert(camera.get_parent() == pitch, "Camera needs to be a child of pitch")
	assert(pitch.get_parent() == yaw, "Pitch needs to be a child of yaw")
	assert(yaw.get_parent() == self, "Yaw needs to be a child of this CharacterBody3D")
	camera_sensitivity = camera_sensitivity / 1000
	yaw.position.y = CAM_HEIGHT_STAND
	speed = walk_speed
	if arms_ap:
		arms_ap.play("idle")
	body_at_playback = body_at["parameters/body/playback"]

	
@onready var look_at_component: RayCast3D = %LookAtComponent

signal weapon_changed(gun:Resource)

signal grabbed_object(world_obj:Node3D)
signal loot_opened(model:InventoryModel,display:String)

func hurted(damage:float,info:Dictionary) -> void:
	view_punch.punch(Vector2(damage,0))
	ui.flash_hurt()
	
func _try_interact(hit_object: Node) -> void:
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
	__camera_input(event)
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
	_input_direction = Input.get_vector(left, right, forward, backward)
	if %StateMachine.state.name != "hang":
		direction = (yaw.transform.basis * Vector3(_input_direction.x  , 0, _input_direction.y  )).normalized()
	else:
		direction = (yaw.transform.basis * Vector3(_input_direction.x  , 0, 0  )).normalized()
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

	if direction == Vector3.ZERO:
		if is_on_floor():
			# Sin input en el suelo: frenar hasta 0 con deceleration.
			horizontal = horizontal.move_toward(Vector3.ZERO, player_stats.deceleration * delta)
			velocity.x = horizontal.x
			velocity.z = horizontal.z
		# Sin input en el aire: no tocar la horizontal, el impulso del salto
		# se conserva (el aire no frena).
	else:
		var target: Vector3 = direction * speed / player_stats.base_speed
		# Contra-giro: si la velocidad actual apunta en CONTRA de la dirección
		# pedida, frenar (respuesta inmediata); si va a favor (o estamos
		# parados), acelerar.
		var rate: float = player_stats.deceleration
		if horizontal == Vector3.ZERO or horizontal.normalized().dot(direction) >= 0.0:
			rate = player_stats.acceleration
		if not is_on_floor():
			rate *= player_stats.air_control
		horizontal = horizontal.move_toward(target, rate * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

	move_and_slide()



## Velocidad de salida al soltar un objeto (m/s). Es VELOCIDAD, no fuerza:
## al fijar la velocidad directamente, el lanzamiento se siente igual
## cualquier que sea la masa del objeto (una mochila y una lata salen igual).
const THROW_SPEED: float = 6.0
## Distancia frente a la cámara donde aparece el objeto soltado.
const DROP_DISTANCE: float = 0.6


## Escena prefabricada del objeto agarrable (D-009): al soltar se instancia
## SIEMPRE ésta; el descriptor solo aporta el mesh (ItemDescriptor.item_mesh).
const PICKABLE_SCENE := preload("res://scenes/components/pickable_object.tscn")


## Suelta un objeto del inventario en el mundo físico.
## Quien llame (UI o estado de brazos) debe sacarlo del inventario ANTES.
## Si no se puede soltar, el item se devuelve al inventario: nunca se pierde.
func drop_item(item: ItemInstance) -> void:
	if item == null:
		return
	if not %normal.can_transition:  # recargando: no se suelta (y no se pierde)
		inventory.add_anywhere(item)
		return
	if item.descriptor.item_mesh == null:
		push_warning("drop_item: '%s' no tiene item_mesh." % item.descriptor.item_name)
		inventory.add_anywhere(item)  # se devuelve: el item no se pierde
		return
	var pickable: PickableItem = PICKABLE_SCENE.instantiate()
	pickable.item_descriptor = item.descriptor
	pickable.item = item  # conserva contenido y estado (antes de entrar al árbol)
	get_tree().current_scene.add_child(pickable)
	var forward := -camera.global_transform.basis.z
	pickable.global_position = camera.global_position + forward * DROP_DISTANCE
	pickable.launch(forward * THROW_SPEED)
	weapon_controller.update_inventory_ammo(item)



func equip_weapon(resource:EquippableDescriptor) -> void:
	if resource != get_current_weapon():
		weapon_changed.emit(resource)
		return
	weapon_changed.emit(null)



func get_current_weapon() -> EquippableDescriptor:
	return weapon_controller.current_weapon
	


## La UI pidió usar un objeto (comida, bebida, medicina): el Player decide qué
## estado del FSM de brazos corresponde y lo pide.
func use_item(item: ItemInstance) -> void:
	await get_tree().process_frame
	%ArmsFSM.state.finished.emit("consuming", {"item": item})


## El jugador agarró un objeto del mundo: entra al inventario y se anima.
func _on_grabbed_object(world_obj: Node3D) -> void:
	if not inventory.pick_up(world_obj.item):
		print_debug("No entra en ningún lado")
		return

	weapon_controller.play_grab_animation()
	_animate_grab(world_obj)
	weapon_controller.update_inventory_ammo(world_obj)
	


## Arrastra el objeto del mundo hasta el jugador y lo libera.
func _animate_grab(what: PickableItem) -> void:
	var tween = create_tween()
	tween.tween_property(what,"global_position",global_position,0.15)
	await tween.finished
	if is_instance_valid(what):
		what.queue_free()

signal grab_escaped  # el jugador llenó la barra de escape

var grabber: CharacterBody3D
var grab_anchor: Node3D

func get_grabbed(by: CharacterBody3D, anchor: Node3D) -> void:
	if grabber:
		return
	grabber = by
	grab_anchor = anchor
	var data := {"grabber": by, "anchor": anchor}
	%StateMachine.state.finished.emit("grabbed", data)
	%ArmsFSM.state.can_transition = true  # aunque esté recargando
	%ArmsFSM.state.finished.emit("grabbed", data)

func end_grab() -> void:
	if not grabber:
		return
	grabber = null
	grab_anchor = null
	%StateMachine.state.finished.emit("idle")
	%ArmsFSM.state.finished.emit("normal")
