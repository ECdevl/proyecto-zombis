extends Node3D
## Sonda de la escopeta (D-037): datos del descriptor, daño dividido, dirección
## de los perdigones y elección del proyectil en WeaponController.
##
## Uso: godot --headless --path . res://tools/probe_escopeta.tscn

const REMINGTON_RES = preload("res://resources/weapons/firearm/remington.tres")
const GLOCK_RES = preload("res://resources/weapons/firearm/glock-17.tres")

## Captura las direcciones de los rayos sin tocar la física: basta con
## reemplazar `_trace_ray` para que `fire()` no consulte el mundo.
class Recorder extends ShotgunProjectile:
	## Array externo: `fire()` llama a `queue_free()`, así que el Recorder ya no
	## existe cuando se comprueban las direcciones. El Array sí sobrevive.
	var sink: Array[Vector3] = []

	func _trace_ray(origin: Vector3, direction: Vector3, max_range: float) -> Dictionary:
		var dir: Vector3 = direction.normalized()
		sink.append(dir)
		_ray_end = origin + dir * max_range
		return {}


var fallos: int = 0
var _camera: Camera3D = null


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true

	var rem: Weapon = REMINGTON_RES as Weapon
	var glock: Weapon = GLOCK_RES as Weapon

	print("=== 1) Datos del descriptor ===")
	ok(rem.weapon_type == Weapon.WEAPON_TYPE.SHOTGUN, "remington es SHOTGUN")
	ok(rem.pellets_per_shot == 8, "8 perdigones por cartucho (%d)" % rem.pellets_per_shot)
	ok(is_equal_approx(rem.pellet_spread_deg, 4.0), "semiángulo 4° (%.2f)" % rem.pellet_spread_deg)
	ok(is_equal_approx(rem.damage, 50.0), "daño del arma 50 (%.2f)" % rem.damage)
	ok(rem.curr_bullets > 0, "tiene munición inicial (%d)" % rem.curr_bullets)
	ok(glock.pellets_per_shot == 1, "una pistola sigue con 1 perdigón por defecto")

	print("=== 2) Daño dividido entre los perdigones ===")
	var dmg: ShotgunProjectile = ShotgunProjectile.new()
	add_child(dmg)
	dmg.setup(rem.pellets_per_shot, rem.pellet_spread_deg, rem.damage, rem.weapon_range)
	ok(is_equal_approx(dmg.damage, 6.25), "50 / 8 = 6.25 por perdigón (%.4f)" % dmg.damage)
	ok(is_equal_approx(dmg._damage_for(null), 6.25), "_damage_for devuelve el daño del perdigón")
	ok(is_equal_approx(dmg.damage * float(dmg.pellets), rem.damage), "si impactan todos suma 50")
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("=== 3) Un perdigón siempre al centro, el resto disperso ===")
	var straight_dirs: Array[Vector3] = []
	var straight: Recorder = Recorder.new()
	straight.sink = straight_dirs
	add_child(straight)
	straight.setup(9, 0.0, 50.0, 100.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	ok(straight_dirs.size() == 9, "se lanzan 9 rayos (%d)" % straight_dirs.size())
	var forward: Vector3 = -_camera.global_basis.z
	var all_center: bool = true
	for dir: Vector3 in straight_dirs:
		if dir.distance_to(forward) > 0.000001:
			all_center = false
	ok(all_center, "con 0° todos van por la mira")

	var spread_dirs: Array[Vector3] = []
	var spread: Recorder = Recorder.new()
	spread.sink = spread_dirs
	add_child(spread)
	spread.setup(9, 8.0, 50.0, 100.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	ok(spread_dirs.size() == 9, "con dispersión se lanzan 9 rayos (%d)" % spread_dirs.size())
	if spread_dirs.size() > 0:
		ok(spread_dirs[0].distance_to(forward) < 0.000001, "el perdigón 0 va exactamente al centro")
	var max_angle: float = 0.0
	var some_off_center: bool = false
	for i in range(1, spread_dirs.size()):
		var angle: float = rad_to_deg(acos(clampf(spread_dirs[i].dot(forward), -1.0, 1.0)))
		max_angle = maxf(max_angle, angle)
		if angle > 0.5:
			some_off_center = true
	ok(some_off_center, "los perdigones 1..8 se desperdigan")
	ok(max_angle <= 8.0 + 0.001, "ninguno sale del cono de 8° (máx %.3f°)" % max_angle)

	print("=== 4) WeaponController elige el proyectil ===")
	var holder: Node3D = Node3D.new()
	add_child(holder)
	var wc: WeaponController = WeaponController.new()
	wc.weapon_node = holder

	wc.load_projectile(rem)
	var escopeta_child: Node = holder.get_child(0)
	ok(escopeta_child is ShotgunProjectile, "remington instancia ShotgunProjectile")
	if escopeta_child is ShotgunProjectile:
		ok((escopeta_child as ShotgunProjectile).pellets == 8, "con 8 perdigones")
	await get_tree().physics_frame
	await get_tree().physics_frame

	wc.load_projectile(glock)
	# El proyectil de la escopeta puede seguir unos frames en el árbol hasta
	# que se procese su queue_free(); el último hijo es siempre el recién creado.
	var pistola_child: Node = holder.get_child(holder.get_child_count() - 1)
	ok(pistola_child is Projectile and not (pistola_child is ShotgunProjectile), "glock sigue con Projectile")
	await get_tree().physics_frame
	await get_tree().physics_frame

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
