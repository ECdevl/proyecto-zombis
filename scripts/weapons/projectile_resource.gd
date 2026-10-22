extends Node3D
class_name Projectile
## Base de todo golpe: balas (esta clase), perdigones de escopeta y cuerpo a cuerpo (MeleeProjectile).
## Se divide en 3 partes para que las subclases cambien solo lo que necesitan:
##   fire()          → CÓMO se busca el objetivo  (cada subclase lo cambia)
##   _apply_hit()    → QUÉ pasa al golpear        (común a todas)
##   _spawn_trace()  → efecto visual de la bala   (solo balas)

const TRACE = preload("uid://d4f0qs7a20vub")
## Capa donde viven los hitboxes (Area3D) del zombi.
const HITBOX_MASK := 512
## Capa del mundo (paredes, piso).
const WORLD_MASK := 1

var damage : float = 0
var range: float = 100

var _ray_end : Vector3  # punto final del raycast (sirve cuando no choca)


func set_projectile(proj_damage:float,proj_range:float) -> void:
	damage = proj_damage
	range = proj_range
	fire()


## Hitscan: un rayo desde la cámara. Las subclases lo reemplazan.
func fire() -> void:
	var result : Dictionary = await _camera_raycast(range, get_parent())
	_spawn_trace(result)
	if not result.is_empty() and is_instance_valid(result.collider):
		_apply_hit(result.collider, result.position)
	queue_free()


## Daña al zombi dueño del hitbox golpeado. Común a todas las subclases.
func _apply_hit(collider: Object, hit_pos: Vector3) -> void:
	var hitbox := collider as Node
	if hitbox == null or not (hitbox.owner is Zombie):
		return
	var zombie := hitbox.owner as Zombie
	zombie.health_component.hurt(_damage_for(hitbox), hitbox, _attacker(), hit_pos)


## TEMPORAL (igual que antes): solo la cabeza hace daño, el resto 0.
## Cuando haya daño por zona, se cambia SOLO acá.
func _damage_for(hitbox: Node) -> float:
	return 9999.0 if hitbox.is_in_group("zombie_head") else 0.0


## Quién ataca (el zombi usa su posición para la dirección de la sangre).
func _attacker() -> Node3D:
	return get_parent() as Node3D


func _spawn_trace(result: Dictionary) -> void:
	var bullet_trace : Node3D = TRACE.instantiate()
	add_sibling(bullet_trace)
	bullet_trace.global_position = global_position

	# Si chocó va al impacto; si no, al final del rayo.
	var target : Vector3 = result.position if not result.is_empty() else _ray_end
	bullet_trace.look_at(target)
	bullet_trace.target_pos = target


func _camera_raycast(max_range: float, _by: Node3D = null) -> Dictionary:
	await get_tree().physics_frame
	var cam_xform := get_viewport().get_camera_3d().global_transform
	var space_state := get_viewport().get_camera_3d().get_world_3d().direct_space_state
	var origin: Vector3 = cam_xform.origin
	_ray_end = origin + (-cam_xform.basis.z * max_range)

	var query := PhysicsRayQueryParameters3D.create(origin, _ray_end)
	query.collide_with_areas = true
	query.exclude = [owner, get_parent()]
	query.collision_mask = WORLD_MASK | HITBOX_MASK
	return space_state.intersect_ray(query)
