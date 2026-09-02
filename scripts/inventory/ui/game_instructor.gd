extends RichTextLabel

var target: Node3D        # El objeto 3D a rastrear

@export var margin: float = 50    # Margen en píxeles para que la flecha no se corte
@onready var arrow: TextureRect = %arrow
func set_target(targ:Node3D,label:String) -> void:
	target = targ
	text = "[img=40]res://Assets/sprites/instructor_warn.png[/img] " + label 

func _ready() -> void:
	var tween = create_tween()
	tween.set_loops(0)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self,"scale",Vector2(1.25,1.25),.5)
	tween.tween_property(self,"scale",Vector2(1,1),.5)

func _process(_delta: float) -> void:
	if not target or not is_instance_valid(target):
		queue_free()
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	else:
		show()

	var view_size = get_viewport_rect().size
	var my_size = size
	
	# Definimos los vectores de límite basados en el tamaño de la pantalla y el nodo
	var min_vector = Vector2(margin, margin)
	var max_vector = Vector2(view_size.x - my_size.x - margin, view_size.y - my_size.y - margin)

	# 1. Proyección inicial a la pantalla
	var screen_pos = camera.unproject_position(target.global_position)

	# 2. CORRECCIÓN CLAVE: Si está detrás, invertimos la posición respecto al centro de la pantalla
	if camera.is_position_behind(target.global_position):
		var screen_center = view_size / 2.0
		var direction_from_center = (screen_pos - screen_center).normalized()
		# Forzamos a que el vector apunte al lado opuesto del centro de la pantalla
		screen_pos = screen_center - direction_from_center * max(view_size.x, view_size.y)

	# 3. Validar si está fuera de los márgenes visibles (ya sea por estar detrás o muy a los lados)
	var is_off_screen = screen_pos.x < min_vector.x or screen_pos.x > max_vector.x or screen_pos.y < min_vector.y or screen_pos.y > max_vector.y


	if is_off_screen or camera.is_position_behind(target.global_position):
		# Modo Instructor: Se queda pegado en los bordes respetando tus márgenes
		global_position = screen_pos.clamp(min_vector, max_vector)
		arrow.show()
		arrow.rotation = screen_pos.angle()
		visible_characters = 1
		
	else:
		visible_characters = -1
		# Modo Normal: Sigue al objeto flotando perfectamente sobre él en el mundo 3D
		global_position = screen_pos
		arrow.hide()
