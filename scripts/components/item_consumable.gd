extends Item
class_name ItemConsumable
enum Stats {HEALTH,STAMINA,HUNGER,THIRST,SLEEP}
@export var stats_affected : Dictionary[Stats,float]
@export var time_consume : float = 5.0

func get_actions() -> Array[StringName]:
	return [&"use",&"drop"]
