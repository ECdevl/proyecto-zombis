extends Resource
class_name PlayerStats

@export var base_carry_weight : float = 10.0
@export var base_speed : float = 1.0
@export_group("Movement Feel")
## Unidades/s² al apretar una dirección.
@export var acceleration : float = 40.0
## Unidades/s² al soltar las teclas.
@export var deceleration : float = 50.0
## Multiplicador de control en el aire (0 = ninguno, 1 = igual que en suelo).
@export_range(0.0, 1.0, 0.05) var air_control : float = 0.3
