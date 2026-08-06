extends Item
class_name ItemCloth
enum WearPlace {BACK,HEAD,TORSO,LEGS,FOOT}
@export var can_carry : bool = true
@export var carry_addition : float = 5.0
@export var temperature_resistance : float = 2.0
@export var place : WearPlace
@export var container : ContainerResource
@export var time_consume : float = 3.0

func get_actions() -> Array[StringName]:
	return [&"wear",&"drop",&"move"]
