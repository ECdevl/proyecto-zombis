extends PanelContainer 

var resource : ItemDescriptor
@onready var rich_label: RichTextLabel = %rich_label


func _ready() -> void:
	rich_label.bbcode_enabled = true

	var tooltip_lines : Array[String] = resource.get_tooltip_lines()
	for line in tooltip_lines:
		rich_label.text = "\n".join(tooltip_lines)



func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position()
