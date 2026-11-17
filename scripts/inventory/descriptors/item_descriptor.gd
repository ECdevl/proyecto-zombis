@abstract
class_name ItemDescriptor extends Resource
## FICHA de un tipo de objeto: datos fijos, compartidos por todas las copias.
## Nunca guardar estado acá. El estado de cada objeto real vive en ItemInstance.

## Escena liviana del generador automático. El estudio manual es icon_creator.tscn.
const ICON_CREATOR = preload("res://scenes/ui/icon_creator_auto.tscn")

## Se emite cuando termina un intento de generación automática. Los objetos que
## pidieron el ícono mientras ya se estaba generando esperan esta señal en vez
## de volver con la textura en null.
signal icon_ready

@export var item_name: String
## Ícono MANUAL del objeto (opcional). Se asigna desde el inspector del .tres
## arrastrando una textura. Si queda vacío, ensure_icon() genera el ícono
## automático desde item_mesh y la UI usa ese.
@export var icon: Texture2D
@export var weight: float
@export var max_stack: int = 1
@export var dimensions := Vector2i(1, 1)
## Malla del objeto en el mundo (el ArrayMesh del modelo importado, FBX).
## Al soltarlo, PickableItem la vuelca en su hijo "Malla"; para decorarla
## (rotarla, posicionarla) se puede ver en el editor asignando el descriptor
## a una instancia de pickable_object.tscn (script con @tool).
@export var item_mesh: Mesh
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


## Ícono automático generado en runtime desde item_mesh. Es solo caché de esta
## sesión: no se exporta ni se guarda en el .tres.
var _auto_icon: Texture2D

## Mientras se genera el icono, no volver a entrar (el _ready del objeto que
## llama puede disparar ensure_icon otra vez).
var _icon_requesting: bool = false


## Ícono que debe mostrar la UI: el manual si el usuario asignó uno; si no, el
## automático generado desde la malla. null mientras no haya ninguno de los dos.
func get_icon() -> Texture2D:
	return icon if icon != null else _auto_icon


## Genera el icono desde item_mesh la primera vez. 'host' = nodo que ya está en el árbol.
func ensure_icon(host: Node) -> void:
	if get_icon() != null or item_mesh == null:
		return
	if _icon_requesting:
		await icon_ready
		return
	if DisplayServer.get_name() == "headless":
		return
	if not is_instance_valid(host) or not host.is_inside_tree():
		return
	_icon_requesting = true
	var creator: Variant = ICON_CREATOR.instantiate()
	host.add_child(creator)
	# Malla temporal con el mismo look que tendrá en el mundo (decorar_malla).
	var malla: MeshInstance3D = MeshInstance3D.new()
	malla.mesh = item_mesh
	decorar_malla(malla)
	var generated: Texture2D = await creator.create_texture(malla)
	if generated != null:
		_auto_icon = generated
	_icon_requesting = false
	icon_ready.emit()


## Hook de decoración: cada tipo de objeto puede darle un look propio a la
## malla de ESTA instancia (la ropa elige color, por ejemplo). Se llama con la
## malla ya asignada y antes de mostrarla: en el editor, en el ícono y en el
## mundo. Implementación base: no hace nada.
func decorar_malla(_malla: MeshInstance3D) -> void:
	pass
