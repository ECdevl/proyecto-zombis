extends RichTextLabel
## Cartel del "game instructor" (estilo Left 4 Dead 2).
## - WORLD: sigue a un objetivo 3D; si no se ve, se pega al borde con flecha.
## - SCREEN: pista fija en pantalla (p. ej. teclas a pulsar), sin objetivo ni flecha.

enum Mode { WORLD, SCREEN }

const DEFAULT_ICON: String = "res://assets/sprites/instructor_warn.png"
const KEY_DARK_DIR: String = "res://assets/sprites/keys/Dark/"
const KEY_LIGHT_DIR: String = "res://assets/sprites/keys/Light/"

var mode: Mode = Mode.WORLD
var target: Node3D  # objetivo 3D a seguir (modo WORLD)
var hint_id: StringName = &""  # identificador opcional para gestionarlo desde la UI

@export var margin: float = 50.0  # distancia mínima a los bordes de la pantalla
@onready var arrow: TextureRect = %arrow


## Muestra una pista anclada a un objeto 3D (objeto, enemigo, etc.).
func set_target(targ: Node3D, label: String, icon_path: String = DEFAULT_ICON) -> void:
	mode = Mode.WORLD
	target = targ
	visible_characters = -1
	_apply_label(label, icon_path)
	_set_arrow_visible(false)


## Muestra una pista fija en pantalla (sin objetivo 3D). No usa flecha.
## 'anchor_preset' y 'anchor_offset' permiten colocarla (p. ej. centro-inferior).
func set_screen(label: String, icon_path: String = "", anchor_preset: int = -1, anchor_offset: Vector2 = Vector2.ZERO) -> void:
	mode = Mode.SCREEN
	target = null
	visible_characters = -1
	fit_content = true
	_apply_label(label, icon_path)
	_set_arrow_visible(false)
	if anchor_preset >= 0:
		call_deferred("_apply_screen_anchor", anchor_preset, anchor_offset)


func _apply_screen_anchor(anchor_preset: int, anchor_offset: Vector2) -> void:
	set_anchors_and_offsets_preset(anchor_preset, Control.PRESET_MODE_MINSIZE, 0)
	position += anchor_offset


func _apply_label(label: String, icon_path: String) -> void:
	if icon_path.is_empty():
		text = label
	else:
		text = "[img=40]%s[/img] %s" % [icon_path, label]


## Actualiza solo el contenido de la pista (útil para refrescar teclas pulsadas).
func update_label(label: String, icon_path: String = "") -> void:
	_apply_label(label, icon_path)


func _set_arrow_visible(is_visible: bool) -> void:
	if arrow:
		arrow.visible = is_visible


func _ready() -> void:
	var tween: Tween = create_tween()
	tween.set_loops(0)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2(1.11, 1.11), 1)
	tween.tween_property(self, "scale", Vector2(1, 1), 1)


func _process(_delta: float) -> void:
	if mode == Mode.SCREEN:
		return
	if not is_instance_valid(target):
		queue_free()
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	show()

	var world_pos: Vector3 = target.global_position
	if not camera.is_position_behind(world_pos):
		var screen_pos: Vector2 = camera.unproject_position(world_pos)
		if _fits_on_screen(screen_pos):
			_show_on_target(screen_pos)
			return
	_show_on_edge(camera.to_local(world_pos))


## ¿El cartel entra completo dentro de los márgenes si su esquina está en 'screen_pos'?
func _fits_on_screen(screen_pos: Vector2) -> bool:
	var inner: Vector2 = Vector2(margin, margin)
	var area: Rect2 = Rect2(inner, get_viewport_rect().size - size - inner * 2.0)
	return area.has_point(screen_pos)


func _show_on_target(screen_pos: Vector2) -> void:
	global_position = screen_pos
	visible_characters = -1
	_set_arrow_visible(false)


## 'local_pos' = posición del objetivo en el espacio de la cámara (x derecha, y arriba, -z adelante).
func _show_on_edge(local_pos: Vector3) -> void:
	var dir: Vector2 = Vector2(local_pos.x, -local_pos.y)
	if dir.is_zero_approx():
		dir = Vector2.DOWN  # justo en el eje de la cámara: no hay dirección, elegimos una
	dir = dir.normalized()

	var center: Vector2 = get_viewport_rect().size * 0.5
	var half: Vector2 = center - Vector2(margin, margin) - size * 0.5
	var t: float = minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))

	global_position = center + dir * t - size * 0.5  # el cartel queda centrado en ese punto
	visible_characters = 1
	_set_arrow_visible(true)
	arrow.rotation = dir.angle()  # 0 = flecha mirando a la derecha
