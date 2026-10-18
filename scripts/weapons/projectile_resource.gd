extends Node3D
class_name Projectile

var damage : float = 50
var range: float = 100
const TRACE = preload("uid://d4f0qs7a20vub")

func set_projectile(proj_damage:float,proj_range:float) -> void:
	
	damage = proj_damage
	range = proj_range
	fire()
	
func fire() -> void:
	var collider : Dictionary = await _camera_raycast(range,get_parent())


	hitreg_collision(collider)

var _ray_end : Vector3  # punto final del raycast (sirve cuando no choca)

func hitreg_collision(result: Dictionary) -> void:
	var bullet_trace : Node3D = TRACE.instantiate()
	add_sibling(bullet_trace)
	bullet_trace.global_position = global_position

	# Si chocó va al impacto; si no, al final del rayo.
	var target : Vector3 = result.position if result else _ray_end
	bullet_trace.look_at(target)
	bullet_trace.target_pos = target

	if not result:
		queue_free()
		return
	var hit: Object = result.collider
	if not is_instance_valid(hit):
		queue_free()
		return
	if hit.owner is Zombie:
		if hit.is_in_group("zombie_head"):
			damage = 9999
		else:
			damage = 0
		hit.owner.health_component.hurt(damage, hit, get_parent(), result.position)
	queue_free()


func _camera_raycast(max_range: float, _by: Node3D = null) -> Dictionary:
	await get_tree().physics_frame
	var cam_xform := get_viewport().get_camera_3d().global_transform
	var space_state := get_viewport().get_camera_3d().get_world_3d().direct_space_state
	var origin: Vector3 = cam_xform.origin
	_ray_end = origin + (-cam_xform.basis.z * max_range)

	var query := PhysicsRayQueryParameters3D.create(origin, _ray_end)
	query.collide_with_areas = true
	query.exclude = [owner, get_parent()]
	query.collision_mask = (1 << 0) | 512
	return space_state.intersect_ray(query) 
	
