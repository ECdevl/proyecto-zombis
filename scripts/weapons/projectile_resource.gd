extends Node3D
class_name Projectile
## Base de todo golpe: balas (esta clase), perdigones de escopeta y cuerpo a cuerpo (MeleeProjectile).
## Se divide en 3 partes para que las subclases cambien solo lo que necesitan:
##   fire()          → CÓMO se busca el objetivo  (cada subclase lo cambia)
##   _apply_hit()    → QUÉ pasa al golpear        (común a todas)
##   _spawn_trace()  → efecto visual de la bala   (solo balas)

const TRACE = preload("uid://d4f0qs7a20vub")
## Textura de la partícula reutilizada como agujero de bala en el CUERPO del zombi.
const BULLET_HOLE_TEX = preload("res://assets/sprites/blood_particle.png")
## Agujero en el MUNDO (placeholder temporal: icono de Godot, a reemplazar).
const WORLD_HOLE_TEX = preload("res://assets/sprites/decals/bullet_hole.png")
## Tamaño objetivo del agujero de bala (~0.18 m).
const BULLET_HOLE_SIZE := 0.18
## Capa donde viven los hitboxes (Area3D) del zombi.
const HITBOX_MASK := 512
## Capa del mundo (paredes, piso).
const WORLD_MASK := 1

var damage : float = 0
var range: float = 100
var knockback : float = 20.0
var _ray_end : Vector3  # punto final del raycast (sirve cuando no choca)


func set_projectile(proj_damage:float,proj_range:float,proj_knockback:float = 20.0) -> void:
	damage = proj_damage
	range = proj_range
	knockback = proj_knockback
	fire()


## Hitscan: un rayo desde la cámara. Las subclases lo reemplazan.
func fire() -> void:
	var result : Dictionary = await _camera_raycast(range, get_parent())
	_spawn_trace(result)
	if not result.is_empty() and is_instance_valid(result.collider):
		_apply_hit(result.collider, result.position, result.normal)
	queue_free()


## Daña al zombi dueño del hitbox golpeado. Común a todas las subclases.
## `hit_normal` es la normal de la superficie golpeada (vacía en melee).
## En el zombi el agujero mira hacia el tirador (`-salida`); en el mundo
## usa la normal real del rayo.
func _apply_hit(collider: Object, hit_pos: Vector3, hit_normal: Vector3 = Vector3.ZERO) -> void:
	var hitbox := collider as Node
	if hitbox == null:
		return
	if hitbox.owner is Zombie:
		var zombie := hitbox.owner as Zombie
		var exit_dir: Vector3 = _attacker().global_position.direction_to(hit_pos)
		var bone := hitbox.get_parent() as Node3D
		_spawn_bullet_hole_on_bone(bone, hit_pos, -exit_dir)
		zombie.health_component.hurt(_damage_for(hitbox),{"who":hitbox,"attacker":_attacker(),"hit_pos":hit_pos,"impulse":exit_dir,"force":knockback})
		if _attacker() is Player:
			_attacker().attacked_close.emit()
	elif collider is StaticBody3D and hit_normal.length_squared() > 0.0001:
		# Solo paredes/piso: no hay agujero sobre pickups ni otros cuerpos.
		_spawn_bullet_hole(hit_pos, hit_normal)


## Agujero de bala fijo en el mundo: se queda en `pos` con la normal dada.
## Textura placeholder (icono de Godot) a reemplazar por el usuario.
func _spawn_bullet_hole(pos: Vector3, surface_normal: Vector3) -> void:
	if surface_normal.length_squared() < 0.0001 or not surface_normal.is_finite():
		surface_normal = Vector3.UP
	var decal: Decal = _make_hole_decal(WORLD_HOLE_TEX)
	get_tree().current_scene.add_child(decal)
	decal.global_position = pos + surface_normal.normalized() * 0.05
	decal.global_basis = _basis_from_up(surface_normal.normalized())


## Agujero pegado al cuerpo del zombi (hijo del BoneAttachment del hitbox):
## sigue al hueso cuando el zombi se mueve. Se libera con el zombi al morir
## (la raíz se libera en death.gd).
func _spawn_bullet_hole_on_bone(bone: Node3D, pos: Vector3, outward: Vector3) -> void:
	if bone == null or outward.length_squared() < 0.0001 or not outward.is_finite():
		var fallback := outward if outward.length_squared() > 0.0001 else Vector3.UP
		_spawn_bullet_hole(pos, fallback)
		return
	var normal: Vector3 = outward.normalized()
	var global_pos: Vector3 = pos + normal * 0.02
	# Giro al azar sobre la normal (como BloodSplatter).
	var global_basis: Basis = _basis_from_up(normal).rotated(normal, randf() * TAU)
	var decal: Decal = _make_hole_decal(BULLET_HOLE_TEX)
	bone.add_child(decal)
	# Local = inversa del hueso * deseado global.
	decal.modulate = Color(0.608, 0.0, 0.0)
	decal.transform = bone.global_transform.affine_inverse() * Transform3D(global_basis, global_pos)


func _make_hole_decal(tex: Texture2D) -> Decal:
	var decal := Decal.new()
	decal.texture_albedo = tex
	decal.size = Vector3(BULLET_HOLE_SIZE, 0.2, BULLET_HOLE_SIZE)
	decal.cull_mask = 1
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 20.0
	return decal


## Base ortonormal cuyo eje Y es `up` (debe venir normalizado).
static func _basis_from_up(up: Vector3) -> Basis:
	var helper := Vector3.RIGHT if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x: Vector3 = up.cross(helper).normalized()
	return Basis(x, up, x.cross(up))


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
	var cam_xform : Transform3D = get_viewport().get_camera_3d().global_transform
	var space_state : PhysicsDirectSpaceState3D = get_viewport().get_camera_3d().get_world_3d().direct_space_state
	var origin: Vector3 = cam_xform.origin
	_ray_end = origin + (-cam_xform.basis.z * max_range)

	var query := PhysicsRayQueryParameters3D.create(origin, _ray_end)
	query.collide_with_areas = true
	# `owner` suele ser null (la escena del proyectil se instancia con
	# `instantiate()` y nadie le pone owner): meter null en un `Array[RID]`
	# tira un error de tipos en runtime, así que solo se excluye lo que aporta
	# un RID (ver ERRORES.md E-013). Además no hace falta excluir al jugador
	# (capa 8) ni al zombi (capa 2): ninguno de los dos está en esta máscara.
	var excluded: Array[RID] = []
	for obj in [owner, get_parent()]:
		if obj is CollisionObject3D:
			excluded.append((obj as CollisionObject3D).get_rid())
	# Los pickups no deben tapar el disparo: si alguno quedó en capa 1
	# (mundo), se excluye por RID (el rayo lo atraviesa).
	if get_tree() != null and get_tree().current_scene != null:
		for pick: Node in get_tree().current_scene.find_children("*", "PickableItem", true, false):
			if pick is CollisionObject3D:
				excluded.append((pick as CollisionObject3D).get_rid())
	query.exclude = excluded
	query.collision_mask = WORLD_MASK | HITBOX_MASK
	return space_state.intersect_ray(query)
