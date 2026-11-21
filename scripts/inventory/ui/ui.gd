extends Control
class_name UI
## HUD: barras, textos de ayuda, munición e "instructor".
## El inventario vive en el Player; el InventoryUIController solo lo muestra.

signal inventory_open
signal inventory_close

const INSTRUCTOR = preload("uid://b6idlm6tyvtrx")
const INSTRUCTOR_ICON_WARN: String = "res://assets/sprites/instructor_warn.png"

## El jugador al que pertenece esta interfaz. Lo asigna player.tscn.
@export var player: Player

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

@onready var sturggle_progress: TextureProgressBar = %SturggleProgress
@onready var key_struggle: Label = %key_struggle
@onready var quick_slots: HBoxContainer = %quick_slots
@onready var hurt_flash: ColorRect = %hurt_flash

var hurt_flash_alpha : float
## Pistas del instructor registradas por id (para cerrarlas o actualizarlas).
var _hints_by_id: Dictionary = {}

func _ready() -> void:
	hurt_flash_alpha = hurt_flash.modulate.a
	# El inventario lo tiene el Player; la interfaz solo lo observa.
	inventory_ui.bind_inventory(player.inventory)
	# La UI es vista: le avisa al Player, que es la autoridad del inventario (D-004).
	inventory_ui.item_used.connect(player.use_item)
	inventory_ui.item_dropped.connect(player.drop_item)
	inventory.hide.call_deferred()
	var tween = create_tween().set_loops(0)
	tween.tween_property(sturggle_progress,"scale",Vector2(1.2,1.2),.1)
	tween.tween_property(sturggle_progress,"scale",Vector2(1,1),.1)

func flash_hurt() -> void:
	player_hurt()
	hurt_flash.show()
	hurt_flash.modulate.a = hurt_flash_alpha
	var tween = create_tween()
	tween.tween_property(hurt_flash,"modulate:a",0.0,.25)
	await tween.finished
	hurt_flash.hide()




func player_hurt() -> void:
	var vignete_material : ShaderMaterial = vignette.material
	var health_value : float = player.health_component.current_health
	if health_value <= 0.0:
		vignette.show()
		vignete_material.set_shader_parameter("intensity",1.0)
	elif health_value <= 25.0:
		vignette.show()
		vignete_material.set_shader_parameter("intensity",0.5)
	elif health_value <= 50.0:
		vignette.show()
		vignete_material.set_shader_parameter("intensity",0.25)
	else:
		vignette.hide()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and inventory.visible:
		close_inventory()
		get_viewport().set_input_as_handled()

@onready var vignette: ColorRect = %vignette

func _process(_delta: float) -> void:
	health.value = player.health_component.current_health
	stamina.value = player.player_needs.current_stamina
	hunger.value = player.player_needs.current_hunger
	thirst.value = player.player_needs.current_thirst
	sleep.value = player.player_needs.current_sleep

	_update_ammo()
	_update_hint()


func _update_ammo() -> void:
	var weapon : Weapon = player.get_current_weapon() as Weapon
	if weapon == null or weapon.weapon_type == Weapon.WEAPON_TYPE.MELEE:
		ammo_count.hide()
		return
	ammo_count.show()
	ammo_count.text = "%d/%d" % [weapon.curr_bullets, player.weapon_controller.get_reserve_ammo()]


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
	if text == "":
		text_hint.text = text
	else:
		text_hint.text = Instructor.get_action_key_bbcode(&"use") 


func toggle_inventory() -> void:
	if inventory.visible:
		close_inventory()
		return
	if player == null or player.is_dead or player.grabber != null:
		return
	inventory.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_input_lock(&"inventory", true)
	inventory_open.emit()


## Cierra el inventario y el loot, y devuelve el control al jugador si sigue vivo.
func close_inventory() -> void:
	var was_open : bool = inventory.visible
	inventory.visible = false
	inventory_ui.close_loot()
	if player:
		player.set_input_lock(&"inventory", false)
		if not player.is_dead:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if was_open:
		inventory_close.emit()


# --- Conexiones desde la escena / otros nodos ------------------------------

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


# --- Game Instructor / Tutorial ------------------------------------------

## Devuelve el sprite de una tecla (Dark = sin pulsar, Light = pulsada) si existe.
func get_key_icon_path(file_name: String, pressed: bool = false) -> String:
	return Instructor.get_key_icon_path(file_name, pressed)


## Devuelve el nombre de archivo de sprite para un evento de entrada, o "" si no hay sprite.
func get_key_sprite_name(event: InputEvent) -> String:
	return Instructor.get_key_sprite_name(event)


