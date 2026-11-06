extends Node3D
## Sonda de movimiento (D-017): comprueba la aceleración, el frenado con
## derrape, el sprint y la conservación del impulso horizontal en el aire.
##   A) Acelerar caminando: rampa visible y velocidad final ≈ walk_speed.
##   B) Frenar soltando las teclas: baja rápido pero NO instantáneo, se frena
##      solo y recorre un derrape ≈ v²/(2·deceleration).
##   C) Sprint: alcanza ≈ sprint_speed tras la rampa.
##   D) Salto en carrera soltando todo en el aire: el impulso horizontal NO se
##      pierde en el vuelo y al aterrizar se desliza y frena solo.
## Uso: godot --headless --path . res://tools/probe_movimiento.tscn
## No sirve `--script`: el player necesita el árbol de escena completo
## (máquina de estados, animaciones, ui) y los autoloads del proyecto.
## OJO: la física de este proyecto corre a Engine.physics_ticks_per_second
## (120), así que las esperas son en SEGUNDOS, nunca en frames sueltos.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

var fallos: int = 0
var player: CharacterBody3D = null


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


## Velocidad horizontal (XZ) del player.
func _hvel() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


## Espera `seconds` de física, independiente de los ticks por segundo.
func _wait(seconds: float) -> void:
	var ticks: int = int(round(seconds * float(Engine.physics_ticks_per_second)))
	for i in ticks:
		await get_tree().physics_frame


func _ready() -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)

	# Piso: tapa en y=0; el player (mask 3) colisiona con su capa 1.
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	# 200×200: las pruebas B→D recorren ~25 m acumulados hacia -Z; un piso
	# chico hace que el player se caiga por el borde y "no frene" en el aire.
	box.size = Vector3(200, 1, 200)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var cam: Camera3D = Camera3D.new()
	cam.current = true
	add_child(cam)

	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	add_child(player)
	for i in 120:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	ok(player.is_on_floor(), "el player asentó sobre el piso antes de empezar")

	# ===== A) Aceleración caminando =====
	print("=== A) Acelerar caminando ===")
	Input.action_press("forward")
	await _wait(0.1)
	var v_early: float = _hvel()
	ok(v_early > 0.2 and v_early < 3.0, "a ~0.1 s la velocidad es parcial, no instantánea (v=%.2f)" % v_early)
	await _wait(0.9)  # ~1.0 s en total
	var v_walk: float = _hvel()
	ok(absf(v_walk - 5.0) < 0.25, "a 1 s alcanzó la velocidad de caminar 5.00 (v=%.2f)" % v_walk)

	# ===== B) Frenado y derrape =====
	print("=== B) Frenar soltando las teclas ===")
	Input.action_release("forward")
	await _wait(2.0 * dt)
	var v_brake: float = _hvel()
	ok(v_brake > 3.5, "2 frames tras soltar aún va rápido: el freno NO es instantáneo (v=%.2f)" % v_brake)
	var traveled: float = 0.0
	var t: int = 0
	var stopped: bool = false
	for i in 240:
		traveled += _hvel() * dt
		await get_tree().physics_frame
		t = i + 1
		if _hvel() < 0.05:
			stopped = true
			break
	ok(stopped, "se frena solo sin input (en %.2f s)" % (float(t) * dt))
	ok(traveled > 0.3 and traveled < 0.8, "derrape ≈ v²/(2a) = 0.50 m (recorrió %.2f m)" % traveled)

	# ===== C) Sprint =====
	print("=== C) Sprint ===")
	Input.action_press("forward")
	Input.action_press("shift")
	await _wait(1.5)  # la rampa tarda 8/12 ≈ 0.67 s, sobra
	var v_run: float = _hvel()
	ok(absf(v_run - 8.0) < 0.5, "esprintando alcanza 8.00 (v=%.2f)" % v_run)

	# ===== D) Impulso aéreo conservado =====
	print("=== D) Salto en carrera conserva el impulso ===")
	Input.action_press("space")
	await _wait(dt)
	Input.action_release("space")
	var despego: bool = false
	for i in 60:
		await get_tree().physics_frame
		if not player.is_on_floor():
			despego = true
			break
	ok(despego and player.velocity.y > 0.0, "despegó el salto")
	var v_takeoff: float = _hvel()
	# Soltar TODO en el aire: el impulso horizontal debe sobrevivir al vuelo.
	Input.action_release("forward")
	Input.action_release("shift")
	var v_min_air: float = 999.0
	for i in 180:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
		v_min_air = minf(v_min_air, _hvel())
	ok(v_min_air > v_takeoff * 0.85, "en el aire la horizontal casi no cae (despegue=%.2f, mínima aérea=%.2f)" % [v_takeoff, v_min_air])
	var v_land: float = _hvel()
	ok(v_land > maxf(1.0, v_takeoff * 0.4), "aterriza con inercia y se desliza (v al aterrizar=%.2f)" % v_land)
	var freno: bool = false
	for i in 240:
		await get_tree().physics_frame
		if _hvel() < 0.05:
			freno = true
			break
	ok(freno, "tras el derrape del aterrizaje se detiene solo")

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
