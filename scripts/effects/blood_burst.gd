class_name BloodBurst
extends GPUParticles3D
## Chorro de sangre que sale de la herida en el momento del golpe.
##
## El chorro es visual: las partículas vuelan con gravedad en espacio de mundo
## (sin colisión física por partícula, por rendimiento con hordas). Donde cae
## la sangre lo dibujan los decal de `BloodSplatter` (posición de impacto +
## proyección al piso). Este nodo solo pinta el chorro y se libera solo con la
## señal `finished`.
##
## Recibe la dirección de SALIDA (`exit_dir`): el vector del proyectil/tajo
## que sigue después de atravesar el cuerpo (de atacante hacia el punto de
## impacto). Sin atacante se usa la salida del propio zombi.

## Fuerza mínima del chorro (toque leve, p. ej. pierna a melee).
@export var min_strength := 0.35
## Fuerza máxima del chorro (tiro a la cabeza, muerte).
@export var max_strength := 1.5
## Tope global de chorros vivos: si hay más, el nuevo se descarta.
## Evita inundar con una escopeta o muchos zombis a la vez.
@export var max_active := 12

static var _active := 0
var _counted: bool = false


func _ready() -> void:
	_counted = true
	_active += 1
	finished.connect(_on_finished)


func _discard() -> void:
	if _counted:
		_counted = false
		_active = maxi(0, _active - 1)
	queue_free()


func _on_finished() -> void:
	_discard()


## Enciende el chorro en `world_pos` hacia `exit_dir` con intensidad
## `strength` (0 = nada, 1 = golpe normal, >1 = cabeza/muerte).
func spray(world_pos: Vector3, exit_dir: Vector3, strength: float) -> void:
	if strength <= 0.0:
		_discard()
		return
	if _active > max_active:
		_discard()
		return
	var dir: Vector3 = exit_dir
	if dir.length_squared() < 0.0001 or not dir.is_finite():
		dir = Vector3.UP
	global_position = world_pos + dir.normalized() * 0.03
	# El material es compartido entre instancias: duplicarlo para poder
	# orientar y escalar cada chorro sin mover los demás.
	var mat: Variant = process_material.duplicate()
	var ppm: ParticleProcessMaterial = mat as ParticleProcessMaterial
	if ppm == null:
		_discard()
		return
	ppm.direction = dir.normalized()
	# La velocidad inicial y la cantidad escalan con la fuerza del golpe.
	ppm.initial_velocity_min = 2.5 * strength
	ppm.initial_velocity_max = 7.0 * strength
	process_material = ppm
	restart()
