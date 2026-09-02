extends Control
class_name UI


@onready var item_actions: ItemActions = %ItemActions

signal instruct(what:Node3D,label:String)

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
signal item_success_grab(what:PickableItem)

@onready var inventory: Control = %Inventory



@export var equipment_model : EquipmentModel
@onready var clothes: Panel = %Clothes

signal drop_item(item: ItemDescriptor)

func _ready() -> void:

	player_containers.register_container(player_inventory_model,0,"Bolsillos")
	player = get_parent().owner
	inventory.hide.call_deferred()
	player_inventory_model.connect("item_added",Callable(self,"model_item_added"))
	equipment_model.item_equipped.connect(_on_equipment_item_equipped)
	equipment_model.item_unequipped.connect(_on_equipment_item_unequipped)



func model_item_added(descriptor: ItemDescriptor) -> void:
	print_debug("added ",descriptor.item_name)


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
		
const OUTLINE = preload("uid://4x87d50eon8w")


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

func show_actions(visual:ItemVisual) -> void:
	
	item_actions.visual = visual
	item_actions.add_action(visual.descriptor)
	item_actions.show()
	visual.item_drop.connect(_on_player_containers_drop_item_world)
	item_actions.global_position = get_global_mouse_position()
	

func _on_player_loot_opened(model: InventoryModel, display: String) -> void:
	inventory_ui_controller.open_loot_container(model,display)
	toggle_inventory()


# Flow: player picks up a world item -> try to slot it in any carried inventory ->
# if it doesn't fit and it's wearable, try to equip it directly.
# Container registration for wearables is handled ONLY in _on_equipment_item_equipped,
# which fires from equipment_model's item_equipped signal — no need to duplicate it here.
func _on_player_grabbed_object(world_obj: PickableItem) -> void:
	if player_containers.try_add_anywhere(world_obj.item_descriptor):
		emit_signal("item_success_grab",world_obj)
		
		return 
	else:
		if world_obj.item_descriptor is WearableItemDescriptor and equipment_model.equip(world_obj.item_descriptor.equip_slot, world_obj.item_descriptor):
			emit_signal("item_success_grab",world_obj)

			
			return
	print_debug("impossible to grab")
	# else: item couldn't be stored anywhere, stays in the world


func _on_equipment_item_equipped(_slot: WearableItemDescriptor.EquipSlot, wearable: WearableItemDescriptor) -> void:
	if wearable.container_capability:
		player_containers.register_container(wearable.container_capability,0,wearable.item_name)


func _on_equipment_item_unequipped(_slot: WearableItemDescriptor.EquipSlot, wearable: WearableItemDescriptor) -> void:
	if not player_containers.try_add_anywhere(wearable):
		player_containers.unregister_container(wearable.container_capability)
		emit_signal("drop_item",wearable)
		


func _on_player_containers_item_received(descriptor: ItemDescriptor, container: InventoryModel) -> void:
	if descriptor is WearableItemDescriptor:
		if descriptor.container_capability:
			player_containers.register_container(descriptor.container_capability,0,descriptor.item_name)


func _on_player_containers_item_lost(descriptor: ItemDescriptor) -> void:
	if descriptor is WearableItemDescriptor:
		if descriptor.container_capability:
			player_containers.unregister_container(descriptor.container_capability)
			


func _on_player_containers_drop_item_world(descriptor: ItemDescriptor) -> void:
	drop_item.emit(descriptor)


func _on_item_actions_action_drop(what: ItemVisual) -> void:
	pass # Replace with function body.



@onready var instructor_container: Control = %InstructorContainer
const INSTRUCTOR = preload("uid://b6idlm6tyvtrx")


func _on_item_instruct_body_entered(body: Node3D) -> void:
	var game_instructor : RichTextLabel = INSTRUCTOR.instantiate()
	if body is PickableItem:
		game_instructor.set_target(body,body.item_descriptor.item_name)
	elif body is ContainerInteractable:
		
		game_instructor.set_target(body,body.name)
	instructor_container.add_child(game_instructor)


func _on_item_instruct_body_exited(body: Node3D) -> void:
	for i in instructor_container.get_children():
		if i.target == body:
			i.target = null 
