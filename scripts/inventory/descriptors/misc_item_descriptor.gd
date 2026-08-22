class_name MiscItemDescriptor extends ItemDescriptor

@export var lore_text: String

func get_tooltip_lines() -> Array[String]:
	var lines = super.get_tooltip_lines()
	lines.append_array([lore_text])
	return lines
