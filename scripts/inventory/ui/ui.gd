extends Control
class_name UI
## HUD: barras, textos de ayuda, munición e "instructor".
## El inventario vive en InventoryUIController; acá solo se abre/cierra y se reenvían sus eventos.

signal inventory_open
signal inventory_close
signal item_used(item: ItemInstance)
signal drop_item(item: ItemInstance)
signal item_success_grab(what: PickableItem)

const INSTRUCTOR = preload("uid://b6idlm6tyvtrx")

@export var player_inventory_model: InventoryModel
@export var equipment_model: EquipmentModel

@onready var carried: PlayerCarriedInventories = %PlayerContainers
@onready var inventory_ui: InventoryUIController = %InventoryUIController
@onready var inventory: Control = %Inventory
@onready var instructor_container: Control = %InstructorContainer

@onready var health: ProgressBar = %health
@onready var stamina: ProgressBar = %stamina
@onready var hunger: ProgressBar = %hunger
@onready var sleep: ProgressBar = %sleep
@onready var thirst: ProgressBar = %thirst
@onready var text_hint: RichTextLabel = %text_hint
@onready var progress: TextureProgressBar = %progress
@onready var ammo_count: Label = %ammo_count

var player: Player


func _ready() -> void:
	player = get_parent().owner
	carried.setup(player_inventory_model, equipment_model)
	carried.hands.main_weapon_changed.connect(player.equip_weapon)
	inventory_ui.item_used.connect(item_used.emit)
	inventory_ui.item_dropped.connect(drop_item.emit)
	inventory.hide.call_deferred()
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()


func _process(_delta: float) -> void:
	health.value = player.health_component.current_health
	stamina.value = player.player_needs.current_stamina
	hunger.value = player.player_needs.current_hunger
	thirst.value = player.player_needs.current_thirst
	sleep.value = player.player_needs.current_sleep

	_update_ammo()
	_update_hint()


func _update_ammo() -> void:
	var weapon : Weapon = player.get_current_weapon()
	if weapon and weapon.weapon_type != weapon.WEAPON_TYPE.MELEE:
		ammo_count.show()
		ammo_count.text = "%d/%d" % [player.get_current_weapon().curr_bullets, player.weapon_controller.get_reserve_ammo()]
	else:
		ammo_count.hide()


func _update_hint() -> void:
	var target := player.looking_at_obj
	if is_instance_valid(target) and target.has_method("_get_hint"):
		var hint: String = target._get_hint()
		set_text_hint(hint.replace("USE", _key_of("use")))
	else:
		set_text_hint("")


func _key_of(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	return events[0].as_text() if not events.is_empty() else "?"


func set_text_hint(text: String) -> void:
	text_hint.text = text


func toggle_inventory() -> void:
	inventory.visible = not inventory.visible
	if inventory.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		inventory_open.emit()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		inventory_ui.close_loot()
		inventory_close.emit()


# --- Conexiones desde la escena / otros nodos ------------------------------

func _on_player_grabbed_object(world_obj: PickableItem) -> void:
	if carried.pick_up(world_obj.item):
		item_success_grab.emit(world_obj)
	else:
		print_debug("No entra en ningún lado")


func _on_player_loot_opened(model: InventoryModel, _display: String) -> void:
	inventory_ui.open_loot(model)
	if not inventory.visible:
		toggle_inventory()


func _on_consuming_tick(duration: float, max_duration: float) -> void:
	progress.value = duration
	progress.max_value = max_duration
	progress.show()


func _on_item_consumed(item: ItemInstance) -> void:
	if item:
		inventory_ui.remove_item(item)
	progress.hide()


func _on_item_instruct_body_entered(body: Node3D) -> void:
	var label: String
	if body is PickableItem:
		label = body.item_descriptor.item_name
	elif body is ContainerInteractable:
		label = body.name
	else:
		return
	var instructor: RichTextLabel = INSTRUCTOR.instantiate()
	instructor.set_target(body, label)
	instructor_container.add_child(instructor)


func _on_item_instruct_body_exited(body: Node3D) -> void:
	for instructor in instructor_container.get_children():
		if instructor.target == body:
			instructor.target = null
