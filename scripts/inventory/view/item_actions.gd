extends PanelContainer
class_name ItemActions
## Menú de acciones de un objeto (soltar, usar...). Solo muestra botones y avisa cuál se eligió.

signal action_selected(item: ItemInstance, action: String)

@onready var item_icon: TextureRect = %ItemIcon
@onready var buttons_container: VBoxContainer = %ButtonsContainer

var _item: ItemInstance


## 'extra' = acciones propias del lugar donde está el objeto (ej: "guardar" en una mano).
func open(item: ItemInstance, at: Vector2, extra: Array[String] = []) -> void:
	_clear_buttons()
	_item = item
	item_icon.texture = item.descriptor.icon
	for action in extra + item.descriptor.get_actions():
		var button := Button.new()
		button.text = action
		button.pressed.connect(_on_action_pressed.bind(action))
		buttons_container.add_child(button)
	global_position = at
	show()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		close()


func close() -> void:
	hide()
	_clear_buttons()


func _clear_buttons() -> void:
	for button in buttons_container.get_children():
		buttons_container.remove_child(button)
		button.queue_free()


func _on_action_pressed(action: String) -> void:
	var item := _item
	close()
	action_selected.emit(item, action)