## BBCode de la tecla asociada a una acción (sprite si existe; si no, texto).
func get_action_key_bbcode(action: StringName, pressed: bool = false, img_size: int = 40) -> String:
	return Instructor.get_action_key_bbcode(action, pressed, img_size)


## Crea o reemplaza una pista del instructor registrada por 'id'.
func show_hint(id: StringName, builder: Callable) -> RichTextLabel:
	hide_hint(id)
	var instructor: RichTextLabel = INSTRUCTOR.instantiate() as RichTextLabel
	instructor.hint_id = id
	instructor_container.add_child(instructor)
	builder.call(instructor)
	_hints_by_id[id] = instructor
	return instructor


## Pista anclada a un objetivo 3D (objeto a recoger, enemigo, etc.).
func show_world_hint(id: StringName, target: Node3D, label: String, icon_path: String = INSTRUCTOR_ICON_WARN) -> RichTextLabel:
	return show_hint(id, func(instructor: RichTextLabel) -> void:
		instructor.set_target(target, label, icon_path)
	)


## Pista fija en pantalla (sin señalar un objeto), ideal para indicar teclas.
## Si ya existe, actualiza solo el contenido (permite refresco por frame, p. ej. tecla pulsada).
func show_screen_hint(id: StringName, label: String, icon_path: String = "", anchor_preset: int = Control.PRESET_CENTER_BOTTOM, anchor_offset: Vector2 = Vector2(0, -120)) -> RichTextLabel:
	if _hints_by_id.has(id):
		var existing: Variant = _hints_by_id[id]
		if existing is RichTextLabel and is_instance_valid(existing):
			var existing_hint: RichTextLabel = existing as RichTextLabel
			existing_hint.update_label(label, icon_path)
			return existing_hint
		_hints_by_id.erase(id)
	return show_hint(id, func(instructor: RichTextLabel) -> void:
		instructor.set_screen(label, icon_path, anchor_preset, anchor_offset)
	)


## Cierra una pista por id.
func hide_hint(id: StringName) -> void:
	if not _hints_by_id.has(id):
		return
	var instructor_obj: Variant = _hints_by_id[id]
	_hints_by_id.erase(id)
	if instructor_obj is Node and is_instance_valid(instructor_obj):
		(instructor_obj as Node).queue_free()


## Cierra todas las pistas cuyo objetivo 3D sea 'body'.
func hide_hints_for_target(body: Node3D) -> void:
	for instructor_node: Node in instructor_container.get_children():
		if instructor_node.get("target") == body:
			var hid: StringName = StringName(instructor_node.get("hint_id"))
			if hid != &"":
				_hints_by_id.erase(hid)
			instructor_node.set("target", null)


func _on_item_instruct_body_entered(body: Node3D) -> void:
	var label: String = ""
	# El cuerpo que entra en el área ES el PickableItem (raíz RigidBody3D, D-009).
	var pickable: PickableItem = body as PickableItem
	if pickable and pickable.item_descriptor:
		label = pickable.item_descriptor.item_name
	elif body is ContainerInteractable:
		label = body.name
	else:
		return
	var id: StringName = StringName("target_%d" % body.get_instance_id())
	show_world_hint(id, body, label, INSTRUCTOR_ICON_WARN)


func _on_item_instruct_body_exited(body: Node3D) -> void:
	hide_hints_for_target(body)


func _on_grabbed_progress_changed(value: float) -> void:
	key_struggle.text = _key_of("struggle")
	sturggle_progress.value = value
	if sturggle_progress.value >= 1.0:
		sturggle_progress.hide()


func _on_grabbed_progress_show() -> void:
	sturggle_progress.show()
	sturggle_progress.value = 0.0

@onready var screen_splatter: TextureRect = %screen_splatter

func _on_player_attacked_close() -> void:
	var tween = create_tween()
	screen_splatter.show()
	tween.tween_property(screen_splatter,"modulate:a",1.0,0)
	tween.tween_property(screen_splatter,"modulate:a",0.0,2)


func _on_player_player_death() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	close_inventory()
	vignette.show()
	var tween = create_tween()
	tween.tween_property(vignette.material,"shader_parameter/intensity",1.0,.25)
	await tween.finished
	death_screen.show()
	set_process_input(false)
@onready var death_screen: PanelContainer = %DeathScreen

func _on_restart_pressed() -> void:
	if player.health_component.current_health <= 0:
		get_tree().reload_current_scene()
		set_process_input(true)
		vignette.hide()
