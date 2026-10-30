@abstract
class_name ItemDescriptor extends Resource
## FICHA de un tipo de objeto: datos fijos, compartidos por todas las copias.
## Nunca guardar estado acá. El estado de cada objeto real vive en ItemInstance.

const ICON_CREATOR = preload("uid://w8pon5lrn51x")

@export var item_name: String
@export var icon: Texture2D
@export var weight: float
@export var max_stack: int = 1
@export var dimensions := Vector2i(1, 1)
@export var item_mesh: PackedScene
## Plantilla de contenedor (mochila, bolso). null = no es contenedor.
## Cada ItemInstance recibe su PROPIA copia.
@export var container_capability: InventoryModel


func get_tooltip_lines() -> Array[String]:
	return [
		"[b]" + item_name.to_upper() + "[/b]",
		"Tamaño: [color=yellow]%dx%d[/color]" % [dimensions.x, dimensions.y],
	]


## Manos que necesita para sostenerse: 0 = no se puede sostener, 1 o 2. Las armas lo sobrescriben.
func get_hands_required() -> int:
	return 0


func get_actions() -> Array[String]:
	return ["soltar"]


## Mientras se genera el icono, no volver a entrar: si 'item_mesh' es una escena
## PickableItem, su _ready llama otra vez a ensure_icon (recursión infinita).
var _icon_requesting := false


## Genera el icono desde item_mesh la primera vez. 'host' = nodo que ya está en el árbol.
func ensure_icon(host: Node) -> void:
	if icon != null or item_mesh == null or _icon_requesting:
		return
	_icon_requesting = true
	var creator: SubViewport = ICON_CREATOR.instantiate()
	host.add_child(creator)
	icon = await creator.create_texture(item_mesh)
	_icon_requesting = false
