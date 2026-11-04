extends Node3D
## Sonda de la dirección del impulso del melee: comprueba que el ragdoll
## sale volando hacia la IZQUIERDA o la DERECHA DEL JUGADOR según
## `SwingData.direction`, girando junto con el jugador (no en mundo fijo).
##   1) direction = Vector3.RIGHT con la cámara mirando al norte → vuela
##      a la derecha del jugador.
##   2) la misma dirección con la cámara girada180° → el mundo del vuelo
##      gira con el jugador (opuesto al caso1).
##   3) direction = Vector3.LEFT con la cámara al norte → vuela a la
##      izquierda del jugador.
##   4) Diagnóstico (sin aserción): misma cámara, zombi de espaldas → se
##      imprime la dirección para comparar con el caso1.
##   5) Con el descriptor REAL `machete.tres` (knockback por defecto20)
##      → impulso presente y a la derecha del jugador.
## Uso: godot --headless --path . res://tools/probe_hitdir.tscn

const ZOMBIE_SCENE := preload("res://scenes/zombies/zombie.tscn")
const MACHETE := preload("res://resources/weapons/melee/machete.tres")

var fallos := 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	# Piso: sin él el zombi cae y arranca ragdoll por su cuenta, contamina la sonda.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)

	print("=== 1) direction = RIGHT, cámara al norte ===")
	var c1 := await _kill_with(cam, Vector3.RIGHT, 0.0, 0.0)
	var r1 := _horiz(c1.right)
	var v1 := _horiz(c1.vel)
	print("   derecha de la cámara: ", r1, " | velocidad pelvis: ", c1.vel)
	ok(v1.length_squared() > 0.01, "hubo impulso (|v| = %.2f m/s)" % v1.length())
	if v1.length_squared() > 0.01 and r1.length_squared() > 0.01:
		ok(v1.normalized().dot(r1.normalized()) > 0.5, "vuela a la DERECHA del jugador")

	print("=== 2) direction = RIGHT, cámara girada180° (sur) ===")
	var c2 := await _kill_with(cam, Vector3.RIGHT, PI, 0.0)
	var r2 := _horiz(c2.right)
	var v2 := _horiz(c2.vel)
	print("   derecha de la cámara: ", r2, " | velocidad pelvis: ", c2.vel)
	ok(v2.length_squared() > 0.01, "hubo impulso (|v| = %.2f m/s)" % v2.length())
	if v2.length_squared() > 0.01 and r2.length_squared() > 0.01:
		ok(v2.normalized().dot(r2.normalized()) > 0.5, "sigue yendo a la DERECHA del jugador")
	if v1.length_squared() > 0.01 and v2.length_squared() > 0.01:
		ok(v1.normalized().dot(v2.normalized()) < -0.5, "en el mundo gira con el jugador (opuesto al caso1)")

	print("=== 3) direction = LEFT, cámara al norte ===")
	var c3 := await _kill_with(cam, Vector3.LEFT, 0.0, 0.0)
	var r3 := _horiz(c3.right)
	var v3 := _horiz(c3.vel)
	print("   derecha de la cámara: ", r3, " | velocidad pelvis: ", c3.vel)
	ok(v3.length_squared() > 0.01, "hubo impulso (|v| = %.2f m/s)" % v3.length())
	if v3.length_squared() > 0.01 and r3.length_squared() > 0.01:
		ok(v3.normalized().dot(r3.normalized()) < -0.5, "vuela a la IZQUIERDA del jugador")

	print("=== 4) Diagnóstico: misma cámara, zombi de espaldas (sin aserción) ===")
	var c4 := await _kill_with(cam, Vector3.RIGHT, 0.0, PI)
	var v4 := _horiz(c4.vel)
	print("   velocidad pelvis (debe parecerse a la del caso1): ", c4.vel)

	print("=== 5) Descriptor real machete.tres (knockback por defecto20) ===")
	var c5 := await _kill_with(cam, Vector3.RIGHT, 0.0, 0.0, MACHETE)
	var r5 := _horiz(c5.right)
	var v5 := _horiz(c5.vel)
	print("   derecha de la cámara: ", r5, " | velocidad pelvis: ", c5.vel)
	ok(v5.length_squared() > 0.01, "el machete real también da impulso (|v| = %.2f m/s)" % v5.length())
	if v5.length_squared() > 0.01 and r5.length_squared() > 0.01:
		ok(v5.normalized().dot(r5.normalized()) > 0.5, "el machete vuela a la DERECHA del jugador")

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


## Mata un zombi con un golpe melee de dirección `swing_dir` y devuelve la
## velocidad real de la pelvis (hacia dónde salió volando) junto con el eje
## derecho de la cámara con la que se apuntó.
## `yaw` gira alrededor del Y (0 = norte, PI = sur); `zombie_yaw` gira al
## zombi sobre sí mismo (PI = de espaldas a la cámara).
## Si no se pasa descriptor, se usa uno controlado con knockback =5.
func _kill_with(cam: Camera3D, swing_dir: Vector3, yaw: float, zombie_yaw: float, melee_desc: Melee = null) -> Dictionary:
	var forward := -Basis(Vector3.UP, yaw).z
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	zombie.global_position = forward * 1.5
	zombie.rotation.y = zombie_yaw
	# Dejar que esqueleto, hitboxes y estado inicial se asienten.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.4).timeout
	# Salud mínima: cualquier hitbox que toque el rayo remata.
	zombie.health_component.current_health = 0.05

	# Cámara a la altura del pecho, mirando al zombi.
	cam.global_position = Vector3(0, 1.6, 0)
	cam.look_at(zombie.global_position + Vector3.UP * 1.2, Vector3.UP)

	# Descriptor controlado: mismo camino que el juego (Melee → MeleeProjectile),
	# con knockback > 0 porque machete.tres y cuchillo.tres no lo guardan.
	var melee := melee_desc
	if melee == null:
		melee = Melee.new()
		melee.weapon_range = 3.0
		melee.damage = 10.0
		melee.knockback = 5.0
	var swing := SwingData.new()
	swing.direction = swing_dir

	var hit := MeleeProjectile.new()
	add_child(hit)
	hit.setup(melee, swing, self)

	# El rayo tarda1 frame de física; dejar que el impulso actúe unos frames
	# pero medir antes de que la gravedad domine la velocidad.
	for i in 6:
		await get_tree().physics_frame

	var result := {
		"vel": zombie.ragdoll_component.pelvis.linear_velocity,
		"right": cam.global_basis.x,
	}
	zombie.queue_free()
	await get_tree().physics_frame
	return result


## Componente horizontal de un vector (para comparar direcciones sin la gravedad).
func _horiz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
