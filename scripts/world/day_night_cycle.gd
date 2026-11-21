class_name DayNightCycle
extends Node3D
## Ciclo día/noche autocontenido.
##
## Contrato de escena (ver scenes/environment/day_night_cycle.tscn):
##   WorldEnvironment (WorldEnvironment)  — entorno propio del ciclo
##   Sun          (DirectionalLight3D)    — luz del sol
##   Moon         (DirectionalLight3D)    — luz de la luna
##
## La dirección de una DirectionalLight3D es -Z de su basis global; la posición
## del nodo se ignora (documentación oficial de Godot 4.7). Por eso este script
## solo rota las luces y nunca las traslada.
##
## El reloj avanza de forma continua dentro de cada fase. Cada fase tiene su
## propia duración real y su propio rango horario, de modo que la hora no salta
## al cruzar amanecer/atardecer:
##   hour_rate = (horas de la fase) / (duración real de la fase)

signal phase_changed(phase: StringName)
signal hour_changed(hour: float)
signal sun_direction_changed(direction: Vector3)

enum Phase { DAY, NIGHT }

const _DAY: StringName = &"day"
const _NIGHT: StringName = &"night"

## Duración real de cada fase, en segundos. Se comprueba en _ready().
@export var day_duration_seconds: float = 120.0
@export var night_duration_seconds: float = 60.0

## Reloj. 0 = medianoche, 12 = mediodía.
@export_range(0.0, 24.0, 0.1) var start_hour: float = 6.0
@export_range(0.0, 24.0, 0.1) var day_start_hour: float = 6.0
@export_range(0.0, 24.0, 0.1) var night_start_hour: float = 18.0

@export var auto_start: bool = true

## Elevated guidance de la trayectoria: el sol describe un arco de este a oeste.
@export var sun_rise_azimuth_deg: float = 90.0
@export var sun_set_azimuth_deg: float = 270.0
@export var sun_max_elevation_deg: float = 75.0

## Colores e intensidades. Se interpolan en los crepúsculos.
@export var day_light_color: Color = Color(1.0, 0.95, 0.85, 1.0)
@export var night_light_color: Color = Color(0.45, 0.55, 0.85, 1.0)
@export var day_light_energy: float = 1.2
@export var night_light_energy: float = 0.25
@export var twilight_hours: float = 1.0

@export var day_sky_color: Color = Color(0.45, 0.65, 0.9, 1.0)
@export var night_sky_color: Color = Color(0.02, 0.03, 0.09, 1.0)
@export var day_ambient_energy: float = 0.6
@export var night_ambient_energy: float = 0.15

## Skyboxes equirectangulares. Se conmutan según la hora; si falta la asignación,
## el entorno cae al color de fondo interpolado.
@export var morning_sky_texture: Texture2D
@export var afternoon_sky_texture: Texture2D
@export var night_sky_texture: Texture2D

## Límites de hora para cada skybox: [day_start_hour, morning_sky_end_hour) usa
## la de mañana, [morning_sky_end_hour, night_sky_start_hour) la de tarde y
## [night_sky_start_hour, day_start_hour) la de noche (el último rango puede
## envolver la medianoche).
@export_range(0.0, 24.0, 0.1) var morning_sky_end_hour: float = 12.0
@export_range(0.0, 24.0, 0.1) var night_sky_start_hour: float = 19.0

## Anchura del fundido, en horas de reloj, alrededor de cada umbral.
## El fundido se centra en morning_sky_end_hour, night_sky_start_hour y en el
## cruce de medianoche (day_start_hour). 0 desactiva la transición.
@export_range(0.0, 6.0, 0.05) var sky_transition_hours: float = 1.0

## Permite sustituir el Environment desde fuera de la escena.
@export var env: Environment

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var moon: DirectionalLight3D = $Moon

var _hour: float = 6.0
var _phase: int = Phase.DAY
var _time_in_phase: float = 0.0
var _running: bool = false
var _last_emitted_hour: float = -1.0
var _last_emitted_phase: int = -1
var _sky_transition_valid: bool = true

func _ready() -> void:
	_validate_configuration()
	# El override debe instalarse ANTES de aplicar el entorno; si no, _apply_all()
	# modificaría el Environment de la escena y después se descartaría.
	if env != null and world_environment != null:
		world_environment.environment = env
	_hour = fmod(start_hour, 24.0)
	if _hour < 0.0:
		_hour += 24.0
	_phase = _phase_for_hour(_hour)
	_time_in_phase = _elapsed_in_phase(_hour, _phase)
	_running = auto_start
	_apply_all()
	_emit_state(true)
