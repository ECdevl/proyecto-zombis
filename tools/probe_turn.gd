extends Node3D
## Sonda del movimiento del zombi: giro limitado, estado `turn` y ataque de
## frente (D-018).
##
## Idea: el zombi NO puede girar en el sitio mientras persigue ni pegar snaps
## hacia el jugador. Solo gira a `zombie.turn_speed_deg` (90°/s por defecto) y
## únicamente mientras camina; el único giro en el sitio es el estado `turn`,
## pensado para cuando escuche un ruido.
##
##   A) `chase` con el objetivo DETRÁS (un ruido detrás del zombi): el zombi
##      camina hacia ADELANTE (-Z) y NO se da la vuelta al instante; en 0.5 s
##      como mucho gira turn_speed_deg * 0.5 + margen. La cabeza NO clava la
##      mirada en el jugador (LookAtModifier3D con influencia 0 y sin target).
##   B) `chase` sigue girando: al cabo de 3 s el cuerpo ya mira al objetivo.
##   C) `turn` con {"direction": Vector3(1, 0, 0)} (a su derecha): gira en el
##      sitio a velocidad limitada, se queda con v_horiz = 0, termina cuando
##      mira a la fuente y vuelve a `next_state` (idle por defecto).
##   D) El ataque exige estar de frente: `is_facing_target()` es falso con el
##      jugador a la espalda y verdadero con el jugador delante.
##   E) `turn` con datos inválidos ({ }): termina de inmediato y no se queda
##      atrapado en el estado.
##
## Uso: godot --headless --path . res://tools/probe_turn.tscn

