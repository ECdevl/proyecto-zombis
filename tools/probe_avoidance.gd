extends Node3D
## Sonda de avoidance entre zombis (RVO de `NavigationAgent3D`, D-015).
##
## Monta un escenario mínimo: piso, un `NavigationRegion3D` cuyo
## `NavigationMesh` se arma a mano (cuadrado de 24 x 24 m en y = 0) y un
## objetivo real (`player.tscn`) en el grupo "player". Después corre el
## código real de persecución (`states/chase.gd`) en tres escenarios:
##
##   A) UN zombi solo → control: sin vecinos el RVO devuelve la velocidad
##      deseada tal cual, así que NO debería haber desvío lateral.
##   B) CUATRO zombis con `avoidance_mask = 0` → el RVO sigue calculando
##      (la señal se emite con solo `avoidance_enabled = true`, según la
##      doc) pero IGNORA a los demás agentes: es el mismo código sin la
##      evitación mutua. Sirve de control para comparar contra C.
##   C) CUATRO zombis con avoidance real (`avoidance_mask = 1`) → el RVO
##      debería apartarlos antes de que se toquen.
##
## Aserciones:
##   1) A: sin vecinos no hay desvío lateral (el RVO no inventa movimiento
##      lateral por su cuenta) y la velocidad es la pedida.
##   2) B: el control ciego sigue emitiendo `velocity_computed` y llega al
##      objetivo → es una base de comparación válida (se mueve igual).
##   3) B: el RVO ciego tampoco desvía → la métrica no mide ruido sino
##      evitación.
##   4) C: `velocity_computed` dispara para todos los zombis que persiguen.
##   5) C: la velocidad horizontal queda ≤ SPEED * 1.3 (con el bug de doble
##      multiplicación daría SPEED² = 4.0 m/s).
##   6) C: la distancia mínima entre pares nunca baja de MIN_DIST.
##   7) C: todos llegan a menos de 2 m del objetivo (no se bloquean entre
##      sí).
##   8) C: el RVO aparta a los zombis → altera MÁS la velocidad que el control
##      ciego B. La comparación es contra B, no contra un número fijo: lo que
##      mide es el efecto de la evitación mutua.
##
## El desvío del RVO se mide sobre `safe_velocity` comparada con la velocidad
## DESEADA (`NavigationAgent3D.velocity`, la que fija `chase`), y NO sobre la
## velocidad final de la escena ni sobre la recta al objetivo: con el zombi
## andando "hacia adelante" (D-018) el rumbo del cuerpo no coincide con la
## recta al objetivo, así que medir contra esa recta contaría el giro como si
## fuera evitación.
##
## Nota: los errores de script NO detienen la ejecución en Godot, así que la
## salida hay que mirarla además del RESULTADO: no debe aparecer ningún
## `SCRIPT ERROR`.
##
## Uso: godot --headless --path . res://tools/probe_avoidance.tscn

