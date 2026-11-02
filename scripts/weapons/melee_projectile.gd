class_name MeleeProjectile extends Projectile
## Golpe cuerpo a cuerpo. En vez de un rayo, usa una CÁPSULA que va desde la cámara
## hasta `range` metros hacia adelante, y daña el primer hueso tocado de cada zombi.

var radius : float = 0.15
var attacker : Node3D
var knockback : float = 0.0
var push_direction : Vector3 = Vector3.ZERO  # en mundo
var swing_data_ref: SwingData


## Se llama DESPUÉS de add_child (necesita estar en el árbol para usar la física).
func setup(melee: Melee, swing: SwingData, by: Node3D) -> void:
	radius = melee.hitbox_radius
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
	var forward := -cam.global_basis.z

	# La cápsula mide `range` de punta a punta (height incluye las dos semiesferas).
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(range, radius * 2.0)

	# La cápsula nace parada (eje Y). Se la gira -90° sobre X para que el eje Y
	# apunte hacia adelante de la cámara, y se centra a media altura.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(
		cam.global_basis * Basis(Vector3.RIGHT, -PI / 2.0),
		origin + forward * (capsule.height * 0.5))
	query.collision_mask = HITBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hits := cam.get_world_3d().direct_space_state.intersect_shape(query)

	# Un zombi tiene muchos hitboxes: se queda con el más cercano a la cámara
	# (el primero que el arma toca), así no recibe daño varias veces por golpe.
	var nearest : Dictionary[Zombie, Node3D] = {}
	for hit in hits:
		var hitbox := hit.collider as Node3D
		if hitbox == null or not (hitbox.owner is Zombie):
			continue
		var zombie := hitbox.owner as Zombie
		if not nearest.has(zombie) \
				or forward.dot(hitbox.global_position - origin) \
				< forward.dot(nearest[zombie].global_position - origin):
			nearest[zombie] = hitbox

	for zombie in nearest:
		var hitbox := nearest[zombie]
		# intersect_shape no devuelve el punto de contacto: se usa la posición del hueso.
		_apply_hit_with_dir(hitbox, hitbox.global_position, zombie)
		# Después del daño: si lo mató, el ragdoll total ya empezó y la reacción no hace nada.
	queue_free()

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

	zombie.health_component.hurt(dmg, {"who":hitbox,"attacker":_attacker(),"hit_pos":hit_pos,"impulse":push_direction,"force":20.0})


func _damage_for(hitbox: Node) -> float:
	# Solo dañar en la cabeza con melee
	if hitbox.is_in_group("zombie_head"):
		return damage
	return 0.1


func _attacker() -> Node3D:
	return attacker