func _process(delta: float) -> void:
	if not _running:
		return
	_time_in_phase += delta
	var span_hours: float = _phase_hours(_phase)
	var duration: float = _phase_duration(_phase)
	var advance: float = span_hours * delta / duration
	var previous_hour: float = _hour
	var next_hour: float = _hour + advance
	_hour = fmod(next_hour, 24.0)

	var limit: float = _phase_end_hour(_phase)
	var crossed: bool = _reached_limit(previous_hour, next_hour, limit)
	if crossed:
		# Solo se conserva el exceso de la fase anterior. El reloj sigue siendo
		# continuo porque ambas fases parten de la misma hora de transición.
		var excess_seconds: float = maxf(0.0, _time_in_phase - duration)
		_phase = _opposite(_phase)
		_time_in_phase = excess_seconds
		_apply_all()
		_emit_state(true)
	else:
		_apply_all()
		_emit_state(false)

func start() -> void:
	_running = true

func stop() -> void:
	_running = false

func set_hour(value: float) -> void:
	_hour = fmod(value, 24.0)
	if _hour < 0.0:
		_hour += 24.0
	_phase = _phase_for_hour(_hour)
	_time_in_phase = _elapsed_in_phase(_hour, _phase)
	_apply_all()
	_emit_state(true)

func get_hour() -> float:
	return _hour

func get_phase() -> StringName:
	return _DAY if _phase == Phase.DAY else _NIGHT

func get_sun_direction() -> Vector3:
	if sun == null:
		return Vector3.FORWARD
	return -(sun.global_basis.z.normalized())

func get_time_left_in_phase() -> float:
	return maxf(0.0, _phase_duration(_phase) - _time_in_phase)

func _validate_configuration() -> void:
	if day_duration_seconds <= 0.0 or night_duration_seconds <= 0.0:
		push_error("DayNightCycle: las duraciones deben ser > 0")
		set_process(false)
		return
	if not is_equal_approx(day_start_hour, night_start_hour):
		_sky_transition_valid = _validate_sky_thresholds()
		return
	push_error("DayNightCycle: day_start_hour y night_start_hour no pueden coincidir")
	set_process(false)

func _phase_for_hour(hour_value: float) -> int:
	if _is_in_day(hour_value):
		return Phase.DAY
	return Phase.NIGHT

func _is_in_day(hour_value: float) -> bool:
	if day_start_hour < night_start_hour:
		return hour_value >= day_start_hour and hour_value < night_start_hour
	# El día cruza medianoche (p. ej. 20:00 -> 04:00).
	return hour_value >= day_start_hour or hour_value < night_start_hour

func _opposite(phase: int) -> int:
	return Phase.NIGHT if phase == Phase.DAY else Phase.DAY

func _phase_hours(phase: int) -> float:
	var start_h: float = day_start_hour if phase == Phase.DAY else night_start_hour
	var end_h: float = night_start_hour if phase == Phase.DAY else day_start_hour
	var span: float = end_h - start_h
	if span <= 0.0:
		span += 24.0
	return span

func _phase_end_hour(phase: int) -> float:
	return night_start_hour if phase == Phase.DAY else day_start_hour

func _phase_duration(phase: int) -> float:
	return day_duration_seconds if phase == Phase.DAY else night_duration_seconds

func _elapsed_in_phase(hour_value: float, phase: int) -> float:
	var start_h: float = day_start_hour if phase == Phase.DAY else night_start_hour
	var span: float = _phase_hours(phase)
	var delta_h: float = hour_value - start_h
	if delta_h < 0.0:
		delta_h += 24.0
	var fraction: float = clampf(delta_h / span, 0.0, 1.0)
	return fraction * _phase_duration(phase)

## Detecta si el intervalo [from, to] (en horas, sin modular) alcanzó `limit`.
## Se compara en el espacio sin modular para no confundir el cruce de medianoche.
func _reached_limit(from_hour: float, to_hour: float, limit: float) -> bool:
	# `to_hour` se pasa sin modular (puede superar 24); `_hour` sí se reduce
	# a [0,24) para exponerlo. Por eso se compara en espacio continuo.
	var distance: float = to_hour - from_hour
	if distance <= 0.0:
		return false
	if from_hour <= limit and to_hour >= limit:
		return true
	# El límite puede estar detrás de 24 (p. ej. día 22->06: límite 6 equivale a 30).
	if limit + 24.0 >= from_hour and limit + 24.0 <= to_hour:
		return true
	return false

