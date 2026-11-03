class_name SwingData extends Resource
## Un swing cuerpo a cuerpo. Se guarda un .tres por categoría de agarre
## (cuchillo, arma corta, arma larga) y lo comparten todas las armas de esa categoría.

## Nombre de la animación de brazos (nodo del AnimationTree).
@export var animation: StringName
## Segundos desde que arranca la animación hasta el golpe.
@export var hit_time: float = 0.3
## Hacia dónde empuja al zombi, en espacio local de la cámara
## (X derecha, Y arriba, -Z adelante). Ej: tajo de izquierda a derecha = Vector3.RIGHT.
@export var direction: Vector3 = Vector3.RIGHT
## Apertura total del barrido del swing, en radianes. El golpe tira un abanico
## de rayos repartidos dentro de este ángulo alrededor de la mira (D-012).
## 0.6 rad ≈ 34°. Si es 0, el golpe queda en un solo rayo (el de la mira).
@export var sweep_angle: float = 0.6
## Cantidad de rayos del abanico. El central es el de la mira: con valor impar
## hay uno exactamente en el centro.
@export var sweep_rays: int = 7
@export var recoil_kick : Vector2 = Vector2(0,2)
