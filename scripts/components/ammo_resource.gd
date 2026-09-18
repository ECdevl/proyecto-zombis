extends ItemDescriptor
class_name AmmoDescriptor

@export var type : Weapon.AMMO_TYPE
@export var amount : int = 10

func get_tooltip_lines() -> Array[String]:
	var lines = super.get_tooltip_lines()
	var tipo : String
	match type:
		Weapon.AMMO_TYPE.LOW_CALIBER:
			tipo = "9mm"
		Weapon.AMMO_TYPE.MID_CALIBER:
			tipo = ".45AP"
		Weapon.AMMO_TYPE.HIGH_CALIBER:
			tipo = ".357"
		Weapon.AMMO_TYPE.CAL:
			tipo = ".50CAL"
	lines.append_array(["[color=red]"+tipo+"[/color]"+":"+str(amount)])
	return lines
