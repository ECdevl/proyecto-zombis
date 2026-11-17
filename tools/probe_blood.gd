extends Node3D
## Sonda del sistema de sangre (T-016): chorro en la herida + decals al caer.
##
##   1) Tiro a la cabeza → chorro rápido (velocidad alta) en hit_pos y decals al caer.
##   2) Roce en la pierna (daño 0.1) → chorro lento + pocos decals.
## NOTA: desde 2026-11-06 el draw pass es RibbonTrailMesh (amount fijo 24);
## la escala por daño se mide por initial_velocity_max, no por amount.
##   3) Dirección de salida: el material del chorro mira hacia la dirección del tiro.
##   4) Salida positiva (-Z) queda más lejos del punto de impacto que el aterrizaje.
##
## Uso: godot --headless --path . res://tools/probe_blood.tscn

const ZOMBIE_SCENE: PackedScene = preload("res://scenes/zombies/zombie.tscn")

var fallos: int = 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	_build_floor()

	print("=== 1) Tiro a la cabeza ===")
	var c1: Dictionary = await _shoot({"head": true, "damage": 9999.0})
	ok(c1.get("burst_count", 0) >= 1, "se instanció 1 chorro en la herida (%d)" % int(c1.get("burst_count", 0)))
	ok(float(c1.get("vmax", 0.0)) > 6.0, "chorro de cabeza rápido (vmax = %.1f)" % float(c1.get("vmax", 0.0)))
	ok(int(c1.get("decals", 0)) >= 1, "hay decals donde cae la sangre (%d)" % int(c1.get("decals", 0)))

	print("=== 2) Roce en la pierna ===")
	var c2: Dictionary = await _shoot({"head": false, "damage": 0.1})
	ok(c2.get("burst_count", 0) >= 1, "se instanció chorro pequeño (%d)" % int(c2.get("burst_count", 0)))
	ok(float(c2.get("vmax", 0.0)) < float(c1.get("vmax", 0.0)), "el roce sangra menos que la cabeza (%.1f < %.1f)" % [float(c2.get("vmax", 0.0)), float(c1.get("vmax", 0.0))])

	print("=== 3) Dirección de salida ===")
	ok(int(c1.get("has_ppm", 0)) == 1, "el chorro tiene ParticleProcessMaterial")
	var dir_dot: float = float(c1.get("dir_dot", -1.0))
	ok(dir_dot > 0.9, "el chorro sale hacia la dirección del tiro (dot = %.2f)" % dir_dot)

	print("=== 4) Decals más cerca del suelo que el chorro ===")
	var ground_y: float = float(c1.get("ground_y", 99.0))
	var burst_y: float = float(c1.get("burst_y", 0.0))
	ok(ground_y < burst_y, "los decals están en el piso (%.2f < %.2f)" % [ground_y, burst_y])

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


func _shoot(opts: Dictionary) -> Dictionary:
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	add_child(z)
	z.global_position = Vector3(0, 0.9, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var who: Area3D = null
	if bool(opts.get("head", false)):
		who = z.find_child("Physical Bone neck", true, false) as Area3D
	else:
		who = z.find_child("thight_left", true, false) as Area3D
	# Atacante a 4 m al -Z mirando al zombi: la salida es hacia +Z.
	var dummy := Node3D.new()
	add_child(dummy)
	dummy.global_position = Vector3(0, 1.2, -4.0)
	var hit_pos: Vector3 = who.global_position if who != null else z.global_position + Vector3.UP
	var expected: Vector3 = dummy.global_position.direction_to(hit_pos)
	var info: Dictionary = {"who": who, "attacker": dummy, "hit_pos": hit_pos}
	z.hurted(float(opts.get("damage", 1.0)), info)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var burst_count: int = 0
	var vmax: float = 0.0
	var burst_y: float = 0.0
	var ppm_dot: float = -1.0
	var has_ppm: int = 0
	for node: Node in get_tree().current_scene.get_children():
		if node is BloodBurst:
			burst_count += 1
			var b: BloodBurst = node as BloodBurst
			vmax = (b.process_material as ParticleProcessMaterial).initial_velocity_max if b.process_material is ParticleProcessMaterial else 0.0
			burst_y = b.global_position.y
			var ppm: Variant = b.process_material
			if ppm is ParticleProcessMaterial:
				has_ppm = 1
				var d: Vector3 = (ppm as ParticleProcessMaterial).direction
				if d.length_squared() > 0.001 and expected.length_squared() > 0.001:
					ppm_dot = d.normalized().dot(expected.normalized())
	var ground_y: float = 99.0
	var decals: int = 0
	for node: Node in get_tree().current_scene.get_children():
		if node is Decal:
			decals += 1
			ground_y = minf(ground_y, (node as Node3D).global_position.y)
	if decals == 0:
		ground_y = -1.0
	var result: Dictionary = {
		"burst_count": burst_count,
		"vmax": vmax,
		"burst_y": burst_y,
		"dir_dot": ppm_dot,
		"has_ppm": has_ppm,
		"decals": decals,
		"ground_y": ground_y,
	}
	dummy.queue_free()
	z.queue_free()
	for node: Node in get_tree().current_scene.get_children():
		if node is BloodBurst or node is Decal or node is BloodSplatter:
			node.queue_free()
	await get_tree().physics_frame
	return result


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	add_child(body)
