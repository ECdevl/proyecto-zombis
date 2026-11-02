extends SceneTree
## Sonda de física: mide el ATRAVIESO del piso (tunneling) de un objeto
## delgado tipo machete, en las mismas condiciones del juego:
##   - motor Jolt (project.godot), 120 ticks/s,
##   - piso estático con trimesh (igual que test.tscn),
##   - casco convexo REAL del machete (extraído del prefab),
##   - velocidad de soltado igual a la del juego (6 m/s horizontales).
##
## Variantes medidas por ola (solo V2 y V6 cuentan en el RESULTADO):
##   V1 casco + CCD apagado (línea base documental del bug)
##   V2 casco + CCD encendido (fix candidato)
##   V3 BoxShape3D del mismo tamaño (¿es culpa del tipo de colisión?)
##   V4 casco engrosado +1 cm en el eje fino (mitigación documentada por Godot)
##   V5 forma ESCALADA (x100 en puntos + escala 0.01 en el nodo) — ¿soporta
##      Jolt escalar formas de colisión? (Godot docs dice que no)
##   V6 prefab real + descriptor machete = el objeto del juego (cuenta)
##
## Escenarios por ola (5 cuerpos, repartidos en z):
##   S1 spawn plano (caída lenta, como el machete puesto en la escena)
##   S2 soltado plano (6 m/s horizontales)
##   S3 soltado de canto (eje fino hacia abajo)
##   S4 soltado mango-primero con giro (impacto de extremo + rotación)
##   S5 caída vertical rápida (30 m/s, prueba de estrés de CCD)
##
## Uso: godot --headless --path . --script res://tools/probe_tunel.gd

const TIEMPO_S := 3.0
const SPAWN_Y := 1.5

