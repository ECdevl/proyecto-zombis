extends Control
class_name UI
const ITEM_INVENTORY = preload("uid://emtrk8exj7f")
@onready var slots: VBoxContainer = %slots
@onready var interaction: VBoxContainer = %interaction
@onready var inventory: Panel = %inventory
var player : Player
@onready var progress: TextureProgressBar = %progress
@onready var health: ProgressBar = %health
@onready var stamina: ProgressBar = %stamina
@onready var hunger: ProgressBar = %hunger
@onready var sleep: ProgressBar = %sleep
@onready var thirst: ProgressBar = %thirst
@onready var text_hint: RichTextLabel = %text_hint

signal item_used(item:ItemConsumable)
signal equip_weapon(weapon:Weapon)
signal drop_item(item:Item)
signal action_cancelled


var binds : Dictionary[String,Weapon]

var current_weight : float = 0.0
var max_weight : float = 1.0
var item_selected : Array[ItemSlot] = []
@onready var generic_timer: Timer = %GenericTimer


signal inventory_open
signal inventory_close


@onready var clothes_panel: Panel = %clothes_panel
const PLAYER_INVENTORY = preload("uid://byxugjqoxthnx")
@onready var ammo_count: Label = %ammo_count


var inventory_container : ContainerResource 
@onready var inventory_tab: TabContainer = %inventory_tab
var current_container : ContainerItems 

var containers_available : Dictionary[Node,ContainerResource] = {}


func _ready() -> void:
	containers_available[slots] = inventory_container
	connect("action_cancelled",Callable(self,"_on_action_cancelled"))
	
	inventory_container = slots.container_resource
	current_container = slots
	player = get_parent()
	inventory.hide()
	max_weight = player.player_stats.base_carry_weight
	for i in clothes_panel.get_children():
		if i is Button:
			i.connect("pressed",Callable(self,"body_pressed"),CONNECT_APPEND_SOURCE_OBJECT)



func set_text_hint(text:String) -> void:
	if text:
		text_hint.text = text
	else:
		text_hint.text = ""

var clothes : Dictionary[ItemCloth,ItemCloth.WearPlace]
signal key_slot_pressed(key:String)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("X"):
		equip_item(null)
	if event is InputEventKey:

			
		if event.pressed:
			var key_string = OS.get_keycode_string(event.keycode)
			if key_string in ["0","1","2","3","4","5","6","7","8","9","0"]:
				emit_signal("key_slot_pressed",key_string)
				equip_item(binds.get(key_string))







func toggle_inventory() -> void:
	inventory.visible = !inventory.visible
	if inventory.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		emit_signal("inventory_open")
	else:
		emit_signal("inventory_close")
		
var cancel : bool = false
func _process(delta: float) -> void:
	health.value = player.player_needs.current_health
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
	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_inventory()



func add_item(resource:Item) -> void:
	if resource:
		current_container.container_resource.add(resource)
		if resource is ItemCloth:
			if resource.can_carry:
				add_new_container(resource)
		update_inventory()


@onready var capacity: Label = %capacity

func update_inventory() -> void:
	current_weight = 0
	max_weight = player.player_stats.base_carry_weight
	for i in clothes.keys():
		if i is ItemCloth:
			max_weight += i.carry_addition
			if i.can_carry:
				add_new_container(i)
			match i.place:
				ItemCloth.WearPlace.HEAD:
					var head_equipment: Button = %head_equipment
					head_equipment.icon = i.icon
				ItemCloth.WearPlace.TORSO:
					var head_equipment: Button = %torso_equipment
					head_equipment.icon = i.icon
				ItemCloth.WearPlace.BACK:
					var head_equipment: Button = %back_equipment
					head_equipment.icon = i.icon
				ItemCloth.WearPlace.LEGS:
					var head_equipment: Button = %legs_equipment
					head_equipment.icon = i.icon
				ItemCloth.WearPlace.FOOT:
					var head_equipment: Button = %foot_equipment
					head_equipment.icon = i.icon
	for i in current_container.get_children():
		if i is Button:
			if not i.has_connections("pressed"):
				i.connect("pressed",Callable(self,"item_pressed"),16)
	
	capacity.text = "Capacity: "+str(current_container.container_weight)+" / "+str(max_weight)
	if current_weight > max_weight:
		player.player_stats.base_speed = 2
	else:
		player.player_stats.base_speed = 1

