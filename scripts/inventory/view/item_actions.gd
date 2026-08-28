extends PanelContainer
class_name ItemActions

@onready var item_icon: TextureRect = %ItemIcon
@onready var buttons_container: VBoxContainer = %ButtonsContainer
@onready var item_actions: VBoxContainer = %ItemActions

signal action_drop(what:ItemVisual)
signal action_use(what:ItemConsumable)

var item : ItemDescriptor
var visual : ItemVisual



func add_action(descriptor:ItemDescriptor) -> void:
	item = descriptor
	for action_name in descriptor.get_actions():
		
		var action_button = Button.new()
		action_button.theme = UI
		action_button.text = action_name
		action_button.connect("pressed",_on_action_presss,CONNECT_APPEND_SOURCE_OBJECT)
		item_icon.texture = descriptor.icon
		buttons_container.add_child(action_button)

func _clear_buttons() -> void:
	for butt in buttons_container.get_children():
		butt.queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			hide()
			_clear_buttons()

func _on_action_presss(button:Button) -> void:
	match button.text:
		"soltar":
			action_drop.emit(visual)
	hide()
	_clear_buttons()
