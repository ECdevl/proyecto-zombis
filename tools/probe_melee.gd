extends Node3D
## Sonda del golpe cuerpo a cuerpo (D-011): comprueba que `MeleeProjectile` es
## un RAYO que pega en la extremidad que se apunta.
##   1) Apuntar a la pierna  → golpea ESA hitbox, daño mínimo (0.1) y el zombi
##                              entra en "stun".
##   2) Apuntar a la cabeza  → golpea ESA hitbox, daño completo y guarda
##                              "melee_hit_dir" (rumbo del ragdoll).
##   3) Apuntar al vacío     → no pasa nada.
## Uso: godot --headless --path . res://tools/probe_melee.tscn
## No sirve `--script`: `zombie.gd` necesita el autoload GameManager, que en ese
## modo aún no existe cuando se compila (ver ERRORES.md E-004).

const ZOMBIE_SCENE := preload("res://scenes/zombies/zombie.tscn")
const MELEE := preload("res://resources/weapons/melee/machete.tres")

var fallos := 0
var last_who: Node = null
var last_damage := 0.0


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
		await _swing_at(cam, _hitbox_point(leg), zombie)
		var delta := hp0 - zombie.health_component.current_health
		ok(last_who == leg, "pegó a ESA hitbox (fue: %s)" % (last_who.name if last_who else "ninguna"))
		ok(absf(delta - 0.1) < 0.001 and absf(last_damage - 0.1) < 0.001, "daño mínimo de 0.1, no daño de cabeza (delta=%.3f)" % delta)
		var estado := str(zombie.state_machine.state.name)
		ok(estado == "stun", "el zombi quedó en stun (estado actual: %s)" % estado)

	print("=== 2) Apuntar a la cabeza ===")
	var head := _find_hitbox(zombie, "zombie_head")
	ok(head != null, "hay hitbox de cabeza")
	if head != null:
		zombie.remove_meta("melee_hit_dir")
		var hp1 := zombie.health_component.current_health
		await _swing_at(cam, _hitbox_point(head), zombie)
		var delta1 := hp1 - zombie.health_component.current_health
		ok(last_who == head, "pegó a ESA hitbox (fue: %s)" % (last_who.name if last_who else "ninguna"))
		ok(absf(delta1 - MELEE.damage) < 0.001, "daño completo de %s (delta=%.3f)" % [MELEE.damage, delta1])
		ok(zombie.has_meta("melee_hit_dir"), "se guardó melee_hit_dir (rumbo del ragdoll)")

	print("=== 3) Apuntar al vacío ===")
	var hp2 := zombie.health_component.current_health
	await _swing_at(cam, zombie.global_position + Vector3(0, 4, -6), zombie)
	ok(zombie.health_component.current_health == hp2 and last_who == null, "sin daño si no hay nada en la mira")

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


func _on_hurted(damage: float, info: Dictionary) -> void:
	last_damage = damage
	last_who = info.get("who") as Node


## Pone la cámara a 0.45 m del objetivo, mirándolo, y saliendo del cuerpo del
## zombi (si no, el rayo empezaría dentro del zombi y pegaría a otro hueso).
func _aim(cam: Camera3D, target: Vector3, zombie: Zombie) -> void:
	var dir := Vector3(target.x - zombie.global_position.x, 0.0, target.z - zombie.global_position.z)
	if dir.length_squared() < 0.01:
		dir = Vector3.UP  # la cabeza está justo arriba: se pega desde arriba
	else:
		dir.y = 0.3  # un poco por encima para no rasar el piso
	cam.global_position = target + dir.normalized() * 0.45
	var forward := (target - cam.global_position).normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	cam.look_at(target, up)


## Apunta y ejecuta un golpe real de MeleeProjectile, esperando a que se resuelva.
func _swing_at(cam: Camera3D, target: Vector3, zombie: Zombie) -> void:
	last_who = null
	last_damage = 0.0
	_aim(cam, target, zombie)
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