func _make_buttons(pressed:ItemSlot,actions:Array[StringName]) -> void:
	for action in actions:
		var button = Button.new()
		button.text = action
		button.connect("pressed",Callable(self,"_action_press").bind(pressed.slot_resource,action))
		interaction.add_child(button)

func item_pressed(pressed:ItemSlot) -> void:
	interaction.show()
	if Input.is_action_pressed("shift"):
		item_selected.append(pressed)
	else:
		item_selected.clear()
		item_selected.append(pressed)

	for i in interaction.get_children():
		i.queue_free()

	if item_selected.size() > 1:
		if item_selected.all(func(element): if is_instance_valid(element): return element.slot_resource is ItemCloth):
			_make_buttons(pressed,ItemCloth.new().get_actions())
			return
		else:
			_make_buttons(pressed,Item.new().get_actions())
			return
		
	for action in pressed.slot_resource.get_actions():
		var button = Button.new()
		button.text = action
		button.connect("pressed",Callable(self,"_action_press").bind(pressed.slot_resource,action))
		interaction.add_child(button)

func _get_resource_item_slot(item:Item) -> ItemSlot:
	for i in containers_available.keys():
		for child in i.get_children():
			if child is ItemSlot:
				if child.slot_resource == item:
					return child
	return null

func add_new_container(item:ItemCloth) -> void:
	if !containers_available.values().has(item.container):
		var container_item : ContainerItems = ContainerItems.new()
		container_item.container_resource = item.container
		
		inventory_tab.add_child(container_item)
		container_item.owner = self
		
		inventory_tab.set_tab_title(inventory_tab.get_tab_count()-1,item.item_name)
		containers_available[container_item] = item.container

func _action_press(item:Item,action:StringName) -> void:
	interaction.hide()
	match action:
		&"use":
			for i in item_selected:
				use_item(i.slot_resource)
				toggle_inventory()
		&"drop":
			for i in item_selected:
				remove_item(i.slot_resource,1,true)
		&"equip":
			for i in item_selected:
				equip_item(i.slot_resource)
		&"wear":
			for i in item_selected:
				i.button_mask = MOUSE_BUTTON_MASK_MB_XBUTTON1
			for i in item_selected:
				var cancelled = await wear_item(i.slot_resource)
				i.button_mask = MOUSE_BUTTON_MASK_LEFT
				if cancelled:
					for butt in item_selected:
						if is_instance_valid(butt):
							butt.button_pressed = false
							butt.button_mask = MOUSE_BUTTON_MASK_LEFT
					return
		&"set quick slot":
			await set_quick_slot()
		&"move":
			slot_indication.show()
			slot_indication.get_child(0).text = "Press the container above to move selected items to that container"
			var tab_clicked = await inventory_tab.tab_clicked
			slot_indication.hide()
			var move_to_container : ContainerItems = inventory_tab.get_child(tab_clicked)
			for i in item_selected:
				i.button_mask = MOUSE_BUTTON_MASK_MB_XBUTTON1
			for i in item_selected:
				var cancelled = await move_to(i,i.get_parent(),move_to_container)
				i.button_mask = MOUSE_BUTTON_MASK_LEFT
				if cancelled:
					for butt in item_selected:
						if is_instance_valid(butt):
							butt.button_pressed = false
							butt.button_mask = MOUSE_BUTTON_MASK_LEFT
					return
				
	
	item_selected.clear()
@onready var slot_indication: Panel = %slot_indication

var key_slot : String = "0"
@onready var consuming: ConsumeState = $"../ArmsFSM/consuming"


func set_quick_slot() -> void:
	slot_indication.show()
	slot_indication.get_child(0).text = "Press the slot you want this item to be attached 