var fallos := 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _initialize() -> void:
	var ticks := Engine.physics_ticks_per_second
	print("ticks/s = %d | motor = %s" % [ticks,
			ProjectSettings.get_setting("physics/3d/physics_engine")])
	var pasos := int(TIEMPO_S * ticks)

	# Piso idéntico al de test.tscn: caja grande con colisión trimesh,
	# cara superior en y = 0.
	var piso := StaticBody3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(50, 1.725, 36)
	var cs_piso := CollisionShape3D.new()
	cs_piso.shape = caja.create_trimesh_shape()
	piso.add_child(cs_piso)
	piso.position = Vector3(0, -0.8625, 0)
	get_root().add_child(piso)

	# Diagnóstico previo: trayectoria tick a tick de V1 en S1 (plano) y
	# S3 (de canto) para ver si hay contacto con el piso o no lo hay.
	var puntos_diag := _casco_machete()
	if puntos_diag.size() > 0:
		await _diagnosticar_trayectoria(puntos_diag)
		await _experimentos_causa(puntos_diag)

	# Casco real del machete tal como lo genera el juego (desde item_mesh).
	var puntos := _casco_machete()
	ok(puntos.size() > 0, "casco del machete derivado del descriptor (%d puntos)" % puntos.size())
	var aabb := _aabb_de_puntos(puntos)
	print("casco: %.3f x %.3f x %.3f m (largo x alto x grosor)" %
			[aabb.size.x, aabb.size.y, aabb.size.z])

	# Aserciones del fix: el prefab del juego debe traer CCD activo y SIN
	# casco horneado (la colisión se regenera desde el descriptor).
	var prefab := load("res://scenes/components/pickable_object.tscn") as PackedScene
	var inst := prefab.instantiate()
	ok((inst as RigidBody3D).continuous_cd,
			"prefab: continuous_cd activo (fix E-012)")
	var col_prefab := inst.get_node(^"Colision") as CollisionShape3D
	ok(col_prefab != null and col_prefab.shape == null,
			"prefab: sin casco horneado obsoleto en 'Colision'")
	inst.free()

	var escenarios := [
		{"nombre": "S1 spawn plano", "rot": Basis.IDENTITY, "vel": Vector3.ZERO, "ang": Vector3.ZERO},
		{"nombre": "S2 soltado plano", "rot": Basis.IDENTITY, "vel": Vector3(6, 0, 0), "ang": Vector3.ZERO},
		{"nombre": "S3 soltado de canto", "rot": Basis(Vector3.RIGHT, PI / 2), "vel": Vector3(6, 0, 0), "ang": Vector3.ZERO},
		{"nombre": "S4 mango-primero + giro", "rot": Basis(Vector3.BACK, 0.35), "vel": Vector3(6, -3, 0), "ang": Vector3(0, 0, 8)},
		{"nombre": "S5 caída vertical 30 m/s", "rot": Basis.IDENTITY, "vel": Vector3(0, -30, 0), "ang": Vector3.ZERO},
	]

	var forma_casco := ConvexPolygonShape3D.new()
	forma_casco.points = puntos
	var forma_caja := BoxShape3D.new()
	forma_caja.size = aabb.size
	var forma_gruesa := ConvexPolygonShape3D.new()
	forma_gruesa.points = _engrosar(puntos, 0.01)
	var forma_escalada := ConvexPolygonShape3D.new()
	var pts100: PackedVector3Array = []
	for p in puntos:
		pts100.append(p * 100.0)
	forma_escalada.points = pts100

	var olas := [
		{"nombre": "V1 casco + CCD off (línea base del bug)", "forma": forma_casco, "ccd": false, "escala": Vector3.ONE, "cuenta": false},
		{"nombre": "V2 casco + CCD on (fix)", "forma": forma_casco, "ccd": true, "escala": Vector3.ONE, "cuenta": true},
		{"nombre": "V3 BoxShape3D (mismo tamaño)", "forma": forma_caja, "ccd": false, "escala": Vector3.ONE, "cuenta": false},
		{"nombre": "V4 casco +1cm eje fino", "forma": forma_gruesa, "ccd": false, "escala": Vector3.ONE, "cuenta": false},
		{"nombre": "V5 forma x100 con escala 0.01", "forma": forma_escalada, "ccd": false, "escala": Vector3(0.01, 0.01, 0.01), "cuenta": false},
	]

	for ola in olas:
		print("")
		print("=== %s ===" % ola["nombre"])
		var cuerpos: Array[RigidBody3D] = []
		for i in escenarios.size():
			var esc: Dictionary = escenarios[i]
			# En la ola V5 solo corre S1 (es la prueba del soporte de escala).
			if ola["nombre"].begins_with("V5") and i > 0:
				continue
			var cuerpo := RigidBody3D.new()
			cuerpo.collision_layer = 2
			cuerpo.collision_mask = 7
			cuerpo.continuous_cd = ola["ccd"]
			var cs := CollisionShape3D.new()
			cs.shape = ola["forma"]
			cs.scale = ola["escala"]
			cuerpo.add_child(cs)
			cuerpo.position = Vector3(-10, SPAWN_Y, -10 + i * 5.0)
			cuerpo.basis = esc["rot"]
			cuerpo.name = "cuerpo_%d" % i
			get_root().add_child(cuerpo)
			cuerpo.linear_velocity = esc["vel"]
			cuerpo.angular_velocity = esc["ang"]
			cuerpos.append(cuerpo)
		for _p in pasos:
			await physics_frame
		for i in cuerpos.size():
			var c := cuerpos[i]
			var etiqueta: String = escenarios[i]["nombre"] if i < escenarios.size() else "?"
			var y := c.position.y
			if y < -0.5:
				print("  ATRAVESÓ  %-28s y_final = %+.3f" % [etiqueta, y])
				if ola["cuenta"]:
					fallos += 1
			else:
				print("  quedó     %-28s y_final = %+.3f" % [etiqueta, y])
			c.free()

	# V6: el objeto REAL del juego — instancia del prefab con descriptor,
	# el mismo flujo que Player.drop_item() (la colisión la regenera el
	# script desde el mesh y el CCD viene del prefab).
	var desc_machete := load("res://resources/weapons/melee/machete.tres")
	print("")
	print("=== V6 prefab real + descriptor machete (objeto del juego, cuenta) ===")
	if desc_machete == null:
		ok(false, "V6: no se pudo cargar el descriptor machete")
	else:
		var cuerpos6: Array[RigidBody3D] = []
		for i in escenarios.size():
			var esc: Dictionary = escenarios[i]
			var cuerpo := prefab.instantiate() as RigidBody3D
			cuerpo.set("item_descriptor", desc_machete)
			cuerpo.position = Vector3(-10, SPAWN_Y, -10 + i * 5.0)
			cuerpo.basis = esc["rot"]
			get_root().add_child(cuerpo)
			cuerpo.linear_velocity = esc["vel"]
			cuerpo.angular_velocity = esc["ang"]
			cuerpos6.append(cuerpo)
		for _p in pasos:
			await physics_frame
		for i in cuerpos6.size():
			var c := cuerpos6[i]
			var y := c.position.y
			if y < -0.5:
				print("  ATRAVESÓ  %-28s y_final = %+.3f" % [escenarios[i]["nombre"], y])
				fallos += 1
			else:
				print("  quedó     %-28s y_final = %+.3f" % [escenarios[i]["nombre"], y])
			c.free()

	print("")
	if fallos == 0:
		print("RESULTADO: NINGÚN ATRAVIESO")
	else:
		print("RESULTADO: %d ATRAVIESO(S)" % fallos)
	quit(1 if fallos > 0 else 0)


