class_name BloodSplatter
extends Node3D
## Salpicadura de sangre sobre el entorno.
## Desde el punto de impacto lanza rayos en abanico (conos) y deja un Decal en
## cada superficie que encuentra. Solo dibuja: no toca daño ni vida.

const MAX_DECALS := 60

## Decals vivos, el más viejo primero. Es estático: se comparte entre instancias.
static var _decals: Array[Decal] = []

@export var splat_textures: Array[Texture2D]
## Capas de FÍSICA donde puede pegarse la sangre (1 = mundo). No incluir zombis.
@export_flags_3d_physics var world_mask: int = 1
## Capas VISUALES sobre las que se proyecta el decal. Dejar fuera zombis/jugador.
@export_flags_3d_render var decal_cull_mask: int = 1
@export var decal_lifetime := 20.0
@export var fade_time := 5.0
var custom_parent : Node3D

## pos: punto de impacto. normal: normal de la superficie golpeada.
## shot_dir: dirección de salida del proyectil/tajo (normalizada).
## intensity: 1 = golpe normal; los valores bajos (pierna 0.1) apenas
## salpican y los altos (cabeza/muerte) ensucian más y más lejos.
func splash(pos: Vector3, normal: Vector3, shot_dir: Vector3, intensity: float = 1.0) -> void:
	global_position = pos + normal * 0.05
	await get_tree().physics_frame  # el raycast directo se hace en frame de física
	if not is_instance_valid(self):
		return
	var space := get_world_3d().direct_space_state
	var k: float = clampf(intensity, 0.15, 1.6)
	_spray(space, shot_dir, 35.0, maxi(2, int(6.0 * k)), 2.5 + 2.5 * k, k)  # salida: pared de atrás
	_spray(space, normal, 60.0, maxi(1, int(3.0 * k)), 1.2 + 1.2 * k, k)  # rebote hacia el tirador
	# Donde cae: la segunda mitad de las gotas va al piso. Se proyecta
	# también el punto de aterrizaje por delante, siguiendo el chorro.
	_spray(space, Vector3.DOWN, 50.0, maxi(1, int(4.0 * k)), 2.0 + 2.0 * k, k)
	_ground_drop(space, shot_dir, 1.0 + 2.0 * k, k)
	queue_free()

func _process(delta: float) -> void:
	if custom_parent:
		global_position = custom_parent.global_position
## Lanza `count` rayos dentro de un cono alrededor de `axis`.
func _spray(space: PhysicsDirectSpaceState3D, axis: Vector3, half_angle_deg: float, count: int, max_dist: float, size_scale: float = 1.0) -> void:
	var frame := _basis_from_up(axis.normalized())
	var cos_max := cos(deg_to_rad(half_angle_deg))
	for i in count:
		# Dirección aleatoria uniforme dentro del cono (eje local = Y)
		var cos_t := lerpf(1.0, cos_max, randf())
		var sin_t := sqrt(1.0 - cos_t * cos_t)
		var phi := randf() * TAU
		var dir: Vector3 = frame * Vector3(sin_t * cos(phi), cos_t, sin_t * sin(phi))

		var query := PhysicsRayQueryParameters3D.create(
			global_position,
			global_position + dir * max_dist * randf_range(0.5, 1.0)
		)
		query.collision_mask = world_mask
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		_place_decal(hit.position, hit.normal, size_scale)


## Punto de aterrizaje: avanza `forward_dist` en la dirección del chorro y
## deja un decal en el piso (si hay). Simula dónde caería la sangre.
func _ground_drop(space: PhysicsDirectSpaceState3D, shot_dir: Vector3, forward_dist: float, size_scale: float) -> void:
	var fwd: Vector3 = Vector3(shot_dir.x, 0.0, shot_dir.z)
	if fwd.length_squared() < 0.0001:
		fwd = -global_basis.z
	var origin: Vector3 = global_position + fwd.normalized() * forward_dist
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 5.0)
	query.collision_mask = world_mask
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		_place_decal(hit.position, hit.normal, size_scale)


func _place_decal(pos: Vector3, normal: Vector3, size_scale: float = 1.0) -> void:
	if splat_textures.is_empty():
		return
	var decal := Decal.new()
	decal.texture_albedo = splat_textures.pick_random()
	var width: float = randf_range(0.35, 0.85) * size_scale
	decal.modulate = Color(0.608, 0.0, 0.0)
	decal.size = Vector3(width, 0.3, width)  # Y = profundidad de proyección
	decal.cull_mask = decal_cull_mask
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 20.0

	get_tree().current_scene.add_child(decal)
	decal.global_position = pos + normal * 0.05
	# Decal proyecta hacia -Y local => su +Y debe ser la normal. Giro al azar sobre la normal.
	decal.global_basis = _basis_from_up(normal).rotated(normal, randf() * TAU)
	_track(decal)


## Límite de decals + desvanecido. Borra el más viejo al pasarse del máximo.
func _track(decal: Decal) -> void:
	_decals.append(decal)
	decal.tree_exited.connect(_decals.erase.bind(decal))
	if _decals.size() > MAX_DECALS:
		var old: Decal = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tween := decal.create_tween()
	tween.tween_interval(decal_lifetime)
	tween.tween_property(decal, "modulate:a", 0.0, fade_time)
	tween.tween_callback(decal.queue_free)


## Base ortonormal cuyo eje Y es `up` (debe venir normalizado).
static func _basis_from_up(up: Vector3) -> Basis:
	var helper := Vector3.RIGHT if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x := up.cross(helper).normalized()
	return Basis(x, up, x.cross(up))
