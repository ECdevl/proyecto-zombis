class_name MeleeProjectile extends Projectile
## Golpe cuerpo a cuerpo: un RAYO desde la cámara hacia adelante, de `range`
## metros, que daña el primer hitbox que toca. Al ser un rayo fino, la extremidad
## que se pega es la que se apunta (cabeza = daño total, pierna = stun; ver
## `Zombie.hurted` y los grupos `zombie_head` / `zombie_legs_*`).
##
## Nota: la máscara sigue siendo solo la de hitboxes (lo mismo que la cápsula
## anterior), así que el golpe atraviesa paredes. Para que el mundo lo corte,
## hay que sumar `WORLD_MASK` a `collision_mask`.

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
	var forward := -cam.global_basis.z
	_ray_end = origin + forward * range

	# Un solo rayo: el primer hitbox que toca es el que recibe el golpe.
	# collide_with_bodies = false, igual que la cápsula anterior: solo interesan
	# los hitboxes del zombi, así que ni el jugador ni el mundo tapan el rayo.
	var query := PhysicsRayQueryParameters3D.create(origin, _ray_end)
	query.collision_mask = HITBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := cam.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		queue_free()
		return

	var hitbox := result.collider as Node
	if hitbox == null or not (hitbox.owner is Zombie):
		queue_free()
		return

	# intersect_ray sí devuelve el punto de contacto: se usa para la sangre.
	_apply_hit_with_dir(hitbox, result.position, hitbox.owner as Zombie)
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
	# Cabeza = daño completo. El resto recibe un daño mínimo (0.1) que no mata
	# pero sí dispara `Zombie.hurted()`, que es lo que activa el stun de pierna.
	if hitbox.is_in_group("zombie_head"):
		return damage
	return 0.1


func _attacker() -> Node3D:
	return attacker
