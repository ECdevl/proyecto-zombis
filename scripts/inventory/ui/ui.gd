extends Control
class_name UI
## HUD: barras, textos de ayuda, munición e "instructor".
## El inventario vive en el Player; el InventoryUIController solo lo muestra.

signal inventory_open
signal inventory_close

const INSTRUCTOR = preload("uid://b6idlm6tyvtrx")

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
	hurt_flash.show()
	hurt_flash.modulate.a = hurt_flash_alpha
	var tween = create_tween()
	tween.tween_property(hurt_flash,"modulate:a",0.0,.25)
	await tween.finished
	hurt_flash.hide()

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
	var weapon := player.get_current_weapon()
	if weapon != Weapon:
		return
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
	# El cuerpo que entra en el área ES el PickableItem (raíz RigidBody3D, D-009).
	var pickable := body as PickableItem
	if pickable and pickable.item_descriptor:
		label = pickable.item_descriptor.item_name
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


func _on_grabbed_progress_changed(value: float) -> void:
	key_struggle.text == _key_of("struggle")
	sturggle_progress.value = value
	if sturggle_progress.value >= 1.0:
		sturggle_progress.hide()


func _on_grabbed_progress_show() -> void:
	sturggle_progress.show()
	sturggle_progress.value = 0.0
