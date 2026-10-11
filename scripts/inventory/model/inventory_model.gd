class_name InventoryModel extends Resource
## Grilla de objetos (bolsillos, mochila, cofre). Solo datos y reglas de colocación.
## Cada cambio emite el signal `changed` que ya trae Resource.

@export var title := ""
@export var dimensions := Vector2i(10, 7)
@export var starting_items: Array[ItemDescriptor]

var _cells: Array[ItemInstance] = []                # ancho*alto. null = celda libre
var _rects: Dictionary[ItemInstance, Rect2i] = {}   # objeto -> celdas que ocupa


## Crea la grilla y mete starting_items. Seguro de llamar más de una vez.
func setup() -> void:
	if not _cells.is_empty():
		return
	_cells.resize(dimensions.x * dimensions.y)
	for descriptor in starting_items:
		if descriptor:
			add(ItemInstance.new(descriptor))


# --- Consultas -------------------------------------------------------------

func has_item(item: ItemInstance) -> bool:
	return _rects.has(item)


func items() -> Array:
	return _rects.keys()


## Celdas que ocupa. Llamar solo si has_item(item).
func get_rect(item: ItemInstance) -> Rect2i:
	return _rects[item]


func is_rotated(item: ItemInstance) -> bool:
	return _rects[item].size != item.descriptor.dimensions


## Tamaño en celdas (ancho, alto), con o sin rotar 90°.
func footprint_of(item: ItemInstance, rotated := false) -> Vector2i:
	var dims := item.descriptor.dimensions
	return Vector2i(dims.y, dims.x) if rotated else dims


func can_place(item: ItemInstance, cell: Vector2i, rotated := false) -> bool:
	var rect := Rect2i(cell, footprint_of(item, rotated))
	if not Rect2i(Vector2i.ZERO, dimensions).encloses(rect):
		return false
	if _is_inside(item):
		return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var other: ItemInstance = _cells[y * dimensions.x + x]
			if other != null and other != item:  # 'other != item' permite mover sobre sí mismo
				return false
	return true


# --- Cambios ---------------------------------------------------------------

## Coloca (o mueve, si ya estaba acá) el objeto en 'cell'.
func place(item: ItemInstance, cell: Vector2i, rotated := false) -> bool:
	if not can_place(item, cell, rotated):
		return false
	_take_out(item)
	var rect := Rect2i(cell, footprint_of(item, rotated))
	_rects[item] = rect
	_fill(rect, item)
	emit_changed()
	return true


## Busca el primer hueco libre.
func add(item: ItemInstance) -> bool:
	var size := footprint_of(item)
	for y in range(dimensions.y - size.y + 1):
		for x in range(dimensions.x - size.x + 1):
			if place(item, Vector2i(x, y)):
				return true
	return false


func remove(item: ItemInstance) -> bool:
	if not _take_out(item):
		return false
	emit_changed()
	return true


## Mueve un objeto entre dos inventarios (pueden ser el mismo) con UN solo aviso por lado.
static func transfer(item: ItemInstance, from: InventoryModel, to: InventoryModel,
		cell: Vector2i, rotated: bool) -> bool:
	if not to.can_place(item, cell, rotated):
		return false
	if from != to:
		from._take_out(item)  # sin avisar todavía: evita que una mochila "desaparezca" un instante
	to.place(item, cell, rotated)
	if from != to:
		from.emit_changed()
	return true


# --- Internos --------------------------------------------------------------

func _take_out(item: ItemInstance) -> bool:
	if not _rects.has(item):
		return false
	_fill(_rects[item], null)
	_rects.erase(item)
	return true


func _fill(rect: Rect2i, value: ItemInstance) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_cells[y * dimensions.x + x] = value


## true si 'self' está dentro de 'item' (ej: mochila metida en sí misma o en su propio contenido).
func _is_inside(item: ItemInstance) -> bool:
	if item.container == null:
		return false
	if item.container == self:
		return true
	for inner: ItemInstance in item.container.items():
		if _is_inside(inner):
			return true
	return false
