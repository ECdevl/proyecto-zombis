class_name Melee extends EquippableDescriptor
## Arma cuerpo a cuerpo. Daño, rango, velocidad y empuje vienen de EquippableDescriptor.

## Máximo de swings por arma: más chocaría con las animaciones de brazos.
const MAX_SWINGS := 2

## Se elige uno al azar en cada golpe.
@export var swings: Array[SwingData]
## Radio del volumen de golpe. HOY NO SE USA: el golpe es un rayo fino
## (`MeleeProjectile.fire()`). Queda reservado por si el hitbox vuelve a ser un
## volumen (barrido por extremidades, por ejemplo).
@export var hitbox_radius: float = 0.15


## Valores por defecto de Melee. Los .tres viejos no guardaron lo que valía igual que el default.
func _init() -> void:
	damage = 25.0
	weapon_range = 1.0
	fire_rate = 0.4
