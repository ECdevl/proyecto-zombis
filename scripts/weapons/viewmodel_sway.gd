extends Node

signal footstep

@export var sway_amount: float = 0.001
@export var sway_speed: float = 8.0
@export var bob_amount: float = 0.02
@export var bob_speed: float = 5.0
@onready var state_machine: StateMachine = %StateMachine
@onready var arms_fsm: StateMachine = %ArmsFSM
@onready var weapon_pivot: Node3D = %WeaponPivot

var mouse_delta: Vector2 = Vector2.ZERO
var sway_target: Vector3 = Vector3.ZERO
var bob_time: float = 0.0
var player: Player
var _last_step_phase: float = 0.0

func _ready() -> void:
	player = get_parent()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_delta = event.screen_relative

func _process(delta: float) -> void:
	var mouse_step: Vector2 = mouse_delta
	mouse_delta = Vector2.ZERO
	var moving: bool = state_machine.state.name == "walk" or state_machine.state.name == "run"
	var bobbing: bool = moving and not arms_fsm.state.name in ["aim", "aim_shoot"]
	if bobbing:
		advance_footsteps(delta)
	if not player.get_current_weapon():
		return
	## Mientras se apunta, el ADSControl es dueño del weapon_pivot (blend por
	## transform); pelear con el sway por position causa jitter (E-027).
	if player.ads_controller and player.ads_controller.aiming:
		return
	sway_target = sway_target.lerp(
		Vector3(-mouse_step.x, mouse_step.y, 0) * sway_amount,
		delta * sway_speed
	)
	var bob_offset: Vector3 = Vector3.ZERO
	if bobbing:
		bob_offset = Vector3(sin(bob_time) * bob_amount, absf(cos(bob_time)) * bob_amount, 0)
	weapon_pivot.position = sway_target + bob_offset

func advance_footsteps(delta: float) -> void:
	bob_time += delta * bob_speed
	var phase: float = fmod(bob_time, PI)
	if phase < _last_step_phase:
		footstep.emit()
	_last_step_phase = phase
