class_name ViewPunch
extends Node

@export var camera: Node3D
@export var camera2 : Node3D
## Fuerza del resorte (HL2: 65). Más alto = vuelve más rápido.
@export var spring_constant: float = 65.0
## Amortiguación (HL2: 9). Más alto = menos rebote.
@export var damping: float = 9.0
## Tope de seguridad del desvío total, en grados.
@export var max_punch_deg: float = 25.0

var _punch := Vector2.ZERO     # desvío actual (x = pitch, y = yaw), en grados
var _velocity := Vector2.ZERO  # velocidad del desvío, en grados/s


## kick.x: grados hacia arriba. kick.y: grados hacia la izquierda (negativo = derecha).
func punch(kick: Vector2) -> void:
	_velocity += kick * 20.0  # el x20 es el de HL2: el golpe es un "empujón", no un salto


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)  # evita inestabilidad si hay un tirón de FPS

	_punch += _velocity * delta
	_velocity *= maxf(0.0, 1.0 - damping * delta)
	_velocity -= _punch * clampf(spring_constant * delta, 0.0, 2.0)

	_punch.x = clampf(_punch.x, -max_punch_deg, max_punch_deg)
	_punch.y = clampf(_punch.y, -max_punch_deg, max_punch_deg)

	if camera:
		camera.rotation.x = deg_to_rad(_punch.x)
		camera.rotation.y = deg_to_rad(_punch.y)
	if camera2:
		camera2.rotation.x = deg_to_rad(_punch.x)
		camera2.rotation.y = deg_to_rad(_punch.y)