func _apply_all() -> void:
	_apply_sun()
	_apply_moon()
	_apply_environment()

func _apply_sun() -> void:
	if sun == null:
		return
	var t: float = _day_fraction()
	var azimuth_deg: float = lerpf(sun_rise_azimuth_deg, sun_set_azimuth_deg, t)
	var elevation_deg: float = sin(t * PI) * sun_max_elevation_deg
	sun.global_basis = _rotation_from_azimuth_elevation(azimuth_deg, elevation_deg)

	var daylight: float = _daylight_factor()
	sun.light_color = day_light_color.lerp(night_light_color, 1.0 - daylight)
	sun.light_energy = lerpf(night_light_energy, day_light_energy, daylight)
	sun.visible = daylight > 0.001

func _apply_moon() -> void:
	if moon == null:
		return
	var t: float = _night_fraction()
	var azimuth_deg: float = lerpf(sun_set_azimuth_deg, sun_rise_azimuth_deg + 360.0, t)
	var elevation_deg: float = sin(t * PI) * sun_max_elevation_deg * 0.7
	moon.global_basis = _rotation_from_azimuth_elevation(azimuth_deg, elevation_deg)
	moon.light_energy = night_light_energy * (1.0 - _daylight_factor())
	moon.visible = moon.light_energy > 0.001

func _apply_environment() -> void:
	var environment: Environment = _get_environment()
	if environment == null:
		return
	var daylight: float = _daylight_factor()
	# El color interpolado sigue gobernando la luz ambiente: con
	# ambient_light_sky_contribution = 0 el sky no ilumina la escena y se conserva
	# el control suave del crepúsculo (documentación de Environment).
	environment.background_color = night_sky_color.lerp(day_sky_color, daylight)
	environment.ambient_light_color = environment.background_color
	environment.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, daylight)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution = 0.0

	# El skybox se mezcla en la GPU con un ShaderMaterial (ver shaders/sky_blend.gdshader).
	# Si no hay material de shader o falta alguna textura, se conserva el color de fondo.
	_apply_sky(environment)

func _get_environment() -> Environment:
	if env != null:
		return env
	if world_environment == null:
		return null
	return world_environment.environment

## Umbrales relativos a day_start_hour, en [0,24). Deben estar ordenados para
## que los tres fundidos no se solapen. Si no lo están, se avisa y se usa cambio
## instantáneo para no producir mezclas incoherentes.
func _validate_sky_thresholds() -> bool:
	var afternoon_at: float = _wrapped_offset(morning_sky_end_hour - day_start_hour)
	var night_at: float = _wrapped_offset(night_sky_start_hour - day_start_hour)
	var ordered: bool = afternoon_at > 0.0 and afternoon_at < night_at and night_at < 24.0
	if not ordered:
		push_warning("DayNightCycle: umbrales de skybox desordenados; cambio instantáneo")
	return ordered

func _wrapped_offset(value: float) -> float:
	var result: float = fmod(value, 24.0)
	if result < 0.0:
		result += 24.0
	return result

