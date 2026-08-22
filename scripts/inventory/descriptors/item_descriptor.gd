
@abstract
class_name ItemDescriptor extends Resource

@export var item_name: String
@export var icon: Texture2D 
@export var weight: float
@export var max_stack: int = 1
@export var dimensions : Vector2i = Vector2i(1,1)

@export var item_mesh : PackedScene

@export var container_capability: ContainerCapability  # null = no es contenedor

func get_tooltip_lines() -> Array[String]:
	return ["[b]"+item_name.to_upper()+"[/b]", "Tamaño: "+ "[color=yellow]" + "%dx%d" % [dimensions.x,dimensions.y] + "[/color]" ]
