class_name MovementStateMachine
extends Node

var _can_debug       : bool
var _crouch_pressed  : bool

var target           : Player

var crouch_action    : StringName
var jump_action      : StringName
var sprint_action    : StringName

var _current_state   : MovementState
var idle_state       : IdleMovementState
var jump_state       : JumpMovementState
var fall_state       : FallMovementState
var sprint_state     : SprintMovementState
var walk_state       : WalkMovementState

func _ready() -> void:
	idle_state   = IdleMovementState.new(self)
	walk_state   = WalkMovementState.new(self)
	sprint_state = SprintMovementState.new(self)
	jump_state   = JumpMovementState.new(self)
	fall_state   = FallMovementState.new(self)

func _input(event: InputEvent) -> void:
	_current_state._update_state_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if has_crouch() and event.is_action_pressed(crouch_action):
		_crouch_pressed = true
		change_stance_crouch()
	if has_crouch() and event.is_action_released(crouch_action):
		_crouch_pressed = false
		change_stance_stand()
	_current_state._update_state_unhandled_input(event)

func _process(delta: float) -> void:
	_current_state._update_state_process(delta)

func _physics_process(delta: float) -> void:
	if not target.is_on_floor() and _current_state != fall_state:
		change_state(fall_state)
	if not is_crouching():
		change_stance_check()
	_current_state._update_state_physics(delta)

func initialize_state_machine(character_body : Player, initial_state : MovementState, can_debug : bool = false) -> void:
	target = character_body
	_can_debug = can_debug
	if _can_debug:
		print_debug("Movement State Machine initialized, switching to Idle State\nCharacter target is " + str(target))
	change_state(initial_state)

func change_state(new_state : MovementState) -> void:
	if _current_state:
		_current_state._exit_state()
	_current_state = new_state
	_current_state._enter_state()

func change_stance_check() -> void:
	if target.shape_cast_standing.is_colliding():
		#if true:
			#await get_tree().create_timer(0.5).timeout
			#print_debug("ShapeCast3D is colliding")
		return
	change_stance_stand()

func change_stance_crouch() -> void:
	var yaw_tween = target.yaw.create_tween()
	yaw_tween.tween_property(target.yaw, "position:y", target.CAM_HEIGHT_CROUCH, 0.15)
	target.collision_standing.set_deferred("disabled", true)
	target.collision_crouched.set_deferred("disabled", false)
	
func change_stance_stand() -> void:
	if not target.shape_cast_standing.is_colliding():
		var yaw_tween = target.yaw.create_tween()
		yaw_tween.tween_property(target.yaw, "position:y", target.CAM_HEIGHT_STAND, 0.15)
		target.collision_crouched.set_deferred("disabled", true)
		target.collision_standing.set_deferred("disabled", false)

func has_crouch() -> bool:
	if crouch_action:
		return true
	if _can_debug:
		print_debug("No crouch button set")
	return false

func has_jump() -> bool:
	if jump_action:
		return true
	if _can_debug:
		print_debug("No jump button set")
	return false

func has_sprint() -> bool:
	if sprint_action:
		return true
	if _can_debug:
		print_debug("No sprint button set")
	return false

func is_crouching() -> bool:
	if not _crouch_pressed:
		return false
	return true

func set_crouch_action(new_crouch_action : StringName) -> void:
	crouch_action = new_crouch_action

func set_jump_action(new_jump_action : StringName) -> void:
	jump_action = new_jump_action

func set_sprint_action(new_sprint_action : StringName) -> void:
	sprint_action = new_sprint_action
