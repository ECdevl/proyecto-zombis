class_name ShotgunProjectile extends Projectile
## Descarga de escopeta: N rayos desde la cámara dentro de un cono.
## El perdigón 0 va SIEMPRE por la mira (centro del cono); los demás se reparten
## al azar con distribución uniforme en sólido dentro del cono.
## `damage` llega ya dividido entre los perdigones: si todos impactan (a
## quemarropa) la suma es el daño completo del arma.

var pellets: int = 1
var spread_deg: float = 0.0


## Se llama DESPUÉS de add_child (necesita estar en el árbol para usar la física).
func setup(pellet_count: int, spread_degrees: float, weapon_damage: float, proj_range: float, proj_knockback: float = 20.0) -> void:
	pellets = maxi(pellet_count, 1)
	spread_deg = maxf(spread_degrees, 0.0)
	damage = weapon_damage / float(pellets)
	range = proj_range
	knockback = proj_knockback
	fire()


func fire() -> void:
	await get_tree().physics_frame
	var cam: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3 = -cam.global_basis.z
	# Base ortonormal con el eje local Y apuntando al frente: la componente Y
	# del vector local es el coseno del ángulo con la mira (ver blood_splatter.gd).
	var frame: Basis = Projectile._basis_from_up(forward)
	var cos_max: float = cos(deg_to_rad(spread_deg))
	var origin: Vector3 = cam.global_position
	_ray_end = origin + forward * range

	for i in pellets:
		var dir: Vector3 = forward
		if i > 0:
			# cos_t uniforme entre 1 (centro) y cos_max (borde): reparte por
			# ángulo sólido, no por radio, para que no se amontonen en el centro.
			var cos_t: float = lerpf(1.0, cos_max, randf())
			var sin_t: float = sqrt(maxf(0.0, 1.0 - cos_t * cos_t))
			var phi: float = randf() * TAU
			dir = (frame * Vector3(sin_t * cos(phi), cos_t, sin_t * sin(phi))).normalized()
		var result: Dictionary = _trace_ray(origin, dir, range)
		_spawn_trace(result)
		if not result.is_empty() and is_instance_valid(result.collider):
			_apply_hit(result.collider, result.position, result.normal)
	queue_free()


## Cada perdigón aporta su parte del daño del arma, en cualquier zona del
## zombi. La bala única conserva el daño temporal 9999/0 de la clase base;
## la escopeta es la excepción deliberada para que la suma sea el daño total.
func _damage_for(hitbox: Node) -> float:
	return damage
