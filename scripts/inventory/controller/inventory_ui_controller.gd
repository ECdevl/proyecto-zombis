extends Control
class_name InventoryUIController

@export var inventory_panel_scene: PackedScene  # la escena "Inventory" completa
@export var panels_container: Control
@onready var loot_view_container: VBoxContainer = %LootViewContainer

var open_panels: Dictionary = {}  # InventoryModel -> Node (raíz "Inventory")

var player_panels : Dictionary = {}

func _ready() -> void:
	add_to_group("inventory_ui")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_all()

func open_loot_container(model: InventoryModel, title: String = "") -> void:
	if open_panels.has(model):
		return

	var panel : Control = inventory_panel_scene.instantiate()
	loot_view_container.add_child(panel)
	panel.get_child(0).title = title

	var view: InventoryView = panel.inventory_view
	view.setup(model)

	open_panels[model] = panel




func open_container(model: InventoryModel, title: String = "") -> void:
	if player_panels.has(model):
		return

	var panel : Control = inventory_panel_scene.instantiate()
	panels_container.add_child(panel)
	#panel.title = title

	var view: InventoryView = panel.inventory_view
	view.setup(model)
	
	player_panels[model] = panel


func close_player_container(model: InventoryModel) -> void:
	if not player_panels.has(model):
		print_debug("no close")
		return
	var panel: Node = player_panels[model]
	var view: InventoryView = panel.inventory_view
	view.close()
	panel.queue_free()
	player_panels.erase(model)
	print_debug("closed", model)

func close_container(model: InventoryModel) -> void:
	if not open_panels.has(model):
		return
	var panel: Node = open_panels[model]
	var view: InventoryView = panel.inventory_view
	view.close()
	panel.queue_free()
	open_panels.erase(model)


func close_all() -> void:
	for model in open_panels.keys():
		close_container(model)


func _on_ui_inventory_close() -> void:
	close_all()
