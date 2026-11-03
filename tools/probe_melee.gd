extends Node3D
## Sonda del golpe cuerpo a cuerpo (D-011 / D-012): comprueba que
## `MeleeProjectile` tira un ABAÑICO de rayos que pega en la extremidad que se
## apunta.
##   1) Apuntar a la pierna  → golpea ESA hitbox, daño mínimo (0.1) y el zombi
##                              entra en "stun".
##   2) Apuntar a la cabeza  → golpea ESA hitbox, daño completo y guarda
##                              "melee_hit_dir" (rumbo del ragdoll).
##   3) Apuntar al vacío     → no pasa nada.
##   4) Apuntar a 12 cm de lado → el rayo central erra pero un lateral del
##                              abanico pega: perdón de puntería, y igual solo
##                              UN golpe por zombi por swing.
## Uso: godot --headless --path . res://tools/probe_melee.tscn
## No sirve `--script`: `zombie.gd` necesita el autoload GameManager, que en ese
## modo aún no existe cuando se compila (ver ERRORES.md E-004).

const ZOMBIE_SCENE := preload("res://scenes/zombies/zombie.tscn")
const MELEE := preload("res://resources/weapons/melee/machete.tres")

var fallos := 0
var last_who: Node = null
var last_damage := 0.0
var hurt_count := 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	# Piso: sin él el zombi cae, pasa0.5 s en el aire y arranca ragdoll,
	# que dispara su propio stun y contamina la sonda.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)

	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	# Dejar que el esqueleto, las hitboxes y el estado inicial se asienten.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.6).timeout

	# Salud alta: ningún golpe debe matar al zombi durante la sonda.
	zombie.health_component.current_health = 1000.0
	zombie.health_component.hurted.connect(_on_hurted)

	print("=== 1) Apuntar a la pierna ===")
	var leg := _find_hitbox(zombie, "zombie_legs_left")
	ok(leg != null, "hay hitbox de pierna izquierda")
	if leg != null:
		var hp0 := zombie.health_component.current_health
		await _swing_at(cam, _hitbox_point(leg), zombie, 0.0, leg)
		var delta := hp0 - zombie.health_component.current_health
		ok(last_who == leg, "pegó a ESA hitbox (fue: %s)" % (last_who.name if last_who else "ninguna"))
		ok(absf(delta - 0.1) < 0.001 and absf(last_damage - 0.1) < 0.001, "daño mínimo de 0.1, no daño de cabeza (delta=%.3f)" % delta)
		ok(hurt_count == 1, "un solo golpe por zombi por swing (hurt_count=%d)" % hurt_count)
		var estado := str(zombie.state_machine.state.name)
		ok(estado == "stun", "el zombi quedó en stun (estado actual: %s)" % estado)

	print("=== 2) Apuntar a la cabeza ===")
	var head := _find_hitbox(zombie, "zombie_head")
	ok(head != null, "hay hitbox de cabeza")
	if head != null:
		zombie.remove_meta("melee_hit_dir")
		var hp1 := zombie.health_component.current_health
		await _swing_at(cam, _hitbox_point(head), zombie, 0.0, head)
		var delta1 := hp1 - zombie.health_component.current_health
		ok(last_who == head, "pegó a ESA hitbox (fue: %s)" % (last_who.name if last_who else "ninguna"))
		ok(absf(delta1 - MELEE.damage) < 0.001, "daño completo de %s (delta=%.3f)" % [MELEE.damage, delta1])
		ok(hurt_count == 1, "un solo golpe por zombi por swing (hurt_count=%d)" % hurt_count)
		ok(zombie.has_meta("melee_hit_dir"), "se guardó melee_hit_dir (rumbo del ragdoll)")

	print("=== 3) Apuntar al vacío ===")
	var hp2 := zombie.health_component.current_health
	await _swing_at(cam, zombie.global_position + Vector3(0, 4, -6), zombie)
	ok(zombie.health_component.current_health == hp2 and hurt_count == 0, "sin daño si no hay nada en la mira")

	print("=== 4) Apuntar a 12 cm de lado (perdón del abanico) ===")
	var hp3 := zombie.health_component.current_health
	await _swing_at(cam, _hitbox_point(head) if head != null else zombie.global_position + Vector3.UP, zombie, 0.12, head)
	var delta3 := hp3 - zombie.health_component.current_health
	ok(hurt_count >= 1, "un rayo lateral pegó aunque el central erró (hurt_count=%d)" % hurt_count)
	ok(hurt_count == 1, "aun así fue un solo golpe por zombi (hurt_count=%d)" % hurt_count)
	ok(delta3 > 0.0 and last_who != null, "hubo daño y se registró la hitbox (%s)" % (last_who.name if last_who else "ninguna"))

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


