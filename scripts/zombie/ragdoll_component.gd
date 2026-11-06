class_name ZombieRagdoll extends Node
## Ragdoll temporal: se activa en el aire, el zombi sigue a la pelvis
## y se levanta cuando la pelvis queda quieta cerca del piso.

signal ragdoll_started
signal animation_face(face_up: bool)
signal recovered(face_up: bool)  # true = boca arriba

@export var body: CharacterBody3D
@export var simulator: PhysicalBoneSimulator3D
@export var pelvis: PhysicalBone3D
## Segundos en el aire antes de caer en ragdoll (evita falsos positivos en escalones).
@export var air_time_to_ragdoll := 0.5
## Tiempo mínimo en ragdoll antes de poder levantarse.
@export var min_ragdoll_time := 2.0
## Velocidad (m/s) por debajo de la cual la pelvis cuenta como "quieta".
@export var rest_speed := 0.3
## Distancia máxima pelvis-piso para considerar que tocó el piso.
@export var floor_check_distance := 0.6
@export_flags_3d_physics var floor_mask: int = 1  # solo mundo, no los huesos
## Eje LOCAL de la pelvis que sale del vientre. Calibrar (ver nota abajo).
@export var front_axis := Vector3.FORWARD

var is_ragdoll := false
var permanent := false  # true = muerto, nunca se levanta
var _air_time := 0.0
var _ragdoll_time := 0.0


func _ready() -> void:
	# Los huesos no chocan con la cápsula del zombi.
	simulator.physical_bones_add_collision_exception(body.get_rid())

@export var default_push_bone : PhysicalBone3D
func start(is_permanent := false,impulse: Vector3 = Vector3.ZERO,force: float = 0.0,bone:PhysicalBone3D = null) -> void:
	simulator.influence = 1.0
	permanent = is_permanent
	if is_ragdoll:
		return
	is_ragdoll = true
	
	_ragdoll_time = 0.0
	simulator.physical_bones_start_simulation()
	if not bone:
		default_push_bone.apply_central_impulse(impulse * force)
	else:
		bone.apply_central_impulse(impulse*force)
	ragdoll_started.emit()



func _physics_process(delta: float) -> void:

	if not is_ragdoll:
		_air_time = 0.0 if body.is_on_floor() else _air_time + delta
		if _air_time >= air_time_to_ragdoll:
			
			start()
		return

	# La pelvis manda: el zombi va donde esté ella.
	body.global_position = pelvis.global_position
	body.velocity = Vector3.ZERO  # evita que la gravedad se acumule

	if permanent:
		return
	_ragdoll_time += delta
	if _ragdoll_time >= min_ragdoll_time and _is_resting():
		_recover()


func _is_resting() -> bool:
	# length_squared() evita la raíz cuadrada: v² < rest² equivale a v < rest.
	print_debug(pelvis.linear_velocity.length_squared())
	return pelvis.linear_velocity.length_squared() < rest_speed * rest_speed \
			and _find_floor() != null


## Punto del piso bajo la pelvis, o null si no hay piso cerca.
func _find_floor() -> Variant:
	var from := pelvis.global_position
	var to := from + Vector3.DOWN * floor_check_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, floor_mask)
	query.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.position



func _recover() -> void:
	_air_time = 0
	var floor_pos: Variant = _find_floor()
	if floor_pos == null:
		return
	# Boca arriba si el vientre apunta hacia arriba (dot > 0).
	var front: Vector3 = pelvis.global_basis * front_axis
	var face_up := front.dot(Vector3.UP) > 0.0
	simulator.physical_bones_stop_simulation()
	body.global_position = floor_pos  # los pies al piso, no a la altura de la pelvis
	
	if face_up:
		pass
	is_ragdoll = false
	recovered.emit(face_up)
	
