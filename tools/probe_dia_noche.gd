extends SceneTree
## Sonda headless del ciclo día/noche.
## Ejecutar: godot --headless --path . --script res://tools/probe_dia_noche.gd

var _fallos: int = 0

func _init() -> void:
	# En _init el SceneTree aún no está listo: diferir al primer turno del loop.
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/environment/day_night_cycle.tscn") as PackedScene
	if packed == null:
		_fail("no se pudo cargar day_night_cycle.tscn")
		_finalizar()
		return

	var cycle: DayNightCycle = packed.instantiate() as DayNightCycle
	if cycle == null:
		_fail("la raíz no es DayNightCycle")
		_finalizar()
		return

	cycle.auto_start = false
	cycle.day_duration_seconds = 10.0
	cycle.night_duration_seconds = 5.0
	root.add_child(cycle)

	_check(is_equal_approx(cycle.get_hour(), 6.0), "hora inicial 6")
	_check(cycle.get_phase() == &"day", "fase inicial day")
	_check(cycle.sun != null and cycle.moon != null and cycle.world_environment != null, "hijos presentes")
	if cycle.sun == null or cycle.moon == null or cycle.world_environment == null:
		var nombres: Array[String] = []
		for hijo in cycle.get_children():
			nombres.append(hijo.name)
		printerr("  DEBUG hijos: ", nombres)
		_finalizar()
		return

	# Skyboxes: mañana [6,12), tarde [12,19), noche [19,6).
	_check(cycle.morning_sky_texture != null, "textura de mañana asignada")
	_check(cycle.afternoon_sky_texture != null, "textura de tarde asignada")
	_check(cycle.night_sky_texture != null, "textura de noche asignada")
	cycle.set_hour(8.0)
	_check(cycle.world_environment.environment.background_mode == Environment.BG_SKY, "background_mode BG_SKY activo")
	var estado: Dictionary = _sky_state(cycle)
	_check(estado["from"] == cycle.morning_sky_texture, "skybox de mañana a las 8")
	_check(is_equal_approx(float(estado["blend"]), 0.0), "sin fundido a las 8")

	cycle.set_hour(11.75)
	estado = _sky_state(cycle)
	_check(estado["from"] == cycle.morning_sky_texture and estado["to"] == cycle.afternoon_sky_texture, "fundido mañana→tarde a las 11:45")
	var mezcla: float = float(estado["blend"])
	_check(mezcla > 0.0 and mezcla < 1.0, "fundido parcial a las 11:45 (%.3f)" % mezcla)

	cycle.set_hour(15.0)
	estado = _sky_state(cycle)
	_check(estado["from"] == cycle.afternoon_sky_texture and is_equal_approx(float(estado["blend"]), 0.0), "skybox de tarde a las 15")

	cycle.set_hour(18.5)
	estado = _sky_state(cycle)
	_check(estado["from"] == cycle.afternoon_sky_texture and estado["to"] == cycle.night_sky_texture, "fundido tarde→noche a las 18:30")

	cycle.set_hour(22.0)
	estado = _sky_state(cycle)
	_check(estado["from"] == cycle.night_sky_texture and is_equal_approx(float(estado["blend"]), 0.0), "skybox de noche a las 22")

	cycle.set_hour(5.75)
	estado = _sky_state(cycle)
	_check(estado["from"] == cycle.night_sky_texture and estado["to"] == cycle.morning_sky_texture, "fundido noche→mañana a las 05:45")

	cycle.set_hour(12.0)
	var mediodia: Vector3 = cycle.get_sun_direction()
	_check(mediodia.y > 0.9, "sol alto al mediodía (y=%.3f)" % mediodia.y)
	_check(cycle.sun.visible, "sol visible al mediodía")

	cycle.set_hour(18.0)
	var atardecer: Vector3 = cycle.get_sun_direction()
	_check(absf(atardecer.y) < 0.15, "sol en el horizonte a las 18 (y=%.3f)" % atardecer.y)

	cycle.set_hour(0.0)
	_check(cycle.get_phase() == &"night", "medianoche es night")
	_check(not cycle.sun.visible, "sol apagado de noche")
	_check(cycle.moon.visible, "luna encendida de noche")
	var cielo_noche: Color = cycle.world_environment.environment.background_color

	cycle.set_hour(12.0)
	var cielo_dia: Color = cycle.world_environment.environment.background_color
	_check(cielo_dia.g > cielo_noche.g, "cielo diurno más claro que el nocturno")

	# Avance real: 10 s de día a razón de 12 h / 10 s = 1.2 h/s.
	cycle.set_hour(6.0)
	cycle.start()
	var delta: float = 0.05
	for i in range(200):
		cycle._process(delta)
	_check(cycle.get_phase() == &"night", "tras 10 s la fase pasa a night")
	_check(absf(cycle.get_hour() - 18.0) < 0.1, "hora ~18 tras el día (%.3f)" % cycle.get_hour())

	for i in range(100):
		cycle._process(delta)
	_check(cycle.get_phase() == &"day", "tras 5 s más vuelve a day")
	_check(absf(cycle.get_hour() - 6.0) < 0.1, "hora ~6 tras la noche (%.3f)" % cycle.get_hour())

	cycle.stop()
	var congelada: float = cycle.get_hour()
	for i in range(20):
		cycle._process(delta)
	_check(is_equal_approx(cycle.get_hour(), congelada), "stop() congela el reloj")

	_finalizar()

func _sky_state(cycle: DayNightCycle) -> Dictionary:
	if cycle.world_environment == null or cycle.world_environment.environment == null:
		return {"from": null, "to": null, "blend": -1.0}
	var environment: Environment = cycle.world_environment.environment
	if environment.sky == null:
		return {"from": null, "to": null, "blend": -1.0}
	var material: ShaderMaterial = environment.sky.sky_material as ShaderMaterial
	if material == null:
		return {"from": null, "to": null, "blend": -1.0}
	return {
		"from": material.get_shader_parameter("sky_from"),
		"to": material.get_shader_parameter("sky_to"),
		"blend": material.get_shader_parameter("sky_blend"),
	}

func _check(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("  PASS  ", mensaje)
	else:
		_fail(mensaje)

func _fail(mensaje: String) -> void:
	_fallos += 1
	printerr("  FAIL  ", mensaje)

func _finalizar() -> void:
	if _fallos == 0:
		print("SONDA DAY/NIGHT: OK")
	else:
		print("SONDA DAY/NIGHT: %d fallos" % _fallos)
	quit(1 if _fallos > 0 else 0)
