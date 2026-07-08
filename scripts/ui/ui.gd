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

signal item_used(item:ItemConsumable)
signal equip_weapon(weapon:Weapon)
signal drop_item(item:Item)

var binds : Dictionary[String,Weapon]

var current_weight : float = 0.0
var max_weight : float = 1.0
var item_selected : Array[ItemSlot] = []





@onready var clothes_panel: Panel = %clothes_panel
const PLAYER_INVENTORY = preload("uid://byxugjqoxthnx")

@export var current_container : ContainerResource
var inventory_container : ContainerResource = PLAYER_INVENTORY
@onready var inventory_tab: TabBar = %inventory_tab

var containers_available : Array[ContainerResource] = [inventory_container]

func _ready() -> void:
	current_container = containers_available[0]
	player = get_parent()
	inventory.hide()
	max_weight = player.player_stats.base_carry_weight
	for i in clothes_panel.get_children():
		if i is Button:
			i.connect("pressed",Callable(self,"body_pressed"),CONNECT_APPEND_SOURCE_OBJECT)



var clothes : Dictionary[ItemCloth,ItemCloth.WearPlace]
signal key_slot_pressed(key:String)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			var key_string = OS.get_keycode_string(event.keycode)
			if key_string in ["0","1","2","3","4","5","6","7","8","9","G","g"]:
				emit_signal("key_slot_pressed",key_string)
				equip_item(binds.get(key_string))





func toggle_inventory() -> void:
	inventory.visible = !inventory.visible
	if inventory.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		for i in item_selected:
			i.button_pressed = false
		item_selected.clear()
		interaction.hide()
var cancel : bool = false
func _process(delta: float) -> void:
	health.value = player.player_needs.current_health
	stamina.value = player.player_needs.current_stamina
	hunger.value = player.player_needs.current_hunger
	thirst.value = player.player_needs.current_thirst
	sleep.value = player.player_needs.current_sleep

	
	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_inventory()



func add_item(resource:Item) -> void:
	if resource:
		current_container.items_inside.append(resource)
		update_inventory()


@onready var capacity: Label = %capacity

func update_inventory(target_container: ContainerResource = current_container) -> void:
	current_container = target_container
	for i in slots.get_children():
		i.queue_free()
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
	
	
	for item in target_container.items_inside:
		if item is Item:
			var item_slot : ItemSlot = ITEM_INVENTORY.instantiate()
			item_slot.slot_resource = item
			slots.add_child(item_slot)
			item_slot.connect("toggled",Callable(self,"item_pressed"),16)
			current_weight += item.weight
			if item is ItemCloth:
				if item.can_carry:
					add_new_container(item)
	capacity.text = "Capacity: "+str(current_weight)+" / "+str(max_weight)
	if current_weight > max_weight:
		player.player_stats.base_speed = 2
	else:
		player.player_stats.base_speed = 1

func item_pressed(toggled_on:bool,pressed:ItemSlot) -> void:

	interaction.show()
	if toggled_on:
		item_selected.append(pressed)
	else:
		item_selected.erase(pressed)
	for i in interaction.get_children():
		i.queue_free()
	if pressed.slot_resource is Weapon:
		if player.get_current_weapon() == pressed.slot_resource:
			equip_item(null)
			return
	if item_selected.size() > 1:
		for action in Item.new().get_actions():
			var button = Button.new()
			button.text = action
			button.connect("pressed",Callable(self,"_action_press").bind(pressed.slot_resource,action))
			interaction.add_child(button)
		return
	for action in pressed.slot_resource.get_actions():
		var button = Button.new()
		button.text = action
		button.connect("pressed",Callable(self,"_action_press").bind(pressed.slot_resource,action))
		interaction.add_child(button)

func add_new_container(item:ItemCloth) -> void:
	if !containers_available.has(item.container):
		containers_available.append(item.container)
		inventory_tab.add_tab(item.item_name)

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
				wear_item(i.slot_resource)
		&"set quick slot":
			await set_quick_slot()
	item_selected.clear()
@onready var slot_indication: Panel = %slot_indication

var key_slot : String = "0"
func set_quick_slot() -> void:
	slot_indication.show()
	await key_slot_pressed
	slot_indication.hide()
	if key_slot in ["G","g"]:
		return
	binds[key_slot] = item_selected[0].slot_resource



func use_item(item:ItemConsumable) -> void:
	cancel = false
	emit_signal("item_used",item)
	progress.max_value = item.time_consume

func wear_item(item:ItemCloth) -> void:
	if !clothes.has(item):
		if !clothes.values().has(item.place):
			clothes[item] = item.place
			remove_item(item,1)
	update_inventory()

func remove_item(item:Item,amount:int,drop:bool = false) -> void:
	item.stack -= amount
	if item.stack <= 0:
		if binds.find_key(item) != null:
			binds.erase(binds.find_key(item))
		current_container.items_inside.erase(item)
		if item is ItemCloth:
			if item.container in containers_available:
				inventory_tab.remove_tab(containers_available.find(item.container))
				containers_available.erase(item.container)
				
	if drop:
		player.drop_item(item)
	update_inventory()
	
func equip_item(item:Item) -> void:
	emit_signal("equip_weapon",item)
	print_debug("emmiitted")

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


func _on_key_slot_pressed(key: String) -> void:
	key_slot = key


func _on_inventory_tab_tab_changed(tab: int) -> void:
	update_inventory(containers_available[tab])
