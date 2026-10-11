extends Control
class_name InventoryUIController
## Flujo visual del inventario: paneles, arrastre de objetos y menú de acciones.
## Los datos viven en InventoryModel / PlayerCarriedInventories. Acá solo se muestra y se reacciona.

signal item_used(item: ItemInstance)
signal item_dropped(item: ItemInstance)  # sale al mundo; quien escuche lo instancia

@export var inventory_panel_scene: PackedScene  # la escena "Inventory" completa
@export var panels_container: Control

@onready var loot_view_container: VBoxContainer = %LootViewContainer
@onready var carried: PlayerCarriedInventories = %PlayerContainers
@onready var item_actions: ItemActions = %ItemActions

var _player_panels: Dictionary[InventoryModel, Control] = {}
var _loot_panels: Dictionary[InventoryModel, Control] = {}

# Estado del arrastre (todo null = no se está arrastrando)
var _drag_item: ItemInstance
var _drag_model: InventoryModel  # de dónde sale; null = viene de una mano
var _drag_ghost: CanvasItem      # el original (visual o icono del slot): queda translúcido
var _drag_preview: ItemVisual  # copia que sigue al mouse
var _drag_rotated := false
var _hover: Control


func _ready() -> void:
	add_to_group("inventory_ui")
	carried.models_changed.connect(_sync_player_panels)
	item_actions.action_selected.connect(_on_action_selected)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_loot()


# --- API pública -----------------------------------------------------------

func open_loot(model: InventoryModel) -> void:
	if not _loot_panels.has(model):
		_loot_panels[model] = _open_panel(model, loot_view_container)


func close_loot() -> void:
	_cancel_drag()
	for panel in _loot_panels.values():
		panel.queue_free()
	_loot_panels.clear()


## Saca el objeto de donde esté (bolsillos, mochilas o cofre abierto). Ej: ya se consumió.
func remove_item(item: ItemInstance) -> bool:
	if carried.remove(item):
		return true
	for model: InventoryModel in _loot_panels.keys():
		if model.remove(item):
			return true
	return false


## Se llama desde EquipSlotView (por grupo "inventory_ui") con clic derecho.
func unequip(slot: WearableItemDescriptor.EquipSlot) -> void:
	var item := carried.equipment.get_equipped(slot)
	if item == null:
		return
	if not carried.add_anywhere(item):
		item_dropped.emit(item)
	carried.equipment.remove(item)


## Clic derecho sobre un slot de mano (lo llama HandSlotView).
func open_hand_menu(hand: HandsModel.Hand) -> void:
	var item := carried.hands.get_held(hand)
	if item:
		item_actions.open(item, get_global_mouse_position(), ["guardar"])


# --- Paneles ---------------------------------------------------------------

func _open_panel(model: InventoryModel, parent: Control) -> Control:
	var panel: Control = inventory_panel_scene.instantiate()
	parent.add_child(panel)
	panel.get_child(0).title = model.title
	var view: InventoryView = panel.inventory_view
	view.setup(model)
	view.item_pressed.connect(_on_item_pressed)
	return panel


## Deja un panel por cada contenedor que el jugador carga.
func _sync_player_panels() -> void:
	for model: InventoryModel in _player_panels.keys():
		if model not in carried.models:
			_player_panels[model].queue_free()
			_player_panels.erase(model)
	for model in carried.models:
		if not _player_panels.has(model):
			_player_panels[model] = _open_panel(model, panels_container)


# --- Clicks ----------------------------------------------------------------

func _on_item_pressed(view: InventoryView, visual: ItemVisual, button: int) -> void:
	if _drag_item != null:
		return
	if button == MOUSE_BUTTON_LEFT:
		_begin_drag(visual.item, visual.rotated, view.model, visual)
	elif button == MOUSE_BUTTON_RIGHT:
		item_actions.open(visual.item, get_global_mouse_position())


func _on_action_selected(item: ItemInstance, action: String) -> void:
	match action:
		"soltar":
			remove_item(item)
			item_dropped.emit(item)
		"usar":
			item_used.emit(item)
		"guardar":  # sale de la mano hacia cualquier contenedor con lugar
			if carried.add_anywhere(item):
				carried.hands.remove(item)


