class_name ZombieVision extends Area3D

signal target_spotted(target: Node3D)
signal target_lost

@export var eye: Node3D  # Marker3D a la altura de los ojos
@export_range(1.0, 360.0) var fov_degrees: float = 120.0
@export_flags_3d_physics var sight_mask: int = 1  # mundo + jugador, SIN capa 7
## -1 si el modelo mira hacia -Z, 1 si mira hacia +Z
@export var forward_sign: float = -1.0

var target: Player
var can_see: bool = false
var _cos_half_fov: float

func _ready() -> void:
	_cos_half_fov = cos(deg_to_rad(fov_degrees * 0.5))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	
	if body is Player:

		target = body
		if not _check_sight():
			target = null

func _on_body_exited(body: Node3D) -> void:
	if body == target:
		target = null
		_set_seen(false)

func _physics_process(_delta: float) -> void:
	
	if target:
		_set_seen(_check_sight())
	
func _set_seen(seen: bool) -> void:
	if seen == can_see:
		return
	can_see = seen
	if seen:
		target_spotted.emit(target)
	else:
		target_lost.emit()

func _check_sight() -> bool:
	var eye_pos := eye.global_position
	var target_pos := target.global_position  # cabeza: baja sola al agacharse/echarse
	target_pos.y = .75

	# 1) Ángulo
	var to_target := target_pos - eye_pos
	to_target.y = 0.0
	var forward: Vector3 = owner.global_transform.basis.z * forward_sign
	forward.y = 0.0
	if forward.normalized().dot(to_target.normalized()) < _cos_half_fov:
		return false

	# 2) Pared
	var query := PhysicsRayQueryParameters3D.create(eye_pos, target_pos, sight_mask)
	query.exclude = [(owner as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target
