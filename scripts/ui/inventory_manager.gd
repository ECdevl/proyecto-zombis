extends Node
class_name Inventory
@onready var clothes_panel: Panel = %clothes_panel
const PLAYER_INVENTORY = preload("uid://byxugjqoxthnx")
@onready var progress: TextureProgressBar = %progress
var player : Player
var current_weight : float = 0.0
var max_weight : float = 1.0
var item_selected : Array[ItemSlot] = []
@onready var generic_timer: Timer = %GenericTimer

var inventory_container : ContainerResource 
@onready var inventory_tab: TabContainer = %inventory_tab
var current_container : ContainerItems 
@onready var slots: VBoxContainer = %slots
var containers_available : Dictionary[Node,ContainerResource] = {}
var clothes : Dictionary[ItemCloth,ItemCloth.WearPlace]
var ui : UI
@onready var interaction: VBoxContainer = %interaction
var binds : Dictionary[String,Weapon]
var cancel : bool = false
@onready var capacity: Label = %capacity
@onready var slot_indication: Panel = %slot_indication

var key_slot : String = "0"


@onready var consuming: ConsumeState = $"../../ArmsFSM/consuming"


signal item_used(item:ItemConsumable)
signal equip_weapon(weapon:Weapon)
signal drop_item(item:Item)
signal action_cancelled
signal key_slot_pressed(key:String)

func _ready() -> void:
	ui = get_parent()
	containers_available[slots] = inventory_container
	connect("action_cancelled",Callable(self,"_on_action_cancelled"))
	
	inventory_container = slots.container_resource
	current_container = slots
	player = get_parent().owner
	max_weight = player.player_stats.base_carry_weight
	for i in clothes_panel.get_children():
		if i is Button:
			i.connect("pressed",Callable(self,"body_pressed"),CONNECT_APPEND_SOURCE_OBJECT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("X"):
		equip_item(null)
	if event is InputEventKey:
		if event.pressed:
			var key_string = OS.get_keycode_string(event.keycode)
			if key_string in ["0","1","2","3","4","5","6","7","8","9","0"]:
				emit_signal("key_slot_pressed",key_string)
				equip_item(binds.get(key_string))






func _make_buttons(pressed:ItemSlot,actions:Array[StringName]) -> void:
	for action in actions:
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

func _action_press(item:Item,action:StringName) -> void:
	interaction.hide()
	match action:
		&"use":
			for i in item_selected:
				use_item(i.slot_resource)
				ui.toggle_inventory()
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


func add_new_container(item:ItemCloth) -> void:
	if !containers_available.values().has(item.container):
		var container_item : ContainerItems = ContainerItems.new()
		container_item.container_resource = item.container
		
		inventory_tab.add_child(container_item)
		container_item.owner = self
		
		inventory_tab.set_tab_title(inventory_tab.get_tab_count()-1,item.item_name)
		containers_available[container_item] = item.container



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








func add_item(resource:Item) -> void:
	if resource:
		current_container.container_resource.add(resource)
		if resource is ItemCloth:
			if resource.can_carry:
				add_new_container(resource)
		update_inventory()


func equip_item(item:Weapon) -> void:
	emit_signal("equip_weapon",item)



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

func use_item(item: ItemConsumable) -> void:
	var slot = _get_resource_item_slot(item)
	await _run_consuming_action(slot, item, item.time_consume, func():
		for stat in item.stats_affected.keys():
			player.player_needs.heal(stat, item.stats_affected.get(stat))
			remove_item(item, 1)
	)

func wear_item(item: ItemCloth) -> bool:
	var slot = _get_resource_item_slot(item)
	var cancelled = await _run_consuming_action(slot, item, item.time_consume, func():
		if !clothes.has(item) and !clothes.values().has(item.place):
			clothes[item] = item.place
			remove_item(item, 1)
		update_inventory()
	)
	return cancelled

func move_to(move_to_item: ItemSlot, from: ContainerItems, to: ContainerItems) -> bool:
	var cancelled = await _run_consuming_action(move_to_item, move_to_item.slot_resource, move_to_item.slot_resource.weight / 1.5, func():
		from.container_resource.remove(move_to_item.slot_resource)
		to.container_resource.add(move_to_item.slot_resource)
		update_inventory()
	)
	return cancelled


func _run_consuming_action(slot: ItemSlot, resource: Resource, max_progress: float, on_success: Callable) -> bool:
	slot.timer_tied = consuming.timer
	emit_signal("item_used", resource)
	progress.max_value = max_progress

	var cancelled = await consuming.proceed
	if cancelled:
		slot.disabled = false
		slot.button_pressed = false
		slot.timer_tied = null
		return true

	on_success.call()
	return false

func _on_key_slot_pressed(key: String) -> void:
	key_slot = key


func _on_inventory_tab_tab_changed(tab: int) -> void:
	current_container = inventory_tab.get_child(tab)
