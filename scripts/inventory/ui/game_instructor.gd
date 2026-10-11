extends RichTextLabel
## Cartel que sigue a un objeto 3D. Si el objeto no se ve, queda pegado al borde
## de la pantalla y una flecha indica hacia dónde mirar.

var target: Node3D  # objeto 3D a seguir

@export var margin: float = 50  # distancia mínima a los bordes de la pantalla
@onready var arrow: TextureRect = %arrow


func set_target(targ: Node3D, label: String) -> void:
	target = targ
	text = "[img=40]res://Assets/sprites/instructor_warn.png[/img] " + label


func _ready() -> void:
	var tween := create_tween()
	tween.set_loops(0)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), .5)
	tween.tween_property(self, "scale", Vector2(1, 1), .5)


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	show()

	var world_pos := target.global_position
	if not camera.is_position_behind(world_pos):
		var screen_pos := camera.unproject_position(world_pos)
		if _fits_on_screen(screen_pos):
			_show_on_target(screen_pos)
			return
	_show_on_edge(camera.to_local(world_pos))


## ¿El cartel entra completo dentro de los márgenes si su esquina está en 'screen_pos'?
func _fits_on_screen(screen_pos: Vector2) -> bool:
	var inner := Vector2(margin, margin)
	var area := Rect2(inner, get_viewport_rect().size - size - inner * 2.0)
	return area.has_point(screen_pos)


func _show_on_target(screen_pos: Vector2) -> void:
	global_position = screen_pos
	visible_characters = -1
	arrow.hide()


## 'local_pos' = posición del objetivo en el espacio de la cámara (x derecha, y arriba, -z adelante).
## Pasos:
##  1) dirección en pantalla: d = (x, -y)   (en pantalla "abajo" es +y, en la cámara es al revés)
##  2) rayo desde el centro C:  P(t) = C + d*t
##  3) 'half' = cuánto puede alejarse el CENTRO del cartel del centro de pantalla
##  4) el rayo toca el borde vertical en t_x = half.x/|d.x| y el horizontal en t_y = half.y/|d.y|;
##     el primero que ocurre (el menor t) es el borde real.
## Esto funciona también si el objetivo está detrás de la cámara.
func _show_on_edge(local_pos: Vector3) -> void:
	var dir := Vector2(local_pos.x, -local_pos.y)
	if dir.is_zero_approx():
		dir = Vector2.DOWN  # justo en el eje de la cámara: no hay dirección, elegimos una
	dir = dir.normalized()

	var center := get_viewport_rect().size * 0.5
	var half := center - Vector2(margin, margin) - size * 0.5
	var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))

	global_position = center + dir * t - size * 0.5  # el cartel queda centrado en ese punto
	visible_characters = 1
	arrow.show()
	arrow.rotation = dir.angle()  # 0 = flecha mirando a la derecha
