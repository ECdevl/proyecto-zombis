extends Area3D
class_name DoorComponent

signal door_opened

enum Type {ROTATE,MOVE}
enum forward_dir {X,Y,Z}
@export var locked : bool = false
@export var direction : Vector3
@export var rotation_axis : Vector3 = Vector3(0,1,0)
@export var rot_amount : float
@export var forward_direction : forward_dir
@export var transition : Tween.TransitionType
@export var ease : Tween.EaseType
@export var door_type : Type = Type.ROTATE
@export var close_timer : float = 5.0
var opener : CharacterBody3D

var open : bool = false
var parent
var timer : Timer
var origin_pos
var origin_rot
var rot_adjust : int = 1

var closing : bool = false
func _ready() -> void:
	set_collision_layer_value(5,true)
	connect("body_entered", Callable(self, "_on_body_entered"))

	parent = get_parent()
	origin_pos = parent.position
	
	origin_rot = parent.rotation

func _get_hint() -> String:
	return "Press USE to open/close"

func interact(target:Node3D):
	check_door(target)



func check_door(target: Node3D = null):
	if target:
		opener = target
	var door_direction : Vector3
	match forward_direction:
		forward_dir.X:
			door_direction = Vector3(1,0,0)
		forward_dir.Z:
			door_direction = Vector3(0,0,1)
			rot_amount *= -1

		forward_dir.Y:
			door_direction = parent.global_transform.basis.y
			
	var door_pos : Vector3 = parent.global_position
	var player_pos : Vector3 = opener.global_position
	var dir_to_player : Vector3 = door_pos.direction_to(player_pos)
	var dot_product : float = dir_to_player.dot(door_direction)

	
	if dot_product > 0:
		rot_adjust = 1
	else:
		rot_adjust = -1
	
	if open:
		close_door()
		return
	else:
		print_debug("ok")

	if !locked:
		if !open:
			open_door()
		else:
			print_debug("no")
	else:
		print_debug("door is locked")

		


func open_door():

	closing = false
	open = true
	match door_type:
		Type.ROTATE:
			var tween = create_tween()
			tween.tween_property(parent,"rotation",origin_rot + (rotation_axis * rot_adjust * deg_to_rad(rot_amount)),.5).set_trans(transition).set_ease(ease)
			emit_signal("door_opened")
		Type.MOVE:
			var tween = create_tween()
			tween.tween_property(parent,"position", origin_pos + (direction),.5).set_trans(transition).set_ease(ease)

func close_door():

	closing = true
	open = false
	var tween = create_tween()
	match door_type:
		Type.ROTATE:
			var start_rot = parent.rotation
			var target_rot = Vector3(
				origin_rot.x,
				start_rot.y + lerp_angle(0.0, origin_rot.y - start_rot.y, 1.0),
				origin_rot.z
			)
			tween.tween_property(parent, "rotation", target_rot, 0.5).set_trans(transition).set_ease(ease)
		Type.MOVE:
			tween.tween_property(parent, "position", origin_pos, .5).set_trans(transition).set_ease(ease)
	await tween.finished
	closing = false
