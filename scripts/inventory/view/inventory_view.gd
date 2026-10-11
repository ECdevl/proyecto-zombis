extends GridContainer
class_name InventoryView
## Dibuja UN InventoryModel: las casillas + un ItemVisual por objeto.
## No decide nada: el arrastre y los clicks los maneja InventoryUIController.

signal item_pressed(view: InventoryView, visual: ItemVisual, button: int)

const CELL_SIZE := 50
const CELL_GAP := 4
const CELL_STEP := CELL_SIZE + CELL_GAP

const COLOR_NORMAL := Color(0.22, 0.22, 0.22)
const COLOR_VALID := Color(0, 255, 0)
const COLOR_INVALID := Color(255, 0, 0)

const ITEM_VISUAL_SCENE = preload("uid://cnpyo1vrq877x")
const SLOT = preload("uid://t0si10ufqqi6")

@export var item_layer: Control

var model: InventoryModel
var _visuals: Dictionary[ItemInstance, ItemVisual] = {}


func _ready() -> void:
	add_to_group("drop_targets")
	set_process(false)  # se activa en setup()


func setup(new_model: InventoryModel) -> void:
	model = new_model
	model.setup()
	columns = model.dimensions.x
	for i in model.dimensions.x * model.dimensions.y:
		add_child(SLOT.instantiate())
	model.changed.connect(refresh)
	clear_preview()
	refresh()
	set_process(true)


func _process(_delta: float) -> void:
	_place_visuals()


## Deja los visuales iguales al modelo: borra los que sobran, crea los que faltan.
func refresh() -> void:
	for item in _visuals.keys():
		if not model.has_item(item):
			_visuals[item].queue_free()
			_visuals.erase(item)
	for item: ItemInstance in model.items():
		if not _visuals.has(item):
			_spawn_visual(item)
		_visuals[item].set_rotated(model.is_rotated(item))


## Crea un visual sin agregarlo a ningún lado (también sirve para el "fantasma" del arrastre).
static func make_visual(item: ItemInstance, rotated: bool) -> ItemVisual:
	var visual: ItemVisual = ITEM_VISUAL_SCENE.instantiate()
	visual.setup(item, rotated)
	return visual


func _spawn_visual(item: ItemInstance) -> void:
	var visual := make_visual(item, model.is_rotated(item))
	visual.pressed.connect(_on_visual_pressed)
	item_layer.add_child(visual)
	_visuals[item] = visual


func _on_visual_pressed(visual: ItemVisual, button: int) -> void:
	item_pressed.emit(self, visual, button)


func _place_visuals() -> void:
	for item in _visuals:
		var origin := _slot(model.get_rect(item).position).global_position
		_visuals[item].place_at(origin)


# --- Mouse -> celda --------------------------------------------------------

## Celda de la grilla donde queda la esquina arriba-izquierda de un objeto de tamaño
## 'footprint' (en celdas) centrado en 'global_pos'. (-1,-1) si se sale de la grilla.
## Fórmula: celda = round((mouse - origen_grilla - footprint * PASO / 2) / PASO)
func cell_at(global_pos: Vector2, footprint: Vector2i) -> Vector2i:
	var top_left := global_pos - global_position - Vector2(footprint) * CELL_STEP * 0.5
	var cell := Vector2i((top_left / CELL_STEP).round())
	if not Rect2i(Vector2i.ZERO, model.dimensions).encloses(Rect2i(cell, footprint)):
		return Vector2i(-1, -1)
	return cell


func show_preview(item: ItemInstance, global_pos: Vector2, rotated: bool) -> void:
	clear_preview()
	var footprint := model.footprint_of(item, rotated)
	var cell := cell_at(global_pos, footprint)
	if cell.x < 0:
		return
	var color := COLOR_VALID if model.can_place(item, cell, rotated) else COLOR_INVALID
	for y in footprint.y:
		for x in footprint.x:
			_slot(cell + Vector2i(x, y)).self_modulate = color


func clear_preview() -> void:
	for slot: Control in get_children():
		slot.self_modulate = COLOR_NORMAL


func _slot(cell: Vector2i) -> Control:
	return get_child(cell.y * model.dimensions.x + cell.x)