## Calcula la pareja de texturas y el peso del fundido, y actualiza los uniforms
## del ShaderMaterial solo cuando cambian (evita recalcular la radiancia cada frame).
func _apply_sky(environment: Environment) -> void:
	var sky_resource: Sky = environment.sky
	var material: ShaderMaterial = null
	if sky_resource != null:
		material = sky_resource.sky_material as ShaderMaterial
	if material == null:
		environment.background_mode = Environment.BG_COLOR
		return
	if morning_sky_texture == null or afternoon_sky_texture == null or night_sky_texture == null:
		environment.background_mode = Environment.BG_COLOR
		return

	var from_texture: Texture2D = morning_sky_texture
	var to_texture: Texture2D = morning_sky_texture
	var weight: float = 0.0
	var local_hour: float = _wrapped_offset(_hour - day_start_hour)
	var afternoon_at: float = _wrapped_offset(morning_sky_end_hour - day_start_hour)
	var night_at: float = _wrapped_offset(night_sky_start_hour - day_start_hour)

	if not _sky_transition_valid:
		var instant: Texture2D = _sky_texture_for_hour(_hour)
		from_texture = instant
		to_texture = instant
	else:
		var half: float = maxf(sky_transition_hours * 0.5, 0.001)
		if absf(local_hour - afternoon_at) <= half:
			from_texture = morning_sky_texture
			to_texture = afternoon_sky_texture
			weight = smoothstep(afternoon_at - half, afternoon_at + half, local_hour)
		elif absf(local_hour - night_at) <= half:
			from_texture = afternoon_sky_texture
			to_texture = night_sky_texture
			weight = smoothstep(night_at - half, night_at + half, local_hour)
		elif local_hour >= 24.0 - half or local_hour <= half:
			from_texture = night_sky_texture
			to_texture = morning_sky_texture
			var extended: float = local_hour if local_hour >= 24.0 - half else local_hour + 24.0
			weight = smoothstep(24.0 - half, 24.0 + half, extended)
		elif local_hour < afternoon_at:
			from_texture = morning_sky_texture
			to_texture = morning_sky_texture
		elif local_hour < night_at:
			from_texture = afternoon_sky_texture
			to_texture = afternoon_sky_texture
		else:
			from_texture = night_sky_texture
			to_texture = night_sky_texture

	if material.get_shader_parameter("sky_from") != from_texture:
		material.set_shader_parameter("sky_from", from_texture)
	if material.get_shader_parameter("sky_to") != to_texture:
		material.set_shader_parameter("sky_to", to_texture)
	var current_blend: Variant = material.get_shader_parameter("sky_blend")
	if current_blend == null or not is_equal_approx(float(current_blend), weight):
		material.set_shader_parameter("sky_blend", weight)
	environment.background_mode = Environment.BG_SKY

func _sky_texture_for_hour(hour_value: float) -> Texture2D:
	if _hour_in_wrapped_range(hour_value, night_sky_start_hour, day_start_hour):
		return night_sky_texture
	if _hour_in_wrapped_range(hour_value, day_start_hour, morning_sky_end_hour):
		return morning_sky_texture
	return afternoon_sky_texture

## Rango circular [inicio, fin). Si fin < inicio, el intervalo cruza medianoche.
func _hour_in_wrapped_range(hour_value: float, start_hour_value: float, end_hour_value: float) -> bool:
	if is_equal_approx(start_hour_value, end_hour_value):
		return true
	if start_hour_value < end_hour_value:
		return hour_value >= start_hour_value and hour_value < end_hour_value
	return hour_value >= start_hour_value or hour_value < end_hour_value

func _daylight_factor() -> float:
	var half: float = maxf(twilight_hours * 0.5, 0.001)
	var day_start: float = day_start_hour
	var day_end: float = night_start_hour
	var distance_to_edge: float = minf(_hour_distance(_hour, day_start), _hour_distance(_hour, day_end))
	if _is_in_day(_hour):
		return smoothstep(0.0, half, distance_to_edge)
	return 0.0

func _day_fraction() -> float:
	var span: float = _phase_hours(Phase.DAY)
	var delta_h: float = _hour - day_start_hour
	if delta_h < 0.0:
		delta_h += 24.0
	return clampf(delta_h / span, 0.0, 1.0)

func _night_fraction() -> float:
	var span: float = _phase_hours(Phase.NIGHT)
	var delta_h: float = _hour - night_start_hour
	if delta_h < 0.0:
		delta_h += 24.0
	return clampf(delta_h / span, 0.0, 1.0)

func _hour_distance(a: float, b: float) -> float:
	var diff: float = absf(a - b)
	return minf(diff, 24.0 - diff)

## Convierte acimut/elevación (grados) en una Basis cuyo -Z apunta al astro.
## Basis.looking_at() con use_model_front=false YA apunta -Z hacia el objetivo
## (documentación oficial de Godot 4.7), que es justo lo que necesita una
## DirectionalLight3D. No se debe invertir el eje Z.
static func _rotation_from_azimuth_elevation(azimuth_deg: float, elevation_deg: float) -> Basis:
	var az: float = deg_to_rad(azimuth_deg)
	var el: float = deg_to_rad(elevation_deg)
	var toward: Vector3 = Vector3(
		sin(az) * cos(el),
		sin(el),
		-cos(az) * cos(el)
	).normalized()
	return Basis.looking_at(toward, Vector3.UP)

func _emit_state(force: bool) -> void:
	if force or not is_equal_approx(_last_emitted_hour, _hour):
		hour_changed.emit(_hour)
		_last_emitted_hour = _hour
	if force or _last_emitted_phase != _phase:
		phase_changed.emit(get_phase())
		_last_emitted_phase = _phase
	sun_direction_changed.emit(get_sun_direction())
