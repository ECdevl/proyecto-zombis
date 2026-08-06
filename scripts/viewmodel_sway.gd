extends Node

@export var sway_amount := 0.001
@export var sway_speed := 8.0
@export var bob_amount := 0.02
@export var bob_speed := 10.0
@onready var state_machine: StateMachine = %StateMachine

var mouse_delta := Vector2.ZERO
var sway_target := Vector3.ZERO
var bob_time := 0.0
var player : Player

func _ready() -> void:
	player = get_parent()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_delta = event.screen_relative
@onready var arms_fsm: StateMachine = %ArmsFSM

func _process(delta: float) -> void:
	if not player.viewmodel:
		return
	# Sway por mouse
	sway_target = sway_target.lerp(
		Vector3(-mouse_delta.x, mouse_delta.y, 0) * sway_amount,
		delta * sway_speed
	)
	mouse_delta = Vector2.ZERO # se resetea cada frame, solo se llena si hay evento

	# Bobbing por movimiento
	var bob_offset := Vector3.ZERO
	if state_machine.state.name == "walk" or state_machine.state.name == "run": # tu variable de estado
		if not arms_fsm.state.name in ["aim","aim_shoot"]:
			bob_time += delta * bob_speed
			bob_offset = Vector3(sin(bob_time) * bob_amount, absf(cos(bob_time)) * bob_amount, 0)

	player.viewmodel.position = sway_target + bob_offset
