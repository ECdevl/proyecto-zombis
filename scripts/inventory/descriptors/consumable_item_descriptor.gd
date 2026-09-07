class_name ConsumableItemDescriptor extends ItemDescriptor

@export var effect_amount: float
@export var effect_duration: float
@export var consume_type: ConsumeType

enum ConsumeType { EAT, DRINK, HEAL }  # esto sí puede seguir siendo enum, son variantes del mismo comportamiento

func get_tooltip_lines() -> Array[String]:
	var lines = super.get_tooltip_lines()
	var consume_name : String
	match consume_type:
		ConsumeType.EAT:
			consume_name = "Hambre"
		ConsumeType.DRINK:
			consume_name = "Sed"
		ConsumeType.HEAL:
			consume_name = "Salud"
	lines.append_array([consume_name+": "+"[color=green]"+str(int(effect_amount))+"[/color]"])
	return lines

func get_actions() -> Array[String]:
	var actions = super.get_actions()
	actions.append("usar")
	return actions