## Puntos del casco convexo del machete, derivados EXACTAMENTE como los
## deriva el juego: _sincronizar_colision llama
## `mesh.create_convex_shape(false, false)` sobre item_mesh del descriptor.
## El prefab ya no hornea casco (fix E-012), así que se carga desde ahí.
func _casco_machete() -> PackedVector3Array:
	var desc := load("res://resources/weapons/melee/machete.tres")
	if desc == null or desc.item_mesh == null:
		return PackedVector3Array()
	var forma: Shape3D = desc.item_mesh.create_convex_shape(false, false)
	if forma is ConvexPolygonShape3D:
		return (forma as ConvexPolygonShape3D).points
	return PackedVector3Array()


func _aabb_de_puntos(pts: PackedVector3Array) -> AABB:
	if pts.is_empty():
		return AABB()
	var aabb := AABB(pts[0], Vector3.ZERO)
	for i in range(1, pts.size()):
		aabb = aabb.expand(pts[i])
	return aabb


## Engrosa el casco sumando `m` a cada lado del eje fino (z), la dirección
## donde el objeto mide apenas milímetros (recomendación de los docs de Godot
## para objetos rápidos: la forma debe extenderse un poco fuera del objeto).
func _engrosar(pts: PackedVector3Array, m: float) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for p in pts:
		var z := p.z
		out.append(Vector3(p.x, p.y, z + (m if z >= 0.0 else -m)))
	return out


## Trajectory tick a tick (V1, casco real, CCD apagado) de dos cuerpos:
##   T1 plano (S1) y T2 de canto (S3).
## Imprime una fila por tick mientras el objeto está cerca del piso
## (y < 0.20) para responder: ¿contacta y falla la depenetración, o
## atraviesa sin contactar nunca?
func _diagnosticar_trayectoria(pts: PackedVector3Array) -> void:
	var ticks := Engine.physics_ticks_per_second
	var forma := ConvexPolygonShape3D.new()
	forma.points = pts

	# Altura del casco por debajo del origen en cada orientación
	# (contacto teórico: y = -min_y_de_puntos).
	var aabb := _aabb_de_puntos(pts)
	print("")
	print("=== DIAGNÓSTICO de trayectoria (V1 casco, CCD off) ===")
	print("casco AABB y: [%.4f, %.4f] | grosor z = %.4f m" %
			[aabb.position.y, aabb.position.y + aabb.size.y, aabb.size.z])
	print("velocidad por tick a 120 Hz = 1/%d m por tick" % ticks)

	var casos := [
		{"nombre": "T1 plano (S1)", "rot": Basis.IDENTITY},
		{"nombre": "T2 de canto (S3)", "rot": Basis(Vector3.RIGHT, PI / 2)},
	]
	for caso in casos:
		var c := RigidBody3D.new()
		c.collision_layer = 2
		c.collision_mask = 7
		c.continuous_cd = false
		var cs := CollisionShape3D.new()
		cs.shape = forma
		c.add_child(cs)
		c.position = Vector3(-10, 1.5, 0)
		c.basis = caso["rot"]
		get_root().add_child(c)

		# Altura mínima de los puntos transformados = y de contacto teórica.
		var y_contacto := 0.0
		var min_y := INF
		for p in pts:
			var pw: Vector3 = caso["rot"] * p
			min_y = min(min_y, pw.y)
		y_contacto = -min_y
		print("")
		print("-- %s | contacto teórico en y = %.4f (abajo del casco en y=0)" %
				[caso["nombre"], y_contacto])

		var impreso := false
		for paso in ticks * 3:
			await physics_frame
			var y := c.position.y
			# Imprime solo la ventana de aproximación + cruce.
			if y < 0.20:
				print("   t=%6.1f ms  y=%+.4f  vy=%+.3f m/s (%.1f cm/tick)" %
						[paso * 1000.0 / ticks, y, c.linear_velocity.y,
							absf(c.linear_velocity.y) * 100.0 / ticks])
				impreso = true
			if impreso and y < -1.0:
				print("   ... y = %.3f (ya muy por debajo, sin contacto)" % y)
				break
		c.free()


