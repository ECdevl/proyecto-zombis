extends Control
class_name HandSlotView
## Slot de mano (izquierda o derecha). Muestra el icono y acepta armas arrastradas.
## Un arma de 2 manos se ve en los dos slots.

@export var hand: HandsModel.Hand
@export var icon_rect: TextureRect

@onready var carried: PlayerCarriedInventories = %PlayerContainers
@onready var controller: InventoryUIController = %InventoryUIController


func _ready() -> void:
	add_to_group("drop_targets")
	mouse_filter = Control.MOUSE_FILTER_STOP
	if icon_rect == null:
		icon_rect = get_child(0) as TextureRect
	carried.hands.changed.connect(_refresh)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		controller.start_hand_drag(hand, icon_rect)
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		controller.open_hand_menu(hand)


func _refresh() -> void:
	var item := carried.hands.get_held(hand)
	icon_rect.texture = item.descriptor.icon if item else null
