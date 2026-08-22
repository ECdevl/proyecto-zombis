extends GridContainer
class_name InventoryView

@export var inventory_model: InventoryModel

const CELL_SIZE : int = 50

const CELL_GAP : int = 4
const CELL_STEP : int = CELL_SIZE + CELL_GAP

const COLOR_NORMAL : Color = Color(0.22,0.22,0.22)
const COLOR_VALID : Color = Color(0,255,0)
const COLOR_INVALID : Color = Color(255,0,0)

const ITEM_VISUAL_SCENE = preload("uid://cnpyo1vrq877x")
const SLOT = preload("uid://t0si10ufqqi6")

@export var test_slots : Array[ItemDescriptor]
@export var item_layer : Control

var _visuals: Dictionary = {}  # ItemDescriptor -> ItemVisual



func _ready() -> void:
	add_to_group("drop_targets")  # antes: "inventory_views"

static func find_at(global_pos: Vector2, tree: SceneTree) -> Control:
	for v in tree.get_nodes_in_group("drop_targets"):
		if v is Control and v.get_global_rect().has_point(global_pos):
			return v
	return null
	
func _process(_delta: float) -> void:
	reposition_items()


func release_visual(descriptor: ItemDescriptor) -> void:
	_visuals.erase(descriptor)

func setup(model: InventoryModel) -> void:
	if inventory_model:
		if inventory_model.item_placed.is_connected(_on_item_placed):
			inventory_model.item_placed.disconnect(_on_item_placed)
		if inventory_model.item_removed.is_connected(_on_item_removed):
			inventory_model.item_removed.disconnect(_on_item_removed)

	inventory_model = model
	inventory_model.init_grid()
	_init_cells()
	clear_preview()
	inventory_model.item_placed.connect(_on_item_placed)
	inventory_model.item_removed.connect(_on_item_removed)

	_rebuild_items()

	if test_slots:
		for i in test_slots:
			inventory_model.add_item_by_descriptor.call_deferred(i)

func reposition_items() -> void:
	for descriptor in _visuals:
		var pos := inventory_model.get_grid_position(descriptor)
		if pos.x >= 0:
			_visuals[descriptor].global_position = cell_to_world(pos.y, pos.x)

func _init_cells() -> void:
	columns = inventory_model.dimensions.x
	for i in inventory_model.dimensions.x * inventory_model.dimensions.y:
		add_child(SLOT.instantiate())


func _rebuild_items() -> void:
	for row in inventory_model.grid:
		for descriptor in row:
			if descriptor and not _visuals.has(descriptor):
				_spawn_visual(descriptor)


func _spawn_visual(descriptor: ItemDescriptor) -> ItemVisual:
	var visual: ItemVisual = ITEM_VISUAL_SCENE.instantiate()
	visual.descriptor = descriptor
	visual.view = self
	visual.rotated = inventory_model.is_rotated(descriptor)
	item_layer.add_child(visual)
	_visuals[descriptor] = visual
	return visual


func close() -> void:
	for visual in item_layer.get_children():
		item_layer.remove_child(visual)
		visual.queue_free()
	_visuals.clear()
	if inventory_model.item_placed.is_connected(_on_item_placed):
		inventory_model.item_placed.disconnect(_on_item_placed)
	if inventory_model.item_removed.is_connected(_on_item_removed):
		inventory_model.item_removed.disconnect(_on_item_removed)


func _on_item_placed(descriptor: ItemDescriptor, row: int, col: int, rotated: bool) -> void:
	var visual: ItemVisual = _visuals.get(descriptor)
	if visual == null:
		visual = _spawn_visual(descriptor)
	visual.rotated = rotated
	visual.update_item()
	visual.global_position = cell_to_world(row, col)
	clear_preview()


func _on_item_removed(descriptor: ItemDescriptor) -> void:
	# El nodo visual sigue vivo (puede estar siendo arrastrado en ese momento).
	# Destruirlo de verdad es responsabilidad de una futura acción explícita
	# (usar/tirar item), no de remove_item.
	clear_preview()


func try_place(item: ItemVisual, world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos, item.cur_w(), item.cur_h())
	if cell.x == -1:
		return false

	if not inventory_model.can_place(item.descriptor, cell.y, cell.x, item.rotated):
		return false

	if item.view != self:
		item.view.release_visual(item.descriptor)
		item.get_parent().remove_child(item)
		item_layer.add_child(item)
		_visuals[item.descriptor] = item
		item.view = self

	return inventory_model.try_place(item.descriptor, cell.y, cell.x, item.rotated)


func remove_item(item: ItemVisual) -> void:
	inventory_model.remove_item(item.descriptor)


func update_preview(item : ItemVisual, world_pos: Vector2) -> void:
	clear_preview()
	var cell : Vector2i = world_to_cell(world_pos, item.cur_w(), item.cur_h())
	if cell.x == -1:
		return
	var color := COLOR_VALID if inventory_model.can_place(item.descriptor, cell.y, cell.x, item.rotated) else COLOR_INVALID
	for y in range(item.cur_h()):
		for x in range(item.cur_w()):
			color_cell(cell.y + y, cell.x + x, color)


func clear_preview() -> void:
	for y in inventory_model.dimensions.y:
		for x in inventory_model.dimensions.x:
			color_cell(y, x, COLOR_NORMAL)


func world_to_cell(world_pos:Vector2, w:int, h:int) -> Vector2i:
	var local := world_pos - global_position
	local -= Vector2(w,h) * CELL_STEP * 0.5
	var col := roundi(local.x / CELL_STEP)
	var row := roundi(local.y / CELL_STEP)
	if row < 0 or col < 0 or row + h > inventory_model.dimensions.y or col + w > inventory_model.dimensions.x:
		return Vector2i(-1,-1)
	return Vector2i(col,row)


func cell_to_world(row: int, col: int) -> Vector2:
	return get_child(
		row * inventory_model.dimensions.x + col
	).global_position

func color_cell(row:int, col:int, color:Color) -> void:
	get_child(row * inventory_model.dimensions.x + col).self_modulate = color
