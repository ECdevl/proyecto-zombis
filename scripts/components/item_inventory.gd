# item.gd (base)
extends Resource
class_name Item

@export var item_name : String
@export var icon : Texture2D = preload("res://Assets/Ashtons dev textures/dev_blue (copia 1).png")
@export var weight : float = 0.1
@export var stack : int = 1
@export var stack_max : int = 1
@export var item_mesh : PackedScene

func get_actions() -> Array[StringName]:
	return [&"drop",&"move"]
