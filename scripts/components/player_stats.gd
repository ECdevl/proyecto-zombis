extends Resource
class_name PlayerStats

@export var base_carry_weight : float = 10.0
@export var base_speed : float = 1.0
@export_group("Movement Feel")
## Unidades/s² al apretar una dirección: cuánto tarda en arrancar
## (tiempo = velocidad / acceleration).
@export var acceleration : float = 12.0
## Unidades/s² al soltar las teclas: cuánto tarda en parar y cuánto derrapa
## (derrape = velocidad² / (2 · deceleration)). También se usa para frenar
## cuando la nueva dirección va en contra de la velocidad actual.
@export var deceleration : float = 25.0
## Multiplicador de control en el aire (0 = ninguno, 1 = igual que en suelo).
## Sin input en el aire NO se frena: el impulso del salto se conserva.
@export_range(0.0, 1.0, 0.05) var air_control : float = 0.5
