extends PlayerComponent

var player : Player
var _left_held : bool = false
var _right_held : bool = false
var _lean_tween : Tween

@export var lean_amount : float = 2.0
@export var lean_degrees : float = 25.0
const LEAN_WALL_MARGIN : float = 0.05

func _ready() -> void:
	player = owner

func _process(_delta: float) -> void:
	if enabled == false or player == null:
		return
	if _can_lean():
		return
	if _left_held or _right_held:
		_left_held = false
		_right_held = false
		_lean_tween = null
		reset()

func _input(event: InputEvent) -> void:
	if enabled == false or player == null:
		return
	if not _can_lean():
		_left_held = false
		_right_held = false
		_lean_tween = null
		reset()
		return
	if event.is_action_pressed("lean_left"):
		_left_held = true
	elif event.is_action_released("lean_left"):
		_left_held = false
	if event.is_action_pressed("lean_right"):
		_right_held = true
	elif event.is_action_released("lean_right"):
		_right_held = false
	if _left_held or _right_held:
		_lean()
	else:
		_left_held = false
		_right_held = false
		_lean_tween = null
		reset()

func reset() -> void:
	if _lean_tween:
		_lean_tween.kill()
		_lean_tween = null
	var tween : Tween = create_tween()
	tween.tween_property(player.pitch, "rotation_degrees:z", 0.0, 0.15)
	tween.tween_property(player.pitch, "position:x", 0.0, 0.15)

func _lean() -> void:
	if _lean_tween:
		_lean_tween.kill()
		_lean_tween = null
	var desired_x : float = 0.0
	if _left_held:
		desired_x = -lean_amount
	else:
		desired_x = lean_amount
	var pitch_transform : Transform3D = player.pitch.global_transform
	var desired_origin : Vector3 = pitch_transform.origin
	desired_origin.x = desired_x
	var desired_pitch_transform := Transform3D(pitch_transform.basis, desired_origin)
	var head_transform := player.yaw.global_transform * desired_pitch_transform
	var head : Vector3 = head_transform.origin
	head += Vector3(0.0, 1.0, 0.0)
	var lateral : Vector3 = player.yaw.global_transform.basis * Vector3(desired_x, 0.0, 0.0)
	var target : Vector3 = head + lateral
	var query := PhysicsRayQueryParameters3D.create(head, target, 1, [player])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_distance : float = result.position.distance_to(head)
		var margin : float = LEAN_WALL_MARGIN
		if hit_distance > margin:
			var allowed : float = hit_distance - margin
			desired_x = clampf(desired_x, -allowed, allowed)
	var final_x : float = clampf(desired_x, -lean_amount, lean_amount)
	var final_z : float = -lean_degrees if _right_held else lean_degrees
	var tween : Tween = create_tween()
	tween.tween_property(player.pitch, "rotation_degrees:z", final_z, 0.15)
	tween.tween_property(player.pitch, "position:x", final_x, 0.15)
	_lean_tween = tween

func _can_lean() -> bool:
	return enabled and player != null and not player.is_dead and player.grabber == null and not player.is_input_locked() and player.is_on_floor()
