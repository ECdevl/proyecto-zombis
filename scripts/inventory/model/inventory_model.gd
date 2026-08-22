class_name InventoryModel extends Resource

signal item_placed(descriptor: ItemDescriptor, row: int, col: int, rotated: bool)
signal item_removed(descriptor: ItemDescriptor)
signal item_used(descriptor: ItemDescriptor)


var grid: Array = []  # Array[Array[ItemDescriptor]] -- solo datos, sin nodos
@export var dimensions: Vector2i = Vector2i(10, 7)

@export var starting_items : Array[ItemDescriptor]

func init_grid() -> void:
	if not grid.is_empty():
		return  # ya inicializado, no pisar items existentes
	grid.clear()
	for y in dimensions.y:      # filas = altura
		grid.append([])
		for x in dimensions.x:  # columnas = ancho
			grid[y].append(null)
	if starting_items.size() > 0:
		for item in starting_items:
			add_item_by_descriptor(item)


func _size_for(descriptor: ItemDescriptor, rotated: bool) -> Vector2i:
	if rotated:
		return Vector2i(descriptor.dimensions.y, descriptor.dimensions.x)
	return descriptor.dimensions


# models/inventory/inventory_model.gd

func can_place(descriptor: ItemDescriptor, row: int, col: int, rotated: bool = false) -> bool:
	if _contains_model(descriptor):
		return false
	if row < 0 or col < 0:
		return false
	var size := _size_for(descriptor, rotated)
	if row + size.y > dimensions.y or col + size.x > dimensions.x:
		return false
	for y in size.y:
		for x in size.x:
			if grid[row + y][col + x] != null:
				return false
	return true


# ¿Yo (self) ya estoy en algún lugar dentro del árbol de contenedores de `descriptor`?
# Cubre el caso directo (metértela a sí misma) y el anidado (mochila A dentro de mochila B
# que ya está dentro de mochila A).
func _contains_model(descriptor: ItemDescriptor) -> bool:
	if descriptor is not WearableItemDescriptor:
		return false
	var nested: InventoryModel = (descriptor as WearableItemDescriptor).container_model
	if nested == null:
		return false
	if nested == self:
		return true
	for row in nested.grid:
		for cell_descriptor in row:
			if cell_descriptor != null and self._contains_model(cell_descriptor):
				return true
	return false

func try_place(descriptor: ItemDescriptor, row: int, col: int, rotated: bool = false) -> bool:
	if not can_place(descriptor, row, col, rotated):
		return false
	var size := _size_for(descriptor, rotated)
	for y in size.y:
		for x in size.x:
			grid[row + y][col + x] = descriptor
	item_placed.emit(descriptor, row, col, rotated)
	return true


func remove_item(descriptor: ItemDescriptor) -> void:
	var anchor := get_grid_position(descriptor)
	if anchor.x < 0:
		return
	var size := get_occupied_size(descriptor, anchor)
	for y in size.y:
		for x in size.x:
			grid[anchor.y + y][anchor.x + x] = null
	item_removed.emit(descriptor)


# Primera celda (arriba-izquierda) donde aparece el descriptor en el grid.
func get_grid_position(descriptor: ItemDescriptor) -> Vector2i:
	for row in grid.size():
		for col in grid[row].size():
			if grid[row][col] == descriptor:
				return Vector2i(col, row)
	return Vector2i(-1, -1)


# Cuántas celdas ocupa realmente a partir del ancla (ya refleja si está rotado).
func get_occupied_size(descriptor: ItemDescriptor, anchor: Vector2i) -> Vector2i:
	var row := anchor.y
	var col := anchor.x
	var w := 0
	while col + w < dimensions.x and grid[row][col + w] == descriptor:
		w += 1
	var h := 0
	while row + h < dimensions.y and grid[row + h][col] == descriptor:
		h += 1
	return Vector2i(w, h)


func is_rotated(descriptor: ItemDescriptor) -> bool:
	var anchor := get_grid_position(descriptor)
	if anchor.x < 0:
		return false
	return get_occupied_size(descriptor, anchor) != descriptor.dimensions


func find_free_position(w: int, h: int) -> Vector2i:
	for row in dimensions.y - h + 1:
		for col in dimensions.x - w + 1:
			if _area_free(row, col, w, h):
				return Vector2i(col, row)
	return Vector2i(-1, -1)


func _area_free(row: int, col: int, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			if grid[row + y][col + x] != null:
				return false
	return true



func add_item_by_descriptor(descriptor: ItemDescriptor) -> bool:
	var origin := find_free_position(descriptor.dimensions.x, descriptor.dimensions.y)
	if origin == Vector2i(-1, -1):
		return false
	return try_place(descriptor, origin.y, origin.x)