(0-9)"
	await key_slot_pressed
	slot_indication.hide()
	if key_slot in ["G","g"]:
		return
	if item_selected.size() > 0:
		binds[key_slot] = item_selected[0].slot_resource

func move_to(move_to_item:ItemSlot,from:ContainerItems,to:ContainerItems) -> bool:
	move_to_item.timer_tied = consuming.timer
	emit_signal("item_used",move_to_item.slot_resource)
	progress.max_value = move_to_item.slot_resource.weight / 1.5
	var action_cancelled = await consuming.proceed
	if action_cancelled:
		move_to_item.disabled = false
		move_to_item.button_pressed = false
		move_to_item.timer_tied = null
		return true

	from.container_resource.remove(move_to_item.slot_resource)
	to.container_resource.add(move_to_item.slot_resource)

	update_inventory()
	return false

	

func use_item(item:ItemConsumable) -> void:
	cancel = false
	emit_signal("item_used",item)
	progress.max_value = item.time_consume
	var consuming_cancelled = await consuming.proceed
	if consuming_cancelled:
		_get_resource_item_slot(item).disabled = false
		_get_resource_item_slot(item).button_pressed = false
		_get_resource_item_slot(item).timer_tied = null
		return
	for stat in item.stats_affected.keys():
		player.player_needs.heal(stat,item.stats_affected.get(stat))
		remove_item(item,1)

func wear_item(item:ItemCloth) -> bool:
	var slot = _get_resource_item_slot(item)
	slot.timer_tied = consuming.timer
	
	emit_signal("item_used",item)
	progress.max_value = item.time_consume
	var consuming_result = await consuming.proceed
	if consuming_result:
		slot.timer_tied = null
		slot.disabled = false
		slot.button_pressed = false
		return true
	if !clothes.has(item):
		if !clothes.values().has(item.place):
			clothes[item] = item.place
			remove_item(item,1)
	update_inventory()
	return false

func remove_item(item:Item,amount:int,drop:bool = false) -> void:
	item.stack -= amount
	if item.stack <= 0:
		if binds.find_key(item) != null:
			binds.erase(binds.find_key(item))
		current_container.container_resource.remove(item)
		if item is ItemCloth:
			if item.can_carry:
				if item.container in containers_available.values():
					var remove_key : Node = containers_available.find_key(item.container)
					remove_key.queue_free()
					containers_available.erase(remove_key)
					
					containers_available.values().erase(item.container)
				
	if drop:
		player.drop_item(item)
	
func equip_item(item:Item) -> void:
	emit_signal("equip_weapon",item)

func body_pressed(what:Control) -> void:
	match what.name:
		"head_equipment":
			if clothes.values().has(ItemCloth.WearPlace.HEAD):
				var key = clothes.find_key(ItemCloth.WearPlace.HEAD)
				add_item(key)
				clothes.erase(key)
				what.icon = null
				
		"torso_equipment":
			if clothes.values().has(ItemCloth.WearPlace.TORSO):
				var key = clothes.find_key(ItemCloth.WearPlace.TORSO)
				add_item(key)
				clothes.erase(key)
				what.icon = null
				
		"legs_equipment":
			if clothes.values().has(ItemCloth.WearPlace.LEGS):
				var key = clothes.find_key(ItemCloth.WearPlace.LEGS)
				add_item(key)
				clothes.erase(key)
				what.icon = null
				
		"back_equipment":
			if clothes.values().has(ItemCloth.WearPlace.BACK):
				var key = clothes.find_key(ItemCloth.WearPlace.BACK)
				add_item(key)
				clothes.erase(key)
				what.icon = null
				
		"foot_equipment":
			if clothes.values().has(ItemCloth.WearPlace.FOOT):
				var key = clothes.find_key(ItemCloth.WearPlace.FOOT)
				add_item(key)
				clothes.erase(key)
				what.icon = null
	update_inventory()


func _on_key_slot_pressed(key: String) -> void:
	key_slot = key


func _on_inventory_tab_tab_changed(tab: int) -> void:
	current_container = inventory_tab.get_child(tab)
	
