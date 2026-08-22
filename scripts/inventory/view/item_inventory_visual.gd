extends TextureRect
class_name ItemVisual

var item_w : int = 1
var item_h : int = 1

@export var descriptor : ItemDescriptor

var rotated : bool = false
var dragging : bool = false
var view : InventoryView = null

var old_row : int = -1
var old_col : int = -1
var old_rotated : bool = false

var _hover_view : Control = null

const TOOL_TIP = preload("uid://ciydg2iod5xvi")


func _ready() -> void:
	item_w = descriptor.dimensions.x
	item_h = descriptor.dimensions.y
	texture = descriptor.icon
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false

	update_item()



func cur_w() -> int:
	return item_h if rotated else item_w

func cur_h() -> int:
	return item_w if rotated else item_h

func update_item() -> void:
	size = Vector2(cur_w(),cur_h()) * view.CELL_STEP - Vector2.ONE * view.CELL_GAP

	pivot_offset = size * 0.5
	var draw_size : Vector2 = size if not rotated else Vector2(size.y,size.x)
	size = draw_size
	position = (size-draw_size)*0.5
	
	rotation_degrees = 90 if rotated else 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			start_drag()
		elif dragging and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			rotate_item()

func _input(event: InputEvent) -> void:

	if not dragging:
		return
	
	var mouse : Vector2 = get_global_mouse_position()
	
	if event is InputEventMouseMotion:
		global_position = mouse - size * 0.5

		var target := InventoryView.find_at(mouse, get_tree())
		if target != _hover_view:
			if _hover_view:
				if _hover_view is InventoryView:
					_hover_view.clear_preview()
			_hover_view = target
		if _hover_view:
			if _hover_view is InventoryView:
				_hover_view.update_preview(self, mouse)

	elif event.is_action_pressed("rotate"):
		rotate_item()
	elif event.is_action_released("M1"):
		end_drag()

func start_drag() -> void:
	var pos := view.inventory_model.get_grid_position(descriptor)
	old_row = pos.y
	old_col = pos.x
	old_rotated = rotated
	dragging = true
	z_index = 10
	_hover_view = view
	view.remove_item(self)


func end_drag() -> void:
	dragging = false
	z_index = 0
	var placed = _hover_view != null and _hover_view.try_place(self, get_global_mouse_position())
	if placed:
		if _hover_view is InventoryView:
			_hover_view.clear_preview()
		else:
			view.release_visual(descriptor)  # avisar a la view de origen antes de destruirse
			queue_free()
	else:
		rotated = old_rotated
		update_item()
		if old_row >= 0:
			view.inventory_model.try_place(descriptor, old_row, old_col, old_rotated)
		if _hover_view is InventoryView:
			_hover_view.clear_preview()
	_hover_view = null

func rotate_item() -> void:
	var center : Vector2 = global_position + size * 0.5
	rotated = !rotated
	update_item()
	global_position = center - size * 0.5
	if _hover_view:
		_hover_view.update_preview(self, get_global_mouse_position())


func _on_mouse_entered() -> void:
	var tip = TOOL_TIP.instantiate()
	tip.resource = descriptor
	add_child(tip)


func _on_mouse_exited() -> void:
	get_child(0).queue_free()
