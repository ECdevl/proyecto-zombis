class_name ZombieVision extends Node

signal target_spotted(target: Node3D)
signal target_lost(target: Variant)

@export var eye: Node3D  # Marker3D a la altura de los ojos
@export_range(1.0, 360.0) var fov_degrees: float = 120.0
@export_flags_3d_physics var sight_mask: int = 1  # mundo + jugador, SIN capa 7
## -1 si el modelo mira hacia -Z, 1 si mira hacia +Z
@export var forward_sign: float = -1.0
## 0 = sin límite
@export var max_distance: float = 0.0
## Cada cuántos segundos revisa. No hace falta hacerlo en cada frame.
@export var check_interval: float = 0.1

var target: Player
var can_see: bool = false
var _cos_half_fov: float
var _time_left: float


func _ready() -> void:
	_cos_half_fov = cos(deg_to_rad(fov_degrees * 0.5))
	_time_left = randf() * check_interval  # desfasa a los zombis entre sí


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = check_interval

	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Player
		if target == null:
			return
	_set_seen(_check_sight())


func _set_seen(seen: bool) -> void:
	if seen == can_see:
		return
	can_see = seen
	if seen:
		target_spotted.emit(target)
	else:
		target_lost.emit(target)


func _check_sight() -> bool:
	var eye_pos := eye.global_position
	var target_pos := target.global_position
	target_pos.y = .75

	var to_target := target_pos - eye_pos

	# 0) Distancia (length_squared evita la raíz cuadrada)
	if max_distance > 0.0 and to_target.length_squared() > max_distance * max_distance:
		return false

	# 1) Ángulo
	to_target.y = 0.0
	var forward: Vector3 = owner.global_transform.basis.z * forward_sign
	forward.y = 0.0
	if forward.normalized().dot(to_target.normalized()) < _cos_half_fov:
		return false

	# 2) Pared
	var query := PhysicsRayQueryParameters3D.create(eye_pos, target_pos, sight_mask)
	query.exclude = [(owner as CollisionObject3D).get_rid()]
	var hit := eye.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target