# --- Arrastre --------------------------------------------------------------

## Clic izquierdo sobre un slot de mano (lo llama HandSlotView).
func start_hand_drag(hand: HandsModel.Hand, icon: CanvasItem) -> void:
	var item := carried.hands.get_held(hand)
	if item and _drag_item == null:
		_begin_drag(item, false, null, icon)


## 'source_model' = inventario de origen (null si sale de una mano).
## 'ghost' = lo que se ve en el lugar de origen; queda translúcido mientras se arrastra.
func _begin_drag(item: ItemInstance, rotated: bool, source_model: InventoryModel,
		ghost: CanvasItem) -> void:
	item_actions.close()
	_drag_item = item
	_drag_model = source_model
	_drag_ghost = ghost
	_drag_rotated = rotated
	_drag_ghost.modulate.a = 0.3
	_drag_preview = InventoryView.make_visual(item, rotated)
	_drag_preview.interactive = false
	_drag_preview.z_index = 10
	add_child(_drag_preview)
	_move_drag()


func _input(event: InputEvent) -> void:
	if _drag_item == null:
		return
	if event is InputEventMouseMotion:
		_move_drag()
		return
	var click := event as InputEventMouseButton
	var right_click := click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT
	if event.is_action_pressed("rotate") or right_click:
		_rotate_drag()
		get_viewport().set_input_as_handled()
	elif click and not click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_end_drag()


func _move_drag() -> void:
	var mouse := get_global_mouse_position()
	_drag_preview.global_position = mouse - _drag_preview.size * 0.5  # centro del objeto = mouse
	var target := _target_at(mouse)
	if target != _hover:
		_clear_hover()
	_hover = target
	var view := _hover as InventoryView
	if view:
		view.show_preview(_drag_item, mouse, _drag_rotated)


func _rotate_drag() -> void:
	_drag_rotated = not _drag_rotated
	_drag_preview.set_rotated(_drag_rotated)
	_move_drag()


func _end_drag() -> void:
	var mouse := get_global_mouse_position()
	var target := _target_at(mouse)
	if target is InventoryView:
		_drop_on_inventory(target as InventoryView, mouse)
	elif target is EquipSlotView:
		_drop_on_equip_slot(target as EquipSlotView)
	elif target is HandSlotView:
		_drop_on_hand(target as HandSlotView)
	_finish_drag()  # si no se pudo soltar, nada cambió: el objeto sigue donde estaba


func _drop_on_inventory(view: InventoryView, mouse: Vector2) -> void:
	var footprint := view.model.footprint_of(_drag_item, _drag_rotated)
	var cell := view.cell_at(mouse, footprint)
	if cell.x < 0:
		return
	if _drag_model:
		InventoryModel.transfer(_drag_item, _drag_model, view.model, cell, _drag_rotated)
	elif view.model.place(_drag_item, cell, _drag_rotated):  # viene de una mano
		carried.hands.remove(_drag_item)  # primero se coloca y después se saca: nunca queda "en el aire"


func _drop_on_equip_slot(slot: EquipSlotView) -> void:
	if _drag_model and slot.accepts(_drag_item) and slot.equipment_model.equip(_drag_item):
		_drag_model.remove(_drag_item)


func _drop_on_hand(slot: HandSlotView) -> void:
	if _drag_model:
		if carried.hands.equip(_drag_item, slot.hand):
			_drag_model.remove(_drag_item)
	else:
		carried.hands.move(_drag_item, slot.hand)  # de una mano a la otra


func _cancel_drag() -> void:
	if _drag_item != null:
		_finish_drag()


func _finish_drag() -> void:
	_clear_hover()
	if is_instance_valid(_drag_ghost):
		_drag_ghost.modulate.a = 1.0
	if is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_item = null
	_drag_model = null
	_drag_ghost = null
	_drag_preview = null


func _clear_hover() -> void:
	var view := _hover as InventoryView
	if view:
		view.clear_preview()
	_hover = null


## Primer InventoryView / slot visible bajo el mouse.
func _target_at(global_pos: Vector2) -> Control:
	for target: Control in get_tree().get_nodes_in_group("drop_targets"):
		if target.is_visible_in_tree() and target.get_global_rect().has_point(global_pos):
			return target
	return null