const ZOMBIE_SCENE := preload("res://scenes/zombies/zombie.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

## Velocidad que se le impone a cada zombi. La escena trae 1.5; con el bug de
## doble multiplicación la velocidad resultante sería SPEED², así que poner
## 2.0 deja el bug en 4.0 y el fix en 2.0 (margen claro para medir).
const SPEED := 2.0
## Distancia mínima exigida entre dos zombis en planta. La caja de colisión
## mide 0.51 x 0.46, así que por debajo de ~0.45 ya se atraviesan.
const MIN_DIST := 0.45
## Techo de frames de física por escenario. El bucle se corta antes si todos
## llegan al objetivo.
const MAX_FRAMES := 2400
var fallos := 0

var _target: Player
var _zombies: Array[Zombie] = []
var _fires: Dictionary = {}
var _max_speed := 0.0
var _min_dist := INF
var _max_rvo_dev := 0.0
var _reached := 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	_build_floor()
	_build_navmesh()

	var target: Player = PLAYER_SCENE.instantiate()
	add_child(target)
	target.global_position = Vector3(0, 0, -9)
	_target = target

	# Dejar que el navmesh se registre en el mapa de navegación por defecto.
	for i in 5:
		await get_tree().physics_frame

	# Los mismos cuatro spawns para B y C: la única variable que cambia es
	# la máscara de evitación.
	var grupo: Array[Vector3] = [
		Vector3(-1.2, 0, 4), Vector3(1.2, 0, 4),
		Vector3(-1.2, 0, 6), Vector3(1.2, 0, 6),
	]

	print("=== A) Un zombi solo (sin vecinos) ===")
	await _run([Vector3(0, 0, 4)], target, true)
	_dump()
	ok(_zombies.size() == 1, "el escenario A spawneó 1 zombi (%d)" % _zombies.size())
	var lat_a := _max_rvo_dev
	ok(lat_a <= SPEED * 0.15,
		"sin vecinos el RVO no desvía (%.3f <= %.3f m/s)" % [lat_a, SPEED * 0.15])

	print("=== B) Cuatro zombis, avoidance_mask = 0 (control ciego) ===")
	await _run(grupo, target, false)
	_dump()
	var lat_b := _max_rvo_dev
	var n := _zombies.size()
	ok(n == grupo.size(), "el escenario B spawneó %d zombis (esperaba %d)" % [n, grupo.size()])
	var ciegos_firing := _count_firing()
	var ciegos_llegaron := _reached
	ok(ciegos_firing == n,
		"el control ciego sigue emitiendo velocity_computed (%d/%d)" % [ciegos_firing, n])
	ok(ciegos_llegaron == n,
		"el control ciego también llega (%d/%d): sirve de comparación" % [ciegos_llegaron, n])
	ok(lat_b <= SPEED * 0.15,
		"el RVO ciego no desvía (%.3f <= %.3f m/s)" % [lat_b, SPEED * 0.15])

	print("=== C) Cuatro zombis, avoidance real (mask = 1) ===")
	await _run(grupo, target, true)
	_dump()

	n = _zombies.size()
	ok(n == grupo.size(), "el escenario C spawneó %d zombis (esperaba %d)" % [n, grupo.size()])
	var con_fuego := _count_firing()
	ok(con_fuego == n, "velocity_computed dispara para todos (%d/%d)" % [con_fuego, n])
	ok(_max_speed <= SPEED * 1.3,
		"la velocidad no se multiplica dos veces (%.2f <= %.2f m/s)" % [_max_speed, SPEED * 1.3])
	ok(_min_dist >= MIN_DIST,
		"nunca se atraviesan (mín %.2f >= %.2f m)" % [_min_dist, MIN_DIST])
	ok(_reached == n, "todos llegan al objetivo (%d/%d)" % [_reached, n])
	# Comparación contra el control ciego B (no contra un número fijo):
	# el margen es el doble del ruido medido en A y B.
	var margen := maxf(SPEED * 0.05, lat_b * 2.0)
	ok(_max_rvo_dev > lat_b + margen,
		"el RVO aparta a los zombis (%.3f > %.3f + %.3f m/s)"
			% [_max_rvo_dev, lat_b, margen])

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


## Corre un escenario: limpia los zombis anteriores, spawnea `spawns` ya en
## persecución y muestrea hasta que todos llegan (o `MAX_FRAMES`).
## `avoid_agents` = false deja `avoidance_mask = 0`, es decir el mismo
## código pero sin evitación mutua.
func _run(spawns: Array[Vector3], target: Player, avoid_agents: bool) -> void:
	for z in _zombies:
		if is_instance_valid(z):
			z.queue_free()
	_zombies.clear()
	_fires.clear()
	_max_speed = 0.0
	_min_dist = INF
	_max_rvo_dev = 0.0
	_reached = 0
	await get_tree().physics_frame
	await get_tree().physics_frame

	var zs: Array[Zombie] = []
	var llegaron: Dictionary = {}
	for pos in spawns:
		var z: Zombie = ZOMBIE_SCENE.instantiate()
		z.speed = SPEED
		z.can_debug = false
		add_child(z)
		# `nav` es @onready: solo existe después de entrar al árbol.
		z.nav.avoidance_mask = 1 if avoid_agents else 0
		z.global_position = pos
		z.rotation.y = 0.0
		# La visión no hace falta para el ensayo: se le pone el objetivo a
		# mano y se fuerza la transición a `chase`, que es quien usa el Nav.
		z.vision.target = target
		z.state_machine.state.finished.emit("chase")
		var id := z.get_instance_id()
		_fires[id] = 0
		z.nav.velocity_computed.connect(_on_velocity.bind(id, z))
		zs.append(z)
	_zombies = zs

	for _f in MAX_FRAMES:
		await get_tree().physics_frame

		# Traza diagnóstica del primer zombi (1 de cada 192 frames).
		if _f % 192 == 0 and zs.size() > 0 and is_instance_valid(zs[0]):
			var z0 := zs[0]
			var st := z0.state_machine.state
			print("   [f%04d] state=%-6s pos=(%.1f, %.1f, %.1f) dist=%.1f vel=(%.2f, %.2f, %.2f) stop=%s"
				% [_f, st.name, z0.global_position.x, z0.global_position.y, z0.global_position.z,
					z0.global_position.distance_to(target.global_position),
					z0.velocity.x, z0.velocity.y, z0.velocity.z,
					str(st.get("stop"))])

		var peor := INF
		for i in zs.size():
			var a := zs[i]
			if not is_instance_valid(a):
				continue

			var vh := Vector3(a.velocity.x, 0.0, a.velocity.z)
			_max_speed = maxf(_max_speed, vh.length())

			# El desvío lateral se mide en `_on_velocity`, sobre la salida
			# del RVO: aquí solo interesa si llegó al objetivo y a qué
			# distancia están los pares.
			var hacia := target.global_position - a.global_position
			hacia.y = 0.0

			if hacia.length() < 2.0:
				llegaron[a.get_instance_id()] = true

			for j in range(i + 1, zs.size()):
				var b := zs[j]
				if not is_instance_valid(b):
					continue
				var dx := a.global_position.x - b.global_position.x
				var dz := a.global_position.z - b.global_position.z
				peor = minf(peor, sqrt(dx * dx + dz * dz))

		_min_dist = minf(_min_dist, peor)

		# Cortar apenas llegan todos (ahora ya no hay más que medir).
		if llegaron.size() == zs.size() and _f > 120:
			break

	_reached = llegaron.size()


## Callback del RVO: `Nav` devuelve la velocidad ya desviada. Se mide AQUÍ
## cuánto se aparta de la velocidad DESEADA (`Nav.velocity`, la que fija
## `chase`): así se aísla lo que decide el RVO del rumbo del cuerpo.
func _on_velocity(safe_velocity: Vector3, id: int, z: Zombie) -> void:
	_fires[id] = int(_fires.get(id, 0)) + 1

	if not is_instance_valid(z):
		return

	var safe_h : Vector3 = Vector3(safe_velocity.x, 0.0, safe_velocity.z)
	var desired : Vector3 = z.nav.velocity
	var desired_h : Vector3 = Vector3(desired.x, 0.0, desired.z)
	_max_rvo_dev = maxf(_max_rvo_dev, (safe_h - desired_h).length())


func _count_firing() -> int:
	var n := 0
	for id in _fires:
		if int(_fires[id]) > 0:
			n += 1
	return n


func _dump() -> void:
	print("   vel máx        : %.2f m/s (speed = %.1f)" % [_max_speed, SPEED])
	print("   desvío del RVO: %.3f m/s" % _max_rvo_dev)
	print("   dist mín par   : %s m" % ("inf" if _min_dist == INF else "%.2f" % _min_dist))
	print("   llegaron       : %d/%d | velocity_computed: %d/%d"
		% [_reached, _zombies.size(), _count_firing(), _zombies.size()])


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)  # superficie en y = 0
	body.add_child(cs)
	add_child(body)


## Navmesh armado a mano (sin hornear): un cuadrado de 24 x 24 m en y = 0.
## Los vértices van en sentido antihorario vistos desde arriba para que la
## normal del polígono apunte a +Y.
func _build_navmesh() -> void:
	var nm := NavigationMesh.new()
	nm.set_vertices(PackedVector3Array([
		Vector3(-12, 0, -12),
		Vector3(-12, 0, 12),
		Vector3(12, 0, 12),
		Vector3(12, 0, -12),
	]))
	nm.add_polygon(PackedInt32Array([0, 1, 2]))
	nm.add_polygon(PackedInt32Array([0, 2, 3]))
	nm.agent_radius = 0.5

	var region := NavigationRegion3D.new()
	region.navigation_mesh = nm
	add_child(region)
