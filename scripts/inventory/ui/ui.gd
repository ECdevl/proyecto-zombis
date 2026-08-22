extends Control
class_name UI





var player : Player
@onready var player_containers: PlayerCarriedInventories = %PlayerContainers

@onready var health: ProgressBar = %health
@onready var stamina: ProgressBar = %stamina
@onready var hunger: ProgressBar = %hunger
@onready var sleep: ProgressBar = %sleep
@onready var thirst: ProgressBar = %thirst
@onready var text_hint: RichTextLabel = %text_hint

@onready var inventory_view_container: Control = %InventoryViewContainer
@onready var loot_view_container: VBoxContainer = %LootViewContainer


@onready var inventory_ui_controller: InventoryUIController = %InventoryUIController
@export var player_inventory_model: InventoryModel


signal inventory_open
signal inventory_close

@onready var inventory: Control = %Inventory

@onready var pockets_view: ScrollContainer = %pockets_view

@export var equipment_model : EquipmentModel
@onready var clothes: Panel = %Clothes

signal drop_item(item: ItemDescriptor)

func _ready() -> void:

	player_containers.register_container(player_inventory_model)
	player = get_parent().owner
	inventory.hide.call_deferred()
	equipment_model.item_equipped.connect(_on_equipment_item_equipped)
	equipment_model.item_unequipped.connect(_on_equipment_item_unequipped)





func set_text_hint(text:String) -> void:
	if text:
		text_hint.text = text
	else:
		text_hint.text = ""

@onready var ammo_count: Label = %ammo_count
func toggle_inventory() -> void:
	inventory.visible = !inventory.visible
	if inventory.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		emit_signal("inventory_open")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		emit_signal("inventory_close")
		


func _process(delta: float) -> void:
	health.value = player.health_component.current_health
	stamina.value = player.player_needs.current_stamina
	hunger.value = player.player_needs.current_hunger
	thirst.value = player.player_needs.current_thirst
	sleep.value = player.player_needs.current_sleep
	if player.get_current_weapon():
		if player.get_current_weapon().weapon_type == player.get_current_weapon().Type.GUN:
			ammo_count.show()
			ammo_count.text = str(player.get_current_weapon().weapon_current_ammo)+"/"+str(player.get_current_weapon().weapon_current_bullets)
	if player.looking_at_obj:
		if player.looking_at_obj.has_method("_get_hint"):
			var text : String = player.looking_at_obj._get_hint()
			text.replace("USE",InputMap.action_get_events("use")[0].as_text())
			set_text_hint(player.looking_at_obj._get_hint())
		else:
			set_text_hint("")
	else:
		set_text_hint("")
	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_inventory()

	


func _on_player_loot_opened(model: InventoryModel, display: String) -> void:
	inventory_ui_controller.open_loot_container(model,display)
	toggle_inventory()


func _on_player_grabbed_object(obj: ItemDescriptor, world_obj: PickableItem) -> void:
	if player_containers.try_add_anywhere(obj):
		pass
	else:
		if obj is WearableItemDescriptor:
			if not equipment_model.equip(obj.equip_slot,obj):
				return
			else:
				player_containers.register_container(obj.container_model)
	world_obj.queue_free()


func _on_equipment_item_equipped(_slot: WearableItemDescriptor.EquipSlot, wearable: WearableItemDescriptor) -> void:
	if wearable.container_model == null:
		return
	print_debug("EQUIPPED: ",wearable, " IN ",_slot)


func _on_equipment_item_unequipped(_slot: WearableItemDescriptor.EquipSlot, wearable: WearableItemDescriptor) -> void:
	if wearable.container_model == null:
		return 
	if not player_containers.try_add_anywhere(wearable):
		player_containers.unregister_container(wearable.container_model)
		emit_signal("drop_item",wearable)
		