const ZOMBIE_SCENE := preload("res://scenes/zombies/zombie.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var fallos : int = 0
var _physics_dt : float = 0.0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _build_floor() -> void:
	var body : StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs : CollisionShape3D = CollisionShape3D.new()
	var box : BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	add_child(body)


func _build_navmesh() -> void:
	var nm : NavigationMesh = NavigationMesh.new()
	nm.set_vertices(PackedVector3Array([
		Vector3(-12, 0, -12),
		Vector3(-12, 0, 12),
		Vector3(12, 0, 12),
		Vector3(12, 0, -12),
	]))
	nm.add_polygon(PackedInt32Array([0, 1, 2]))
	nm.add_polygon(PackedInt32Array([0, 2, 3]))
	nm.agent_radius = 0.5

	var region : NavigationRegion3D = NavigationRegion3D.new()
	region.navigation_mesh = nm
	add_child(region)


func _spawn(pos: Vector3, rot_y: float) -> Zombie:
	var z : Zombie = ZOMBIE_SCENE.instantiate()
	z.can_debug = false
	add_child(z)
	z.global_position = pos
	z.rotation.y = rot_y
	return z


func _physics_ticks(seconds: float) -> int:
	return int(round(seconds * float(Engine.physics_ticks_per_second)))


func _ready() -> void:
	_physics_dt = 1.0 / float(Engine.physics_ticks_per_second)
	_build_floor()
	_build_navmesh()

	var target : Player = PLAYER_SCENE.instantiate()
	add_child(target)
	target.global_position = Vector3(0, 0, 10)  # a la ESPALDA del zombi que mira a -Z

	for _i in 5:
		await get_tree().physics_frame

	print("=== A) chase con el objetivo DETRÁS: camina hacia adelante y no gira de golpe ===")
	var za : Zombie = _spawn(Vector3(0, 0, 4), 0.0)
	za.vision.target = target
	za.state_machine.state.finished.emit("chase")
	var start_yaw : float = za.rotation.y
	var start_z : float = za.global_position.z
	for _i in _physics_ticks(0.5):
		await get_tree().physics_frame
	var moved_forward : float = start_z - za.global_position.z
	var yaw_delta : float = absf(wrapf(za.rotation.y - start_yaw, -PI, PI))
	var max_step : float = deg_to_rad(za.turn_speed_deg) * 0.5 + deg_to_rad(2.0)
	ok(moved_forward > 0.5, "avanza HACIA ADELANTE (-Z) aunque el objetivo esté detrás (%.2f m)" % moved_forward)
	ok(yaw_delta > 0.0001, "sí empieza a girar hacia el objetivo (%.1f°)" % rad_to_deg(yaw_delta))
	ok(yaw_delta <= max_step, "el giro está limitado a turn_speed_deg × 0.5 s (%.1f° <= %.1f°)" % [rad_to_deg(yaw_delta), rad_to_deg(max_step)])
	ok(za.look_head.influence <= 0.001, "la cabeza no se gira hacia el jugador (influencia %.2f)" % za.look_head.influence)
	ok(za.look_head.target_node.is_empty(), "la cabeza no tiene target (no hay snap de mirada)")

	print("=== B) chase sigue girando mientras camina: a los 3 s ya mira al objetivo ===")
	for _i in _physics_ticks(2.5):
		await get_tree().physics_frame
	var to_target : Vector3 = target.global_position - za.global_position
	to_target.y = 0.0
	var forward : Vector3 = -za.global_basis.z
	forward.y = 0.0
	var facing : float = forward.normalized().dot(to_target.normalized())
	ok(facing > cos(deg_to_rad(30.0)), "el cuerpo termina mirando al objetivo (dot %.2f)" % facing)
	za.queue_free()
	await get_tree().physics_frame

	print("=== C) turn con direction Vector3(1, 0, 0) (a su derecha) ===")
	var zb : Zombie = _spawn(Vector3(0, 0, 0), 0.0)
	ok(zb.state_machine.has_node("turn"), "el estado `turn` está cableado en zombie.tscn")
	zb.state_machine.state.finished.emit("turn", {"direction": Vector3(1, 0, 0)})
	var max_rate_ok : bool = true
	var still : bool = true
	var prev_yaw : float = zb.rotation.y
	for _i in _physics_ticks(5.0):
		await get_tree().physics_frame
		var h : float = Vector2(zb.velocity.x, zb.velocity.z).length()
		if h > 0.01:
			still = false
		var step : float = absf(wrapf(zb.rotation.y - prev_yaw, -PI, PI))
		if step > deg_to_rad(zb.turn_speed_deg) * _physics_dt + deg_to_rad(1.0):
			max_rate_ok = false
		prev_yaw = zb.rotation.y
		if zb.state_machine.state.name != "turn":
			break
	ok(zb.state_machine.state.name != "turn", "sale del estado turn al terminar (estado actual: %s)" % zb.state_machine.state.name)
	var target_yaw : float = atan2(-1.0, 0.0)
	var err : float = absf(wrapf(zb.rotation.y - target_yaw, -PI, PI))
	ok(err < deg_to_rad(4.0), "el cuerpo mira a la fuente del ruido (error %.1f°)" % rad_to_deg(err))
	ok(still, "v_horiz = 0 durante todo el giro (gira en el sitio, sin patinar)")
	ok(max_rate_ok, "nunca gira más rápido que turn_speed_deg")
	zb.queue_free()

	print("=== D) el ataque exige estar de frente ===")
	var zd : Zombie = _spawn(Vector3(0, 0, 0), 0.0)
	var chase : ZombieState = zd.get_node("StateMachine/chase")
	chase.target = target
	target.global_position = Vector3(0, 0, 2)   # detrás del zombi (mira a -Z)
	ok(not chase.is_facing_target(), "con el jugador a la espalda NO puede atacar")
	target.global_position = Vector3(0, 0, -2)  # delante del zombi
	ok(chase.is_facing_target(), "con el jugador de frente SÍ puede atacar")
	zd.queue_free()

	print("=== E) turn con datos inválidos: termina de inmediato ===")
	var zc : Zombie = _spawn(Vector3(0, 0, 0), 0.0)
	zc.state_machine.state.finished.emit("turn", {})
	for _i in 3:
		await get_tree().physics_frame
	ok(zc.state_machine.state.name != "turn", "datos inválidos -> no se queda atrapado (estado actual: %s)" % zc.state_machine.state.name)
	zc.queue_free()

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
