class_name MeleeProjectile extends Projectile
## Golpe cuerpo a cuerpo: un ABAÑICO de rayos desde la cámara hacia adelante,
## de `weapon_range` metros, tirado en el instante del golpe (D-012, estilo
## `melee_show_swing 1` de Left 4 Dead 2).
##
## El rayo central es el de la mira y es el que elige la extremidad del zombi
## apuntado (cabeza = daño completo, pierna = stun; ver `Zombie.hurted` y los
## grupos `zombie_head` / `zombie_legs_*`). Los laterales agregan otros zombis
## y perdonan la puntería, sin robarle la extremidad al zombi apuntado.
##
## Nota: la máscara sigue siendo solo la de hitboxes (lo mismo que la cápsula
## anterior), así que el golpe atraviesa paredes. Para que el mundo lo corte,
## hay que sumar `WORLD_MASK` a `collision_mask`.

## Dibuja los rayos del swing durante 0.5 s, como el `melee_show_swing 1` de
## L4D2. Se dibuja solo en builds de debug.
const DRAW_DEBUG_RAYS := true

var attacker : Node3D
var knockback : float = 0.0
var push_direction : Vector3 = Vector3.ZERO  # en mundo
var swing_data_ref: SwingData


## Se llama DESPUÉS de add_child (necesita estar en el árbol para usar la física).
func setup(melee: Melee, swing: SwingData, by: Node3D) -> void:
	knockback = melee.knockback
	attacker = by
	swing_data_ref = swing
	# La dirección del swing está en espacio local de la cámara: Basis * vector la pasa a mundo.
	push_direction = get_viewport().get_camera_3d().global_basis * swing.direction
	if push_direction.length_squared() < 0.0001:
		push_direction = -get_viewport().get_camera_3d().global_basis.z
	set_projectile(melee.damage, melee.weapon_range)


func fire() -> void:
	await get_tree().physics_frame
	var cam := get_viewport().get_camera_3d()
	var origin := cam.global_position
	var aim := -cam.global_basis.z  # hacia dónde mira el jugador
	_ray_end = origin + aim * range

	# Eje del barrido: u = A × S es perpendicular a la mira (A) y a la
	# dirección del swing (S), así que rotar A alrededor de u barre el plano
	# del tajo. Ej: A=(0,0,-1), S=(1,0,0) → u=(0,-1,0) = barrido horizontal.
	var swing_local: Vector3 = swing_data_ref.direction if swing_data_ref != null else Vector3.RIGHT
	var axis := aim.cross(cam.global_basis * swing_local)
	if axis.length_squared() < 0.0001:
		# Swing paralelo a la mira: el plano de barrido es indeterminado.
		axis = aim.cross(Vector3.UP)
		if axis.length_squared() < 0.0001:
			axis = Vector3.RIGHT
	axis = axis.normalized()

	var angles := _sweep_angles()
	# Un golpe por zombi por swing: el equivalente al "Already Hit" de L4D2.
	var ya_golpeado: Dictionary = {}

	for i in _ray_order(angles.size()):
		var dir := Basis(axis, angles[i]) * aim
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * range)
		query.collision_mask = HITBOX_MASK
		query.collide_with_areas = true
		query.collide_with_bodies = false  # solo interesan los hitboxes del zombi

		var result := cam.get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var hitbox := result.collider as Node
		if hitbox == null or not (hitbox.owner is Zombie):
			continue
		var zombie := hitbox.owner as Zombie
		if ya_golpeado.has(zombie):
			continue
		ya_golpeado[zombie] = true
		# intersect_ray sí devuelve el punto de contacto: se usa para la sangre.
		_apply_hit_with_dir(hitbox, result.position, zombie)

	_draw_swing(origin, aim, axis, angles)
	queue_free()


## Ángulos del abanico, de -α/2 a +α/2 con separación uniforme.
func _sweep_angles() -> PackedFloat32Array:
	var n := 7 if swing_data_ref == null else maxi(swing_data_ref.sweep_rays, 1)
	var alpha := 0.0 if swing_data_ref == null else maxf(swing_data_ref.sweep_angle, 0.0)
	var angles := PackedFloat32Array()
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1)
		angles.append(lerpf(-alpha * 0.5, alpha * 0.5, t))
	return angles


## Orden en que se tiran los rayos: primero el central (el de la mira, el que
## elige la extremidad) y después los laterales de menor a mayor ángulo, así
## si dos rayos pegan en el mismo zombi gana el más cercano a la mira.
## (No se usa `range()`: `range` es la propiedad con el alcance del arma.)
func _ray_order(n: int) -> PackedInt32Array:
	var order := PackedInt32Array()
	var center := (n - 1) / 2
	order.append(center)
	for step in n:  # 0..n-1 → distancias 1..n
		var distance := step + 1
		var right := center + distance
		var left := center - distance
		if right < n:
			order.append(right)
		if left >= 0:
			order.append(left)
	return order


## Dibuja los rayos del swing 0.5 s (ImmediateMesh con PRIMITIVE_LINES).
func _draw_swing(origin: Vector3, aim: Vector3, axis: Vector3, angles: PackedFloat32Array) -> void:
	if not DRAW_DEBUG_RAYS :
		return
	var parent := get_tree().current_scene
	if parent == null:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.25, 0.2, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES	, material)
	for angle in angles:
		var dir := Basis(axis, angle) * aim
		mesh.surface_add_vertex(origin)
		mesh.surface_add_vertex(origin + dir * range)
	mesh.surface_end()

	var lines := MeshInstance3D.new()
	lines.mesh = mesh
	parent.add_child(lines)
	get_tree().create_timer(3).timeout.connect(lines.queue_free)


func _apply_hit_with_dir(collider: Object, hit_pos: Vector3, zombie: Zombie) -> void:
	var hitbox := collider as Node
	if hitbox == null:
		return
	var dmg := _damage_for(hitbox)
	if dmg <= 0.0:
		return
	# Guardar dirección para el ragdoll si muere
	if hitbox.is_in_group("zombie_head"):
		zombie.set_meta("melee_hit_dir", push_direction.normalized() if push_direction.length_squared() > 0.0001 else (-get_viewport().get_camera_3d().global_basis.z))

	zombie.health_component.hurt(dmg, {"who":hitbox,"attacker":_attacker(),"hit_pos":hit_pos,"impulse":push_direction,"force":knockback})


func _damage_for(hitbox: Node) -> float:
	# Cabeza = daño completo. El resto recibe un daño mínimo (0.1) que no mata
	# pero sí dispara `Zombie.hurted()`, que es lo que activa el stun de pierna.
	if hitbox.is_in_group("zombie_head"):
		return damage
	return 0.1


func _attacker() -> Node3D:
	return attacker
