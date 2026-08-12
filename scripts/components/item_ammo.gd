extends Item
class_name ItemAmmo

@export_category("AMMO ITEM")
@export var ammo_contains : int = 1
@export var ammo_type : GameManager.AmmoType


func get_actions() -> Array[StringName]:
	return [&"drop",&"move"]
