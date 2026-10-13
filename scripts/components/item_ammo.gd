class_name AmmoItemDescriptor extends ItemDescriptor

@export var ammo_type: Weapon.AMMO_TYPE
@export var rounds: int = 30  # balas que contiene este objeto

func get_tooltip_lines() -> Array[String]:
	var lines = super.get_tooltip_lines()
	lines.append("Balas: [color=yellow]%d[/color]" % rounds)
	return lines
