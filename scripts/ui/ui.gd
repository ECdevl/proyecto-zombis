extends Control
class_name UI
const ITEM_INVENTORY = preload("uid://emtrk8exj7f")


@onready var inventory: Panel = %inventory
var player : Player

@onready var health: ProgressBar = %health
@onready var stamina: ProgressBar = %stamina
@onready var hunger: ProgressBar = %hunger
@onready var sleep: ProgressBar = %sleep
@onready var thirst: ProgressBar = %thirst
@onready var text_hint: RichTextLabel = %text_hint








signal inventory_open
signal inventory_close

@onready var inventory_manager: Node = %InventoryManager


func _ready() -> void:
	player = get_parent()
	inventory.hide()




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

	

func body_pressed(what:Control) -> void:
	match what.name:
		"head_equipment":
			if inventory_manager.clothes.values().has(ItemCloth.WearPlace.HEAD):
				var key = inventory_manager.clothes.find_key(ItemCloth.WearPlace.HEAD)
				inventory_manager.add_item(key)
				inventory_manager.clothes.erase(key)
				what.icon = null
				
		"torso_equipment":
			if inventory_manager.clothes.values().has(ItemCloth.WearPlace.TORSO):
				var key = inventory_manager.clothes.find_key(ItemCloth.WearPlace.TORSO)
				inventory_manager.add_item(key)
				inventory_manager.clothes.erase(key)
				what.icon = null
				
		"legs_equipment":
			if inventory_manager.clothes.values().has(ItemCloth.WearPlace.LEGS):
				var key = inventory_manager.clothes.find_key(ItemCloth.WearPlace.LEGS)
				inventory_manager.add_item(key)
				inventory_manager.clothes.erase(key)
				what.icon = null
				
		"back_equipment":
			if inventory_manager.clothes.values().has(ItemCloth.WearPlace.BACK):
				var key = inventory_manager.clothes.find_key(ItemCloth.WearPlace.BACK)
				inventory_manager.add_item(key)
				inventory_manager.clothes.erase(key)
				what.icon = null
				
		"foot_equipment":
			if inventory_manager.clothes.values().has(ItemCloth.WearPlace.FOOT):
				var key = inventory_manager.clothes.find_key(ItemCloth.WearPlace.FOOT)
				inventory_manager.add_item(key)
				inventory_manager.clothes.erase(key)
				what.icon = null
	inventory_manager.update_inventory()
