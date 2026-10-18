extends Node3D

@export var target_pos : Vector3 = Vector3.FORWARD
@export var speed : float = 75.0
@export var length : int = 1

const MAX_LIFETIME_MS = 5000

@onready var spawn_time = Time.get_ticks_msec()

func _process(delta: float) -> void:
	var diff = target_pos - global_position
	var add = diff.normalized() * speed * delta
	add = add.limit_length(diff.length())
	global_position += add
	if (target_pos - global_position).length() <= length or Time.get_ticks_msec() - spawn_time > MAX_LIFETIME_MS:
		queue_free()
