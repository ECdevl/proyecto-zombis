extends Control
class_name ItemVisual
## Dibujo de UN objeto en la grilla. No arrastra ni decide: solo avisa que lo clickearon.

signal pressed(visual: ItemVisual, button: int)

const TOOL_TIP = preload("uid://ciydg2iod5xvi")

var item: ItemInstance
var rotated := false
## false = solo dibujo (el fantasma que sigue al mouse no debe recibir clicks).
var interactive := true

var _tooltip: Control


func setup(new_item: ItemInstance, is_rotated: bool) -> void:
	item = new_item
	get_child(0).texture = item.descriptor.icon
	set_rotated(is_rotated)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if get_child(0).texture == null and item:
		await item.descriptor.ensure_icon(self)
		get_child(0).texture = item.descriptor.icon


## El control mantiene su tamaño "sin rotar" y se gira 90° alrededor de su centro.
func set_rotated(value: bool) -> void:
	rotated = value
	size = Vector2(item.descriptor.dimensions) * InventoryView.CELL_STEP \
			- Vector2.ONE * InventoryView.CELL_GAP
	pivot_offset = size * 0.5
	rotation_degrees = 90.0 if rotated else 0.0


## Alinea lo que SE VE con la celda de origen.
## Girar 90° alrededor del centro deja el centro quieto, así que:
##   posición = origen_celda + (tamaño_que_ocupa - tamaño_del_control) / 2
func place_at(cell_origin: Vector2) -> void:
	var occupied := Vector2(size.y, size.x) if rotated else size
	global_position = cell_origin + (occupied - size) * 0.5


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed:
		pressed.emit(self, click.button_index)


func _on_mouse_entered() -> void:
	if _tooltip or item == null:
		return
	_tooltip = TOOL_TIP.instantiate()
	_tooltip.resource = item.descriptor
	_tooltip.top_level = true  # ignora la rotación/posición de este visual
	add_child(_tooltip)
	_tooltip.global_position = get_global_mouse_position()


func _on_mouse_exited() -> void:
	if _tooltip:
		_tooltip.queue_free()
		_tooltip = null