## Experimentos para aislar la causa del fallo de contacto, todos con el
## casco plano y CCD apagado:
##   A) barrido de alturas de caída sobre el piso trimesh del juego →
##      ¿existe un umbral de "primera penetración por tick"?
##   B) mismo barrido sobre una caja SÓLIDA (BoxShape3D) →
##      ¿es culpa del trimesh?
##   C) trimesh con backface_collision = true →
##      ¿es culpa de las caras unidireccionales?
func _experimentos_causa(pts: PackedVector3Array) -> void:
	var forma := ConvexPolygonShape3D.new()
	forma.points = pts
	var aabb := _aabb_de_puntos(pts)
	var y_c := -aabb.position.y  # altura de contacto del casco plano
	var alturas := [y_c, 0.07, 0.10, 0.15, 0.30, 0.60, 1.50]
	print("")
	print("=== EXPERIMENTOS: umbral de la primera penetración (casco plano, CCD off) ===")
	print("contacto teórico y = %.4f | alturas de caída = %s" % [y_c, str(alturas)])

	# A: el piso trimesh ya creado en _initialize (backface=false, como el juego).
	var rA: Array = await _correr_caida(forma, alturas, Vector3(-10, 0, -7))

	# B: piso de caja sólida, lejos del escenario.
	var suelo_b := StaticBody3D.new()
	var cs_b := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(50, 1.725, 36)
	cs_b.shape = caja
	suelo_b.add_child(cs_b)
	suelo_b.position = Vector3(100, -0.8625, 0)
	get_root().add_child(suelo_b)
	var rB: Array = await _correr_caida(forma, alturas, Vector3(100, 0, -7))
	suelo_b.free()

	# C: trimesh con backface_collision = true.
	var suelo_c := StaticBody3D.new()
	var cs_c := CollisionShape3D.new()
	var malla := BoxMesh.new()
	malla.size = Vector3(50, 1.725, 36)
	cs_c.shape = malla.create_trimesh_shape()
	(cs_c.shape as ConcavePolygonShape3D).backface_collision = true
	suelo_c.add_child(cs_c)
	suelo_c.position = Vector3(200, -0.8625, 0)
	get_root().add_child(suelo_c)
	var rC: Array = await _correr_caida(forma, alturas, Vector3(200, 0, -7))
	suelo_c.free()

	print("")
	print("   altura  | A trimesh (juego) | B caja sólida | C trimesh backface=true")
	for i in alturas.size():
		print("   %-7.4f | %-18s | %-13s | %s" % [alturas[i], rA[i], rB[i], rC[i]])


## Crea un cuerpo con `forma` por cada altura de `alturas`, deja caer 2,5 s
## (CCD apagado) y devuelve un String por cuerpo con el desenlace.
func _correr_caida(forma: Shape3D, alturas: Array, origen: Vector3) -> Array:
	var cuerpos: Array[RigidBody3D] = []
	for i in alturas.size():
		var c := RigidBody3D.new()
		c.collision_layer = 2
		c.collision_mask = 7
		c.continuous_cd = false
		var cs := CollisionShape3D.new()
		cs.shape = forma
		c.add_child(cs)
		c.position = Vector3(origen.x, alturas[i], origen.z + i * 1.5)
		get_root().add_child(c)
		cuerpos.append(c)
	var pasos := int(2.5 * Engine.physics_ticks_per_second)
	for _p in pasos:
		await physics_frame
	var res: Array = []
	for c in cuerpos:
		var y := c.position.y
		res.append("y=%+.3f %s" % [y, "quedó" if y > -0.5 else "ATRAVESÓ"])
		c.free()
	return res