func _on_hurted(damage: float, info: Dictionary) -> void:
	last_damage = damage
	last_who = info.get("who") as Node
	hurt_count += 1


## Pone la cámara a 0.45 m del objetivo, mirándolo, y saliendo del cuerpo del
## zombi (si no, el rayo empezaría dentro del zombi y pegaría a otro hueso).
## `lateral_offset` desvía la mira hacia un costado (en metros) para probar el
## perdón del abanico: el rayo central erra por ese offset y pega un lateral.
## `wanted` es el hitbox al que se quiere llegar: si se pasa, se busca un
## ángulo de cámara desde el que el rayo central no esté tapado por otra
## extremidad del esqueleto (los brazos se interponen y rompen la sonda).
func _aim(cam: Camera3D, target: Vector3, zombie: Zombie, lateral_offset := 0.0, wanted: Area3D = null) -> void:
	var dir := _base_dir(target, zombie)
	if wanted != null:
		var clear := _find_clear_dir(target, zombie, wanted)
		if clear != Vector3.ZERO:
			dir = clear
	# Lateral horizontal perpendicular a la dirección de apunte.
	var lateral := dir.cross(Vector3.UP)
	lateral = Vector3.RIGHT if lateral.length_squared() < 0.0001 else lateral.normalized()
	var aim_point := target + lateral * lateral_offset
	cam.global_position = aim_point + dir * 0.45
	var forward := (aim_point - cam.global_position).normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	cam.look_at(aim_point, up)


## Dirección base de apunte: horizontal desde el centro del zombi hacia el
## objetivo, con un poco de elevación (o desde arriba si el objetivo está
## encima del centro, como la cabeza).
func _base_dir(target: Vector3, zombie: Zombie) -> Vector3:
	var dir := Vector3(target.x - zombie.global_position.x, 0.0, target.z - zombie.global_position.z)
	if dir.length_squared() < 0.01:
		dir = Vector3.UP  # la cabeza está justo arriba: se pega desde arriba
	else:
		dir.y = 0.3  # un poco por encima para no rasar el piso
	return dir.normalized()


## Barre 16 direcciones girando la base alrededor del eje Y y devuelve la
## primera desde la que el rayo central llega limpio a `wanted`
## (Vector3.ZERO si ninguna sirve).
func _find_clear_dir(target: Vector3, zombie: Zombie, wanted: Area3D) -> Vector3:
	var base := _base_dir(target, zombie)
	for k in 16:
		var dir := (Basis(Vector3.UP, TAU * float(k) / 16.0) * base).normalized()
		if _reaches(target + dir * 0.45, target, wanted):
			return dir
	return Vector3.ZERO


## ¿El rayo desde `from` hasta `to` llega al hitbox `wanted` sin que otra
## hitbox se interponga? Usa la misma consulta que el golpe (solo hitboxes).
func _reaches(from: Vector3, to: Vector3, wanted: Area3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 512  # Projectile.HITBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.get("collider") == wanted


## Apunta y ejecuta un golpe real de MeleeProjectile, esperando a que se resuelva.
func _swing_at(cam: Camera3D, target: Vector3, zombie: Zombie, lateral_offset := 0.0, wanted: Area3D = null) -> void:
	last_who = null
	last_damage = 0.0
	hurt_count = 0
	_aim(cam, target, zombie, lateral_offset, wanted)
	var hit := MeleeProjectile.new()
	add_child(hit)
	hit.setup(MELEE, MELEE.swings[0], self)
	for i in 8:
		await get_tree().physics_frame


## Centro de la forma del hitbox: el origen del Area3D queda en la articulación,
## afuera de la cápsula/box, así que apuntar ahí erra.
func _hitbox_point(area: Area3D) -> Vector3:
	var shape := area.get_node_or_null("CollisionShape3D")
	if shape is CollisionShape3D:
		return shape.global_position
	return area.global_position


func _find_hitbox(zombie: Zombie, group: String) -> Area3D:
	for node in get_tree().get_nodes_in_group(group):
		if node is Area3D and node.owner == zombie:
			return node
	return null
